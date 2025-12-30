/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*
* Based on KeyEventChannel.java originally written by
* Copyright (C) 2013 The Flutter Authors.
*
*/

import BasicMessageChannel from '../../../plugin/common/BasicMessageChannel';
import { BinaryMessenger } from '../../../plugin/common/BinaryMessenger';
import Log from '../../../util/Log';
import JSONMessageCodec from '../../../plugin/common/JSONMessageCodec';
import { KeyCode } from '@kit.InputKit';
import { ModifierKeyMetaInfo } from '../../ohos/KeyboardMap'

export default class KeyEventChannel {
  private static TAG = "KeyEventChannel";
  private static CHANNEL_NAME = "flutter/keyevent";
  private channel: BasicMessageChannel<Map<String, Object>>;

  constructor(binaryMessenger: BinaryMessenger) {
    this.channel = new BasicMessageChannel<Map<String, Object>>(binaryMessenger, KeyEventChannel.CHANNEL_NAME,
      JSONMessageCodec.INSTANCE);
  }

  sendFlutterKeyEvent(keyEvent: FlutterKeyEvent,
    isKeyUp: boolean,
    responseHandler: EventResponseHandler): void {
    this.channel.send(this.encodeKeyEvent(keyEvent, isKeyUp),
      (message: Map<String, Object>) => {
        let isEventHandled = false;
        try {
          if (message != null) {
            isEventHandled = message.get("handled") as boolean;
          }
        } catch (e) {
          Log.e(KeyEventChannel.TAG, "Unable to unpack JSON message: " + e);
        }
        responseHandler.onFrameworkResponse(isEventHandled);
      }
    );
  }

  private encodeKeyEvent(keyEvent: FlutterKeyEvent, isKeyUp: boolean): Map<String, Object> {
    let message: Map<String, Object> = new Map();
    message.set("type", isKeyUp ? "keyup" : "keydown");
    message.set("keymap", "ohos");
    message.set("keyCode", keyEvent.event.keyCode);
    message.set("deviceId", keyEvent.event.deviceId);
    message.set("flags", keyEvent.event.keyText);
    // the keyEvent of ohos do not support the getMetaState feature,
    // so the flutter-ohos side adapts the getMetaState() method
    message.set("metaState", keyEvent.getMetaState());
    message.set("source", keyEvent.event.keySource);
    message.set("intentionCode", keyEvent.event.intentionCode);
    return message;
  }

  // simulate the hardware key event in soft-keyboard text-editing function of the inputMethod
  simulateSendFlutterKeyEvent(keyEvent: SimulateKeyEvent,
    isKeyUp: boolean,
    responseHandler: EventResponseHandler): void {
    this.channel.send(this.encodeSimulatedKeyEvent(keyEvent, isKeyUp),
      (message: Map<String, Object>) => {
        let isEventHandled = false;
        try {
          if (message !== null) {
            isEventHandled = message.get("handled") as boolean;
          }
        } catch (e) {
          Log.e(KeyEventChannel.TAG, "Unable to unpack JSON message: " + e);
        }
        responseHandler.onFrameworkResponse(isEventHandled);
      }
    );
  }

  private encodeSimulatedKeyEvent(keyEvent: SimulateKeyEvent, isKeyUp: boolean): Map<String, Object> {
    let message: Map<String, Object> = new Map();
    message.set("type", isKeyUp ? "keyup" : "keydown");
    message.set("keymap", "ohos");
    message.set("keyCode", keyEvent.keyCode);
    message.set("flags", keyEvent.keyText);
    return message;
  }
}

export interface EventResponseHandler {
  onFrameworkResponse: (isEventHandled: boolean) => void;
}

export class FlutterKeyEvent {
  event: KeyEvent;
  private mMetaState: number;
  private isCtrlPressed: boolean | undefined = false;
  private isAltPressed: boolean | undefined = false;
  private isShiftPressed: boolean | undefined = false;

  constructor(ohosKeyEvent: KeyEvent) {
    this.event = ohosKeyEvent;
    this.mMetaState = ModifierKeyMetaInfo.NONE;
    this.isCtrlPressed = ohosKeyEvent.getModifierKeyState && ohosKeyEvent.getModifierKeyState(['Ctrl']);
    this.isAltPressed = ohosKeyEvent.getModifierKeyState && ohosKeyEvent.getModifierKeyState(['Alt']);
    this.isShiftPressed = ohosKeyEvent.getModifierKeyState && ohosKeyEvent.getModifierKeyState(['Shift']);
    this.didUpdateOhosMetaState();
  }

