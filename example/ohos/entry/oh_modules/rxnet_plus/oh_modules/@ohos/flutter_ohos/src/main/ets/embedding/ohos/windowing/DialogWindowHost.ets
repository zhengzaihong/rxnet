/*
 * Copyright (c) 2026 Huawei Device Co., Ltd. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE_HW file.
 */

import window from '@ohos.window';
import { BusinessError } from '@ohos.base';
import Log from '../../../util/Log';
import { FlutterView } from '../../../view/FlutterView';
import { FlutterWindowHost } from './FlutterWindowHost';
import { WindowHostContext } from './WindowHostContext';
import { DialogWindowCreationRequest,
  WindowArchetype, WindowConstraints, WindowSizeRequest } from './WindowingUtils';

const TAG = 'DialogWindowHost'

const SUB_WINDOW_NAME_PREFIX: string = 'Dialog-';

const NESTED_DIALOG_CASCADE_PX: number = 20;


/**
 * MODAL dialog host (SubWindow path; a no-parent/modeless request is routed
 * to a spawned RegularWindowHost in FlutterManager.createDialogWindow — this
 * host always has a VALID parentViewId). 
 */
export class DialogWindowHost extends FlutterWindowHost {
  protected readonly request: DialogWindowCreationRequest;
  private readonly parentWnd: window.Window | undefined;

  constructor(ctx: WindowHostContext, viewId: number, request: DialogWindowCreationRequest) {
    super(ctx, viewId, request.parentViewId, request.title, WindowArchetype.DIALOG);
    this.request = request;
    this.parentWnd = ctx.getHostWindowByView(request.parentViewId)?.getWindow() ?? undefined;
  }

  async attach(): Promise<void> {
    if (this.parentWnd === undefined) {
      Log.e(TAG, `attach: no parent window for parentViewId=${this.parentViewId}`);
      this.failAttach('attach: no parent window');
      return;
    }

    const rect = this.getInitialRect(this.request.preferredSize, this.request.preferredConstraints, this.parentWnd);
    rect.left -= NESTED_DIALOG_CASCADE_PX;
    rect.top -= NESTED_DIALOG_CASCADE_PX; // offset the dialog to cascade from the parent window
    const options: window.SubWindowOptions = {
      title: this.title,
      decorEnabled: false,
      isModal: true,
      modalityType: window.ModalityType.WINDOW_MODALITY,
      maximizeSupported: false,
    };
    // 0×0 (no preferred size / no owner props) → omit; the system decides.
    if (rect.width > 0 && rect.height > 0) {
      options.windowRect = rect;
    }

    let subWindow: window.Window;
    try {
      subWindow = await this.parentWnd.createSubWindowWithOptions(
        SUB_WINDOW_NAME_PREFIX + String(this.viewId), options);
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
    try {
      await subWindow.loadContent(this.ctx.subWindowPage(), storage);
      await subWindow.showWindow();
      subWindow.on('windowEvent', (event: window.WindowEventType) => {
        if (event === window.WindowEventType.WINDOW_DESTROYED) {
          this.handleOsClosed();
        }
      });
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
    // Attach to the SAME engine as the parent (single-engine, multi-view)
    if (!fv.isAttachedToFlutterEngine()) {
      const engine = parentView.getFlutterEngine();
      if (engine === null) {
        Log.e(TAG, `viewAttachEngine: parent view ${this.parentViewId} engine unavailable for sub-view ${String(this.viewId)}`);
        this.failAttach('viewAttachEngine: no engine for parent view');
        return false;
      }
      fv.attachToFlutterEngine(engine);
    }
    return true;
  }

  getInitialRect(preferred_size: WindowSizeRequest,
                 constraints: WindowConstraints,
                 owner_window: window.Window | undefined): window.Rect {
    let owner_props: window.WindowProperties | undefined = undefined;
    if (owner_window !== undefined) {
      try {
        owner_props = owner_window.getWindowProperties();
      } catch (e) {
        Log.w(TAG, `getInitialRect: owner properties unavailable for ${String(this.viewId)}: ` +
          `${JSON.stringify(e)}`);
      }
    }
    let smallest: window.Size | undefined = undefined;
    let biggest: window.Size | undefined = undefined;
    if (constraints.hasViewConstraints) {
      smallest = { width: constraints.viewMinWidth, height: constraints.viewMinHeight };
      biggest = { width: constraints.viewMaxWidth, height: constraints.viewMaxHeight };
    }
    const window_size = this.getWindowSizeForClientSize(
      { width: preferred_size.preferredViewWidth, height: preferred_size.preferredViewHeight },
      smallest, biggest, owner_window);
    // Origin 0,0 == "system decides" (win32 CW_USEDEFAULT); only a known
    // owner + a known size pin the dialog centered over the owner.
    const window_origin: window.Position = { x: 0, y: 0 };
    if (window_size !== undefined && owner_props !== undefined) {
      const frame: window.Rect = owner_props.windowRect;
      window_origin.x = Math.round(frame.left + (frame.width - window_size.width) * 0.5);
      window_origin.y = Math.round(frame.top + (frame.height - window_size.height) * 0.5);
    }
    return { left: window_origin.x, top: window_origin.y,
             width: window_size?.width ?? 0, height: window_size?.height ?? 0 };
  }

  /**
   * Late failures (load/resize/show) may leave an OS sub-window behind —
   * destroy it so no hidden, never-rendering host lingers; early failures
   * have no window yet and take the base path only.
   */
  protected failAttach(where: string): void {
    if (this.window !== undefined) {
      this.detachView();
      this.closeHost();
    }
    super.failAttach(where);
  }

  /** Drops the OS sub-window. Best-effort: the callback form is the only
   * OS-level teardown for a SubWindow. */
  protected closeHost(): void {
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
