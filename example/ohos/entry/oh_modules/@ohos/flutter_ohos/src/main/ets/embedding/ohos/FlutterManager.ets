/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*/


import { FlutterView } from '../../view/FlutterView';
import UIAbility from '@ohos.app.ability.UIAbility';
import window from '@ohos.window';
import Log from '../../util/Log';
import HashMap from '@ohos.util.HashMap';
import List from '@ohos.util.List';
import { deviceInfo } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';
import PiPVisibilityBridge from './PiPVisibilityBridge';
import FlutterNapi from '../engine/FlutterNapi';
import { WindowHostContext } from './windowing/WindowHostContext';
import { FlutterWindowHost } from './windowing/FlutterWindowHost';
import { DialogWindowCreationRequest, IMPLICIT_VIEW_ID, NO_PARENT_VIEW_ID,
  numericViewId, PopupWindowCreationRequest, RegularWindowCreationRequest,
  TooltipWindowCreationRequest,
  WindowArchetype } from './windowing/WindowingUtils';
import { DialogWindowHost } from './windowing/DialogWindowHost';
import { TooltipWindowHost } from './windowing/TooltipWindowHost';
import { PopupWindowHost } from './windowing/PopupWindowHost';
import { RegularWindowHost, AbilityHostMode } from './windowing/RegularWindowHost';
import { FlutterAbility } from './FlutterAbility';

const TAG = "FlutterManager"

/**
 * Singleton manager for Flutter views and UI abilities.
 * This class manages the lifecycle of FlutterView instances and their association with UI abilities.
 *
 * Multi-window: per-window host behavior lives in the window/ host classes;
 * this manager keeps the shared bookkeeping and implements WindowHostContext.
 */
export default class FlutterManager implements WindowHostContext {
  private static instance: FlutterManager;

  /**
   * Gets the singleton instance of FlutterManager.
   * @returns The singleton FlutterManager instance
   */
  static getInstance(): FlutterManager {
    if (FlutterManager.instance == null) {
      FlutterManager.instance = new FlutterManager();
    }
    return FlutterManager.instance;
  }

  private windowHosts = new Map<number, FlutterWindowHost>();
  private viewAbilities = new Map<number, UIAbility>();
  private flutterViewList = new Map<String, FlutterView>();
  private flutterViewIndex = 1;
  private uiAbilityList = new Array<UIAbility>();
  private windowStageList = new Map<UIAbility, window.WindowStage>();
  private mFullScreenListener: FullScreenListener = new DefaultFullScreenListener();
  private windowStageEventCallbacks = new Map<UIAbility, (event: window.WindowStageEventType) => void>();
  private regularWindowAbilityName: string = 'RegularWindowAbility';
  private subWindowPageName: string = 'pages/FlutterWindowPage';

  private dragEnterCbId: number = 1;
  private dragMoveCbId: number = 1;
  private dragLeaveCbId: number = 1;
  private dropCbId: number = 1;

  private dragEnterCbs: HashMap<number, DragDropCallback> = new HashMap();
  private dragMoveCbs: HashMap<number, DragDropCallback> = new HashMap();
  private dragLeaveCbs: HashMap<number, DragDropCallback> = new HashMap();
  private dropCbs: HashMap<number, DragDropCallback> = new HashMap();

  private getValuesFromMap(map: HashMap<number, DragDropCallback>): List<DragDropCallback> {
    let list: List<DragDropCallback> = new List();
    map.forEach((value, key) => {
      list.add(value);
    });
    return list;
  }

  /**
   * Gets all drag enter callbacks.
   * @returns A list of drag enter callbacks
   */
  getDragEnterCbs(): List<DragDropCallback> {
    return this.getValuesFromMap(this.dragEnterCbs);
  }

  /**
   * Gets all drag move callbacks.
   * @returns A list of drag move callbacks
   */
  getDragMoveCbs(): List<DragDropCallback> {
    return this.getValuesFromMap(this.dragMoveCbs);
  }

  /**
   * Gets all drag leave callbacks.
   * @returns A list of drag leave callbacks
   */
  getDragLeaveCbs(): List<DragDropCallback> {
    return this.getValuesFromMap(this.dragLeaveCbs);
  }

  /**
   * Gets all drop callbacks.
   * @returns A list of drop callbacks
   */
  getDropCbs(): List<DragDropCallback> {
    return this.getValuesFromMap(this.dropCbs);
  }

