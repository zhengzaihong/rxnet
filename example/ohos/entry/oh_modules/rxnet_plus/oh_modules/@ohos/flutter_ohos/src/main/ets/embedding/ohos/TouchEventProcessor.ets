/*
* Copyright (c) 2024 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*/

/** Handle the motion events received by the FlutterNapi. */
// import PlainArray from '@ohos.util.PlainArray';
// import { TouchEvent } from '@ohos.multimodalInput.touchEvent';
// import Queue from '@ohos.util.Queue';

import { CustomTouchEvent, CustomTouchObject } from '../../plugin/platform/CustomTouchEvent';
import display from '@ohos.display';
import FlutterManager from './FlutterManager';
import { EmbeddingNodeController } from './EmbeddingNodeController';
import Any from '../../plugin/common/Any';


type TextInputHandoffOnTouch = (canInvokeViewFocused: boolean) => void;

const OH_NATIVEXCOMPONENT_DOWN = 0;
const OH_NATIVEXCOMPONENT_UNKNOWN = 4;
const OH_NATIVEXCOMPONENT_TOOL_TYPE_UNKNOWN = 0;
const PLATFORM_VIEW_ACTIVE_TOUCHES = 'platformViewActiveTouches';
const PLATFORM_VIEW_LAST_TOUCH_EVENT = 'platformViewLastTouchEvent';
const PLATFORM_VIEW_LAST_TOUCH_EVENT_IS_PX = 'platformViewLastTouchEventIsPx';
const PLATFORM_VIEW_CANCEL_DRAINING = 'platformViewCancelDraining';

/**
 * Represents a touch point in a native XComponent touch event.
 */
class OH_NativeXComponent_TouchPoint {
  id: number = 0;
  screenX: number = 0.0;
  screenY: number = 0.0;
  x: number = 0.0;
  y: number = 0.0;
  type: number = OH_NATIVEXCOMPONENT_UNKNOWN;
  size: number = 0;
  force: number = 0;
  timeStamp: number = 0;
  isPressed: boolean = false;

  /**
   * Constructs a new OH_NativeXComponent_TouchPoint instance.
   * @param id - The touch point ID
   * @param screenX - The screen X coordinate
   * @param screenY - The screen Y coordinate
   * @param x - The local X coordinate
   * @param y - The local Y coordinate
   * @param type - The touch type
   * @param size - The touch size
   * @param force - The touch force
   * @param timeStamp - The timestamp
   * @param isPressed - Whether the touch is pressed
   */
  constructor(id: number,
    screenX: number,
    screenY: number,
    x: number,
    y: number,
    type: number,
    size: number,
    force: number,
    timeStamp: number,
    isPressed: boolean) {
    this.id = id;
    this.screenX = screenX;
    this.screenY = screenY;
    this.x = x;
    this.y = y;
    this.type = type;
    this.size = size;
    this.force = force;
    this.timeStamp = timeStamp;
    this.isPressed = isPressed;
  }
}

/**
 * Represents a native XComponent touch event.
 */
class OH_NativeXComponent_TouchEvent {
  id: number = 0;
  screenX: number = 0.0;
  screenY: number = 0.0;
  x: number = 0.0;
  y: number = 0.0;
  type: number = OH_NATIVEXCOMPONENT_UNKNOWN;
  size: number = 0;
  force: number = 0;
  deviceId: number = 0;
  timeStamp: number = 0;
  touchPoints: OH_NativeXComponent_TouchPoint[] = [];
  numPoints: number = 0;

