/*
 * Copyright (c) 2026 Huawei Device Co., Ltd. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE_HW file.
 */

import window from '@ohos.window';
import display from '@ohos.display';
import { BusinessError } from '@ohos.base';
import Log from '../../../util/Log';
import { FlutterView } from '../../../view/FlutterView';
import FlutterNapi, { WindowPositionResult } from '../../engine/FlutterNapi';
import { FlutterWindowHost } from './FlutterWindowHost';
import { WindowHostContext } from './WindowHostContext';
import { TooltipWindowCreationRequest, WindowArchetype } from './WindowingUtils';

const TAG = 'TooltipWindowHost'

const SUB_WINDOW_NAME_PREFIX: string = 'Tooltip-';

const kBirthOffscreenPx: number = -10000;

/** Placement outcome in physical px; placed=false → system default. */
export class BirthPlacement {
  rect: window.Rect = { left: 0, top: 0, width: 0, height: 0 };
  placed: boolean = false;
}

/** A parent-bound, decoration-free, never-focusable SubWindow. */
export class TooltipWindowHost extends FlutterWindowHost {
  protected readonly request: TooltipWindowCreationRequest;

  private contentWidthPx: number = 0;
  private contentHeightPx: number = 0;

  private positionInFlight: boolean = false;
  private positionPending: boolean = false;

  private surfaceStorage: LocalStorage | null = null;
  private lastLeft: number = NaN;
  private lastTop: number = NaN;
  private lastWidth: number = NaN;
  private lastHeight: number = NaN;
  private placedOnScreen: boolean = false;

  private parentWnd: window.Window | null = null;
  private parentWindowEventHandler: ((event: window.WindowEventType) => void) | null = null;
  private parentSizeChangedHandler: ((size: window.Size) => void) | null = null;

  constructor(ctx: WindowHostContext, viewId: number, request: TooltipWindowCreationRequest) {
    super(ctx, viewId, request.parentViewId, '', WindowArchetype.TOOLTIP);
    this.request = request;
  }

  async attach(): Promise<void> {
    const parentWnd = this.ctx.getHostWindowByView(this.parentViewId)?.getWindow() ?? undefined;
    if (parentWnd === undefined) {
      Log.e(TAG, `attach: no parent window for parentViewId=${this.parentViewId}`);
      this.failAttach('attach: no parent window');
      return;
    }

    const size = this.getWindowSizeForClientSize(this.initialWindowRect(), undefined, undefined, parentWnd);
    const rect: window.Rect = {
      left: kBirthOffscreenPx, top: kBirthOffscreenPx,
      width: size?.width ?? 0, height: size?.height ?? 0,
    };
    const options: window.SubWindowOptions = {
      title: SUB_WINDOW_NAME_PREFIX + String(this.viewId),
      decorEnabled: false,
      isModal: false,
      maximizeSupported: false,
    };
    if (rect.width > 0 && rect.height > 0) {
      options.windowRect = rect;
    }

    let subWindow: window.Window;
    try {
      subWindow = await parentWnd.createSubWindowWithOptions(SUB_WINDOW_NAME_PREFIX + String(this.viewId), options);
    } catch (e) {
      const err = e as BusinessError;
      Log.e(TAG, `createSubWindowWithOptions failed for ${String(this.viewId)}: ${JSON.stringify(err)}`);
      this.failAttach('createSubWindowWithOptions');
      return;
    }
    this.window = subWindow;

    if (!this.viewAttachEngine()) {
      return;
    }

    const storage = new LocalStorage();
    storage.setOrCreate('viewId', String(this.viewId));
    this.surfaceStorage = storage;
    const surface = this.initialSurfaceSize(parentWnd);
    const dpr = this.densityPixels(parentWnd);
    const disp = display.getDefaultDisplaySync();
    storage.setOrCreate('surfaceWidth', Math.min(Math.round(surface.width * dpr), disp.width));
    storage.setOrCreate('surfaceHeight', Math.min(Math.round(surface.height * dpr), disp.height));
    try {
      await subWindow.loadContent(this.ctx.subWindowPage(), storage);
      try {
        await subWindow.setWindowFocusable(false);
      } catch (e) {
        Log.w(TAG, `setWindowFocusable(false) failed for ${String(this.viewId)}: ${JSON.stringify(e)}`);
      }
      const showOptions: window.ShowWindowOptions = { focusOnShow: false };
      await subWindow.showWindow(showOptions);
      await this.setWindowStyle(subWindow);
      subWindow.on('windowSizeChange', (size: window.Size) => {
        storage.setOrCreate('windowWidth', size.width);
        storage.setOrCreate('windowHeight', size.height);
      });
      subWindow.on('windowEvent', (event: window.WindowEventType) => {
        if (event === window.WindowEventType.WINDOW_DESTROYED) {
          this.handleOsClosed();
        }
      });
      this.registerParentWndEvent(parentWnd);
    } catch (e) {
      const err = e as BusinessError;
      Log.e(TAG, `loadContent/showWindow failed for ${String(this.viewId)}: ${JSON.stringify(err)}`);
      this.failAttach('loadContent/showWindow');
      return;
    }
  }