  /**
   * Adds a drag enter callback.
   * @param callback - The drag enter callback
   * @returns The callback ID
   */
  addDragEnterCb(callback: DragDropCallback): number {
    this.dragEnterCbs.set(this.dragEnterCbId, callback);
    return this.dragEnterCbId++;
  }

  /**
   * Adds a drag move callback.
   * @param callback - The drag move callback
   * @returns The callback ID
   */
  addDragMoveCb(callback: DragDropCallback): number {
    this.dragMoveCbs.set(this.dragMoveCbId, callback);
    return this.dragMoveCbId++;
  }

  /**
   * Adds a drag leave callback.
   * @param callback - The drag leave callback
   * @returns The callback ID
   */
  addDragLeaveCb(callback: DragDropCallback): number {
    this.dragLeaveCbs.set(this.dragLeaveCbId, callback);
    return this.dragLeaveCbId++;
  }

  /**
   * Adds a drop callback.
   * @param callback - The drop callback
   * @returns The callback ID
   */
  addDropCb(callback: DragDropCallback): number {
    this.dropCbs.set(this.dropCbId, callback);
    return this.dropCbId++;
  }

  /**
   * Removes a drag enter callback.
   * @param id - The callback ID to remove
   */
  removeDragEnterCb(id: number) {
    this.dragEnterCbs.remove(id);
  }

  /**
   * Removes a drag move callback.
   * @param id - The callback ID to remove
   */
  removeDragMoveCb(id: number) {
    this.dragMoveCbs.remove(id);
  }

  /**
   * Removes a drag leave callback.
   * @param id - The callback ID to remove
   */
  removeDragLeaveCb(id: number) {
    this.dragLeaveCbs.remove(id);
  }

  /**
   * Removes a drop callback.
   * @param id - The callback ID to remove
   */
  removeDropCb(id: number) {
    this.dropCbs.remove(id);
  }

  /**
   * Pushes a UIAbility to the list.
   * @param uiAbility - The UIAbility to add
   */
  pushUIAbility(uiAbility: UIAbility) {
    this.uiAbilityList.push(uiAbility);
  }

  /**
   * Removes a UIAbility from the list.
   * @param uiAbility - The UIAbility to remove
   */
  popUIAbility(uiAbility: UIAbility) {
    let index = this.uiAbilityList.findIndex((item: UIAbility) => item == uiAbility)
    if (index >= 0) {
      this.uiAbilityList.splice(index, 1)
    }
  }

  /**
   * Associates a WindowStage with a UIAbility.
   * @param uiAbility - The UIAbility
   * @param windowStage - The WindowStage to associate
   */
  pushWindowStage(uiAbility: UIAbility, windowStage: window.WindowStage) {
    this.windowStageList.set(uiAbility, windowStage)
    this.startPipWindowStageListener(uiAbility, windowStage);
  }

  /**
   * Removes the WindowStage association for a UIAbility.
   * @param uiAbility - The UIAbility
   */
  popWindowStage(uiAbility: UIAbility) {
    this.stopPipWindowStageListener(uiAbility);
    this.windowStageList.delete(uiAbility)
  }

  private startPipWindowStageListener(uiAbility: UIAbility, windowStage: window.WindowStage): void {
    if (this.windowStageEventCallbacks.has(uiAbility)) {
      return;
    }
    const callback = (event: window.WindowStageEventType): void => {
      if (event === window.WindowStageEventType.HIDDEN) {
        Log.d(TAG, 'PiP: WindowStageEvent HIDDEN, start pip polling');
        PiPVisibilityBridge.getInstance().updateAbilityShown(false);
      } else if (event === window.WindowStageEventType.SHOWN) {
        Log.d(TAG, 'PiP: WindowStageEvent SHOWN, stop pip polling');
        PiPVisibilityBridge.getInstance().updateAbilityShown(true);
      }
    };
    windowStage.on('windowStageEvent', callback);
    this.windowStageEventCallbacks.set(uiAbility, callback);
    Log.d(TAG, 'PiP: WindowStageEvent listener registered for ability');
  }

