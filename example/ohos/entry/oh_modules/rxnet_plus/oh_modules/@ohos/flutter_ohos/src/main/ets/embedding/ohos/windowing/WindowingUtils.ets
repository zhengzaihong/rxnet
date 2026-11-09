/*
 * Copyright (c) 2026 Huawei Device Co., Ltd. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE_HW file.
 */

import window from '@ohos.window';
import Log from '../../../util/Log';

const TAG = 'WindowingUtils';

/**
 * Shared helpers for the windowing hosts — the extension point for
 * cross-host utilities: add future helpers here instead of new files.
 */

/** LOGICAL-px rect a window is born with — the ETS counterpart of win32's
 * HostWindow::GetInitialRect result (host_window_regular.cc /
 * host_window_dialog.cc). Origin 0,0 == "system decides" (win32
 * CW_USEDEFAULT); width/height 0 == "no size preference" (system default
 * size). */
export class InitialWindowRect {
  left: number = 0;
  top: number = 0;
  width: number = 0;
  height: number = 0;

  constructor(left: number, top: number, width: number, height: number) {
    this.left = left;
    this.top = top;
    this.width = width;
    this.height = height;
  }
}

/** C++ kNoParentViewId (ohos_window_types.h) — -1 can never be a real view
 * id (ids are the implicit 0 or allocated from 1 up), so it means "no
 * parent"; 0 IS a legitimate parent (the adopted main window). */
export const NO_PARENT_VIEW_ID: number = -1;

export const IMPLICIT_VIEW_ID: number = 0;

/** C++ WindowSizeRequest. */
export class WindowSizeRequest {
  hasPreferredViewSize: boolean = false;
  preferredViewWidth: number = 0;
  preferredViewHeight: number = 0;

  constructor(raw?: WindowSizeRequest) {
    this.hasPreferredViewSize = raw?.hasPreferredViewSize ?? false;
    this.preferredViewWidth = raw?.preferredViewWidth ?? 0;
    this.preferredViewHeight = raw?.preferredViewHeight ?? 0;
  }

  toString(): string {
    return this.hasPreferredViewSize
      ? `set(${this.preferredViewWidth}x${this.preferredViewHeight})`
      : 'none';
  }
}

/** C++ WindowConstraints. */
export class WindowConstraints {
  hasViewConstraints: boolean = false;
  viewMinWidth: number = 0;
  viewMinHeight: number = 0;
  viewMaxWidth: number = 0;
  viewMaxHeight: number = 0;

  constructor(raw?: WindowConstraints) {
    this.hasViewConstraints = raw?.hasViewConstraints ?? false;
    this.viewMinWidth = raw?.viewMinWidth ?? 0;
    this.viewMinHeight = raw?.viewMinHeight ?? 0;
    this.viewMaxWidth = raw?.viewMaxWidth ?? 0;
    this.viewMaxHeight = raw?.viewMaxHeight ?? 0;
  }

  toString(): string {
    return this.hasViewConstraints
      ? `set[${this.viewMinWidth},${this.viewMinHeight}..${this.viewMaxWidth},${this.viewMaxHeight}]`
      : 'none';
  }
}

/** C++ RegularWindowCreationRequest. */
export class RegularWindowCreationRequest {
  readonly preferredSize: WindowSizeRequest;
  readonly preferredConstraints: WindowConstraints;
  readonly title: string;

  constructor(raw?: RegularWindowCreationRequest) {
    this.preferredSize = new WindowSizeRequest(raw?.preferredSize);
    this.preferredConstraints = new WindowConstraints(raw?.preferredConstraints);
    this.title = raw?.title ?? '';
  }
}

/** C++ DialogWindowCreationRequest: parentViewId != NO_PARENT_VIEW_ID =
 * modal; sentinel = modeless (UIAbility spawn path). */
export class DialogWindowCreationRequest {
  readonly preferredSize: WindowSizeRequest;
  readonly preferredConstraints: WindowConstraints;
  readonly title: string;
  readonly parentViewId: number;

  constructor(raw?: DialogWindowCreationRequest) {
    this.preferredSize = new WindowSizeRequest(raw?.preferredSize);
    this.preferredConstraints = new WindowConstraints(raw?.preferredConstraints);
    this.title = raw?.title ?? '';
    this.parentViewId = raw?.parentViewId ?? NO_PARENT_VIEW_ID;
  }
}

/** C++ TooltipWindowCreationRequest (no preferred size — sized to the
 * content constraints; no title). */
export class TooltipWindowCreationRequest {
  readonly preferredConstraints: WindowConstraints;
  readonly parentViewId: number;

  constructor(raw?: TooltipWindowCreationRequest) {
    this.preferredConstraints = new WindowConstraints(raw?.preferredConstraints);
    this.parentViewId = raw?.parentViewId ?? NO_PARENT_VIEW_ID;
  }
}

/** C++ PopupWindowCreationRequest (mirrors the tooltip shape; win32 has no
 * popup counterpart). */
export class PopupWindowCreationRequest {
  readonly preferredConstraints: WindowConstraints;
  readonly parentViewId: number;

  constructor(raw?: PopupWindowCreationRequest) {
    this.preferredConstraints = new WindowConstraints(raw?.preferredConstraints);
    this.parentViewId = raw?.parentViewId ?? NO_PARENT_VIEW_ID;
  }
}

export enum WindowArchetype {
  /** Top-level window with its own task-center card (UIAbility host). */
  REGULAR = 0,
  /** Dialog: modal (has parent) = SubWindow host; modeless = UIAbility host. */
  DIALOG = 1,
  /** Positioner-anchored, non-focusable SubWindow. */
  TOOLTIP = 2,
  POPUP = 3,
}
/** View-id string → numeric registry key. 'oh_flutter_<n>' ids are the
 * EntryAbility's implicit main view (0); anything else parses as a number
 * (unknown ids yield NaN, which simply never hits the registry). */
export function numericViewId(id: string): number {
  return id.startsWith('oh_flutter_') ? 0 : Number(id);
}