  private viewAttachEngine(): boolean {
    const parentView = this.ctx.getHostWindowByView(this.parentViewId)?.getFlutterView() ?? null;
    if (parentView === null) {
      Log.e(TAG, `viewAttachEngine: no parent view ${this.parentViewId} for sub-view ${String(this.viewId)}`);
      this.failAttach('viewAttachEngine: no parent view');
      return false;
    }
    let fv = this.ctx.getFlutterView(String(this.viewId));
    if (fv === null) {
      fv = new FlutterView(String(this.viewId), parentView.getContext());
      this.ctx.registerFlutterView(String(this.viewId), fv);
    }
    if (!fv.isAttachedToFlutterEngine()) {
      const engine = parentView.getFlutterEngine();
      if (engine === null) {
        Log.e(TAG, `viewAttachEngine: parent view ${this.parentViewId} engine unavailable for sub-view ${String(this.viewId)}`);
        this.failAttach('viewAttachEngine: no engine for parent view');
        return false;
      }
      // Keep the engine-wide text input handler across this view's attach.
      const channel = engine.getTextInputChannel();
      const previousHandler = channel !== null ? channel.textInputMethodHandler : null;
      fv.attachToFlutterEngine(engine);
      if (channel !== null) {
        channel.setTextInputMethodHandler(previousHandler);
      }
    }
    return true;
  }

  private initialWindowRect(): window.Size {
    const c = this.request.preferredConstraints;
    const width = c.hasViewConstraints && c.viewMinWidth > 0 ? c.viewMinWidth : 400;
    const height = c.hasViewConstraints && c.viewMinHeight > 0 ? c.viewMinHeight : 200;
    return { width: width, height: height };
  }

  private initialSurfaceSize(parentWnd: window.Window): window.Size {
    const c = this.request.preferredConstraints;
    const maxW = c.hasViewConstraints && Number.isFinite(c.viewMaxWidth) ? c.viewMaxWidth : 0;
    const maxH = c.hasViewConstraints && Number.isFinite(c.viewMaxHeight) ? c.viewMaxHeight : 0;
    const minW = c.hasViewConstraints && c.viewMinWidth > 0 ? c.viewMinWidth : 0;
    const minH = c.hasViewConstraints && c.viewMinHeight > 0 ? c.viewMinHeight : 0;
    const dr = parentWnd.getWindowProperties().drawableRect;
    const dpr = this.densityPixels(parentWnd);
    const fallbackW = dr.width / dpr;
    const fallbackH = dr.height / dpr;
    const width = maxW > 0 ? maxW : (minW > 0 ? minW : fallbackW);
    const height = maxH > 0 ? maxH : (minH > 0 ? minH : fallbackH);
    return { width: width, height: height };
  }

  detachView(): void {
    // Keep the engine-wide text input handler across this view's teardown.
    const fv = this.getFlutterView();
    const channel = fv !== null ? fv.getFlutterEngine()?.getTextInputChannel() ?? null : null;
    const previousHandler = channel !== null ? channel.textInputMethodHandler : null;
    super.detachView();
    if (channel !== null && previousHandler !== null) {
      channel.setTextInputMethodHandler(previousHandler);
    }
  }

  // ---- Placement ------------------------------------------------------------