  private stopPipWindowStageListener(uiAbility: UIAbility): void {
    const callback = this.windowStageEventCallbacks.get(uiAbility);
    if (callback == null) {
      return;
    }
    try {
      const windowStage = this.windowStageList.get(uiAbility);
      windowStage?.off('windowStageEvent', callback);
    } catch (err) {
      Log.w(TAG, 'PiP: windowStageEvent off failed, window may already be destroyed: ' + JSON.stringify(err));
    } finally {
      this.windowStageEventCallbacks.delete(uiAbility);
    }
    Log.d(TAG, 'PiP: WindowStageEvent listener removed for ability');
  }

  /**
   * Gets the WindowStage for a UIAbility.
   * @param uiAbility - The UIAbility
   * @returns The associated WindowStage
   */
  getWindowStage(uiAbility: UIAbility): window.WindowStage {
    return this.windowStageList.get(uiAbility)!!
  }

  /**
   * Gets a UIAbility by context, or returns the first one if no context is provided.
   * @param context - Optional context to search for
   * @returns The UIAbility instance
   */
  getUIAbility(context?: Context): UIAbility {
    if (!context && this.uiAbilityList.length > 0) {
      return this.uiAbilityList[0];
    }
    return this.uiAbilityList.find((item: UIAbility) => item.context == context)!!
  }

  /**
   * Checks if a FlutterView exists with the given ID.
   * @param viewId - The view ID to check
   * @returns True if the view exists, false otherwise
   */
  hasFlutterView(viewId: string): boolean {
    return this.flutterViewList.has(viewId);
  }

  /**
   * Gets a FlutterView by ID.
   * @param viewId - The view ID
   * @returns The FlutterView instance, or null if not found
   */
  getFlutterView(viewId: string): FlutterView | null {
    return this.flutterViewList.get(viewId) ?? null;
  }

  /**
   * Gets all FlutterView instances.
   * @returns A map of all FlutterView instances by ID
   */
  getFlutterViewList(): Map<String, FlutterView> {
    return this.flutterViewList;
  }

  /**
   * Stores or removes a FlutterView in the list.
   * @param viewId - The view ID
   * @param flutterView - The FlutterView instance, or undefined to remove
   */
  private putFlutterView(viewId: string, flutterView?: FlutterView): void {
    if (flutterView != null) {
      this.flutterViewList.set(viewId, flutterView);
    } else {
      this.flutterViewList.delete(viewId);
    }
  }

  /**
   * Creates a new FlutterView instance.
   * It's suggested to keep 'oh_flutter_' as the prefix for xcomponent_id.
   * Otherwise it might affect the performance.
   * @param context - The context for creating the view
   * @returns A new FlutterView instance
   */
  createFlutterView(context: Context): FlutterView {
    let flutterView = new FlutterView(`oh_flutter_${this.flutterViewIndex++}`, context);
    this.putFlutterView(flutterView.getId(), flutterView);
    return flutterView;
  }

  registerViewAbility(viewId: number, ability: UIAbility): void {
    const holder = ability as FlutterAbility;
    if (viewId === IMPLICIT_VIEW_ID && this.viewAbilities.has(IMPLICIT_VIEW_ID)) {
      Log.w(TAG, `registerViewAbility: main ability already recorded; ignoring`);
      return;
    }
    this.viewAbilities.set(viewId, ability);
    holder.hostedViewId = viewId;
    const fv = this.getFlutterView(String(viewId));
    this.windowHosts.get(viewId)?.setWindow(this.getWindowStage(ability)?.getMainWindowSync());
    this.windowHosts.get(viewId)?.setAbility(ability);
    if (fv !== null) {
      this.windowHosts.get(viewId)?.setFlutterView(fv);
    }

  }

  // ---- Per-archetype window creation (same names as the C++ facade / win32;
  // the typed request IS the archetype — no discriminator int) ---------------

  createRegularWindow(viewId: number, req: RegularWindowCreationRequest): void {
    const request = new RegularWindowCreationRequest(req);
    Log.d(TAG, `createRegularWindow viewId=${viewId}`);
    const host = new RegularWindowHost(this, viewId, AbilityHostMode.SPAWNED,
      request, WindowArchetype.REGULAR);
    this.windowHosts.set(viewId, host);
    host.attach();
  }

