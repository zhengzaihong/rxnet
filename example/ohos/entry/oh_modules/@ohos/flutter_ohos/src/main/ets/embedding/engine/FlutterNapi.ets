/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*/

import flutter, { WindowPositionResult as NativeWindowPositionResult } from 'libflutter.so';
import common from '@ohos.app.ability.common';
import Log from '../../util/Log';
import resourceManager from '@ohos.resourceManager';
import { PlatformMessageHandler } from './dart/PlatformMessageHandler';
import { FlutterCallbackInformation } from '../../view/FlutterCallbackInformation';
import image from '@ohos.multimedia.image';
import { EngineLifecycleListener } from './FlutterEngine';
import { ByteBuffer } from '../../util/ByteBuffer';
import LocalizationPlugin from '../../plugin/localization/LocalizationPlugin';
import i18n from '@ohos.i18n';
import Any from '../../plugin/common/Any';
import FlutterManager from '../ohos/FlutterManager';
import { DialogWindowCreationRequest, PopupWindowCreationRequest,
  RegularWindowCreationRequest, TooltipWindowCreationRequest,
  WindowConstraints } from '../ohos/windowing/WindowingUtils';
import deviceInfo from '@ohos.deviceInfo';
import window from '@ohos.window';
import TouchEventProcessor from '../ohos/TouchEventProcessor';
import BuildProfile from '../../../../../BuildProfile';
import { Action } from '../engine/systemchannels/AccessibilityChannel';

const TAG = "FlutterNapi";

enum ContextType {
  APP_LIFECYCLE = 0,
  JS_PAGE_LIFECYCLE,
}

export enum LTPOSwitchState {
  OFF = 0,
  ON = 1,
  NOT_INIT = 2
}

/**
 * Represents a pending platform message that is queued during preloading.
 * These messages are processed once the Flutter engine is ready to handle them.
 */
interface PendingMessage {
  /** The channel name for the message. */
  channel: string;
  /** The message data as an ArrayBuffer. */
  message: ArrayBuffer;
  /** The reply ID for responding to the message. */
  replyId: number;
  /** Additional message data. */
  messageData: number;
}

/**
 * Handler for Hybrid Composition (HCPP) callbacks coming from the engine.
 * Implemented by the HCPP platform views controller (M2). When absent, the
 * callbacks are logged and the engine degrades gracefully (no overlay / no
 * native view positioning), without affecting the external texture path.
 */
export interface HybridCompositionHandler {
  onDisplayPlatformViewHybrid(viewId: number, x: number, y: number, width: number,
    height: number, viewWidth: number, viewHeight: number): void;
  onDisplayOverlayHybrid(viewId: number, x: number, y: number, width: number,
    height: number): void;
  onDisplayMutatorsHybrid(viewId: number, data: number[]): void;
  hidePlatformViewHybrid(viewId: number): void;
  showOverlaySurfaceHybrid(): void;
  hideOverlaySurfaceHybrid(): void;
  onBeginFrameHybrid(): void;
  onEndFrameHybrid(): void;
}

export class WindowPositionResult implements NativeWindowPositionResult {
  left: number = 0;
  top: number = 0;
  width: number = 0;
  height: number = 0;
  set(left: number, top: number, width: number, height: number): void {
    this.left = left;
    this.top = top;
    this.width = width;
    this.height = height;
  }
}

/**
 * Provides Flutter NAPI interface for ArkTS.
 * This class serves as the bridge between the ArkTS layer and the native Flutter engine,
 * handling initialization, message passing, viewport management, and lifecycle events.
 */
export default class FlutterNapi {
  private static hasInit: boolean = false;
  /** Whether the native methods have been implemented. */
  hasImplemented: boolean = false;
  /** The native shell holder ID, or null if not attached. */
  nativeShellHolderId: number | null = null;
  /** The platform message handler for receiving messages from Dart, or null if not set. */
  platformMessageHandler: PlatformMessageHandler | null = null;
  private engineLifecycleListeners = new Set<EngineLifecycleListener>();
  /** The accessibility delegate for handling accessibility events, or null if not set. */
  accessibilityDelegate: AccessibilityDelegate | null = null;
  /** The localization plugin for handling locale information, or null if not set. */
  localizationPlugin: LocalizationPlugin | null = null;
  /** Whether Flutter UI is currently being displayed. */
  isDisplayingFlutterUi: boolean = false;
  /** Whether Flutter UI has been preloaded. */
  isPreloadedFlutterUi: boolean = false;
  /** Whether Dart code is currently running. */
  isRunningDart: boolean = false;
  private nextSpawnNapi: FlutterNapi | null = null;
  private pendingMessages: PendingMessage[] = [];
  private readyForHandleMessage: boolean = true;
  private firstPreloading: boolean = true;
  /** Hybrid Composition (HCPP) handler, or null when HCPP is inactive. */
  private hybridCompositionHandler: HybridCompositionHandler | null = null;
  /**
   * Cached result of isHybridCompositionEnabled(). The native value is set once
   * during PlatformViewOHOS construction and never changes, so we query NAPI
   * a single time and reuse the cached boolean on subsequent calls (notably the
   * per-touch-event hot path in onTouchEvent). null = not yet queried.
   */
  private hybridCompositionEnabledCached: boolean | null = null;
  /**
   * Reports whether any texture-mode (TLHC) platform view is alive, so the
   * HCPP touch-path skip in onTouchEvent can spare the reinjection stream
   * those views depend on. Wired by FlutterEngine from PlatformViewsController
   * (lazily evaluated per call). null = not wired (skip stays in effect).
   */
  private textureTouchArbiter: (() => boolean) | null = null;

  /**
   * Updates the refresh rate for the Flutter engine.
   * @param refreshRateFPS - The refresh rate in frames per second
   */
  updateRefreshRate(refreshRateFPS: number) {
    flutter.nativeUpdateRefreshRate(refreshRateFPS);
  }

  /**
   * Updates the size of the Flutter view.
   * @param width - The new width in pixels
   * @param height - The new height in pixels
   */
  updateSize(width: number, height: number) {
    flutter.nativeUpdateSize(width, height);
  }

  /**
   * Updates the pixel density of the display.
   * @param densityPixels - The pixel density value (dots per inch)
   */
  updateDensity(densityPixels: number) {
    Log.i(TAG, "updateDensity called: " + densityPixels);
    flutter.nativeUpdateDensity(densityPixels);
  }

  /**
   * Initializes the Flutter engine with the specified parameters.
   * @param context - The application context
   * @param args - Command-line arguments for the Flutter engine
   * @param bundlePath - Path to the Flutter bundle
   * @param appStoragePath - Path to the application storage directory
   * @param engineCachesPath - Path to the engine caches directory
   * @param initTimeMillis - Initialization time in milliseconds
   */
  init(context: common.Context,
    args: Array<string>,
    bundlePath: string,
    appStoragePath: string,
    engineCachesPath: string,
    initTimeMillis: number) {
    if (FlutterNapi.hasInit) {
      Log.e(TAG, "the engine has init");
      return;
    }
    Log.w(TAG, "HAR_VERSION=" + BuildProfile.HAR_VERSION);
    Log.d(TAG, JSON.stringify({
      "name": "init, initTimeMillis=" + initTimeMillis,
      "bundlePath": bundlePath,
      "appStoragePath": appStoragePath,
      "engineCachesPath": engineCachesPath,
      "args": args,
    }));
    let code: number | null = flutter.nativeInit(context, args, bundlePath, appStoragePath,
      engineCachesPath, initTimeMillis, deviceInfo.productModel);
    FlutterNapi.hasInit = code == 0;
    Log.d(TAG, "init code=" + code + ", FlutterNapi.hasInit" + FlutterNapi.hasInit);
  }

  /**
   * Prefetches the default font manager.
   * This should be called before using fonts in the Flutter engine.
   */
  static prefetchDefaultFontManager(): void {
    flutter.nativePrefetchDefaultFontManager();
  }