  /**
   * Constructs a new OH_NativeXComponent_TouchEvent instance.
   * @param id - The event ID
   * @param screenX - The screen X coordinate
   * @param screenY - The screen Y coordinate
   * @param x - The local X coordinate
   * @param y - The local Y coordinate
   * @param type - The touch type
   * @param size - The touch size
   * @param force - The touch force
   * @param deviceId - The device ID
   * @param timeStamp - The timestamp
   * @param touchPoints - Array of touch points
   * @param numPoints - Number of touch points
   */
  constructor(id: number,
    screenX: number,
    screenY: number,
    x: number,
    y: number,
    type: number,
    size: number,
    force: number,
    deviceId: number,
    timeStamp: number,
    touchPoints: OH_NativeXComponent_TouchPoint[],
    numPoints: number) {
    this.id = id;
    this.screenX = screenX;
    this.screenY = screenY;
    this.x = x;
    this.y = y;
    this.type = type;
    this.size = size;
    this.force = force;
    this.deviceId = deviceId;
    this.timeStamp = timeStamp;
    this.touchPoints = touchPoints;
    this.numPoints = numPoints;
  }
}

/**
 * Packet containing touch event data and tool information.
 */
class TouchPacket {
  touchEvent: OH_NativeXComponent_TouchEvent;
  toolType: number = OH_NATIVEXCOMPONENT_TOOL_TYPE_UNKNOWN;
  tiltX: number = 0;
  tiltY: number = 0;

  /**
   * Constructs a new TouchPacket instance.
   * @param touchEvent - The touch event
   * @param toolType - The tool type
   * @param tiltX - The X-axis tilt
   * @param tiltY - The Y-axis tilt
   */
  constructor(touchEvent: OH_NativeXComponent_TouchEvent,
    toolType: number,
    tiltX: number,
    tiltY: number) {
    this.touchEvent = touchEvent;
    this.toolType = toolType;
    this.tiltX = tiltX;
    this.tiltY = tiltY;
  }
}

/**
 * Packet containing mouse event data.
 */
class MousePacket {
  offset: number;
  x: number;
  y: number;
  screenX: number;
  screenY: number;
  timestamp: number;
  action: number;
  button: number;

  /**
   * Constructs a new MousePacket instance.
   * @param offset - The offset value
   * @param x - The local X coordinate
   * @param y - The local Y coordinate
   * @param screenX - The screen X coordinate
   * @param screenY - The screen Y coordinate
   * @param timestamp - The timestamp
   * @param action - The mouse action
   * @param button - The mouse button
   */
  constructor(  offset: number,
    x: number,
    y: number,
    screenX: number,
    screenY: number,
    timestamp: number,
    action: number,
    button: number) {
    this.offset = offset;
    this.x = x;
    this.y = y;
    this.screenX = screenX;
    this.screenY = screenY;
    this.timestamp = timestamp;
    this.action = action;
    this.button = button;
  }
}

/**
 * Processor for handling touch events received by FlutterNapi.
 * This class processes and converts touch events from native format to Flutter format.
 */
export default class TouchEventProcessor {
  private static instance: TouchEventProcessor;

  /**
   * Gets the singleton instance of TouchEventProcessor.
   * @returns The singleton TouchEventProcessor instance
   */
  static getInstance(): TouchEventProcessor {
    if (TouchEventProcessor.instance == null) {
      TouchEventProcessor.instance = new TouchEventProcessor();
    }
    return TouchEventProcessor.instance;
  }