  protected async computePlacementRect(parentWnd: window.Window,
                                       logical: window.Size): Promise<BirthPlacement> {
    const size = this.getWindowSizeForClientSize(logical, undefined, undefined, parentWnd);
    const fallback: window.Rect = { left: 0, top: 0, width: size?.width ?? 0, height: size?.height ?? 0 };
    try {
      const props = parentWnd.getWindowProperties();
      const frame = props.windowRect;
      const dr = props.drawableRect;
      const wa = await this.workAreaPhysical();
      const childPhysical: window.Size =
        this.contentWidthPx > 0 && this.contentHeightPx > 0
          ? { width: this.contentWidthPx, height: this.contentHeightPx }
          : { width: fallback.width, height: fallback.height };
      const parentPhysical: window.Rect = {
        left: frame.left + dr.left, top: frame.top + dr.top,
        width: dr.width, height: dr.height,
      };
      const pos = new WindowPositionResult();
      const placed = this.computePlacement(pos, childPhysical, parentPhysical, wa);
      if (!placed) {
        return { rect: fallback, placed: false };
      }
      const rect: window.Rect = {
        left: Math.round(pos.left),
        top: Math.round(pos.top),
        width: pos.width > 0 ? Math.round(pos.width) : fallback.width,
        height: pos.height > 0 ? Math.round(pos.height) : fallback.height,
      };
      return { rect: rect, placed: true };
    } catch (e) {
      Log.w(TAG, `computePlacementRect failed for ${String(this.viewId)}: ${JSON.stringify(e)}`);
      return { rect: fallback, placed: false };
    }
  }

  /** Screen work area in physical px. */
  protected async workAreaPhysical(): Promise<window.Rect> {
    const disp = display.getDefaultDisplaySync();
    try {
      const wa = await disp.getAvailableArea();
      if (wa.width > 0 && wa.height > 0) {
        return wa;
      }
    } catch (e) {
      Log.w(TAG, `getAvailableArea failed: ${JSON.stringify(e)}; ` +
        `constraining against the FULL display instead`);
    }
    return { left: 0, top: 0, width: disp.width, height: disp.height };
  }

  protected computePlacement(pos: WindowPositionResult,
                             childSize: window.Size,
                             parentRect: window.Rect,
                             workArea: window.Rect): boolean {
    return FlutterNapi.nativeComputeWindowPosition(
      pos, this.viewId, childSize, parentRect, workArea) === 0;
  }

  didUpdateViewSize(widthPx: number, heightPx: number): void {
    if (widthPx === this.contentWidthPx && heightPx === this.contentHeightPx) {
      return;
    }
    this.contentWidthPx = widthPx;
    this.contentHeightPx = heightPx;
    this.surfaceStorage?.setOrCreate('contentWidth', widthPx);
    this.surfaceStorage?.setOrCreate('contentHeight', heightPx);
    this.scheduleUpdatePosition();
  }

  private scheduleUpdatePosition(): void {
    if (this.positionInFlight) {
      this.positionPending = true;
      return;
    }
    this.positionInFlight = true;
    const done = (): void => {
      this.positionInFlight = false;
      if (this.positionPending) {
        this.positionPending = false;
        this.scheduleUpdatePosition();
      }
    };
    this.updatePosition().then(done, done);
  }

  private childLogicalSize(parentWnd: window.Window): window.Size {
    if (this.contentWidthPx > 0 && this.contentHeightPx > 0) {
      const dpr = this.densityPixels(parentWnd);
      return {
        width: this.contentWidthPx / dpr,
        height: this.contentHeightPx / dpr,
      };
    }
    return this.initialWindowRect();
  }