  // Supplementing the missing metaState feature of ohos, when long pressing the ‘ctrl’, ‘alt’, ‘shift’ keys
  // to perform combination key operations across different apps, and returns the updated metaState value
  // when ctrl/alt/shift key is pressed. Currently only supports metaState updates with Ctrl, Alt, and Shift keys.
  getMetaState(): number {
    return this.mMetaState;
  }

  private didUpdateOhosMetaState(): void {
    // The ohos platform only supports whether the Ctrl/Alt/Shift key or combination of them is pressed or not,
    // and cannot distinguish the left or right directions.
    // Here, the left direction key of ctrl/alt/shift is used by default
    if (this.isCtrlPressed != undefined) {
      this.updateMetaStateIfNeeded(KeyCode.KEYCODE_CTRL_LEFT, this.isCtrlPressed);
    }
    if (this.isAltPressed != undefined) {
      this.updateMetaStateIfNeeded(KeyCode.KEYCODE_ALT_LEFT, this.isAltPressed);
    }
    if (this.isShiftPressed != undefined) {
      this.updateMetaStateIfNeeded(KeyCode.KEYCODE_SHIFT_LEFT, this.isShiftPressed);
    }
  }

  private updateMetaStateIfNeeded(keyCode: number, isPressed: boolean): void {
    const oldMetaState: number = this.mMetaState;
    const newMetaState: number = this.updateMetaState(keyCode, isPressed, oldMetaState);
    const isMetaStateChanged: number = oldMetaState ^ newMetaState;
    if (isMetaStateChanged) {
      this.mMetaState = newMetaState;
    }
  }

  private updateMetaState(keyCode: number, isPressed: boolean, oldMetaState: number): number {
    switch (keyCode) {
      case KeyCode.KEYCODE_ALT_LEFT:
        return this.setMetaState(ModifierKeyMetaInfo.ALT_LEFT, isPressed, oldMetaState);
      case KeyCode.KEYCODE_ALT_RIGHT:
        return this.setMetaState(ModifierKeyMetaInfo.ALT_RIGHT, isPressed, oldMetaState);
      case KeyCode.KEYCODE_SHIFT_LEFT:
        return this.setMetaState(ModifierKeyMetaInfo.SHIFT_LEFT, isPressed, oldMetaState);
      case KeyCode.KEYCODE_SHIFT_RIGHT:
        return this.setMetaState(ModifierKeyMetaInfo.SHIFT_RIGHT, isPressed, oldMetaState);
      case KeyCode.KEYCODE_CTRL_LEFT:
        return this.setMetaState(ModifierKeyMetaInfo.CTRL_LEFT, isPressed, oldMetaState);
      case KeyCode.KEYCODE_CTRL_RIGHT:
        return this.setMetaState(ModifierKeyMetaInfo.CTRL_RIGHT, isPressed, oldMetaState);
      default:
        return oldMetaState;
    }
  }

  private setMetaState(mask: number, isPressed: boolean, oldMetaState: number): number {
    let newMetaState: number;
    if (isPressed) { // set the metaState of the pressed modifier key
      newMetaState = oldMetaState | mask;
    } else { // reset/clear the metaState of all modifier keys (ctrl|alt|shift|win/cmd)
      newMetaState = oldMetaState &
        ~(mask | ModifierKeyMetaInfo.CTRL | ModifierKeyMetaInfo.ALT |
        ModifierKeyMetaInfo.SHIFT | ModifierKeyMetaInfo.META);
    }
    // Update the non-sided modifier key metaState to match the content of the sided ones.
    if (newMetaState & (ModifierKeyMetaInfo.ALT_LEFT | ModifierKeyMetaInfo.ALT_RIGHT)) {
      newMetaState |= ModifierKeyMetaInfo.ALT;
    }
    if (newMetaState & (ModifierKeyMetaInfo.SHIFT_LEFT | ModifierKeyMetaInfo.SHIFT_RIGHT)) {
      newMetaState |= ModifierKeyMetaInfo.SHIFT;
    }
    if (newMetaState & (ModifierKeyMetaInfo.CTRL_LEFT | ModifierKeyMetaInfo.CTRL_RIGHT)) {
      newMetaState |= ModifierKeyMetaInfo.CTRL;
    }
    return newMetaState;
  }
}

// simulated keyevent applied in soft-keyboard
export class SimulateKeyEvent {
  keyCode: number;
  keyText: string;
  constructor(keyCode: number, keyText: string) {
    this.keyCode = keyCode;
    this.keyText = keyText;
  }
}