  private decodeTouchPacket(strings: Array<string>, densityPixels: number, top: number, left: number): TouchPacket {
    let offset: number = 0;
    let numPoint: number = parseInt(strings[offset++]);
    let changesId: number = parseInt(strings[offset++]);
    let changesscreenX: number = (parseFloat(strings[offset++]) / densityPixels);
    let changesscreenY: number = (parseFloat(strings[offset++]) / densityPixels);
    let changesX: number = ((parseFloat(strings[offset++]) / densityPixels) - left);
    let changesY: number = ((parseFloat(strings[offset++]) / densityPixels) - top);
    let changesType: number = parseInt(strings[offset++]);
    let changesSize: number = parseFloat(strings[offset++]);
    let changesForce: number = parseFloat(strings[offset++]);
    let changesDeviceId: number = parseInt(strings[offset++]);
    let changesTimeStamp: number = parseInt(strings[offset++]);

    const touchPoints: OH_NativeXComponent_TouchPoint[] = [];
    for (let i = 0; i < numPoint; i++) {
      const touchPoint: OH_NativeXComponent_TouchPoint = new OH_NativeXComponent_TouchPoint(
        parseInt(strings[offset++]),
        (parseFloat(strings[offset++]) / densityPixels),
        (parseFloat(strings[offset++]) / densityPixels),
        ((parseFloat(strings[offset++]) / densityPixels) - left),
        ((parseFloat(strings[offset++]) / densityPixels) - top),
        parseInt(strings[offset++]),
        parseFloat(strings[offset++]),
        parseFloat(strings[offset++]),
        parseInt(strings[offset++]),
        parseInt(strings[offset++]) === 1 ? true : false
      );
      touchPoints.push(touchPoint);
    }

    const touchEventInput: OH_NativeXComponent_TouchEvent = new OH_NativeXComponent_TouchEvent(
      changesId,
      changesscreenX,
      changesscreenY,
      changesX,
      changesY,
      changesType,
      changesSize,
      changesForce,
      changesDeviceId,
      changesTimeStamp,
      touchPoints,
      numPoint
    );

    let toolTypeInput: number = parseInt(strings[offset++]);
    let tiltXTouch: number = parseInt(strings[offset++]);
    let tiltYTouch: number = parseInt(strings[offset++]);

    const touchPointEventPacket: TouchPacket = new TouchPacket(
      touchEventInput,
      toolTypeInput,
      tiltXTouch,
      tiltYTouch
    );
    return touchPointEventPacket;
  }

  private constructCustomTouchEventImpl(touchPacket: TouchPacket, top: number, left: number): CustomTouchEvent {
    // The global fields (display/window/screen) must be derived from the
    // local x/y plus the view layout offset (i.e. Flutter-viewport-global
    // coordinates, the same space the local x/y and the affine transform
    // translation live in) instead of the packet's screenX/screenY:
    // on windowed devices (e.g. desktops) the native touch packet
    // reports screenX/screenY relative to the window top-left (including
    // the modal title bar) while x/y are XComponent(Flutter viewport)
    // relative, so using screenX/screenY shifts every global coordinate -
    // and the affine touch correction that recomputes x/y from them - by
    // the title bar height. On full-screen devices both spaces coincide,
    // so this is a no-op there.
    let changes1: CustomTouchObject = new CustomTouchObject(
      touchPacket.touchEvent.type,
      touchPacket.touchEvent.id,
      touchPacket.touchEvent.x + left,
      touchPacket.touchEvent.y + top,
      touchPacket.touchEvent.x + left,
      touchPacket.touchEvent.y + top,
      touchPacket.touchEvent.x + left,
      touchPacket.touchEvent.y + top,
      touchPacket.touchEvent.x,
      touchPacket.touchEvent.y
    );

    let touches: CustomTouchObject[] = [];
    let touchPointer: number = touchPacket.touchEvent.numPoints;
    for (let i = 0; i < touchPointer; i++) {
      let touchesItem: CustomTouchObject = new CustomTouchObject(
        touchPacket.touchEvent.touchPoints[i].type,
        touchPacket.touchEvent.touchPoints[i].id,
        touchPacket.touchEvent.touchPoints[i].x + left,
        touchPacket.touchEvent.touchPoints[i].y + top,
        touchPacket.touchEvent.touchPoints[i].x + left,
        touchPacket.touchEvent.touchPoints[i].y + top,
        touchPacket.touchEvent.touchPoints[i].x + left,
        touchPacket.touchEvent.touchPoints[i].y + top,
        touchPacket.touchEvent.touchPoints[i].x,
        touchPacket.touchEvent.touchPoints[i].y
      );
      touches.push(touchesItem);
    }

    let customTouchEvent1: CustomTouchEvent = new CustomTouchEvent(
      touchPacket.touchEvent.type,
      touches,
      [changes1],
      touchPacket.touchEvent.timeStamp,
      SourceType.TouchScreen,
      touchPacket.touchEvent.force,
      touchPacket.tiltX,
      touchPacket.tiltY,
      touchPacket.toolType
    );

    return customTouchEvent1;
  }