  createDialogWindow(viewId: number, req: DialogWindowCreationRequest): void {
    const request = new DialogWindowCreationRequest(req);
    Log.d(TAG, `createDialogWindow viewId=${viewId}`);
    let host: FlutterWindowHost;
    if (request.parentViewId !== NO_PARENT_VIEW_ID) {
      host = new DialogWindowHost(this, viewId, request); // modal Dialog path
    } else {
      host = new RegularWindowHost(this, viewId, AbilityHostMode.SPAWNED,
        request, WindowArchetype.DIALOG);
    }
    this.windowHosts.set(viewId, host);
    host.attach();
  }

  /** Tooltip: anchored, parent-bound SubWindow. */
  createTooltipWindow(viewId: number, req: TooltipWindowCreationRequest): void {
    const request = new TooltipWindowCreationRequest(req);
    Log.d(TAG, `createTooltipWindow viewId=${viewId}`);
    const host = new TooltipWindowHost(this, viewId, request);
    this.windowHosts.set(viewId, host);
    host.attach();
  }

  createPopupWindow(viewId: number, req: PopupWindowCreationRequest): void {
    const request = new PopupWindowCreationRequest(req);
    Log.d(TAG, `createPopupWindow viewId=${viewId}`);
    const host = new PopupWindowHost(this, viewId, request);
    this.windowHosts.set(viewId, host);
    host.attach();
  }

  updateTooltipPosition(viewId: number): void {
    const host = this.windowHosts.get(viewId);
    if (host instanceof TooltipWindowHost) {
      host.updatePosition();
    } else {
      Log.w(TAG, `updateTooltipPosition: viewId=${viewId} is not a tooltip host`);
    }
  }

  updatePopupPosition(viewId: number): void {
    const host = this.windowHosts.get(viewId);
    if (host instanceof PopupWindowHost) {
      host.updatePosition();
    } else {
      Log.w(TAG, `updatePopupPosition: viewId=${viewId} is not a popup host`);
    }
  }

  /** Raster content-size report (napi didUpdateViewSize, PHYSICAL px;
   * win32 HostWindowTooltip::DidUpdateViewSize parity): re-place the
   * sized-to-content tooltip/popup. Unknown or other views no-op. */
  didUpdateViewSize(viewId: number, width: number, height: number): void {
    const host = this.windowHosts.get(viewId);
    if (host instanceof TooltipWindowHost || host instanceof PopupWindowHost) {
      host.didUpdateViewSize(width, height);
    }
  }

  /**
   * ADOPT path, view 0 only (C++ CreateWindow routes it here): adopt the
   * EntryAbility's main window as the FIRST Dart Regular window's surface.
   *
   * @param viewId - The engine numeric view id (always 0 here)
   * @param req    - Creation fields (preferred size / title) from native
   */
  bindEntryAbilityToView(viewId: number, req: RegularWindowCreationRequest): void {
    const request = new RegularWindowCreationRequest(req);
    const ability = this.getAbilityByView(viewId);
    if (this.getHostWindowByView(viewId) !== undefined) {
      Log.d(TAG, `bindEntryAbilityToView: view ${viewId} already adopted`);
      return;
    }
    Log.d(TAG, `bindEntryAbilityToView viewId=${viewId} ${request.toString()}`);
    const host = new RegularWindowHost(this, viewId, AbilityHostMode.ADOPTED,
      request, WindowArchetype.REGULAR, ability);
    this.windowHosts.set(viewId, host);
    host.attach();
  }

  /**
   * The host of a view. Registry keys are the numeric view ids (0 = the
   * implicit main view) — the same ids Dart/C++/napi speak, so no translation.
   */
  getHostWindowByView(viewId: number): FlutterWindowHost | undefined {
    return this.windowHosts.get(viewId);
  }

  getAbilityByView(viewId: number): UIAbility | undefined {
    return this.viewAbilities.get(viewId);
  }

  // ---- WindowHostContext: service surface for the window/ host classes ----
  registerFlutterView(viewId: string, flutterView: FlutterView): void {
    this.putFlutterView(viewId, flutterView);
    this.windowHosts.get(numericViewId(viewId))?.setFlutterView(flutterView);
  }

  removeHost(viewId: number): void {
    this.windowHosts.delete(viewId);
  }

  /** Drops the view's ability record (WindowHostContext; idempotent): without
   * it every SPAWNED-window close would leave a destroyed UIAbility pinned. */
  deleteViewAbility(viewId: number): void {
    this.viewAbilities.delete(viewId);
  }

