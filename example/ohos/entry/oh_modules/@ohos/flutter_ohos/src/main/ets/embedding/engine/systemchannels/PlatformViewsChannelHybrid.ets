/*
 * Copyright (c) 2026 Huawei Device Co., Ltd. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE_HW file.
 */

import Any from '../../../plugin/common/Any';
import MethodCall from '../../../plugin/common/MethodCall';
import MethodChannel, { MethodCallHandler, MethodResult } from '../../../plugin/common/MethodChannel';
import StandardMethodCodec from '../../../plugin/common/StandardMethodCodec';
import { ByteBuffer } from '../../../util/ByteBuffer';
import Log from '../../../util/Log';
import DartExecutor from '../dart/DartExecutor';
import {
  PlatformViewCreationRequest,
  PlatformViewTouch
} from './PlatformViewsChannel';

const TAG = "PlatformViewsChannelHybrid";

// Dart 端 Direction 枚举的 RTL 序号(create/setDirection 消息里的 direction 字段)。
const DART_DIRECTION_RTL = 1;

/**
 * System channel dedicated to Hybrid Composition++ (HCPP) platform views.
 *
 * Mirrors Android's {@code flutter/platform_views_2} channel. The Dart
 * framework routes HCPP dispose (and, on some paths, touch) through this
 * channel while the initial create request still arrives on the legacy
 * {@code flutter/platform_views} channel with the {@code hybridFallback} flag.
 */
export default class PlatformViewsChannelHybrid {
  private channel: MethodChannel;
  private handler: PlatformViewsHybridHandler | null = null;
  private parsingHandler = new ParsingCallbackHybrid();

  constructor(dartExecutor: DartExecutor) {
    this.channel =
      new MethodChannel(dartExecutor, "flutter/platform_views_2", StandardMethodCodec.INSTANCE);
    this.parsingHandler.platformChannel = this;
    this.channel.setMethodCallHandler(this.parsingHandler);
  }

  public setPlatformViewsHandler(handler: PlatformViewsHybridHandler | null): void {
    this.handler = handler;
    this.parsingHandler.handler = handler;
  }

  public invokeViewFocused(viewId: number): void {
    if (this.channel == null) {
      return;
    }
    this.channel.invokeMethod("viewFocused", viewId);
  }

  create(call: MethodCall, result: MethodResult): void {
    const createArgs: Map<string, Any> = call.args;
    const additionalParams: ByteBuffer = createArgs.has("params") ? createArgs.get("params") : null;
    let direction: Direction = Direction.Ltr;
    if (createArgs.get("direction") == DART_DIRECTION_RTL) {
      direction = Direction.Rtl;
    }
    try {
      // logicalTop/Left/Width/Height 占位 0:HCPP 的 create 消息不下发尺寸,
      // 几何由后续 onDisplayPlatformViewHybrid 单独下发。
      const request: PlatformViewCreationRequest = new PlatformViewCreationRequest(
        createArgs.get("id"),
        createArgs.get("viewType"),
        0, 0, 0, 0,
        direction,
        additionalParams
      );
      Log.i(TAG, "create (hcpp channel) id=" + request.viewId + " type=" + request.viewType);
      this.handler?.createForPlatformViewLayer(request);
      result.success(null);
    } catch (err) {
      Log.e(TAG, "create (hcpp) failed " + err);
      result.error("error", err, null);
    }
  }

  dispose(call: MethodCall, result: MethodResult): void {
    const disposeArgs: Map<string, Any> = call.args;
    const viewId: number = disposeArgs.get("id");
    Log.i(TAG, "dispose (hcpp channel) id=" + viewId);
    try {
      this.handler?.dispose(viewId);
      result.success(null);
    } catch (err) {
      Log.e(TAG, "dispose (hcpp) failed " + err);
      result.error("error", err, null);
    }
  }