  /**
   * Constructs a CustomTouchEvent from string array data.
   * @param strings - Array of string values representing touch data
   * @param top - The top offset
   * @param left - The left offset
   * @returns A CustomTouchEvent instance
   */
  public constructCustomTouchEvent(strings: Array<string>, top: number, left: number): CustomTouchEvent {
    let densityPixels: number = display.getDefaultDisplaySync().densityPixels;

    let touchPacket: TouchPacket = this.decodeTouchPacket(strings, densityPixels, top, left);
    let customTouchEvent: CustomTouchEvent = this.constructCustomTouchEventImpl(touchPacket, top, left);
    return customTouchEvent;
  }

  private isTerminalTouch(type: TouchType): boolean {
    return type === TouchType.Up || type === TouchType.Cancel;
  }

  private cloneTouchObjectWithType(touch: CustomTouchObject, type: TouchType): CustomTouchObject {
    return new CustomTouchObject(type, touch.id, touch.displayX, touch.displayY, touch.windowX, touch.windowY,
      touch.screenX, touch.screenY, touch.x, touch.y);
  }

  private getActiveTouches(params: Record<string, Any>, create: boolean = false): Map<number, CustomTouchObject> | undefined {
    let activeTouches = params[PLATFORM_VIEW_ACTIVE_TOUCHES] as Map<number, CustomTouchObject> | undefined;
    if (activeTouches === undefined && create) {
      activeTouches = new Map<number, CustomTouchObject>();
      params[PLATFORM_VIEW_ACTIVE_TOUCHES] = activeTouches;
    }
    return activeTouches;
  }

  private rememberPostedTouchEvent(params: Record<string, Any>, event: CustomTouchEvent): void {
    params[PLATFORM_VIEW_LAST_TOUCH_EVENT] = event;
    params[PLATFORM_VIEW_LAST_TOUCH_EVENT_IS_PX] = true;

    let activeTouches = this.getActiveTouches(params, true)!;
    if (event.type === TouchType.Cancel) {
      activeTouches.clear();
      return;
    }

    for (let touch of event.changedTouches) {
      if (this.isTerminalTouch(touch.type)) {
        activeTouches.delete(touch.id);
      } else {
        activeTouches.set(touch.id, this.cloneTouchObjectWithType(touch, touch.type));
      }
    }

    for (let touch of event.touches) {
      if (this.isTerminalTouch(touch.type)) {
        activeTouches.delete(touch.id);
      } else {
        activeTouches.set(touch.id, this.cloneTouchObjectWithType(touch, touch.type));
      }
    }
  }

  /**
   * Posts an axis/scroll event to platform views.
   * Axis/wheel coordinates are passed to nodes through this method.
   * @param strings - Array of string values representing axis event data
   */
  public postAxisEvent(strings: Array<string>) {
    FlutterManager.getInstance().getFlutterViewList().forEach((value) => {
      if (!value.getActive()) {
        return
      }
      let length = value.getDVModel().children.length
      for (let index = length - 1; index >= 0; index--) {
        const dvModel = value.getDVModel().children[index]
        const params = dvModel.getLayoutParams() as Record<string, ESObject>;
        if (!params["hover"]) {
          continue;
        }
        const left = params['left'] as number ?? 0;
        const top = params['top'] as number ?? 0;
        const densityPixels: number = display.getDefaultDisplaySync().densityPixels;

        let offset: number = 0;
        const action: number = parseFloat(strings[offset++]);
        // Same basis as decodeMousePacket: the packet x/y carry layout px
        // (logical * densityPixels), so convert the vp offset with
        // densityPixels instead of the vp2px() round-trip, which uses the
        // window density and diverges on windowed devices.
        const x: number = parseFloat(strings[offset++]) - left * densityPixels;
        const y: number = parseFloat(strings[offset++]) - top * densityPixels;
        const windowX: number = vp2px(parseFloat(strings[offset++]) / densityPixels);
        const windowY: number = vp2px(parseFloat(strings[offset++]) / densityPixels);
        const displayX: number = vp2px(parseFloat(strings[offset++]) / densityPixels);
        const displayY: number = vp2px(parseFloat(strings[offset++]) / densityPixels);
        const scroll: number = parseFloat(strings[offset++]);

        // 构造AxisEvent数据
        // The C++ axis packet already carries decoded windowX/windowY
        // (window-global coordinates); the AxisEvent previously lost the
        // view offset by wrongly assigning local x/y to them.
        const axisEvent: AxisEvent = {
          action: action,
          x: x,
          y: y,
          windowX: windowX,
          windowY: windowY,
          displayX: displayX,
          displayY: displayY,
          scrollStep: scroll,
          axisVertical: scroll
        } as AxisEvent;

        let nodeController = params['nodeController'] as EmbeddingNodeController;
        nodeController.postAxisEvent(axisEvent);
      }
    });
  }
  