  /**
   * ArkUI page loaded into every SubWindow host — APP code, not in the HAR. An app
   * MUST set its own page first: unresolvable → loadContent fails → window reported closed.
   */
  subWindowPage(): string {
    return this.subWindowPageName;
  }

  setSubWindowPageName(name: string): void {
    if (name && name.length > 0) {
      this.subWindowPageName = name;
    }
  }

  /** UIAbility class SPAWNED Regular hosts launch (WindowHostContext): the
    * app's RegularWindowAbility, declared launchType "specified". */
  spawnedAbilityName(): string {
    return this.regularWindowAbilityName;
  }

  setSpawnedAbilityName(name: string): void {
    if (name && name.length > 0) {
      this.regularWindowAbilityName = name;
    }
  }

  /**
   * Focus push for sub-window hosts (WindowHostContext): windowEvent
   * WINDOW_ACTIVE↔WINDOW_INACTIVE translated into the view's activation flag
   * and handed to native. Native no-ops for untracked views — safe at any lifecycle point.
   */
  notifyWindowActivated(viewId: number, activated: boolean): void {
    try {
      FlutterNapi.nativeNotifyWindowActivated(viewId, activated);
    } catch (e) {
      Log.w(TAG, `notifyWindowActivated(${viewId}, ${activated}) napi failed: ${JSON.stringify(e)}`);
    }
  }

  /**
   * Close child windows BEFORE the parent frees the shared engine (survivors
   * dangle); closeForCascade's synchronous detach is the guarantee; idempotent.
   * @param parentAbility - The host that owns and is about to destroy the engine.
   */
  cascadeCloseChildren(parentAbility: UIAbility): void {
    // Only the view-0 (shared-engine main window) ability cascades; a
    // closing own-engine ability must not wipe unrelated windows.
    if (parentAbility !== this.getAbilityByView(IMPLICIT_VIEW_ID)) {
      Log.w(TAG, 'cascadeCloseChildren: caller is not the main-window ability — ignoring');
      return;
    }
    // Snapshot: closeForCascade drops each host from windowHosts as it runs.
    const children: FlutterWindowHost[] = [];
    this.windowHosts.forEach((host: FlutterWindowHost) => {
      children.push(host);
    });
    for (const host of children) {
      try {
        host.closeForCascade(parentAbility);
      } catch (e) {
        Log.w(TAG, `cascadeCloseChildren: viewId=${String(host.viewId)} failed: ${JSON.stringify(e)}`);
      }
    }
  }

  /**
   * Main-window close = quit: terminateSelf() runs the full shutdown
   * (cascadeCloseChildren → engine.destroy). NOT exit(0) — it bypasses the Ability lifecycle.
   */
  exitApplication(): void {
    const mainAbility = this.getAbilityByView(IMPLICIT_VIEW_ID);
    if (!mainAbility) {
      Log.e(TAG, `exitApplication: no main (EntryAbility) host found — cannot terminate`);
      return;
    }
    try {
      (mainAbility.context as common.UIAbilityContext)
        .terminateSelf()
        .catch((e: Error) => {
          Log.e(TAG, `exitApplication: terminateSelf failed: ${JSON.stringify(e)}`);
        });
    } catch (e) {
      Log.e(TAG, `exitApplication: terminateSelf threw: ${JSON.stringify(e)}`);
    }
  }

  /**
   * Gets the next FlutterView ID that will be used.
   * @param idOffset - Optional offset to add to the index
   * @returns The next FlutterView ID string
   */
  getNextFlutterViewId(idOffset: number = 0): string {
    return `oh_flutter_${this.flutterViewIndex + idOffset}`;
  }

  /**
   * Clears all FlutterView instances.
   */
  clear(): void {
    this.flutterViewList.clear();
  }

  /**
   * Sets the full screen listener.
   * @param listener - The FullScreenListener instance
   */
  setFullScreenListener(listener: FullScreenListener) {
    this.mFullScreenListener = listener
  }

  /**
   * Gets the full screen listener.
   * @returns The FullScreenListener instance
   */
  getFullScreenListener(): FullScreenListener {
    return this.mFullScreenListener;
  }

  /**
   * Sets whether to use full screen mode.
   * @param use - Whether to use full screen
   * @param context - Optional context
   */
  setUseFullScreen(use: boolean, context?: Context | null | undefined) {
    this.mFullScreenListener.setUseFullScreen(use, context);
  }