  /**
   * Checks and reloads fonts for this engine instance.
   */
  checkAndReloadFont(): void {
    flutter.nativeCheckAndReloadFont(this.nativeShellHolderId!);
  }

  /**
   * Attaches this FlutterNapi instance to the native engine.
   * This must be called before using most FlutterNapi methods.
   */
  attachToNative(): void {
    if (!FlutterNapi.hasInit) {
      Log.e(TAG, "attachToNative fail, FlutterNapi.hasInit=" + FlutterNapi.hasInit);
      return;
    }
    if (this.nativeShellHolderId == null) {
      this.nativeShellHolderId = flutter.nativeAttach(this);
    }
    Log.d(TAG, "nativeShellHolderId=" + this.nativeShellHolderId);
  }

  /**
   * Runs a Flutter bundle and snapshot from a library.
   * @param bundlePath - Path to the Flutter bundle
   * @param entrypointFunctionName - Name of the entrypoint function
   * @param pathToEntrypointFunction - Path to the entrypoint function
   * @param assetManager - Resource manager for accessing assets
   * @param entrypointArgs - Arguments to pass to the entrypoint function
   */
  runBundleAndSnapshotFromLibrary(
    bundlePath: string,
    entrypointFunctionName: string | undefined,
    pathToEntrypointFunction: string | undefined,
    assetManager: resourceManager.ResourceManager,
    entrypointArgs: Array<string>) {
    if (!FlutterNapi.hasInit) {
      Log.e(TAG, "runBundleAndSnapshotFromLibrary fail, FlutterNapi.hasInit=" + FlutterNapi.hasInit);
      return;
    }
    Log.d(TAG, "init: bundlePath=" + bundlePath + "  entrypointFunctionName=" + entrypointFunctionName +
      "  pathToEntrypointFunction=" + pathToEntrypointFunction + "  entrypointArgs=" + JSON.stringify(entrypointArgs))
    if (!this.nativeShellHolderId) {
      Log.e(TAG, "runBundleAndSnapshotFromLibrary this.nativeShellHolderId = " + this.nativeShellHolderId)
      return;
    }
    const shellHolderId: number = this.nativeShellHolderId as number;
    flutter.nativeRunBundleAndSnapshotFromLibrary(shellHolderId, bundlePath, entrypointFunctionName!,
      pathToEntrypointFunction!, assetManager, entrypointArgs);
    this.isRunningDart = true;
    this.isDisplayingFlutterUi = false;
    this.isPreloadedFlutterUi = false;
  };

  /**
   * Checks if the native methods are implemented.
   * @param methodName - Optional method name for logging
   * @returns true if methods are implemented, false otherwise
   */
  checkImplemented(methodName: string = ""): boolean {
    if (!this.hasImplemented) {
      Log.e(TAG, "this method has not implemented -> " + methodName)
    }
    return this.hasImplemented;
  }

  /**
   * Sets the platform message handler for receiving messages from Dart.
   * @param platformMessageHandler - The PlatformMessageHandler instance, or null to remove
   */
  setPlatformMessageHandler(platformMessageHandler: PlatformMessageHandler | null): void {
    this.ensureRunningOnMainThread();
    this.platformMessageHandler = platformMessageHandler;
  }

  private nativeNotifyLowMemoryWarning(nativeShellHolderId: number): void {

  }

  /**
   * Looks up callback information for a given handler.
   * @param handle - The handler number
   * @returns The FlutterCallbackInformation, or null if not found
   */
  static nativeLookupCallbackInformation(handle: number): FlutterCallbackInformation | null {
    let callbackInformation = new FlutterCallbackInformation();
    let ret: number = flutter.nativeLookupCallbackInformation(callbackInformation, handle);
    if (ret == 0) {
      return callbackInformation;
    }
    return null;
  }

  /**
   * Looks up callback information for a given handler using a bigint handle.
   * @param handle - The handler as a bigint
   * @returns The FlutterCallbackInformation, or null if not found
   */
  static nativeLookupCallbackInformationBigInt(handle: bigint): FlutterCallbackInformation | null {
    let callbackInformation = new FlutterCallbackInformation();
    let ret: number = flutter.nativeLookupCallbackInformationBigInt(callbackInformation, handle);
    if (ret == 0) {
      return callbackInformation;
    }
    return null;
  }

  /**
   * The OS itself destroyed a host window (title-bar close, sub-window
   * teardown): native fires the same teardown Dart destroy() triggers.
   * Safe to call unconditionally — native no-ops if already torn down.
   */
  static nativeHandleOsWindowClosed(viewId: number): void {
    flutter.nativeHandleOsWindowClosed(viewId);
  }

  /**
   * Computes the LOGICAL position for a positioner-anchored sub-window via
   * the Dart positioner callback. `out` is populated only when the view
   * has a positioner; nonzero return → the caller keeps default OS
   * placement. Caller scales to physical px for moveWindowTo.
   */
  static nativeComputeWindowPosition(out: WindowPositionResult, viewId: number,
    childSize: window.Size, parentRect: window.Rect, workArea: window.Rect): number {
    return flutter.nativeComputeWindowPosition(out, viewId,
      childSize.width, childSize.height,
      parentRect.left, parentRect.top, parentRect.width, parentRect.height,
      workArea.left, workArea.top, workArea.width, workArea.height);
  }

  /**
   * Window focus changed (windowEvent/stageEvent ACTIVE↔INACTIVE): native
   * caches the flag and pings the window's notify-listeners chain so Dart
   * `isActivated` dependents rebuild and re-query.
   */
  static nativeNotifyWindowActivated(viewId: number, activated: boolean): void {
    flutter.nativeNotifyWindowActivated(viewId, activated);
  }

  /**
   * Notifies the Flutter engine of a low memory warning.
   */
  notifyLowMemoryWarning(): void {
    this.ensureRunningOnMainThread();
    if (!this.nativeShellHolderId) {
      Log.e(TAG, "notifyLowMemoryWarning this.nativeShellHolderId = " + this.nativeShellHolderId)
      return;
    }
    this.nativeNotifyLowMemoryWarning(this.nativeShellHolderId!);
  }

  /**
   * Checks if this FlutterNapi instance is attached to the native engine.
   * @returns true if attached, false otherwise
   */
  isAttached(): boolean {
    return this.nativeShellHolderId != null;
  }

  /**
   * Ensures that the current code is running on the main thread.
   */
  private ensureRunningOnMainThread(): void {

  }

  /**
   * Dispatches an empty platform message to Dart.
   * @param channel - The channel name for the message
   * @param responseId - The response ID for receiving a reply
   */
  dispatchEmptyPlatformMessage(channel: String, responseId: number): void {
    this.ensureRunningOnMainThread();
    if (this.isAttached()) {
      if (!this.nativeShellHolderId) {
        Log.e(TAG, "dispatchEmptyPlatformMessage this.nativeShellHolderId = " + this.nativeShellHolderId)
        return;
      }
      flutter.nativeDispatchEmptyPlatformMessage(this.nativeShellHolderId!, channel, responseId);
    } else {
      Log.w(
        TAG,
        "Tried to send a platform message to Flutter, but FlutterNapi was detached from native C++. Could not send. Channel: "
          + channel
          + ". Response ID: "
          + responseId);
    }
  }

  /**
   * Sends a platform message with data from OpenHarmony to Flutter over the given channel.
   * @param channel - The channel name for the message
   * @param message - The message data as an ArrayBuffer
   * @param position - The position in the message buffer
   * @param responseId - The response ID for receiving a reply
   */
  dispatchPlatformMessage(channel: String, message: ArrayBuffer, position: number, responseId: number): void {
    this.ensureRunningOnMainThread();
    if (this.isAttached()) {
      if (!this.nativeShellHolderId) {
        Log.e(TAG, "dispatchPlatformMessage this.nativeShellHolderId = " + this.nativeShellHolderId)
        return;
      }
      flutter.nativeDispatchPlatformMessage(this.nativeShellHolderId!, channel, message, position, responseId);
    } else {
      Log.w(
        TAG,
        "Tried to send a platform message to Flutter, but FlutterNapi was detached from native C++. Could not send. Channel: "
          + channel
          + ". Response ID: "
          + responseId);
    }
  }