  async updatePosition(): Promise<void> {
    const win = this.window;
    const parentWnd =
      this.ctx.getHostWindowByView(this.parentViewId)?.getWindow() ?? undefined;
    if (win === undefined || parentWnd === undefined) {
      return;
    }
    if (!this.placedOnScreen && this.contentWidthPx <= 0) {
      return;
    }
    try {
      const placement =
        await this.computePlacementRect(parentWnd, this.childLogicalSize(parentWnd));
      if (!placement.placed) {
        return;
      }
      const r = placement.rect;
      if (this.placedOnScreen &&
          r.left === this.lastLeft && r.top === this.lastTop &&
          r.width === this.lastWidth && r.height === this.lastHeight) {
        return;
      }
      if (r.width > 0 && r.height > 0 &&
          (r.width !== this.lastWidth || r.height !== this.lastHeight)) {
        try {
          await win.resizeAsync(r.width, r.height);
          this.lastWidth = r.width;
          this.lastHeight = r.height;
        } catch (e) {
          Log.w(TAG, `resize rejected viewId=${this.viewId} ` +
            `${r.width}x${r.height}px: ${JSON.stringify(e)}`);
        }
      }
      await win.moveWindowToAsync(r.left, r.top);
      this.lastLeft = r.left;
      this.lastTop = r.top;
      this.placedOnScreen = true;
    } catch (e) {
      Log.w(TAG, `updatePosition failed viewId=${String(this.viewId)}: ${JSON.stringify(e)}`);
    }
  }

  // ---- Parent-driven dismissal ----------------------------------------------

  private registerParentWndEvent(parentWnd: window.Window): void {
    this.parentWnd = parentWnd;
    const onEvent = (event: window.WindowEventType) => {
      if (event === window.WindowEventType.WINDOW_INACTIVE ||
          event === window.WindowEventType.WINDOW_HIDDEN ||
          event === window.WindowEventType.WINDOW_DESTROYED) {
        this.closeFromParentEvent();
      }
    };
    // Ignore drag start/end size-same events; only a real resize dismisses.
    let lastWidth = -1;
    let lastHeight = -1;
    try {
      const rect = parentWnd.getWindowProperties().windowRect;
      lastWidth = rect.width;
      lastHeight = rect.height;
    } catch (e) {
      Log.w(TAG, `registerParentWndEvent: parent rect unavailable for ` +
        `${String(this.viewId)}: ${JSON.stringify(e)}`);
    }
    const onSize = (size: window.Size) => {
      const unchanged = lastWidth >= 0 &&
        lastWidth === size.width && lastHeight === size.height;
      lastWidth = size.width;
      lastHeight = size.height;
      if (unchanged) {
        return;
      }
      this.closeFromParentEvent();
    };
    this.parentWindowEventHandler = onEvent;
    this.parentSizeChangedHandler = onSize;
    parentWnd.on('windowEvent', onEvent);
    parentWnd.on('windowSizeChange', onSize);
  }

  private closeFromParentEvent(): void {
    this.unregisterParentWndEvent();
    this.handleOsClosed();
    this.closeHost();
  }

  private unregisterParentWndEvent(): void {
    const parentWnd = this.parentWnd;
    this.parentWnd = null;
    if (parentWnd === null) {
      return;
    }
    // parentWnd non-null ⟺ both handlers were registered by registerParentWndEvent.
    try {
      parentWnd.off('windowEvent', this.parentWindowEventHandler!);
      parentWnd.off('windowSizeChange', this.parentSizeChangedHandler!);
    } catch (e) {
      Log.w(TAG, `unregisterParentWndEvent: off() failed for ${String(this.viewId)}: ${JSON.stringify(e)}`);
    }
  }

  protected async setWindowStyle(subWindow: window.Window): Promise<void> {
    try {
      subWindow.setWindowBackgroundColor('#00000000');
      subWindow.setWindowShadowRadius(0);
      await subWindow.setWindowCornerRadius(0);
    } catch (e) {
      Log.w(TAG, `applyStyle failed for ${String(this.viewId)}: ${JSON.stringify(e)}`);
    }
  }

  protected failAttach(where: string): void {
    if (this.window !== undefined) {
      this.detachView();
      this.closeHost();
    }
    super.failAttach(where);
  }

  protected closeHost(): void {
    this.unregisterParentWndEvent();
    if (this.window === undefined) {
      Log.w(TAG, `closeHost: no sub-window for ${String(this.viewId)} (already closed?)`);
      return;
    }
    try {
      this.window.destroyWindow((err: BusinessError) => {
        if (err && err.code) {
          Log.w(TAG, `closeHost: destroyWindow failed for ${String(this.viewId)}: ${JSON.stringify(err)}`);
        }
      });
    } catch (e) {
      Log.w(TAG, `closeHost: destroyWindow threw for ${String(this.viewId)}: ${JSON.stringify(e)}`);
    }
  }
}