  /**
   * Posts a touch event to platform views.
   * @param strings - Array of string values representing touch event data
   */
  public postTouchEvent(strings: Array<string>) {
    FlutterManager.getInstance().getFlutterViewList().forEach((value) => {
      if (!value.getActive()) {
        return
      }
      let length = value.getDVModel().children.length
      for (let index = length - 1; index >= 0; index--) {
        let dvModel = value.getDVModel().children[index]
        let params = dvModel.getLayoutParams() as Record<string, ESObject>;
        let left = params['left'] as number ?? 0;
        let top = params['top'] as number ?? 0;
        let down = params['down'] as boolean ?? false;
        if (down) {
          //如果flutter端判断当前platformView是可点击的，则将事件分发出去
          let touchEvent: CustomTouchEvent = TouchEventProcessor.getInstance().constructCustomTouchEvent(strings, top, left);
          // Correct local coordinates for rotation/scale using the global→local
          // affine stored at layout time (PlatformViewsController.offset).
          TouchEventProcessor.applyAffineTransform(touchEvent, params['affineTransform'] as Array<number> | undefined);
          let nodeController = params['nodeController'] as EmbeddingNodeController;
          nodeController.postEvent(touchEvent);
          this.rememberPostedTouchEvent(params, touchEvent);
          // Keep the text-input handoff check on the same path that delivers
          // touch events to ArkUI. postTouchEvent can run more than once for a
          // gesture, so non-DOWN events also consume stale child-editor markers
          // but are not allowed to invoke viewFocused.
          let textInputHandoffOnTouch =
            params['textInputHandoffOnTouch'] as TextInputHandoffOnTouch | undefined;
          if (textInputHandoffOnTouch != undefined) {
            textInputHandoffOnTouch(touchEvent.type == TouchType.Down);
          }
        } else {
          //如果触摸事件为OH_NATIVEXCOMPONENT_DOWN=0，且只有一个手指，说明是下一次点击了，这时候需要清空上一次的数据
          if (strings[6] == OH_NATIVEXCOMPONENT_DOWN.toString() && strings[0] == '1') {
            params['touchEvent'] = undefined
            params[PLATFORM_VIEW_CANCEL_DRAINING] = false;
          }
          //如果触摸事件为OH_NATIVEXCOMPONENT_DOWN=0类型，且在flutter端还没判断当前view是否处于点击区域内，则
          //将点击事件存储在list列表中。
          let touchEvent: CustomTouchEvent = TouchEventProcessor.getInstance().constructCustomTouchEvent(strings, top, left);
          const cancelDraining = params[PLATFORM_VIEW_CANCEL_DRAINING] as boolean ?? false;
          if (cancelDraining && touchEvent.type !== TouchType.Down) {
            continue;
          }
          let array: Array<CustomTouchEvent> | undefined = params['touchEvent'] as Array<CustomTouchEvent>
          if (array == undefined) {
            array = []
            params['touchEvent'] = array
          }
          array.push(touchEvent)
        }
      }
    });
  }