  /**
   * Invokes an empty response callback for a platform message.
   * @param responseId - The response ID that was sent with the original message
   */
  invokePlatformMessageEmptyResponseCallback(responseId: number): void {
    if (this.isAttached()) {
      if (!this.nativeShellHolderId) {
        Log.e(TAG, "invokePlatformMessageEmptyResponseCallback this.nativeShellHolderId = " + this.nativeShellHolderId)
        return;
      }
      flutter.nativeInvokePlatformMessageEmptyResponseCallback(this.nativeShellHolderId!, responseId);
    } else {
      Log.w(
        TAG,
        "Tried to send a platform message response, but FlutterNapi was detached from native C++. Could not send. Response ID: "
          + responseId);
    }
  }

  /**
   * Invokes a response callback with data for a platform message.
   * @param responseId - The response ID that was sent with the original message
   * @param message - The reply data as an ArrayBuffer
   * @param position - The position in the message buffer
   */
  invokePlatformMessageResponseCallback(responseId: number, message: ArrayBuffer, position: number) {
    if (this.isAttached()) {
      if (!this.nativeShellHolderId) {
        Log.e(TAG, "this.nativeShellHolderId = " + this.nativeShellHolderId)
        return;
      }
      flutter.nativeInvokePlatformMessageResponseCallback(
        this.nativeShellHolderId!, responseId, message, position);
    } else {
      Log.w(
        TAG,
        "Tried to send a platform message response, but FlutterNapi was detached from native C++. Could not send. Response ID: "
          + responseId);
    }
  }

  /**
   * Sets the viewport metrics for the Flutter view.
   * @param devicePixelRatio - The device pixel ratio
   * @param physicalWidth - Physical width in pixels
   * @param physicalHeight - Physical height in pixels
   * @param physicalPaddingTop - Top padding in physical pixels
   * @param physicalPaddingRight - Right padding in physical pixels
   * @param physicalPaddingBottom - Bottom padding in physical pixels
   * @param physicalPaddingLeft - Left padding in physical pixels
   * @param physicalViewInsetTop - Top view inset in physical pixels
   * @param physicalViewInsetRight - Right view inset in physical pixels
   * @param physicalViewInsetBottom - Bottom view inset in physical pixels
   * @param physicalViewInsetLeft - Left view inset in physical pixels
   * @param systemGestureInsetTop - Top system gesture inset
   * @param systemGestureInsetRight - Right system gesture inset
   * @param systemGestureInsetBottom - Bottom system gesture inset
   * @param systemGestureInsetLeft - Left system gesture inset
   * @param physicalTouchSlop - Physical touch slop value
   * @param displayFeaturesBounds - Array of display feature bounds
   * @param displayFeaturesType - Array of display feature types
   * @param displayFeaturesState - Array of display feature states
   * @param displayCornerRadiusTopLeft - Top-left display corner radius in physical pixels; defaults to -1 (unavailable) when omitted
   * @param displayCornerRadiusTopRight - Top-right display corner radius in physical pixels; defaults to -1 (unavailable) when omitted
   * @param displayCornerRadiusBottomRight - Bottom-right display corner radius in physical pixels; defaults to -1 (unavailable) when omitted
   * @param displayCornerRadiusBottomLeft - Bottom-left display corner radius in physical pixels; defaults to -1 (unavailable) when omitted
   */
  setViewportMetrics(devicePixelRatio: number, physicalWidth: number
    , physicalHeight: number, physicalPaddingTop: number, physicalPaddingRight: number
    , physicalPaddingBottom: number, physicalPaddingLeft: number, physicalViewInsetTop: number
    , physicalViewInsetRight: number, physicalViewInsetBottom: number, physicalViewInsetLeft: number
    , systemGestureInsetTop: number, systemGestureInsetRight: number, systemGestureInsetBottom: number
    , systemGestureInsetLeft: number, physicalTouchSlop: number, displayFeaturesBounds: Array<number>
    , displayFeaturesType: Array<number>, displayFeaturesState: Array<number>
    , displayCornerRadiusTopLeft: number = -1, displayCornerRadiusTopRight: number = -1
    , displayCornerRadiusBottomRight: number = -1, displayCornerRadiusBottomLeft: number = -1): void {
    if (this.isAttached()) {
      if (!this.nativeShellHolderId) {
        Log.e(TAG, "setViewportMetrics this.nativeShellHolderId = " + this.nativeShellHolderId)
        return;
      }
      flutter.nativeSetViewportMetrics(this.nativeShellHolderId!, devicePixelRatio,
        physicalWidth,
        physicalHeight,
        physicalPaddingTop,
        physicalPaddingRight,
        physicalPaddingBottom,
        physicalPaddingLeft,
        physicalViewInsetTop,
        physicalViewInsetRight,
        physicalViewInsetBottom,
        physicalViewInsetLeft,
        systemGestureInsetTop,
        systemGestureInsetRight,
        systemGestureInsetBottom,
        systemGestureInsetLeft,
        physicalTouchSlop,
        displayFeaturesBounds,
        displayFeaturesType,
        displayFeaturesState,
        displayCornerRadiusTopLeft,
        displayCornerRadiusTopRight,
        displayCornerRadiusBottomRight,
        displayCornerRadiusBottomLeft);
    }
  }

  /**
   * Spawns a new FlutterNapi instance from this instance.
   * @param entrypointFunctionName - Name of the entrypoint function
   * @param pathToEntrypointFunction - Path to the entrypoint function
   * @param initialRoute - Initial route for navigation
   * @param entrypointArgs - Arguments to pass to the entrypoint function
   * @returns A new FlutterNapi instance
   */
  spawn(entrypointFunctionName: string, pathToEntrypointFunction: string, initialRoute: string,
    entrypointArgs: Array<string>): FlutterNapi {
    if (this.nextSpawnNapi) {
      let ret = this.nextSpawnNapi;
      this.nextSpawnNapi = null;
      return ret;
    }
    let flutterNapi = new FlutterNapi();
    let shellHolderId: number =
      flutter.nativeSpawn(this.nativeShellHolderId, entrypointFunctionName, pathToEntrypointFunction, initialRoute,
        entrypointArgs, flutterNapi);
    flutterNapi.nativeShellHolderId = shellHolderId;
    flutterNapi.isRunningDart = this.isRunningDart;
    flutterNapi.isDisplayingFlutterUi = false;
    flutterNapi.isPreloadedFlutterUi = false;
    return flutterNapi;
  }

  /**
   * Spawns a new FlutterNapi instance from this instance asynchronously.
   * @param entrypointFunctionName - Name of the entrypoint function
   * @param pathToEntrypointFunction - Path to the entrypoint function
   * @param initialRoute - Initial route for navigation
   * @param entrypointArgs - Arguments to pass to the entrypoint function
   * @returns Promise of the new FlutterNapi instance
   */
  spawnAsync(entrypointFunctionName: string, pathToEntrypointFunction: string, initialRoute: string,
    entrypointArgs: Array<string>): Promise<FlutterNapi> {
    if (this.nextSpawnNapi) {
      let ret = this.nextSpawnNapi;
      this.nextSpawnNapi = null;
      return Promise.resolve(ret);
    }
    let flutterNapi = new FlutterNapi();
    return flutter.nativeSpawnAsync(this.nativeShellHolderId, entrypointFunctionName, pathToEntrypointFunction,
      initialRoute, entrypointArgs, flutterNapi).then((shellHolderId: number) => {
      flutterNapi.nativeShellHolderId = shellHolderId;
      flutterNapi.isRunningDart = this.isRunningDart;
      flutterNapi.isDisplayingFlutterUi = false;
      flutterNapi.isPreloadedFlutterUi = false;
      return flutterNapi;
    });
  }