  /**
   * Checks if full screen mode is enabled.
   * @returns True if full screen is enabled, false otherwise
   */
  useFullScreen(): boolean {
    return this.mFullScreenListener.useFullScreen();
  }

  /**
   * Sets whether to use full screen mode specifically for free multi-window.
   * @param useFullScreen - Whether to use full screen
   * @param context - Optional context
   */
  setUseFullScreenForFreeWindow(useFullScreen: boolean, context?: Context | null | undefined): void {
    this.mFullScreenListener.setUseFullScreenForFreeWindow(useFullScreen, context);
  }

  /**
   * Checks if the isInFreeWindowMode API is supported on the current device.
   * @param context - Optional context, defaults to first UIAbility
   * @returns True if the isInFreeWindowMode API is available, false otherwise
   */
  isInFreeWindowModeSupported(context?: Context | null | undefined): boolean {
    // API 22+ required for isInFreeWindowMode
    if (deviceInfo.sdkApiVersion < 22) {
      return false;
    }
    const mainWindow = this.getWindowStage(this.getUIAbility(context ?? undefined))?.getMainWindowSync();
    if (!mainWindow) {
      return false;
    }
    try {
      // Avoid compilation errors: isInFreeWindowMode is an API22 interface
      // Check if isInFreeWindowMode API is available
      const result = typeof (mainWindow as ESObject)?.isInFreeWindowMode();
      return result == 'boolean';
    } catch (exception) {
      Log.i(TAG, `Failed to check isInFreeWindowMode support. Cause code: ${exception.code}, message: ${exception.message}`);
      return false;
    }
  }

  /**
   * Checks if the current device is in free free-window mode.
   * @param context - Optional context, defaults to first UIAbility
   * @returns True if the device is in free multi-window mode, false otherwise
   */
  isInFreeMultiWindowMode(context?: Context | null | undefined): boolean {
    if (this.isInFreeWindowModeSupported(context)) {
      const mainWindow = this.getWindowStage(this.getUIAbility(context ?? undefined))?.getMainWindowSync();
      if (!mainWindow) {
        return false;
      }
      try {
        return mainWindow.isInFreeWindowMode();
      } catch (exception) {
        Log.e(TAG, `isInFreeMultiWindowMode failed. Cause code: ${exception.code}, message: ${exception.message}`);
        return false;
      }
    }
    return false;
  }

  /**
   * Deletes a FlutterView from the list.
   * @param viewId - The view ID
   * @param flutterView - Optional FlutterView instance to verify
   */
  deleteFlutterView(viewId: string, flutterView?: FlutterView): void {
    if (flutterView != null) {
      this.flutterViewList.delete(viewId);
    }
  }

  /**
   * Get window ID for notifyPageChanged.
   * @param context The context to get UIAbility
   * @returns The window ID, or 0 if failed
   */
  getWindowId(context: common.Context): number {
    try {
      const uiAbility = this.getUIAbility(context);
      if (uiAbility == null) {
        Log.e(TAG, "getWindowId: uiAbility is null");
        return 0;
      }
      const windowStage = this.getWindowStage(uiAbility);
      if (windowStage == null) {
        Log.e(TAG, "getWindowId: windowStage is null");
        return 0;
      }
      const mainWindow = windowStage.getMainWindowSync();
      if (mainWindow == null) {
        Log.e(TAG, "getWindowId: mainWindow is null");
        return 0;
      }
      const windowId = mainWindow.getWindowProperties()?.id ?? 0;
      return windowId;
    } catch (error) {
      Log.e(TAG, "getWindowId failed: " + JSON.stringify(error));
    }
    return 0;
  }

