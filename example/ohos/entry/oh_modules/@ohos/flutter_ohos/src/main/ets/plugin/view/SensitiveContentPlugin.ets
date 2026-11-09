/*
 * Copyright (c) 2026 Huawei Device Co., Ltd. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE_HW file.
 */

import SensitiveContentChannel, { SensitiveContentMethodHandler } from '../../embedding/engine/systemchannels/SensitiveContentChannel';
import Log from '../../util/Log';
import { BusinessError } from '@kit.BasicServicesKit';
import window from '@ohos.window';

import {
  SENSITIVE_CONTENT_SENSITIVITY,
  NOT_SENSITIVE_CONTENT_SENSITIVITY,
} from '../../embedding/engine/systemchannels/SensitiveContentChannel';
const TAG = "SensitiveContentChannel";
/**
 * Handles sensitive content requests received through the {@link SensitiveContentChannel} and applies
 * the requested sensitivity level to the current OpenHarmony window via window privacy mode.
 */
export default class SensitiveContentPlugin implements SensitiveContentMethodHandler {
  private readonly sensitiveContentChannel: SensitiveContentChannel;
  private currentContentSensitivity: number = NOT_SENSITIVE_CONTENT_SENSITIVITY;

  /**
   * Creates a SensitiveContentPlugin and registers itself as the method handler on the given channel.
   * @param sensitiveContentChannel - Channel used to receive sensitive content requests from Flutter.
   */
  constructor(
    sensitiveContentChannel: SensitiveContentChannel
  ) {
    this.sensitiveContentChannel = sensitiveContentChannel;
    this.sensitiveContentChannel.setSensitiveContentMethodHandler(this);
  }

  /**
   * Sets the content sensitivity level of the current window by toggling window privacy mode.
   * @param requestedContentSensitivity - Sensitivity level to apply.
   */
  setContentSensitivity(requestedContentSensitivity: number): void {
    let isPrivacyMode: boolean;
    switch (requestedContentSensitivity) {
      case SENSITIVE_CONTENT_SENSITIVITY:
        isPrivacyMode = true;
        break;
      case NOT_SENSITIVE_CONTENT_SENSITIVITY:
        isPrivacyMode = false;
        break;
      default:
        isPrivacyMode = false;
        requestedContentSensitivity = NOT_SENSITIVE_CONTENT_SENSITIVITY;
        break;
    }
    if (this.currentContentSensitivity === requestedContentSensitivity) {
      // Content sensitivity for the requested View already set to requestedContentSensitivity.
      return;
    }
    try {
      window.getLastWindow(getContext(), (err: BusinessError, data) => {
        const errCode = err.code;
        if (errCode) {
          return;
        }
        // Set requestedContentSensitivity on the View.
        let promise = data.setWindowPrivacyMode(isPrivacyMode);
        promise.then(() => {
          Log.d(TAG, "success to set the window to privacy mode.");
          this.currentContentSensitivity = requestedContentSensitivity;
        }).catch((err: BusinessError) => {
          Log.e(TAG, "Failed to set the window to privacy mode. Cause: " + JSON.stringify(err));
        });
      })
    } catch (exception) {
      Log.e(TAG, "Exception when setting window privacy mode: " + JSON.stringify(exception));
    }
  }

  /**
   * Gets the current content sensitivity level applied to the window.
   * @returns The current content sensitivity level.
   */
  getContentSensitivity(): number {
   return this.currentContentSensitivity;
  }

  /**
   * Checks whether setting and getting content sensitivity is supported on this device.
   * @returns true if sensitive content APIs are supported, false otherwise.
   */
  isSupported(): boolean {
    return true;
  }

  /**
   * Tears down the plugin by clearing its registration on the sensitive content channel.
   */
  destroy(): void {
    this.sensitiveContentChannel.setSensitiveContentMethodHandler(null);
  }
}