  private decodeMousePacket(strings: Array<string>, densityPixels: number, top: number, left: number): MousePacket {
    let offset: number = 0;
    // The mouse packet strings carry layout pixels (the C++ side maps
    // screen pixels onto the platform-view layout space before sending),
    // while left/top are Flutter logical (vp). Convert the offset with the
    // same densityPixels (layout px = logical * system density) instead of
    // the previous vp -> vp2px() round-trip: vp2px() uses the window
    // density, which is only guaranteed to match densityPixels on
    // full-screen devices, so the round-trip is not always the identity.
    // screenX/screenY are display-global physical pixels and are passed
    // through unchanged.
    let x: number = (parseFloat(strings[offset++])) - left * densityPixels;
    let y: number = (parseFloat(strings[offset++])) - top * densityPixels;
    let screenX: number = parseFloat(strings[offset++]);
    let screenY: number = parseFloat(strings[offset++]);
    let timestamp: number = parseFloat(strings[offset++]);
    let action: number = parseFloat(strings[offset++]);
    let button: number = parseFloat(strings[offset++]);

    const mouseEventPacket: MousePacket = new MousePacket(
      offset,
      x,
      y,
      screenX,
      screenY,
      timestamp,
      action,
      button
    );
    return mouseEventPacket;
  }

  private constructMouseEventImpl(mousePacket: MousePacket): MouseEvent {
    // 构造MouseEvent数据
    // displayX/windowX must carry global coordinates: MousePacket already
    // decodes screenX/screenY (screen-global physical pixels), while the
    // local coordinates mousePacket.x/y were wrongly used before, which
    // made window/display equal to local for the platform view.
    const mouseEvent: MouseEvent = {
      button: mousePacket.button,
      action: mousePacket.action,
      displayX: mousePacket.screenX,
      displayY: mousePacket.screenY,
      windowX: mousePacket.screenX,
      windowY: mousePacket.screenY,
      screenX: mousePacket.screenX,
      screenY: mousePacket.screenY,
      x: mousePacket.x,
      y: mousePacket.y,
      source: SourceType.Mouse,
      sourceTool: SourceTool.MOUSE,
      stopPropagation: () => {},
      timestamp: mousePacket.timestamp,
      pressure: 0,
      tiltX: mousePacket.x,
      tiltY: mousePacket.y,
    } as MouseEvent;

    return mouseEvent;
  }

  /** Construct the MouseEvent and return. */
  public constructMouseEvent(strings: Array<string>, top: number, left: number): MouseEvent {
    let densityPixels: number = display.getDefaultDisplaySync().densityPixels;
    let mousePacket: MousePacket = this.decodeMousePacket(strings, densityPixels, top, left);
    let mouseEvent: MouseEvent = this.constructMouseEventImpl(mousePacket);
    return mouseEvent;
  }

