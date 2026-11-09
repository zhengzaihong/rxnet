/*
 * Copyright (c) 2026 Huawei Device Co., Ltd. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE_HW file.
 */

import UIAbility from '@ohos.app.ability.UIAbility';
import window from '@ohos.window';
import display from '@ohos.display';
import Log from '../../../util/Log';
import { FlutterView } from '../../../view/FlutterView';
import FlutterNapi from '../../engine/FlutterNapi';
import { WindowHostContext } from './WindowHostContext';
import { WindowArchetype } from './WindowingUtils';

const TAG = 'FlutterWindowHost'

/**
 * Base class of the per-archetype window hosts — the ETS counterpart of
 * the C++ OHOSWindow hierarchy. Identity fields only (the C++ OHOSWindow
 * field ctor); sizing/lifecycle arrive in later steps.
 */
export abstract class FlutterWindowHost {
  protected readonly ctx: WindowHostContext;
  readonly viewId: number;
  readonly parentViewId: number;
  readonly archetype: WindowArchetype;
  readonly title: string;

  /** The OS window this host materialized (Dialog/Tooltip/Popup: the created
   * SubWindow; Regular ADOPTED: the claimed EntryAbility main window)
  */
  protected window: window.Window | undefined;

  constructor(ctx: WindowHostContext,
              viewId: number,
              parentViewId: number,
              title: string,
              archetype: WindowArchetype) {
    this.ctx = ctx;
    this.viewId = viewId;
    this.parentViewId = parentViewId;
    this.title = title;
    this.archetype = archetype;
  }

  private flutterView: FlutterView | null = null;

  setFlutterView(flutterView: FlutterView): void {
    this.flutterView = flutterView;
  }

  getFlutterView(): FlutterView | null {
    return this.flutterView;
  }

  /** The UIAbility backing this host, when it has one (SPAWNED Regular /
   * modeless Dialog; set by the manager from registerViewAbility). */
  protected ability: UIAbility | undefined;

  setAbility(ability: UIAbility): void {
    this.ability = ability;
  }

  /** Sets the OS window directly (the shared mount primitive — pushed by
   * registerViewAbility for SPAWNED hosts and used by attachMainWindow for
   * the ADOPTED view-0 host; undefined is a no-op). Callers resolve the
   * windowStage → main-window conversion and its failures. */
  setWindow(window: window.Window | undefined): void {
    this.window = window;
  }

  /** Materializes the OS window host (async: the OS window is created, the
   * view attached to the shared engine, the page loaded, the window shown). */
  abstract attach(): Promise<void>;

  /** The OHOS Window backing this view, or null before the host materializes
   * or after teardown. */
  getWindow(): window.Window | null {
    return this.window ?? null;
  }

  /** Dart-visible destroy (napi destroyWindowHost): synchronous native
   * detach, drop bookkeeping, then the per-host closeHost() teardown
   * (subwindow destroyWindow / SPAWNED ability terminateSelf). Idempotent —
   * the WINDOW_DESTROYED → handleOsClosed chain may re-run parts. */
  destroy(): void {
    this.detachView();
    this.cleanupBookkeeping();
    this.closeHost();
  }

  /** Per-host OS teardown, run LAST on the destroy path. Subclass hooks:
   * subwindow hosts drop their sub-window, RegularWindowHost terminates a
   * SPAWNED ability. Base no-op — hosts whose OS window dies with the view
   * (OS-close path) need nothing. */
  protected closeHost(): void {
  }

  /** Ability-level cascade close (cascadeCloseChildren): synchronous native
   * detach FIRST (crash-safety), then the destroy path's teardown. */
  closeForCascade(parentAbility: UIAbility): void {
    this.detachView();
    this.cleanupBookkeeping();
    this.closeHostForCascade(parentAbility);
  }

  /** Cascade variant of closeHost (the cascade parent is spared). */
  protected closeHostForCascade(_parentAbility: UIAbility): void {
    this.closeHost();
  }

  /** OS-initiated destruction: report to native (Dart `destroyed` flips and
   * unregister runs), detach, drop bookkeeping. */
  handleOsClosed(): void {
    FlutterNapi.nativeHandleOsWindowClosed(this.viewId);
    this.detachView();
    this.cleanupBookkeeping();
  }