  /**
   * Pre-spawns a new FlutterNapi instance for later use.
   * @param entrypointFunctionName - Name of the entrypoint function
   * @param pathToEntrypointFunction - Path to the entrypoint function
   * @param initialRoute - Initial route for navigation
   * @param entrypointArgs - Arguments to pass to the entrypoint function
   * @returns A new FlutterNapi instance that will be used on the next spawn call
   */
  preSpawn(entrypointFunctionName: string, pathToEntrypointFunction: string, initialRoute: string,
    entrypointArgs: Array<string>): FlutterNapi {
    if (this.nextSpawnNapi) {
      this.nextSpawnNapi.detachFromNativeAndReleaseResources();
    }
    let flutterNapi = new FlutterNapi();
    let shellHolderId: number =
      flutter.nativeSpawn(this.nativeShellHolderId, entrypointFunctionName, pathToEntrypointFunction, initialRoute,
        entrypointArgs, flutterNapi);
    flutterNapi.nativeShellHolderId = shellHolderId;
    flutterNapi.isRunningDart = this.isRunningDart;
    flutterNapi.isDisplayingFlutterUi = false;
    flutterNapi.isPreloadedFlutterUi = false;
    this.nextSpawnNapi = flutterNapi;
    return flutterNapi;
  }

  /**
   * Adds an engine lifecycle listener.
   * @param engineLifecycleListener - The EngineLifecycleListener to add
   */
  addEngineLifecycleListener(engineLifecycleListener: EngineLifecycleListener): void {
    this.engineLifecycleListeners.add(engineLifecycleListener);
  }

  /**
   * Removes an engine lifecycle listener.
   * @param engineLifecycleListener - The EngineLifecycleListener to remove
   */
  removeEngineLifecycleListener(engineLifecycleListener: EngineLifecycleListener) {
    this.engineLifecycleListeners.delete(engineLifecycleListener);
  }

  /**
   * Called by native to respond to a platform message that we sent.
   * @param replyId - The response ID that was sent with the original message
   * @param reply - The reply data as an ArrayBuffer
   */
  handlePlatformMessageResponse(replyId: number, reply: ArrayBuffer): void {
    Log.d(TAG, "called handlePlatformMessageResponse Response ID: " + replyId);
    if (this.platformMessageHandler != null) {
      this.platformMessageHandler.handlePlatformMessageResponse(replyId, reply);
    }
  }

  /**
   * Called by native on any thread to handle a platform message from Dart.
   * @param channel - The channel name for the message
   * @param message - The message data as an ArrayBuffer
   * @param replyId - The reply ID for responding to the message
   * @param messageData - Additional message data
   */
  handlePlatformMessage(channel: string, message: ArrayBuffer, replyId: number, messageData: number): void {
    Log.d(TAG, "called handlePlatformMessage Channel: " + channel + ". Response ID: " + replyId);
    if (this.platformMessageHandler != null && this.readyForHandleMessage) {
      this.platformMessageHandler.handleMessageFromDart(channel, message, replyId, messageData);
    } else {
      const pendingMessage: PendingMessage = {
        channel,
        message,
        replyId,
        messageData
      };
      this.pendingMessages.push(pendingMessage);
    }
  }

  /**
   * Sets the preloading state, preventing message handling until ready.
   */
  setPreloading(): void {
    if (this.firstPreloading) {
      this.readyForHandleMessage = false;
      this.firstPreloading = false;
    }
  }

  /**
   * Processes all pending messages that were queued during preloading.
   */
  processPendingMessages(): void {
    Log.d(TAG, "processPendingMessages len:" + this.pendingMessages.length);
    this.readyForHandleMessage = true;
    while (this.pendingMessages.length > 0 && this.platformMessageHandler) {
      const pendingMessage = this.pendingMessages.shift();
      if (pendingMessage) {
        this.platformMessageHandler.handleMessageFromDart(
          pendingMessage.channel,
          pendingMessage.message,
          pendingMessage.replyId,
          pendingMessage.messageData
        );
      }
    }
  }

  /**
   * Called by native to notify that the first Flutter frame has been rendered.
   * @param isPreload - Whether this is a preload frame (1) or a regular frame (0)
   */
  onFirstFrame(isPreload: number): void {
    Log.d(TAG, "called onFirstFrame isPreload:" + isPreload);
    if (isPreload) {
      this.isPreloadedFlutterUi = true;
    } else {
      this.processPendingMessages();
      if (this.isDisplayingFlutterUi) {
        return;
      }
      this.isDisplayingFlutterUi = true;
    }
    FlutterManager.getInstance().getFlutterViewList().forEach((value) => {
      if (this.nativeShellHolderId != null && value.isSameEngineShellHolderId(this.nativeShellHolderId)) {
        value.onFirstFrame(isPreload);
      }
    });
  }

  // Native entries (InvokeJsMethod), one per archetype — the same names as
  // the C++ facade. req carries the creation fields (preferred size / constraints / title /
  // parentViewId, LOGICAL px), field-for-field with the C++ structs in
  // ohos_window_types.h.

  createRegularWindow(viewId: number, req: RegularWindowCreationRequest): void {
    FlutterManager.getInstance().createRegularWindow(viewId, req);
  }

  /** Dialog: modal (parentViewId set) → SubWindow; modeless (sentinel) →
   * UIAbility spawn. */
  createDialogWindow(viewId: number, req: DialogWindowCreationRequest): void {
    FlutterManager.getInstance().createDialogWindow(viewId, req);
  }

  /** Tooltip: anchored, parent-bound SubWindow. */
  createTooltipWindow(viewId: number, req: TooltipWindowCreationRequest): void {
    FlutterManager.getInstance().createTooltipWindow(viewId, req);
  }

  /** Popup: anchored, parent-bound SubWindow. */
  createPopupWindow(viewId: number, req: PopupWindowCreationRequest): void {
    FlutterManager.getInstance().createPopupWindow(viewId, req);
  }

  /**
   * Native entry (InvokeJsMethod "bindEntryAbilityToView"): reuse the
   * EntryAbility's pre-created main window as the surface host for the
   * FIRST Dart-requested Regular window — the first RegularWindow IS the
   * main window, keeping `main.dart` identical across platforms.
   * Subsequent Regular windows use createRegularWindow.
   */
  bindEntryAbilityToView(viewId: number, req: RegularWindowCreationRequest): void {
    FlutterManager.getInstance().bindEntryAbilityToView(viewId, req);
  }

  /** Native entry (InvokeJsMethod "updateTooltipPosition"): Dart pushed a
   * fresh anchorRect/positioner (controller.updatePosition) — re-run the
   * positioner and move the tooltip sub-window. */
  updateTooltipPosition(viewId: number): void {
    FlutterManager.getInstance().updateTooltipPosition(viewId);
  }

  updatePopupPosition(viewId: number): void {
    FlutterManager.getInstance().updatePopupPosition(viewId);
  }

  /** Native entry (InvokeJsMethod "didUpdateViewSize"): the raster thread
   * reported a sized-to-content view's new content size (PHYSICAL px;
   * win32 HostWindowTooltip::DidUpdateViewSize parity). */
  didUpdateViewSize(viewId: number, width: number, height: number): void {
    FlutterManager.getInstance().didUpdateViewSize(viewId, width, height);
  }

  /** Native entry (InvokeJsMethod "destroyWindowHost"): tear down the OS
   * window host when Dart closes it (controller.destroy()). */
  destroyWindowHost(viewId: number): void {
    Log.d(TAG, `destroyWindowHost viewId=${viewId}`);
    const host = FlutterManager.getInstance().getHostWindowByView(viewId);
    if (!host) {
      Log.w(TAG, `destroyWindowHost: no host for ${viewId} (already closed?)`);
      return;
    }
    host.destroy();
  }