  touch(call: MethodCall, result: MethodResult): void {
    const touchArgs: Array<Any> = call.args;
    try {
      // PlatformViewTouch 构造器有 16 个位置参数,逐字段提取防止顺序错位静默赋错。
      let argCursor = 0;
      const viewId: Any = touchArgs[argCursor++];
      const downTime: Any = touchArgs[argCursor++];
      const eventTime: Any = touchArgs[argCursor++];
      const action: Any = touchArgs[argCursor++];
      const pointerCount: Any = touchArgs[argCursor++];
      const rawPointerPropertiesList: Any = touchArgs[argCursor++];
      const rawPointerCoords: Any = touchArgs[argCursor++];
      const metaState: Any = touchArgs[argCursor++];
      const buttonState: Any = touchArgs[argCursor++];
      const xPrecision: Any = touchArgs[argCursor++];
      const yPrecision: Any = touchArgs[argCursor++];
      const deviceId: Any = touchArgs[argCursor++];
      const edgeFlags: Any = touchArgs[argCursor++];
      const source: Any = touchArgs[argCursor++];
      const flags: Any = touchArgs[argCursor++];
      const motionEventId: Any = touchArgs[argCursor];
      const touch: PlatformViewTouch = new PlatformViewTouch(
        viewId, downTime, eventTime, action, pointerCount,
        rawPointerPropertiesList, rawPointerCoords, metaState, buttonState,
        xPrecision, yPrecision, deviceId, edgeFlags, source, flags, motionEventId
      );
      this.handler?.onTouch(touch);
      result.success(null);
    } catch (err) {
      Log.e(TAG, `touch (hcpp) failed: ${err}`);
      result.error("error", err, null);
    }
  }

  setDirection(call: MethodCall, result: MethodResult): void {
    const args: Map<string, Any> = call.args;
    const viewId: number = args.get("id");
    const directionValue: number = args.get("direction");
    let direction: Direction = directionValue == DART_DIRECTION_RTL ? Direction.Rtl : Direction.Ltr;
    try {
      this.handler?.setDirection(viewId, direction);
      result.success(null);
    } catch (err) {
      Log.e(TAG, "setDirection (hcpp) failed " + err);
      result.error("error", err, null);
    }
  }

  clearFocus(call: MethodCall, result: MethodResult): void {
    const viewId: number = call.args;
    try {
      this.handler?.clearFocus(viewId);
      result.success(null);
    } catch (err) {
      Log.e(TAG, "clearFocus (hcpp) failed " + err);
      result.error("error", err, null);
    }
  }

  isSurfaceControlEnabled(call: MethodCall, result: MethodResult): void {
    try {
      result.success(this.handler?.isSurfaceControlEnabled() ?? false);
    } catch (err) {
      result.error("error", err, null);
    }
  }

  setOverscrollOffset(call: MethodCall, result: MethodResult): void {
    const args: Map<string, Any> = call.args;
    const viewId: number = args.get("id");
    const offsetVp: number = args.get("offset");
    try {
      this.handler?.setOverscrollOffset(viewId, offsetVp);
      result.success(null);
    } catch (err) {
      Log.e(TAG, "setOverscrollOffset (hcpp) failed " + err);
      result.error("error", err, null);
    }
  }
}

/**
 * Handler that receives HCPP platform view messages from Flutter.
 */
export interface PlatformViewsHybridHandler {
  createForPlatformViewLayer(request: PlatformViewCreationRequest): void;
  dispose(viewId: number): void;
  onTouch(touch: PlatformViewTouch): void;
  setDirection(viewId: number, direction: Direction): void;
  clearFocus(viewId: number): void;
  isSurfaceControlEnabled(): boolean;
  /** [overscroll-follow] Dart 累积 overscroll 后下传，让 PV 平移跟随 stretch。 */
  setOverscrollOffset(viewId: number, offsetVp: number): void;
}

class ParsingCallbackHybrid implements MethodCallHandler {
  platformChannel: PlatformViewsChannelHybrid | null = null;
  handler: PlatformViewsHybridHandler | null = null;

  onMethodCall(call: MethodCall, result: MethodResult) {
    if (this.handler == null) {
      return;
    }
    Log.i(TAG, "Received '" + call.method + "' message.");
    switch (call.method) {
      case "create":
        this.platformChannel?.create(call, result);
        break;
      case "dispose":
        this.platformChannel?.dispose(call, result);
        break;
      case "touch":
        this.platformChannel?.touch(call, result);
        break;
      case "setDirection":
        this.platformChannel?.setDirection(call, result);
        break;
      case "clearFocus":
        this.platformChannel?.clearFocus(call, result);
        break;
      case "isSurfaceControlEnabled":
        this.platformChannel?.isSurfaceControlEnabled(call, result);
        break;
      case "setOverscrollOffset":
        this.platformChannel?.setOverscrollOffset(call, result);
        break;
      default:
        result.notImplemented();
    }
  }
}
