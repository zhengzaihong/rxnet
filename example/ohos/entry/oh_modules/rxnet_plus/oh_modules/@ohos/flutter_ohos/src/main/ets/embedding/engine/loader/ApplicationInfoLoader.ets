/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*/

import FlutterApplicationInfo from './FlutterApplicationInfo';
import common from '@ohos.app.ability.common';
import bundleManager from '@ohos.bundle.bundleManager';
import FlutterEngineFlags from '../FlutterEngineFlags';
import Log from '../../../util/Log';

const TAG = 'ApplicationInfoLoader';

/**
 * Loader for Flutter application information.
 * This class provides a static method to load FlutterApplicationInfo from the application context.
 */
export default class ApplicationInfoLoader {
  /**
   * Loads FlutterApplicationInfo from the application context.
   * @param context - The application context
   * @returns A FlutterApplicationInfo instance with default or context-based values
   */
  static load(context: common.Context) {
    let applicationInfo =
      new FlutterApplicationInfo(null, null, null, null, null, context.bundleCodeDir + '/libs/arm64', true);
    return applicationInfo
  }

  /**
   * Returns the module.json5 metadata of the current bundle as a name->value
   * map (OHOS counterpart of Android's <meta-data>). Metadata is re-read on
   * each call, as on Android.
   * @returns A map of metadata names to values, empty if unavailable
   */
  static getModuleMetadata(): Map<string, string> {
    const metadata = new Map<string, string>();
    try {
      const bundleInfo = bundleManager.getBundleInfoForSelfSync(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_HAP_MODULE |
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_METADATA);
      if (bundleInfo.hapModulesInfo != null) {
        for (const hapModuleInfo of bundleInfo.hapModulesInfo) {
          if (hapModuleInfo.metadata == null) {
            continue;
          }
          for (const item of hapModuleInfo.metadata) {
            if (item.name != null) {
              const value = item.value == null ? '' : item.value;
              // Only engine-flag keys need conflict diagnostics; other app
              // metadata may legitimately repeat across modules.
              if (item.name.startsWith(FlutterEngineFlags.METADATA_PREFIX) &&
                metadata.has(item.name) && metadata.get(item.name) !== value) {
                Log.w(TAG, `Duplicate metadata key '${item.name}' in module '${hapModuleInfo.name}': ` +
                  `'${metadata.get(item.name)}' is overridden with '${value}'. The last module wins.`);
              }
              metadata.set(item.name, value);
            }
          }
        }
      }
    } catch (e) {
      Log.e(TAG, `Failed to read module metadata: ${e}`);
    }
    return metadata;
  }
}
