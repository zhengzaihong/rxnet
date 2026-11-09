/*
 * Copyright (c) 2026 Huawei Device Co., Ltd. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE_HW file.
 */

import window from '@ohos.window';
import UIAbility from '@ohos.app.ability.UIAbility';
import Want from '@ohos.app.ability.Want';
import StartOptions from '@ohos.app.ability.StartOptions';
import Log from '../../../util/Log';
import { FlutterAbility } from '../FlutterAbility';
import FlutterAbilityLaunchConfigs from '../FlutterAbilityLaunchConfigs';
import { FlutterWindowHost } from './FlutterWindowHost';
import { WindowHostContext } from './WindowHostContext';
import { DialogWindowCreationRequest, IMPLICIT_VIEW_ID, NO_PARENT_VIEW_ID,
  RegularWindowCreationRequest, WindowArchetype } from './WindowingUtils';

const TAG = 'RegularWindowHost'

export enum AbilityHostMode {
  /** The FIRST top-level window ADOPTS the EntryAbility's pre-created main
   * window + implicit view 0 instead of spawning a sibling UIAbility. */
  ADOPTED,
  /** A separate UIAbility instance (RegularWindowAbility) is launched. */
  SPAWNED,
}

/**
 * UIAbility-backed host (Regular / modeless Dialog): own task-center card.
 * ADOPTED binds view 0 to the EntryAbility's existing main window; SPAWNED
 * launches its own ability for Regular and modeless Dialog alike (win32
 * HostWindowDialog with no owner == an overlapped window spawned like a
 * regular one — the DIALOG archetype only marks Dart-side semantics).
 */
export class RegularWindowHost extends FlutterWindowHost {
  private readonly mode: AbilityHostMode;
  // SPAWNED hosts take Regular (task-center card) or Dialog (modeless —
  // the sentinel parent case) requests; ADOPTED takes Regular.
  private readonly request: RegularWindowCreationRequest | DialogWindowCreationRequest;

  constructor(ctx: WindowHostContext,
              viewId: number,
              mode: AbilityHostMode,
              request: RegularWindowCreationRequest | DialogWindowCreationRequest,
              archetype: WindowArchetype = WindowArchetype.REGULAR,
              ability?: UIAbility) {
    // A UIAbility host has no parent window (kNoParentViewId on the C++
    // side for Regular; the modeless dialog's sentinel parent is -1 anyway).
    super(ctx, viewId, NO_PARENT_VIEW_ID, request.title, archetype);
    this.mode = mode;
    this.request = request;
    this.ability = ability;
  }

  getAbility(): UIAbility | undefined {
    return this.ability;
  }

  async attach(): Promise<void> {
    if (this.mode === AbilityHostMode.SPAWNED) {
      // Spawn path shared by Regular and modeless Dialog — attachRegularWindow
      // never reads the archetype (only preferredSize / constraints / title,
      // which both request types carry); win32 parity keeps the system-decided
      // origin (CW_USEDEFAULT) for the no-owner dialog.
      await this.attachRegularWindow();
      return;
    }
    // adopt path
    this.attachMainWindow();
  }

  private attachMainWindow(): void {
    const mainView = (this.ability as FlutterAbility)?.getFlutterView();
    if (mainView === null) {
      Log.w(TAG, `attachMainWindow: main view missing for ${String(this.viewId)}`);
    } else {
      this.setFlutterView(mainView); // seed mainWindowHost flutterview not duplicated op
    }
    let main: window.Window | undefined = undefined;
    try {
      main = this.ctx.getWindowStage(this.ability as FlutterAbility)?.getMainWindowSync();
    } catch (e) {
      Log.w(TAG, `attachMainWindow: main window unavailable for ${String(this.viewId)}: ${JSON.stringify(e)}`);
    }
    this.setWindow(main);
    if (this.window === undefined) {
      Log.e(TAG, `attachMainWindow: no window for ${String(this.viewId)}`);
      this.failAttach('attachMainWindow: no window');
      return;
    }
    try {
      this.window.on('windowEvent', (event: window.WindowEventType) => {
        if (event === window.WindowEventType.WINDOW_DESTROYED) {
          this.handleOsClosed();
        }
      });
    } catch (e) {
      Log.w(TAG, `attachMainWindow: windowEvent on() failed for ${String(this.viewId)}: ${JSON.stringify(e)}`);
    }
    this.applyPreferredSize();
  }

  private applyPreferredSize(): void {
    const size = this.request.preferredSize;
    if (!size.hasPreferredViewSize ||
        size.preferredViewWidth <= 0 || size.preferredViewHeight <= 0) {
      return;
    }
    this.setWindowSize(size.preferredViewWidth, size.preferredViewHeight);
  }