  /** Density of the given window's display (physical px per logical px);
   * 1.0 when the display is unavailable. Protected seam: tests override to
   * a fixed factor. */
  protected densityPixels(win: window.Window | undefined): number {
    try {
      const displayId = win?.getWindowProperties()?.displayId;
      return display.getDisplayByIdSync(displayId ?? -1).densityPixels;
    } catch (e) {
      Log.w(TAG, `densityPixels: display unavailable: ${JSON.stringify(e)}`);
      return 1.0;
    }
  }

  protected getWindowSizeForClientSize(client_size: window.Size,
                                       smallest: window.Size | undefined,
                                       biggest: window.Size | undefined,
                                       owner_window: window.Window | undefined = undefined):
    window.Size | undefined {
    if (client_size.width <= 0 || client_size.height <= 0) {
      return undefined;
    }
    const scale = this.densityPixels(owner_window);
    let width = Math.round(client_size.width * scale);
    let height = Math.round(client_size.height * scale);
    // Apply size constraints.
    if (smallest !== undefined) {
      const min_physical_size = this.ClampToVirtualScreen(
        { width: smallest.width * scale, height: smallest.height * scale });
      width = Math.max(width, min_physical_size.width);
      height = Math.max(height, min_physical_size.height);
    }
    if (biggest !== undefined) {
      const max_physical_size = this.ClampToVirtualScreen(
        { width: biggest.width * scale, height: biggest.height * scale });
      width = Math.min(width, max_physical_size.width);
      height = Math.min(height, max_physical_size.height);
    }
    return { width: width, height: height };
  }

  protected ClampToVirtualScreen(size: window.Size): window.Size {
    try {
      const screen = display.getDefaultDisplaySync();
      return { width: Math.min(Math.max(size.width, 0), screen.width),
               height: Math.min(Math.max(size.height, 0), screen.height) };
    } catch (e) {
      Log.w(TAG, `ClampToVirtualScreen: display unavailable: ${JSON.stringify(e)}`);
      return size;
    }
  }

  detachView(): void {
    const fv = this.getFlutterView();
    if (fv) {
      try {
        fv.detachFromFlutterEngine();
      } catch (e) {
        Log.w(TAG, `detachFromFlutterEngine threw for ${String(this.viewId)}: ${JSON.stringify(e)}`);
      }
    }
  }

  /** Drops this view's manager/registry bookkeeping (idempotent). */
  protected cleanupBookkeeping(): void {
    const fv = this.getFlutterView();
    if (fv != null) {
      this.ctx.deleteFlutterView(String(this.viewId), fv);
    }
    this.ctx.removeHost(this.viewId);
    this.ctx.deleteViewAbility(this.viewId);
  }

  /** Attach failed after C++ CreateWindow already handed the view id to
   * Dart: report via the OS-close channel so Dart `destroyed` flips and
   * unregister runs, then drop this host's bookkeeping. */
  protected failAttach(where: string): void {
    try {
      FlutterNapi.nativeHandleOsWindowClosed(this.viewId);
    } catch (e) {
      Log.w(TAG, `${where}: nativeHandleOsWindowClosed failed for ${String(this.viewId)}: ${JSON.stringify(e)}`);
    }
    this.cleanupBookkeeping();
  }

  protected getDecorHeightPx(win: window.Window | undefined): number {
    if (win === undefined) {
      return 0;
    }
    try {
      const decorVp = win.getWindowDecorHeight();
      return Math.round(decorVp * this.densityPixels(win));
    } catch (e) {
      return 0;
    }
  }

  private windowLimits: window.WindowLimits = {
    maxWidth: 0,
    maxHeight: 0,
    minWidth: 0,
    minHeight: 0,
  };