  // 鼠标坐标通过postInputEvent传入到节点
  /**
   * Posts a mouse event to platform views.
   * @param strings - Array of string values representing mouse event data
   */
  public postMouseEvent(strings: Array<string>) {
    // Same density basis as decodeMousePacket (system display density):
    // the hit test below must convert the vp bounds with the same
    // densityPixels instead of vp2px() (window density).
    const densityPixels: number = display.getDefaultDisplaySync().densityPixels;
    FlutterManager.getInstance().getFlutterViewList().forEach((value) => {
      if (!value.getActive()) {
        return
      }
      let length = value.getDVModel().children.length
      for (let index = length - 1; index >= 0; index--) {
        const dvModel = value.getDVModel().children[index]
        const params = dvModel.getLayoutParams() as Record<string, ESObject>;
        const left = params['left'] as number ?? 0;
        const top = params['top'] as number ?? 0;
        let down = params['down'] as boolean ?? false;
        // 跨区域拖入时合成的 Press 标志，独立于 Dart 管理的 params['down']
        let synthesized = params['mouseDownSynthesized'] as boolean ?? false;
        let mouseEvent: MouseEvent = TouchEventProcessor.getInstance().constructMouseEvent(strings, top, left);

        if (synthesized) {
          // 已合成 Press，Release 直接分发；Move 仅在 view 内分发，避免离开时边界外坐标误触发 mouseleave
          if (mouseEvent.action == MouseAction.Release ||
            (mouseEvent.action == MouseAction.Move &&
              this.checkHitPlatformViewByLocal(mouseEvent, params, densityPixels))) {
            let nodeController = params['nodeController'] as EmbeddingNodeController;
            nodeController.postMouseEvent(mouseEvent);
          }
          if (mouseEvent.action == MouseAction.Release) {
            // 手势结束清除标志（Dart 跨区域时不发 onTouch UP）
            params['mouseDownSynthesized'] = false;
            params['mouseEvent'] = undefined;
          }
          break;
        } else if (mouseEvent.action != MouseAction.Press && mouseEvent.action != MouseAction.Release && params["hover"]) {
          // 如果鼠标事件不是OH_NATIVEXCOMPONENT_MOUSE_PRESS类型或OH_NATIVEXCOMPONENT_MOUSE_RELEASE类型，则
          // 直接分发出去
          let nodeController = params['nodeController'] as EmbeddingNodeController;
          nodeController.postMouseEvent(mouseEvent);
        } else if (down) {
          // 如果flutter端判断当前platformView是可点击的，则将事件分发出去,并结束分发
          let nodeController = params['nodeController'] as EmbeddingNodeController;
          nodeController.postMouseEvent(mouseEvent);
          break;
        } else if (mouseEvent.button != 0 && mouseEvent.action != MouseAction.Press &&
          this.checkHitPlatformViewByLocal(mouseEvent, params, densityPixels)) {
          // 跨区域按键拖入：down 恒为 false，webview 未收到 Press 会拒绝 Release。
          // 拖入瞬间合成 Press 补发，置 synthesized=true 使后续 Release 正常分发。
          // 排除 action==Press：区域内直接点击应走缓存分支由 Dart drain，避免双发 Press。
          let nodeController = params['nodeController'] as EmbeddingNodeController;
          let originalAction = mouseEvent.action;
          mouseEvent.action = MouseAction.Press;
          nodeController.postMouseEvent(mouseEvent);
          mouseEvent.action = originalAction;
          params['mouseDownSynthesized'] = true;
          params['mouseEvent'] = undefined;
          nodeController.postMouseEvent(mouseEvent);
          if (mouseEvent.action == MouseAction.Release) {
            params['mouseDownSynthesized'] = false;
          }
          break;
        } else {
          // 如果鼠标事件为OH_NATIVEXCOMPONENT_MOUSE_PRESS，说明是下一次点击了，这时候需要清空上一次的数据
          if (strings[5] == '1') {
            params['mouseEvent'] = undefined
          }
          // 如果鼠标事件为OH_NATIVEXCOMPONENT_MOUSE_PRESS类型，且在flutter端还没判断当前view是否处于点击区域内，则将点击事件存储在list列表中。
          let array: Array<MouseEvent> | undefined = params['mouseEvent'] as Array<MouseEvent>
          if (array == undefined) {
            array = []
            params['mouseEvent'] = array
          }
          array.push(mouseEvent)
        }
      }
    });
  }

  public checkHitPlatformView(left: number, top: number, width: number, height: number, x: number, y: number): boolean {
    if (x >= left && x <= (left + width) && y >= top && y <= (top + height)) {
      return true;
    } else {
      return false;
    }
  }

