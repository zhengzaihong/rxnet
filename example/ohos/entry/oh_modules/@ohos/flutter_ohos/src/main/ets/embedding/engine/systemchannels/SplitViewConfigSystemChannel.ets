/*
 * Copyright (c) 2026 Huawei Device Co., Ltd. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE_HW file.
 */

import BasicMessageChannel from '../../../plugin/common/BasicMessageChannel';
import StringCodec from '../../../plugin/common/StringCodec';
import Log from '../../../util/Log';
import DartExecutor from '../dart/DartExecutor';
import { common, bundleManager } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';

const TAG: string = "SplitViewConfigSystemChannel";
const CHANNEL_NAME: string = "flutter/split_view_config_system";
const CONFIG_FILE_NAME: string = "split_config.json";

/**
 * Channel for sending split-view configuration from OpenHarmony to Flutter.
 * This channel reads split-view config from a rawfile, injects the app icon,
 * and forwards the assembled config to Dart via a system message channel.
 */
export default class SplitViewConfigSystemChannel {
  private channel: BasicMessageChannel<string>;
  private context: common.Context | null = null;
  private cachedConfigStr: string = '';

  /**
   * Constructs a new SplitViewConfigSystemChannel instance.
   * @param dartExecutor - The DartExecutor for sending messages to Dart.
   * @param context - The ability context used to access resources.
   */
  constructor(dartExecutor: DartExecutor, context: common.Context) {
    this.channel = new BasicMessageChannel<string>(dartExecutor, CHANNEL_NAME, StringCodec.INSTANCE);
    this.context = context;
  }

  /**
   * Sends the split-view configuration to Flutter.
   * Reads the config from cache or rawfile, injects the app icon as base64,
   * and transmits the assembled JSON to Dart via the message channel.
   */
  sendConfigToFlutter(): void {
    if (this.context === null) {
      Log.e(TAG, 'Context is null, cannot send config');
      return;
    }
    let configStr = this.cachedConfigStr;
    if (configStr === null || configStr === '') {
      configStr = this.readConfigFromRawfile() ?? '';
    }
    if (configStr === '') {
      Log.w(TAG, 'Config content is empty, skip sending');
      return;
    }
    const iconBase64 = this.getAppIconBase64();
    if (iconBase64.length > 0) {
      try {
        const config = JSON.parse(configStr) as Record<string, Object>;
        config['placeholderIconData'] = iconBase64;
        configStr = JSON.stringify(config);
      } catch (e) {
        Log.e(TAG, `Error injecting placeholderIconData: ${e}`);
      }
    }
    this.channel.resizeChannelBuffer(1);
    Log.i(TAG, 'Sending split view config to Dart via SystemChannel');
    this.channel.send(configStr);
  }

  private readConfigFromRawfile(): string | null {
    if (this.context === null) {
      return null;
    }
    try {
      const fileData = this.context.resourceManager.getRawFileContentSync(CONFIG_FILE_NAME);
      const decoder = util.TextDecoder.create('utf-8');
      const configStr = decoder.decodeToString(fileData);
      this.cachedConfigStr = configStr;
      return configStr;
    } catch (e) {
      Log.e(TAG, `Error reading rawfile: ${e}`);
      return null;
    }
  }

  private getAppIconBase64(): string {
    if (this.context === null) {
      return '';
    }
    try {
      const bundleInfo = bundleManager.getBundleInfoForSelfSync(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
      const iconId: number = bundleInfo.appInfo.iconId;
      if (iconId === 0) {
        Log.w(TAG, 'App icon not configured (iconId=0), skipping');
        return '';
      }
      // getMediaContentBase64Sync returns a data URI string:
      // "data:image/<subtype>;base64,<Base64EncodedData>"
      // Strip the data URI prefix so Dart receives pure base64.
      const dataUri: string = this.context.resourceManager.getMediaContentBase64Sync(iconId);
      const base64Index: number = dataUri.indexOf(';base64,');
      if (base64Index >= 0) {
        return dataUri.substring(base64Index + ';base64,'.length);
      }
      return dataUri;
    } catch (e) {
      Log.e(TAG, `Error getting app icon: ${e}`);
      return '';
    }
  }
}