  setWindowSize(width: number, height: number): void {
    if (!this.window) {
      Log.e(TAG, `setWindowSize: no window for viewId=${String(this.viewId)}`);
      return;
    }
    const minW = this.windowLimits.minWidth ?? 0;
    const minH = this.windowLimits.minHeight ?? 0;
    const maxW = this.windowLimits.maxWidth ?? 0;
    const maxH = this.windowLimits.maxHeight ?? 0;
    let smallest: window.Size | undefined = undefined;
    let biggest: window.Size | undefined = undefined;
    if (minW > 0 || minH > 0) {
      smallest = { width: minW, height: minH };
    }
    if (maxW > 0 || maxH > 0) {
      biggest = { width: maxW, height: maxH };
    }
    const size = this.getWindowSizeForClientSize({ width: width, height: height },
      smallest, biggest, this.window);
    if (size === undefined) {
      return;
    }
    // Client → outer frame: keep Dart's content height under the title bar.
    size.height += this.getDecorHeightPx(this.window);
    this.window.resize(size.width, size.height).catch((e: Object) => {
      Log.w(TAG, `setWindowSize failed viewId=${String(this.viewId)}: ${JSON.stringify(e)}`);
    });
  }

  setWindowLimits(limits: window.WindowLimits): void {
    this.windowLimits = limits;
    if (!this.window) {
      Log.e(TAG, `setWindowLimits: no window for viewId=${String(this.viewId)}`);
      return;
    }
    const dpr = this.densityPixels(this.window);
    const phys: window.WindowLimits = {
      maxWidth: Math.round((limits.maxWidth ?? 0) * dpr),
      maxHeight: Math.round((limits.maxHeight ?? 0) * dpr),
      minWidth: Math.round((limits.minWidth ?? 0) * dpr),
      minHeight: Math.round((limits.minHeight ?? 0) * dpr),
    };
    this.window.setWindowLimits(phys).catch((e: Object) => {
      Log.w(TAG, `setWindowLimits failed viewId=${String(this.viewId)}: ${JSON.stringify(e)}`);
    });
  }

  /** Brings this window to the front (Dart Window.activate → napi
   * activateWindow). showWindow re-raises an existing window without
   * recreating it; best-effort. */
  activate(): void {
    if (!this.window) {
      Log.e(TAG, `activate: no window for viewId=${String(this.viewId)}`);
      return;
    }
    this.window.showWindow().catch((e: Object) => {
      Log.w(TAG, `activate failed viewId=${String(this.viewId)}: ${JSON.stringify(e)}`);
    });
  }

  setWindowTitle(title?: string): void {
    // Base no-op; hosts with an OS titlebar (dialog / ability) override
  }

  setWindowMaximized(maximized: boolean): void {
    if (maximized && this.archetype === WindowArchetype.DIALOG) {
      // Win32 dialogs carry no WS_MAXIMIZEBOX (host_window_dialog.cc):
      // the maximize direction is refused; restore stays reachable.
      Log.w(TAG, `setWindowMaximized: dialogs cannot be maximized (viewId=${String(this.viewId)})`);
      return;
    }
    if (!this.window) {
      Log.e(TAG, `setWindowMaximized: no window for viewId=${String(this.viewId)}`);
      return;
    }
    const op = maximized ? this.window.maximize() : this.window.restore();
    op.catch((e: Object) => {
      Log.w(TAG, `setWindowMaximized failed viewId=${String(this.viewId)}: ${JSON.stringify(e)}`);
    });
  }

  setWindowMinimized(minimized: boolean): void {
    if (!this.window) {
      Log.e(TAG, `setWindowMinimized: no window for viewId=${String(this.viewId)}`);
      return;
    }
    const op = minimized ? this.window.minimize() : this.window.restore();
    op.catch((e: Object) => {
      Log.w(TAG, `setWindowMinimized failed viewId=${String(this.viewId)}: ${JSON.stringify(e)}`);
    });
  }

  setWindowFullscreen(fullscreen: boolean): void {
    if (this.archetype === WindowArchetype.DIALOG) {
      // HostWindowDialog::SetFullscreen is a hard no-op — dialogs never go
      // fullscreen (win32 host_window_dialog.cc; DialogCanNeverBeFullscreen).
      Log.w(TAG, `setWindowFullscreen: no-op for dialog (viewId=${String(this.viewId)})`);
      return;
    }
    if (!this.window) {
      Log.e(TAG, `setWindowFullscreen: no window for viewId=${String(this.viewId)}`);
      return;
    }
    this.window.setFullScreen(fullscreen).catch((e: Object) => {
      Log.w(TAG, `setWindowFullscreen failed viewId=${String(this.viewId)}: ${JSON.stringify(e)}`);
    });
  }
}