  /**
   * Checks whether the mouse cursor is within the PlatformView bounds.
   * mouseEvent.x/y are local layout px (logical * densityPixels, the system
   * density - see decodeMousePacket); params['width'/'height'] are vp and
   * must be converted with the same densityPixels. vp2px() uses the window
   * density, which diverges from the system density on windowed devices.
   */
  private checkHitPlatformViewByLocal(mouseEvent: MouseEvent, params: Record<string, ESObject>,
    densityPixels: number): boolean {
    const viewWidth = params['width'] as number ?? 0;
    const viewHeight = params['height'] as number ?? 0;
    if (viewWidth <= 0 || viewHeight <= 0) {
      return false;
    }
    return mouseEvent.x >= 0 && mouseEvent.x <= viewWidth * densityPixels &&
      mouseEvent.y >= 0 && mouseEvent.y <= viewHeight * densityPixels;
  }

  /**
   * Corrects the local coordinates of a touch event using the global→local
   * affine derived in PlatformViewsController.applyTransformOffset.
   *
   * affineTransform = [invScaleX, invShearY, invTx, invShearX, invScaleY, invTy] with
   *   localX = invScaleX*gx + invShearY*gy + invTx ; localY = invShearX*gx + invScaleY*gy + invTy
   * where (gx, gy) is the raw screen coordinate (stored identically in the
   * touch object's displayX/displayY/windowX/windowY/screenX/screenY) and
   * (x, y) is the platform-view local coordinate.
   *
   * For an unrotated view at offset (left, top) this reduces to localX = gx −
   * left, matching decodeTouchPacket's existing computation, so non-rotated
   * behaviour is unchanged. Rotated/scaled views (e.g. WebView inside a
   * RotatedBox) get the correctly transformed local coordinate instead.
   *
   * This must be applied exactly once per event, on the dispatch path
   * (postTouchEvent immediate branch, or onTouch flush of buffered events).
   *
   * @param event - The touch event whose touch points need correction
   * @param affineTransform - The global→local affine [invScaleX, invShearY, invTx, invShearX, invScaleY, invTy]
   */
  public static applyAffineTransform(event: CustomTouchEvent, affineTransform: Array<number> | undefined): void {
    if (affineTransform == undefined || affineTransform.length < 6) {
      return;
    }
    let invScaleX = affineTransform[0];
    let invShearY = affineTransform[1];
    let invTx     = affineTransform[2];
    let invShearX = affineTransform[3];
    let invScaleY = affineTransform[4];
    let invTy     = affineTransform[5];

    // Guard against non-finite coefficients (NaN / Infinity).  Although
    // applyTransformOffset validates the source matrix before storing it,
    // this is a defensive check at the consumption site to ensure that
    // stale or corrupted data never produces non-finite touch coordinates.
    if (!Number.isFinite(invScaleX) || !Number.isFinite(invShearY) || !Number.isFinite(invTx) ||
        !Number.isFinite(invShearX) || !Number.isFinite(invScaleY) || !Number.isFinite(invTy)) {
      return;
    }

    TouchEventProcessor.applyAffineToObjects(event.changedTouches, invScaleX, invShearY, invTx, invShearX, invScaleY, invTy);
    TouchEventProcessor.applyAffineToObjects(event.touches, invScaleX, invShearY, invTx, invShearX, invScaleY, invTy);
  }

  // Apply the global→local affine to the touch coordinates.
  // Only x/y (local coordinates) are overwritten; displayX/displayY/windowX/
  // windowY/screenX/screenY intentionally remain as the original screen
  // coordinates — they represent the global touch position, while x/y
  // represent the position relative to the component.  This matches the
  // OHOS TouchObject contract and the Android MotionEvent convention
  // (getX/getY = local, getRawX/getRawY = screen).
  private static applyAffineToObjects(objects: CustomTouchObject[], invScaleX: number, invShearY: number, invTx: number,
    invShearX: number, invScaleY: number, invTy: number): void {
    for (let i = 0; i < objects.length; i++) {
      let obj = objects[i];
      let gx = obj.displayX;
      let gy = obj.displayY;
      let lx = invScaleX * gx + invShearY * gy + invTx;
      let ly = invShearX * gx + invScaleY * gy + invTy;

      if (Number.isFinite(lx)) {
        obj.x = lx;
      }
      if (Number.isFinite(ly)) {
        obj.y = ly;
      }
    }
  }
}