  exitApplication(): void {
    Log.d(TAG, `exitApplication`);
    FlutterManager.getInstance().exitApplication();
  }

  setWindowSize(viewId: number, width: number, height: number): void {
    Log.d(TAG, `setWindowSize viewId=${viewId} size=${width}x${height}`);
    const host = FlutterManager.getInstance().getHostWindowByView(viewId);
    if (!host) {
      Log.e(TAG, `setWindowSize: no window for viewId=${viewId}`);
      return;
    }
    host.setWindowSize(width, height);
  }

  setWindowTitle(viewId: number, title: string): void {
    Log.d(TAG, `setWindowTitle viewId=${viewId} title="${title}"`);
    const host = FlutterManager.getInstance().getHostWindowByView(viewId);
    if (!host) {
      Log.e(TAG, `setWindowTitle: no window for viewId=${viewId}`);
      return;
    }
    host.setWindowTitle(title);
  }

  setWindowMaximized(viewId: number, maximized: boolean): void {
    Log.d(TAG, `setWindowMaximized viewId=${viewId} maximized=${maximized}`);
    const host = FlutterManager.getInstance().getHostWindowByView(viewId);
    if (!host) {
      Log.e(TAG, `setWindowMaximized: no window for viewId=${viewId}`);
      return;
    }
    host.setWindowMaximized(maximized);
  }

  setWindowMinimized(viewId: number, minimized: boolean): void {
    Log.d(TAG, `setWindowMinimized viewId=${viewId} minimized=${minimized}`);
    const host = FlutterManager.getInstance().getHostWindowByView(viewId);
    if (!host) {
      Log.e(TAG, `setWindowMinimized: no window for viewId=${viewId}`);
      return;
    }
    host.setWindowMinimized(minimized);
  }

  setWindowFullscreen(viewId: number, fullscreen: boolean): void {
    Log.d(TAG, `setWindowFullscreen viewId=${viewId} fullscreen=${fullscreen}`);
    const host = FlutterManager.getInstance().getHostWindowByView(viewId);
    if (!host) {
      Log.e(TAG, `setWindowFullscreen: no window for viewId=${viewId}`);
      return;
    }
    host.setWindowFullscreen(fullscreen);
  }

  // LOGICAL-px runtime constraint update (max 0 == unbounded).
  setWindowConstraints(viewId: number, constraints: WindowConstraints): void {
    // Wrap the raw napi object (creation bridges do the same).
    const c = new WindowConstraints(constraints);
    Log.d(TAG, `setWindowConstraints viewId=${viewId} ${c.toString()}`);
    const host = FlutterManager.getInstance().getHostWindowByView(viewId);
    if (!host) {
      Log.e(TAG, `setWindowConstraints: no window for viewId=${viewId}`);
      return;
    }
    const limits: window.WindowLimits = {
      minWidth: c.viewMinWidth,
      minHeight: c.viewMinHeight,
      maxWidth: c.viewMaxWidth,
      maxHeight: c.viewMaxHeight
    };
    host.setWindowLimits(limits);
  }

  // Brings the window to front.
  activateWindow(viewId: number): void {
    Log.d(TAG, `activateWindow viewId=${viewId}`);
    const host = FlutterManager.getInstance().getHostWindowByView(viewId);
    if (!host) {
      Log.e(TAG, `activateWindow: no window for viewId=${viewId}`);
      return;
    }
    host.activate();
  }

  /**
   * Called by native when the engine is about to restart.
   * Notifies all registered lifecycle listeners.
   */
  onPreEngineRestart(): void {
    Log.d(TAG, "called onPreEngineRestart")
    this.engineLifecycleListeners.forEach(listener => listener.onPreEngineRestart());
  }

  /**
   * Registers the HCPP handler that receives engine composition callbacks.
   * @param handler - The handler, or null to unregister.
   */
  setHybridCompositionHandler(handler: HybridCompositionHandler | null): void {
    this.hybridCompositionHandler = handler;
    Log.i(TAG, "setHybridCompositionHandler " + (handler != null ? "registered" : "cleared"));
  }

  /**
   * Whether Hybrid Composition (HCPP) is enabled on the native engine.
   * The native value is immutable after PlatformViewOHOS construction, so the
   * first call queries NAPI and caches the result; subsequent calls (including
   * the per-touch-event hot path) return the cached boolean without crossing
   * the JS→C++ boundary.
   */
  isHybridCompositionEnabled(): boolean {
    if (this.hybridCompositionEnabledCached != null) {
      return this.hybridCompositionEnabledCached;
    }
    if (this.nativeShellHolderId == null) {
      return false;
    }
    const enabled: boolean =
      flutter.nativeIsHybridCompositionEnabled(this.nativeShellHolderId);
    this.hybridCompositionEnabledCached = enabled;
    return enabled;
  }

  /**
   * HCPP route D: injects a DISPLAY system layer's touch event into the engine.
   * Each touchData item fields mirror native HandleTouchEvent's PointerData
   * layout; coordinates must already be physical pixels in the Flutter-view
   * coordinate system.
   */
  dispatchTouchToEngine(touchData: Object[]): void {
    if (this.nativeShellHolderId == null) {
      Log.e(TAG, "dispatchTouchToEngine: nativeShellHolderId is null");
      return;
    }
    flutter.nativeDispatchTouchToEngine(this.nativeShellHolderId, touchData);
  }

  onDisplayPlatformViewHybrid(viewId: number, x: number, y: number, width: number,
    height: number, viewWidth: number, viewHeight: number): void {
    if (this.hybridCompositionHandler != null) {
      this.hybridCompositionHandler.onDisplayPlatformViewHybrid(
        viewId, x, y, width, height, viewWidth, viewHeight);
    } else {
      Log.d(TAG, "onDisplayPlatformViewHybrid (no handler) viewId=" + viewId);
    }
  }

  /** native 下发 SliceViews 算出的 overlay rect → 转发 ControllerHybrid 存 AppStorage。 */
  onDisplayOverlayHybrid(viewId: number, x: number, y: number, width: number,
    height: number): void {
    if (this.hybridCompositionHandler != null) {
      this.hybridCompositionHandler.onDisplayOverlayHybrid(
        viewId, x, y, width, height);
    } else {
      Log.d(TAG, "onDisplayOverlayHybrid (no handler) viewId=" + viewId);
    }
  }

  /** native 下发折叠后的 mutator finals → 转发 ControllerHybrid。 */
  onDisplayMutatorsHybrid(viewId: number, data: number[]): void {
    if (this.hybridCompositionHandler != null) {
      this.hybridCompositionHandler.onDisplayMutatorsHybrid(viewId, data);
    } else {
      Log.d(TAG, "onDisplayMutatorsHybrid (no handler) viewId=" + viewId);
    }
  }

  hidePlatformViewHybrid(viewId: number): void {
    if (this.hybridCompositionHandler != null) {
      this.hybridCompositionHandler.hidePlatformViewHybrid(viewId);
    }
  }

  showOverlaySurfaceHybrid(): void {
    if (this.hybridCompositionHandler != null) {
      this.hybridCompositionHandler.showOverlaySurfaceHybrid();
    }
  }

  hideOverlaySurfaceHybrid(): void {
    if (this.hybridCompositionHandler != null) {
      this.hybridCompositionHandler.hideOverlaySurfaceHybrid();
    }
  }

  onBeginFrameHybrid(): void {
    if (this.hybridCompositionHandler != null) {
      this.hybridCompositionHandler.onBeginFrameHybrid();
    }
  }

  onEndFrameHybrid(): void {
    if (this.hybridCompositionHandler != null) {
      this.hybridCompositionHandler.onEndFrameHybrid();
    }
  }

