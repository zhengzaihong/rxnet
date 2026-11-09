/*
* Copyright (c) 2025 Huawei Device Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_HW file.
*/

import DartExecutor from '../dart/DartExecutor';
import { BinaryMessenger } from '../../../plugin/common/BinaryMessenger';
import MethodChannel from '../../../plugin/common/MethodChannel';
import JSONMethodCodec from '../../../plugin/common/JSONMethodCodec';

/**
 * Channel for handling status bar click events.
 * Sends a scroll-to-top notification to Flutter when the status bar is tapped.
 */
export default class StatusBarClickChannel {
  private static CHANNEL_NAME = "flutter/status_bar";
  private channel: MethodChannel;

  /**
   * Constructs a new StatusBarClickChannel instance.
   * @param binaryMessenger - The BinaryMessenger for sending messages to Dart
   */
  constructor(binaryMessenger: BinaryMessenger) {
    this.channel = new MethodChannel(binaryMessenger, StatusBarClickChannel.CHANNEL_NAME, JSONMethodCodec.INSTANCE);
  }

  /**
   * Notifies Flutter that the status bar was clicked, requesting a scroll-to-top action.
   */
  sendClick() {
    this.channel.invokeMethod('handleScrollToTop', null);
  }
}