  /**
   * Sets the visibility of a specific system bar and applies safe area padding.
   * When hiding a system bar, automatically applies padding to avoid content being covered.
   * @param flutterViewId - The ID of the FlutterView to apply padding
   * @param specificSystemBar - System bar type: 'status' for status bar, 'navigation' for three-key navigation bar, 'navigationIndicator' for gesture navigation bar
   * @param isVisible - True to show, false to hide
   * @param enableAnimation - Whether to enable animation effect, optional
   * @param context - Optional context, uses the first UIAbility if not provided
   */
  setSpecificSystemBarEnabled(flutterViewId: string, specificSystemBar: 'status' | 'navigation' | 'navigationIndicator', isVisible: boolean, enableAnimation?: boolean, context?: Context): void {
    const flutterView: FlutterView | null = this.getFlutterView(flutterViewId);
    if (!flutterView) {
      Log.e(TAG, `setSpecificSystemBarEnabled failed: flutterView not found for id ${flutterViewId}`);
      return;
    }

    try {
      const windowStage = this.getWindowStage(this.getUIAbility(context));
      if (!windowStage) {
        Log.e(TAG, 'setSpecificSystemBarEnabled failed: windowStage is null');
        return;
      }

      const mainWindow = windowStage.getMainWindowSync();
      if (!mainWindow) {
        Log.e(TAG, 'setSpecificSystemBarEnabled failed: mainWindow is null');
        return;
      }
      mainWindow.setSpecificSystemBarEnabled(specificSystemBar, isVisible, enableAnimation);

      switch (specificSystemBar) {
        case 'status':
          // Apply top padding when hiding status bar to avoid content being covered
          const statusBarHeight = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM).topRect.height;
          if (statusBarHeight > 0) {
            flutterView.setPaddingTop(statusBarHeight);
          }
          break;
        case 'navigation':
        case 'navigationIndicator':
          // Apply bottom padding when hiding navigation bar to avoid content being covered
          const navHeight = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR).bottomRect.height;
          if (navHeight > 0) {
            flutterView.setPaddingBottom(navHeight);
          }
          break;
      }

      Log.i(TAG, `setSpecificSystemBarEnabled: ${specificSystemBar} = ${isVisible}, animation = ${enableAnimation} success`);
    } catch (error) {
      Log.e(TAG, `setSpecificSystemBarEnabled error: ${JSON.stringify(error)}`);
    }
  }

  /**
   * Adjusts FlutterView top padding to avoid window decoration overlap.
   * @param flutterViewId - The FlutterView ID
   * @param context - Optional context, defaults to first UIAbility
   */
  handleWindowDecorSafeArea(flutterViewId: string, context?: Context | null | undefined): void {
    if (!this.isWindowDecorSafeAreaAvoidSupported(context)) {
      return;
    }
    const flutterView = this.getFlutterView(flutterViewId);
    if (!flutterView) {
      return;
    }
    const mainWindow = this.getWindowStage(this.getUIAbility(context ?? undefined))?.getMainWindowSync();
    if (!mainWindow) {
      return;
    }

    try {
      // Get current window status
      const currentStatus: window.WindowStatusType = mainWindow.getWindowStatus();
      // In MAXIMIZE mode, skip setting padding because the window menu bar is temporarily displayed
      if (currentStatus == window.WindowStatusType.MAXIMIZE) {
        return;
      }
    } catch (e) {
      Log.e(TAG, "Failed to get window status: " + JSON.stringify(e));
      return;
    }

    // Fall back to systemAvoidArea for status bar avoidance when window decoration is visible
    if (mainWindow.getWindowDecorVisible() ) {
      flutterView.setPaddingTop(undefined);
      return;
    }
    // Fall back to systemAvoidArea when title buttons are hidden (no decoration to avoid)
    const titleButtonRect = mainWindow.getTitleButtonRect();
    if (!titleButtonRect || titleButtonRect.height <= 0) {
      flutterView.setPaddingTop(undefined);
      return;
    }
    // Set padding to match title button height
    flutterView.setPaddingTop(vp2px(titleButtonRect.height));
  }

  /**
   * Checks if window decoration safe area avoidance is supported on the current device.
   * Returns true only when the device is in freeform multi-window mode and supports window decoration.
   * @param context - Optional context, defaults to first UIAbility
   * @returns True if window decoration safe area avoidance is supported, false otherwise
   */
  isWindowDecorSafeAreaAvoidSupported(context?: Context | null | undefined): boolean {
    // API 18+ required for window decoration APIs
    if (deviceInfo.sdkApiVersion < 18) {
      return false;
    }
    const mainWindow = this.getWindowStage(this.getUIAbility(context ?? undefined))?.getMainWindowSync();
    if (!mainWindow) {
      return false;
    }
    try {
      // Avoid compilation errors: getWindowDecorVisible is an API18 interface
      // Check if getWindowDecorVisible API is available
      const result = typeof (mainWindow as ESObject)?.getWindowDecorVisible();
      return result == 'boolean';
    } catch (exception) {
      Log.i(TAG, `Failed to check window decor visibility support. Cause code: ${exception.code}, message: ${exception.message}`);
      return false;
    }
  }
}