  /**
   * Computes the platform-resolved locale from the given locale strings.
   * Invoked by native to obtain the results of OpenHarmony's locale resolution algorithm.
   * @param strings - Array of locale strings
   * @returns Array of resolved locale strings
   */
  computePlatformResolvedLocale(strings: Array<string>): Array<string> {
    Log.d(TAG, "called computePlatformResolvedLocale " + JSON.stringify(strings))
    return []
  }

  /**
   * Sets whether semantics are enabled and sends a response.
   * @param enabled - Whether to enable semantics
   * @param responseId - The response ID for the reply
   */
  setSemanticsEnabledWithRespId(enabled: boolean, responseId: number): void {
    this.ensureRunningOnMainThread();
    if (this.isAttached()) {
      flutter.nativeSetSemanticsEnabled(this.nativeShellHolderId!, enabled);
    } else {
      Log.w(
        TAG,
        "Tried to send a platform message response, but FlutterNapi was detached from native C++. Could not send. Response ID: "
          + responseId);
    }
  }

  /**
   * Sets whether semantics are enabled.
   * @param enabled - Whether to enable semantics
   */
  setSemanticsEnabled(enabled: boolean): void {
    this.ensureRunningOnMainThread();
    if (this.isAttached()) {
      flutter.nativeSetSemanticsEnabled(this.nativeShellHolderId!, enabled);
    } else {
      Log.e(
        TAG,
        "Tried to send a platform message response, but FlutterNapi was detached from native C++. Could not send.");
    }
  }

  /**
   * Sets accessibility features and sends a response.
   * @param accessibilityFeatureFlags - The accessibility feature flags
   * @param responseId - The response ID for the reply
   */
  setAccessibilityFeatures(accessibilityFeatureFlags: number, responseId: number): void {
    if (this.isAttached()) {
      flutter.nativeSetAccessibilityFeatures(accessibilityFeatureFlags, responseId);
    } else {
      Log.w(
        TAG,
        "Tried to send a platform message response, but FlutterNapi was detached from native C++. Could not send. Response ID: "
          + responseId);
    }
  }

  /**
   * Native method for setting accessibility features.
   * @param accessibilityFeatureFlags - The accessibility feature flags
   * @param responseId - The response ID for the reply
   */
  nativeSetAccessibilityFeatures(accessibilityFeatureFlags: number, responseId: number): void {
  }

  /**
   * Dispatches a semantics action to the native engine.
   * @param virtualViewId - The virtual view ID
   * @param action - The semantics action to dispatch
   * @param responseId - The response ID for the reply
   */
  dispatchSemanticsAction(virtualViewId: number, action: Action, responseId: number): void {
    if (this.isAttached()) {
      this.nativeDispatchSemanticsAction(virtualViewId, action, responseId);
    } else {
      Log.w(
        TAG,
        "Tried to send a platform message response, but FlutterNapi was detached from native C++. Could not send. Response ID: "
          + responseId);
    }
  }

  /**
   * Native method for dispatching a semantics action.
   * @param virtualViewId - The virtual view ID
   * @param action - The semantics action to dispatch
   * @param responseId - The response ID for the reply
   */
  nativeDispatchSemanticsAction(virtualViewId: number, action: Action, responseId: number): void {
  }

  /**
   * Sets the accessibility delegate for handling accessibility events.
   * @param delegate - The AccessibilityDelegate instance
   * @param responseId - The response ID for the reply
   */
  setAccessibilityDelegate(delegate: AccessibilityDelegate, responseId: number): void {
    if (this.isAttached()) {
      this.accessibilityDelegate = delegate;
    } else {
      Log.w(
        TAG,
        "Tried to send a platform message response, but FlutterNapi was detached from native C++. Could not send. Response ID: "
          + responseId);
    }
  }

  /**
   * Called when the accessibility state changes.
   * @param state - Whether accessibility is enabled
   */
  accessibilityStateChange(state: Boolean): void {
    this.ensureRunningOnMainThread();
    if (this.accessibilityDelegate != null) {
      this.accessibilityDelegate.accessibilityStateChange(state);
    }
    Log.d(TAG, "accessibilityStateChange: state is " + state ? "on" : "off");
    if (this.nativeShellHolderId != null) {
      flutter.nativeAccessibilityStateChange(this.nativeShellHolderId!, state);
    } else {
      Log.w(TAG, "accessibilityStateChange, nativeShellHolderId is null")
    }
  }

  /**
   * Sets the localization plugin for handling locale information.
   * @param localizationPlugin - The LocalizationPlugin instance, or null to remove
   */
  setLocalizationPlugin(localizationPlugin: LocalizationPlugin | null): void {
    this.localizationPlugin = localizationPlugin;
  }

  /**
   * Called by native when the application locale is changed via dart:ui setApplicationLocale.
   * @param locale - The application locale in BCP 47 format
   */
  onApplicationLocaleChanged(locale: string): void {
    Log.i(TAG, "onApplicationLocaleChanged: " + locale);
    this.localizationPlugin?.onApplicationLocaleChanged(locale);
  }

  /**
   * Gets the system language list from the platform.
   */
  getSystemLanguages() {
    Log.d(TAG, "called getSystemLanguages ")
    let index: number;
    let systemLanguages = i18n.System.getPreferredLanguageList();
    for (index = 0; index < systemLanguages.length; index++) {
      Log.d(TAG, "systemlanguages " + index + ":" + systemLanguages[index]);
    }
    if (!this.nativeShellHolderId) {
      Log.e(TAG, "getSystemLanguages this.nativeShellHolderId = " + this.nativeShellHolderId)
      return;
    }
    flutter.nativeGetSystemLanguages(this.nativeShellHolderId!, systemLanguages);
  }

  /**
   * Attaches a FlutterEngine to an XComponent.
   * @param xcomponentId - The XComponent ID
   */
  xComponentAttachFlutterEngine(xcomponentId: string) {
    flutter.nativeXComponentAttachFlutterEngine(xcomponentId, this.nativeShellHolderId!);
  }

  /**
   * Pre-renders an XComponent.
   * @param xcomponentId - The XComponent ID
   * @param width - The width of the component
   * @param height - The height of the component
   */
  xComponentPreDraw(xcomponentId: string, width: number, height: number) {
    flutter.nativeXComponentPreDraw(xcomponentId, this.nativeShellHolderId!, width, height);
  }

  /**
   * Detaches a FlutterEngine from an XComponent.
   * @param xcomponentId - The XComponent ID
   */
  xComponentDetachFlutterEngine(xcomponentId: string) {
    flutter.nativeXComponentDetachFlutterEngine(xcomponentId, this.nativeShellHolderId!);
  }

  /**
   * Dispatches a mouse wheel event from an XComponent to the Flutter engine.
   * @param xcomponentId - The XComponent ID
   * @param eventType - The type of the mouse wheel event
   * @param event - The pan gesture event containing mouse wheel data
   */
  xComponentDisPatchMouseWheel(xcomponentId: string, eventType: string, event: PanGestureEvent) {
    // only mouse
    if (event.source !== SourceType.Mouse) {
      return;
    }
    const vaildFinger = event.fingerList?.find(item => item.globalX && item.globalY);
    if (!vaildFinger) {
      return;
    }
    flutter.nativeXComponentDispatchMouseWheel(
      this.nativeShellHolderId!!,
      xcomponentId,
      eventType,
      vaildFinger?.id,
      vaildFinger?.localX,
      vaildFinger?.localY,
      event.offsetY,
      event.timestamp
    );
  }

  /**
   * Detaches this FlutterNapi instance from the native engine and releases all resources.
   */
  detachFromNativeAndReleaseResources() {
    if (!this.nativeShellHolderId) {
      Log.e(TAG, "detachFromNativeAndReleaseResources this.nativeShellHolderId = " + this.nativeShellHolderId)
      return;
    }
    flutter.nativeDestroy(this.nativeShellHolderId!!);
    this.nativeShellHolderId = null;
    this.isRunningDart = false;
    this.isDisplayingFlutterUi = false;
    this.isPreloadedFlutterUi = false;
    this.readyForHandleMessage = false;
  }