  private async attachRegularWindow(): Promise<void> {
    const mainHost = this.ctx.getHostWindowByView(IMPLICIT_VIEW_ID);
    const launcher = mainHost instanceof RegularWindowHost ? mainHost.getAbility() : undefined;
    if (launcher === undefined) {
      Log.e(TAG, `attachRegularWindow: no main-window ability to launch from for ${String(this.viewId)}`);
      this.failAttach('attachRegularWindow: no launcher ability');
      return;
    }
    const parameters: Record<string, Object> = {};
    parameters[FlutterAbilityLaunchConfigs.EXTRA_FLUTTER_VIEW_ID] = String(this.viewId);
    parameters[FlutterAbilityLaunchConfigs.EXTRA_FLUTTER_PREFERRED_WIDTH] =
      this.request.preferredSize.preferredViewWidth;
    parameters[FlutterAbilityLaunchConfigs.EXTRA_FLUTTER_PREFERRED_HEIGHT] =
      this.request.preferredSize.preferredViewHeight;
    if (this.title.length > 0) {
      parameters[FlutterAbilityLaunchConfigs.EXTRA_FLUTTER_WINDOW_TITLE] = this.title;
    }
    // MyAbilityStage.onAcceptWant routes on params['instanceKey'].
    parameters['instanceKey'] = String(this.viewId);
    const want: Want = {
      bundleName: launcher.context.abilityInfo.bundleName,
      abilityName: this.ctx.spawnedAbilityName(),
      parameters: parameters,
    };
    const startOptions: StartOptions = {};
    const constraints = this.request.preferredConstraints;
    let smallest: window.Size | undefined = undefined;
    let biggest: window.Size | undefined = undefined;
    if (constraints.hasViewConstraints) {
      if (constraints.viewMinWidth > 0 || constraints.viewMinHeight > 0) {
        smallest = { width: constraints.viewMinWidth, height: constraints.viewMinHeight };
      }
      if (constraints.viewMaxWidth > 0 || constraints.viewMaxHeight > 0) {
        biggest = { width: constraints.viewMaxWidth, height: constraints.viewMaxHeight };
      }
      const minTrack = this.ClampToVirtualScreen(
        { width: constraints.viewMinWidth, height: constraints.viewMinHeight });
      const maxTrack = this.ClampToVirtualScreen(
        { width: constraints.viewMaxWidth, height: constraints.viewMaxHeight });
      if (constraints.viewMinWidth > 0) {
        startOptions.minWindowWidth = minTrack.width;
      }
      if (constraints.viewMinHeight > 0) {
        startOptions.minWindowHeight = minTrack.height;
      }
      if (constraints.viewMaxWidth > 0) {
        startOptions.maxWindowWidth = maxTrack.width;
      }
      if (constraints.viewMaxHeight > 0) {
        startOptions.maxWindowHeight = maxTrack.height;
      }
    }
    const size = this.getWindowSizeForClientSize(
      { width: this.request.preferredSize.preferredViewWidth,
        height: this.request.preferredSize.preferredViewHeight },
      smallest, biggest, mainHost?.getWindow() ?? undefined);
    if (size !== undefined) {
      startOptions.windowWidth = size.width;
      startOptions.windowHeight = size.height +
        this.getDecorHeightPx(mainHost?.getWindow() ?? undefined);
    }
    try {
      await launcher.context.startAbility(want, startOptions);
    } catch (e) {
      Log.e(TAG, `attachRegularWindow: startAbility failed for ${String(this.viewId)}: ${JSON.stringify(e)}`);
      this.failAttach('attachRegularWindow: startAbility');
      return;
    }
  }

  protected failAttach(where: string): void {
    this.closeHost(); // SPAWNED: best-effort terminate of the half-spawned ability
    super.failAttach(where);
  }

  /** FlutterWindowHost.closeHost: SPAWNED hosts own their UIAbility, so the
   * destroy path terminates it (win32 framework-close parity); ADOPTED hosts
   * must never terminate the EntryAbility. */
  protected closeHost(): void {
    if (this.mode === AbilityHostMode.SPAWNED) {
      this.terminateAbility('closeHost');
    }
  }

  /** closeHost, but never terminates the cascade parent itself. */
  protected closeHostForCascade(parentAbility: UIAbility): void {
    if (this.mode === AbilityHostMode.SPAWNED &&
        (this.ability ?? this.ctx.getAbilityByView(this.viewId)) !== parentAbility) {
      this.terminateAbility('closeHostForCascade');
    }
  }

  private terminateAbility(where: string): void {
    // SPAWNED abilities register in the manager before/without setAbility.
    const ability = this.ability ?? this.ctx.getAbilityByView(this.viewId);
    if (ability === undefined) {
      Log.w(TAG, `${where}: no ability for ${String(this.viewId)} (never launched?)`);
      return;
    }
    try {
      ability.context.terminateSelf().catch((e: Object) => {
        Log.w(TAG, `${where}: terminateSelf rejected for ${String(this.viewId)}: ${JSON.stringify(e)}`);
      });
    } catch (e) {
      Log.w(TAG, `${where}: terminateSelf threw for ${String(this.viewId)}: ${JSON.stringify(e)}`);
    }
  }

  setWindowTitle(title?: string): void {
    const win = this.getWindow();
    if (win === null) {
      Log.w(TAG, `setWindowTitle: no window for ${String(this.viewId)} (registration race?)`);
      return;
    }
    win.setWindowTitle(title).catch((e: Object) => {
      Log.w(TAG, `setWindowTitle failed for ${String(this.viewId)}: ${JSON.stringify(e)}`);
    });
  }
}