/**
 * Interface for drag and drop callbacks.
 */
export interface DragDropCallback {
  /**
   * Handles a drag and drop event.
   * @param event - The drag event
   * @param extraParams - Additional parameters
   */
  do(event: DragEvent, extraParams: string): void;
}

/**
 * Interface for full screen state management.
 */
export interface FullScreenListener {
  /**
   * Checks if full screen mode is enabled.
   * @returns True if full screen is enabled, false otherwise
   */
  useFullScreen(): boolean;

  /**
   * Sets whether to use full screen mode.
   * @param useFullScreen - Whether to use full screen
   * @param context - Optional context
   */
  setUseFullScreen(useFullScreen: boolean, context?: Context | null | undefined): void;

  /**
   * Sets whether to use full screen mode specifically for free multi-window.
   * @param useFullScreen - Whether to use full screen
   * @param context - Optional context
   */
  setUseFullScreenForFreeWindow(useFullScreen: boolean, context?: Context | null | undefined): void;

  /**
   * Called when the screen state changes.
   * @param data - The window status type
   */
  onScreenStateChanged(data: window.WindowStatusType): void;
}

/**
 * Default implementation of FullScreenListener.
 */
export class DefaultFullScreenListener implements FullScreenListener {
  private fullScreen: boolean = true;
  private skipCheck: boolean = false;

  /**
   * Checks if full screen mode is enabled.
   * @returns True if full screen is enabled, false otherwise
   */
  useFullScreen(): boolean {
    return this.fullScreen;
  }

  /**
   * Sets whether to use full screen mode.
   * @param useFullScreen - Whether to use full screen
   * @param context - Optional context
   */
  setUseFullScreen(useFullScreen: boolean, context?: Context | null | undefined): void {
    this.fullScreen = useFullScreen;
    this.skipCheck = true;

    context = context??getContext(this);
    const currentWindow = FlutterManager.getInstance()
      .getWindowStage(FlutterManager.getInstance().getUIAbility(context));

    currentWindow.getMainWindowSync().setWindowLayoutFullScreen(useFullScreen);

    if (deviceInfo.deviceType === '2in1' && deviceInfo.sdkApiVersion >= 14 && useFullScreen) {
      currentWindow.getMainWindowSync().maximize(window.MaximizePresentation.ENTER_IMMERSIVE);
    }

     Log.i(TAG, "WindowLayoutFullScreen is on")
  }

  /**
   * Sets whether to use full screen mode specifically for free multi-window.
   * @param useFullScreen - Whether to use full screen
   * @param context - Optional context
   */
  setUseFullScreenForFreeWindow(useFullScreen: boolean, context?: Context | null | undefined): void {
    this.fullScreen = useFullScreen;
    context = context??getContext(this);
    const currentWindow = FlutterManager.getInstance()
      .getWindowStage(FlutterManager.getInstance().getUIAbility(context));

    currentWindow.getMainWindowSync().setWindowLayoutFullScreen(useFullScreen);

    if (deviceInfo.sdkApiVersion >= 14 && useFullScreen) {
      currentWindow.getMainWindowSync().maximize(window.MaximizePresentation.ENTER_IMMERSIVE);
    }
    Log.i(TAG, 'WindowLayoutFullScreen is on')
  }

  /**
   * Called when the screen state changes.
   * @param data - The window status type
   */
  onScreenStateChanged(data: window.WindowStatusType): void {
    if (this.skipCheck) {
      Log.i(TAG, "onScreenStateChanged: skipCheck is on, WindowStatusType = " + data)
      return;
    }
    switch (data) {
      case window.WindowStatusType.MINIMIZE:
        // In the minimized mode of the APP window, the original state is maintained to avoid the problem of evasive calculation errors caused by the lock screen
        break;
      case window.WindowStatusType.FULL_SCREEN:
      case window.WindowStatusType.SPLIT_SCREEN:
      case window.WindowStatusType.FLOATING:
      case window.WindowStatusType.MAXIMIZE:
        this.fullScreen = true;
        Log.i(TAG, "onScreenStateChanged: fullScreen = true")
        break;
      default:
        this.fullScreen = false;
        Log.i(TAG, "onScreenStateChanged: fullScreen = false")
        break;
    }
  }
}