  /**
   * Detaches this FlutterNapi instance from the native engine and releases all resources asynchronously.
   */
  detachFromNativeAndReleaseResourcesAsync(): Promise<void> {
    if (!this.nativeShellHolderId) {
      Log.e(TAG, "detachFromNativeAndReleaseResourcesAsync this.nativeShellHolderId = " + this.nativeShellHolderId)
      return Promise.resolve();
    }
    // Invalidate the holder id on the JS thread before kicking off the async
    // destroy so any concurrent native calls guarded by isAttached() short out
    // and cannot race with the worker thread tearing down the shell holder.
    const shellHolderId = this.nativeShellHolderId!!;
    this.nativeShellHolderId = null;
    return flutter.nativeDestroyAsync(shellHolderId).then(() => {
      this.isRunningDart = false;
      this.isDisplayingFlutterUi = false;
      this.isPreloadedFlutterUi = false;
      this.readyForHandleMessage = false;
    });
  }

  /**
   * Unregisters a texture from the Flutter engine.
   * @param textureId - The texture ID to unregister
   */
  unregisterTexture(textureId: number): void {
    Log.d(TAG, "called unregisterTexture ");
    if (!this.nativeShellHolderId) {
      Log.e(TAG, "unregisterTexture this.nativeShellHolderId = " + this.nativeShellHolderId)
      return;
    }
    flutter.nativeUnregisterTexture(this.nativeShellHolderId!, textureId);
  }

  /**
   * Registers a PixelMap as a texture in the Flutter engine.
   * @param textureId - The texture ID
   * @param pixelMap - The PixelMap to register
   */
  registerPixelMap(textureId: number, pixelMap: PixelMap): void {
    Log.d(TAG, "called registerPixelMap ");
    if (!this.nativeShellHolderId) {
      Log.e(TAG, "registerPixelMap this.nativeShellHolderId = " + this.nativeShellHolderId)
      return;
    }
    flutter.nativeRegisterPixelMap(this.nativeShellHolderId!, textureId, pixelMap);
  }

  /**
   * Sets the background PixelMap for a texture.
   * @param textureId - The texture ID
   * @param pixelMap - The PixelMap to use as background
   */
  setTextureBackGroundPixelMap(textureId: number, pixelMap: PixelMap): void {
    if (this.isAttached()) {
      if (!this.nativeShellHolderId) {
        Log.e(TAG, "this.nativeShellHolderId = " + this.nativeShellHolderId)
        return;
      }
      flutter.nativeSetTextureBackGroundPixelMap(this.nativeShellHolderId!, textureId, pixelMap);
    } else {
      return;
    }
  }

  /**
   * Sets the background color for a texture.
   * @param textureId - The texture ID
   * @param color - The color value in ARGB format
   */
  setTextureBackGroundColor(textureId: number, color: number): void {
    Log.d(TAG, "called setTextureBackGroundColor");
    if (!this.isAttached()) {
      Log.e(TAG, "setTextureBackGroundColor when napi is not attached");
      return;
    }
    flutter.nativeSetTextureBackGroundColor(this.nativeShellHolderId!, textureId, color);
  }

  /**
   * Registers a texture in the Flutter engine.
   * @param textureId - The texture ID to register
   * @returns The registered texture ID, or 0 if registration fails
   */
  registerTexture(textureId: number): number {
    Log.d(TAG, "called registerTexture ");
    if (!this.nativeShellHolderId) {
      Log.e(TAG, "registerTexture this.nativeShellHolderId = " + this.nativeShellHolderId)
      return 0;
    }
    return flutter.nativeRegisterTexture(this.nativeShellHolderId!, textureId);
  }

  /**
   * @deprecated since 3.22
   * @useinstead FlutterNapi#getTextureNativeWindowPtr
   */
  getTextureNativeWindowId(textureId: number): number {
    Log.d(TAG, "called getTextureNativeWindowId ");
    if (this.isAttached()) {
      if (!this.nativeShellHolderId) {
        Log.e(TAG, "this.nativeShellHolderId = " + this.nativeShellHolderId)
        return 0;
      }
      return flutter.nativeGetTextureWindowId(this.nativeShellHolderId!, textureId);
    } else {
      return 0;
    }
  }

  /**
   * Gets the native window pointer for a texture.
   * @param textureId - The texture ID
   * @returns The native window pointer as a bigint, or BigInt("0") if not available
   */
  getTextureNativeWindowPtr(textureId: number): bigint {
    Log.d(TAG, "called getTextureNativeWindowPtr");
    if (this.isAttached()) {
      if (!this.nativeShellHolderId) {
        Log.e(TAG, "this.nativeShellHolderId = " + this.nativeShellHolderId)
        return BigInt("0");
      }
      return flutter.nativeGetTextureWindowPtr(this.nativeShellHolderId!, textureId);
    } else {
      return BigInt("0");
    }
  }

  /**
   * @deprecated since 3.22
   * @useinstead FlutterNapi#setExternalNativeImagePtr
   */
  setExternalNativeImage(textureId: number, native_image: number): boolean {
    Log.d(TAG, "called setExternalNativeImage ");
    if (this.isAttached()) {
      if (!this.nativeShellHolderId) {
        Log.e(TAG, "this.nativeShellHolderId = " + this.nativeShellHolderId)
        return false;
      }
      return Boolean(flutter.nativeSetExternalNativeImage(this.nativeShellHolderId!, textureId, native_image));
    } else {
      return false;
    }
  }

  /**
   * Sets an external native image pointer for a texture.
   * @param textureId - The texture ID
   * @param native_image_ptr - The native image pointer as a bigint
   * @returns true if successful, false otherwise
   */
  setExternalNativeImagePtr(textureId: number, native_image_ptr: bigint): boolean {
    Log.d(TAG, "called setExternalNativeImagePtr");
    if (this.isAttached()) {
      if (!this.nativeShellHolderId) {
        Log.e(TAG, "this.nativeShellHolderId = " + this.nativeShellHolderId)
        return false;
      }
      return Boolean(flutter.nativeSetExternalNativeImagePtr(this.nativeShellHolderId!, textureId, native_image_ptr));
    } else {
      return false;
    }
  }

  /**
   * Resets an external texture.
   * @param textureId - The texture ID
   * @param need_surfaceId - Whether a surface ID is needed
   * @returns The surface ID if needed, or 0 otherwise
   */
  resetExternalTexture(textureId: number, need_surfaceId: boolean): number {
    Log.d(TAG, "called resetExternalTexture ");
    if (this.isAttached()) {
      if (!this.nativeShellHolderId) {
        Log.e(TAG, "this.nativeShellHolderId = " + this.nativeShellHolderId)
        return 0;
      }
      return flutter.nativeResetExternalTexture(this.nativeShellHolderId!, textureId, need_surfaceId);
    } else {
      return 0;
    }
  }

  /**
   * Sets the buffer size for a texture.
   * @param textureId - The texture ID
   * @param width - The width of the buffer
   * @param height - The height of the buffer
   */
  setTextureBufferSize(textureId: number, width: number, height: number): void {
    Log.d(TAG, "called setTextureBufferSize ");
    if (!this.isAttached()) {
      Log.e(TAG, "setTextureBufferSize this.nativeShellHolderId:" + this.nativeShellHolderId)
      return;
    }
    flutter.nativeSetTextureBufferSize(this.nativeShellHolderId!, textureId, width, height);
  }

  /**
   * Notifies the Flutter engine that a texture is being resized.
   * @param textureId - The texture ID
   * @param width - The new width
   * @param height - The new height
   */
  notifyTextureResizing(textureId: number, width: number, height: number): void {
    Log.d(TAG, "called notifyTextureResizing ");
    if (!this.isAttached()) {
      Log.e(TAG, "notifyTextureResizing this.nativeShellHolderId:" + this.nativeShellHolderId)
      return;
    }
    flutter.nativeNotifyTextureResizing(this.nativeShellHolderId!, textureId, width, height);
  }

  /**
   * Enables or disables frame caching for improved performance.
   * @param enable - Whether to enable frame caching
   */
  enableFrameCache(enable: boolean): void {
    if (!this.nativeShellHolderId) {
      return;
    }
    flutter.nativeEnableFrameCache(this.nativeShellHolderId!, enable);
  }

  setPipVisible(visible: boolean): void {
    if (!this.nativeShellHolderId) {
      return;
    }
    try {
      flutter.nativeSetPipVisible(this.nativeShellHolderId!, visible);
    } catch (error) {
      Log.w(TAG, "nativeSetPipVisible unavailable: " + JSON.stringify(error));
    }
  }

  /**
   * Handles touch events from the platform.
   * @param strings - Array of strings containing touch event data
   */
  onTouchEvent(strings: Array<string>): void {
    if (this.isAttached()) {
      const hasTextureViews = this.textureTouchArbiter != null
        ? this.textureTouchArbiter() : false;
      if (this.isHybridCompositionEnabled() && !hasTextureViews) {
        return;
      }
      TouchEventProcessor.getInstance().postTouchEvent(strings);
    }
  }

  /**
   * Wires the texture-PV liveness probe consulted by onTouchEvent's HCPP skip
   * (see textureTouchArbiter). Pass null to restore the unconditional skip.
   */
  setTextureTouchArbiter(arbiter: (() => boolean) | null): void {
    this.textureTouchArbiter = arbiter;
  }

  /**
   * Handles mouse events from the platform.
   * @param strings - Array of strings containing mouse event data
   */
  onMouseEvent(strings: Array<string>): void {
    if (this.isAttached()) {
       TouchEventProcessor.getInstance().postMouseEvent(strings);
    }
  }

  /**
   * Handles axis events (scroll wheel, etc.) from the platform.
   * @param strings - Array of strings containing axis event data
   */
  onAxisEvent(strings: Array<string>): void {
    if (this.isAttached()) {
      TouchEventProcessor.getInstance().postAxisEvent(strings);
    }
  }

  /**
   * Checks if a Unicode code point is an emoji.
   * @param code - The Unicode code point
   * @returns true if the code point is an emoji, false otherwise
   */
  static unicodeIsEmoji(code: number): boolean {
    return Boolean(flutter.nativeUnicodeIsEmoji(code));
  }

  /**
   * Checks if a Unicode code point is an emoji modifier.
   * @param code - The Unicode code point
   * @returns true if the code point is an emoji modifier, false otherwise
   */
  static unicodeIsEmojiModifier(code: number): boolean {
    return Boolean(flutter.nativeUnicodeIsEmojiModifier(code));
  }

  /**
   * Checks if a Unicode code point is an emoji modifier base.
   * @param code - The Unicode code point
   * @returns true if the code point is an emoji modifier base, false otherwise
   */
  static unicodeIsEmojiModifierBase(code: number): boolean {
    return Boolean(flutter.nativeUnicodeIsEmojiModifierBase(code));
  }

  /**
   * Checks if a Unicode code point is a variation selector.
   * @param code - The Unicode code point
   * @returns true if the code point is a variation selector, false otherwise
   */
  static unicodeIsVariationSelector(code: number): boolean {
    return Boolean(flutter.nativeUnicodeIsVariationSelector(code));
  }

  /**
   * Checks if a Unicode code point is a regional indicator symbol.
   * @param code - The Unicode code point
   * @returns true if the code point is a regional indicator symbol, false otherwise
   */
  static unicodeIsRegionalIndicatorSymbol(code: number): boolean {
    return Boolean(flutter.nativeUnicodeIsRegionalIndicatorSymbol(code));
  }

  /**
   * Sets the font weight scale for text rendering.
   * @param fontWeightScale - The font weight scale factor
   */
  setFontWeightScale(fontWeightScale: number): void {
    this.ensureRunningOnMainThread();
    if (this.isAttached()) {
      Log.i(TAG, "setFontWeightScale: " + fontWeightScale);
      flutter.nativeSetFontWeightScale(this.nativeShellHolderId!, fontWeightScale);
    } else {
      Log.w(TAG, "setFontWeightScale is detached !");
    }
  }

  /**
   * Sets the Flutter navigation action state.
   * @param shellHolderId - The shell holder ID
   * @param isNavigate - Whether navigation is active
   */
  setFlutterNavigationAction(shellHolderId: number, isNavigate: boolean): void {
    this.ensureRunningOnMainThread();
    if (this.isAttached()) {
      Log.i(TAG, "setFlutterNavigationAction: " + isNavigate);
      flutter.nativeSetFlutterNavigationAction(shellHolderId, isNavigate);
    } else {
      Log.w(TAG, "setFlutterNavigationAction is detached !");
    }
  }

  /**
   * Sets the D-VSync switch state.
   * @param isEnable - Whether to enable D-VSync
   */
  SetDVsyncSwitch(isEnable: boolean): void {
    flutter.nativeSetDVsyncSwitch(this.nativeShellHolderId!, isEnable);
  }

  /**
   * @brief  [LTPO] Send Animation Velocity
   * @note
   * @param  type: Animation type, 0-TRANSLATE, 1-SCALE, 2-ROTATION
   * @param  velocity: Current animation velocity. Unit is logical pixels
   * @return none
   */
  static animationVoting(type: number, velocity: number): void {
    flutter.nativeAnimationVoting(type, velocity);
  }

  /**
   * @brief  [LTPO] Send Video Frame Count
   * @note
   * @param  seconds: Seconds
   * @param  frameCount: Frame count within a certain period of time
   * @return none
   */
  static videoVoting(seconds: number, frameCount: number): void {
    flutter.nativeVideoVoting(seconds, frameCount);
  }

  /**
   * @brief  [LTPO] Preload Frame Rate Configuration File
   * @note
   * @param  none
   * @return none
   */
  static prefetchFramesCfg(): void {
    flutter.nativePrefetchFramesCfg();
  }

  /**
   * @brief  [LTPO] Check LTPO Activation Status
   * @note
   * @param  none
   * @return number 0: Disabled, 1: Enabled, 2: Uninitialized
   */
  static checkLTPOSwitchState(): number {
    return flutter.nativeCheckLTPOSwitchState();
  }

  /**
   * Sets the QoS (Quality of Service) level when low memory is detected.
   * @param lowMemoryLevel - The low memory level
   */
  SetQosOnLowMemory(lowMemoryLevel: number): void {
    flutter.nativeSetQosOnLowMemory(this.nativeShellHolderId!, lowMemoryLevel);
  }

  SetAnimationStatus(animationStatus: number): void {
    flutter.nativeSetAnimationStatus(this.nativeShellHolderId!, animationStatus);
  }

  NotifyPageChanged(pageName: string, pageNameLen: number, windowID: number): number {
    return flutter.nativeNotifyPageChanged(pageName, pageNameLen, windowID);
  }

  /**
   * @brief  [LTPO] Send high frame rate request when LTPO is enabled
   * @note
   * @param  none
   * @return none
   */
  LTPODispatchHighFrameRate(): void {
    flutter.nativeLTPODispatchHighFrameRate(this.nativeShellHolderId!);
  }
}

/**
 * Interface for handling accessibility state changes.
 * Implementations of this interface will be notified when the accessibility state changes.
 */
export interface AccessibilityDelegate {
  /**
   * Called when the accessibility state changes.
   * @param state - Whether accessibility is enabled
   */
  accessibilityStateChange(state: Boolean): void;
}
