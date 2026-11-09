/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*/

import Log from '../../util/Log';
import { FlutterView } from '../../view/FlutterView';
import FlutterManager from './FlutterManager';
import { DVModel, DVModelChildren, DynamicView } from '../../view/DynamicView/dynamicView';
import { OverlayRect } from '../../plugin/platform/PlatformViewsControllerHybrid';
import Any from '../../plugin/common/Any';
import deviceInfo from '@ohos.deviceInfo';
import flutter from 'libflutter.so';
import { AUTOFILL_SUPPORT_API } from '../../plugin/editing/OhosAutoFillHelper';
const TAG = "FlutterPage";

/**
 * Hosts one `XComponent` surface for `FlutterPage`. In `onLoad`, resolves `FlutterView` and stores the token from
 * `FlutterView.onSurfaceCreated`; in `onDestroy`, passes that token to `FlutterView.onSurfaceDestroyed` so a stale
 * `onDestroy` after fast route replacement cannot detach the current surface.
 */
@Component
struct FlutterSurface {
  @Prop safeAreaEdges: SafeAreaEdge[] | undefined = [];
  @Prop safeAreaTypes: SafeAreaType[] | undefined = [];
  @Prop viewId: string = ""
  @Prop xComponentType: XComponentType = XComponentType.SURFACE
  @Prop xComponentRenderFit: RenderFit = RenderFit.RESIZE_FILL;
  @Prop firstFrameDisplayed: boolean = false;
  @Prop xComponentColor: Color = Color.Black
  /** When true, keep the main XComponent background transparent (HCPP hole-punch). */
  @Prop forceTransparentBackground: boolean = false;
  @Prop defaultFocusOnTouch: boolean = false;

  private surfaceLifecycleToken: number = 0;
  private flutterView?: FlutterView | null;

  private pushAutofillUiContext(source: string): void {
    if (deviceInfo.sdkApiVersion < AUTOFILL_SUPPORT_API) {
      return;
    }
    try {
      const pageUiContext = this.getUIContext();
      this.flutterView?.setAutofillUiContext(source, pageUiContext);
    } catch (error) {
      Log.w(TAG, 'pushAutofillUiContext(' + source + ') failed: ' + JSON.stringify(error));
    }
  }

  build() {
    XComponent({ id: this.viewId, type: this.xComponentType, libraryname: 'flutter' })
      .id(this.viewId)
      .focusable(true)
      .focusOnTouch(this.defaultFocusOnTouch)
      .onLoad((context) => {
        this.flutterView = FlutterManager.getInstance().getFlutterView(this.viewId);
        this.surfaceLifecycleToken = this.flutterView?.onSurfaceCreated() ?? 0;
        this.pushAutofillUiContext('FlutterPage.XComponent.onLoad');
        // Callback is triggered when the xcomponent window is partially visible or completely hidden.
        if (deviceInfo.sdkApiVersion < 15) {
          this.getUIContext()?.getAttachedFrameNodeById(this.viewId)?.commonEvent.setOnVisibleAreaApproximateChange(
            { ratios: [0.0, 1.0], expectedUpdateInterval: 0 },
            (isExpanding: boolean, currentRatio: number) => {
              if (isExpanding) {
                Log.i(TAG, "setOnVisibleAreaApproximateChange -> xcomponentId: " + this.viewId +
                  " isExpanding: " + isExpanding + " ratio: " + currentRatio);
                flutter.nativeUpdateCurrentXComponentId(this.viewId);
              }
            }
          )
        }
        Log.d(TAG, "XComponent onLoad ");
      })
      .onDestroy(() => {
        Log.d(TAG, "XComponent onDestroy ");
        this.flutterView?.onSurfaceDestroyed(this.surfaceLifecycleToken)
        this.flutterView = null;
      })
      .renderFit(this.xComponentRenderFit)
      .backgroundColor(this.forceTransparentBackground ? Color.Transparent :
        (this.firstFrameDisplayed && this.xComponentRenderFit == RenderFit.RESIZE_FILL ?
          this.xComponentColor : Color.Transparent))
      .expandSafeArea(this.safeAreaTypes, this.safeAreaEdges)
      .onAreaChange((oldValue: Area, newValue: Area) => {
        // Only handle when Y position changes (window decoration state changed)
        if (oldValue.globalPosition.y != newValue.globalPosition.y) {
          FlutterManager.getInstance().handleWindowDecorSafeArea(this.viewId, this.getUIContext().getHostContext());
        }
      })
  }
}


/**
 * Hosts the transparent overlay XComponent used by Hybrid Composition (HCPP) to
 * composite Flutter content drawn ABOVE platform views (the "overlay slice").
 *
 * Key difference vs {@link FlutterSurface}: this XComponent is NEVER attached to
 * the engine as the main Flutter surface. Its id carries the `__overlay` suffix
 * so the native {@code XComponentBase::OnSurfaceCreated} routes its window to
 * {@code SetHybridCompositionOverlayWindow} instead of {@code SurfaceCreated}.
 * Transparent + HitTestMode.None so touches fall through to DISPLAY nodes below.
 */
@Component
struct FlutterOverlayXComponent {
  @Prop viewId: string = "";

  build() {
    XComponent({ id: `${this.viewId}__overlay`, type: XComponentType.SURFACE, libraryname: 'flutter' })
      .backgroundColor(Color.Transparent)
      .hitTestBehavior(HitTestMode.None)
      .visibility(Visibility.Visible)
  }
}

/**
 * 局部 Block 节点列表，每个节点几何跟随一个 SliceViews overlay rect
 * （platform view 上方所有 Flutter 控件的 Union 包围盒，如刷新按钮/视频播放控件）。
 * rect 列表来自 AppStorage（ControllerHybrid.onEndFrameHybrid 每 frame flush 覆盖）。
 */
@Component
export struct FlutterOverlayBlock {
  flutterView: FlutterView | null = null;
  @Prop viewId: string = "";
  // ForEach 模式：动态渲染每个 rect 一个局部 Block，支持多 PV。
  // key 含坐标：OverlayRect 是普通 interface（非 @Observed），ForEach 用稳定 key（viewId）复用
  // 节点时不重新执行 itemBuilder，导致 rect 变化时节点几何不更新，
  // key 含坐标则 rect 变即重建 →几何跟随刷新。
  // Map<viewKey, rects>：多引擎时各 controller 只写自己的 slice，本页按
  // viewId 取自己的部分，避免固定 key 的跨引擎 last-writer-wins。
  @StorageLink('hcpp_overlay_rects_map') overlayRectsMap: Map<string, OverlayRect[]> = new Map();

  private getOverlayRects(): OverlayRect[] {
    const rects = this.overlayRectsMap.get(this.viewId);
    return rects != undefined ? rects : [];
  }

  build() {
    Stack() {
      ForEach(this.getOverlayRects(), (r: OverlayRect) => {
        if (r.visible) {
          Stack() {
          }
          .width(r.width)
          .height(r.height)
          .position({ x: r.x, y: r.y })
          .backgroundColor(Color.Transparent)
          .hitTestBehavior(HitTestMode.Block)
          .onTouch((event: TouchEvent) => {
            if (r == undefined || !r.visible) {
              return;
            }
            const flutterView = this.flutterView != null
              ? this.flutterView
              : FlutterManager.getInstance().getFlutterView(this.viewId);
            if (flutterView == null) {
              return;
            }
            flutterView.dispatchTouchToEngineHybrid(r.viewId, event);
          })
          .onHover((isHover: boolean, event: HoverEvent) => {
            if (r == undefined || !r.visible) {
              return;
            }
            const flutterView = this.flutterView != null
              ? this.flutterView
              : FlutterManager.getInstance().getFlutterView(this.viewId);
            if (flutterView == null) {
              return;
            }
            flutterView.dispatchHoverToEngineHybrid(r.viewId, isHover, event);
          })
          .onAxisEvent((event: AxisEvent) => {
            if (r == undefined || !r.visible) {
              return;
            }
            const flutterView = this.flutterView != null
              ? this.flutterView
              : FlutterManager.getInstance().getFlutterView(this.viewId);
            if (flutterView == null) {
              return;
            }
            flutterView.dispatchAxisToEngineHybrid(r.viewId, event);
          })
        }
      }, (r: OverlayRect) => `${r.id}_${r.x}_${r.y}_${r.width}_${r.height}`)
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.None)
  }
}


/**
 * Basic page component that hosts XComponent for Flutter rendering.
 * This component handles the display of Flutter content within an OpenHarmony page.
 */
@Component
export struct FlutterPage {
  /** Safe area edges to expand, or undefined for default. */
  @Prop safeAreaEdges: SafeAreaEdge[] | undefined = [];
  /** Safe area types to expand, or undefined for default. */
  @Prop safeAreaTypes: SafeAreaType[] | undefined = [];
  /** The unique identifier for the XComponent view. */
  @Prop viewId: string = ""
  /** The XComponent type for rendering. */
  @Prop xComponentType: XComponentType = XComponentType.SURFACE
  /**
   * renderFit under XComponent has a default setting of RESIZE_FILL.
   * If the size of XComponent may change, this property needs to be passed in and set to a size-preserving property,
   * such as TOP_LEFT.
   */
  @Prop xComponentRenderFit: RenderFit = RenderFit.RESIZE_FILL;

  /**
   * A switch for enabling the frame cache.
   * When it is true, one frame of response latency will be increased in exchange for higher smoothness,
   * and occasional timeouts in rendering frame submissions will not result in frame dropping.
   */
  @Prop enableFrameCacheForSmooth: boolean = true;

  @Prop shouldPauseWhenInvisible: boolean = true;

  private modifier: StackModifier = new StackModifier(
    this.shouldPauseWhenInvisible,
    this.flutterView
  )

  /**
   * Empty builder function used as default.
   */
  @Builder
  doNothingBuilder() {
  }

  defaultFocusOnTouch = false;
  
  @BuilderParam splashScreenView: () => void = this.doNothingBuilder;

  /** True when the engine runs in HCPP mode; drives Stack z-order. */
  @State hybridCompositionEnabled: boolean = false;

  // hcppOnly: true=仅 HCPP wrapper / false=仅纹理 wrapper / undefined=全部(非 HCPP 态原语义)。
  @Builder
  buildPlatformViewLayer(hcppOnly?: boolean) {
    ForEach(this.rootDvModel!!, (child: ESObject) => {
      if (hcppOnly === undefined ||
        ((child.params as Record<string, ESObject>)['hcpp'] === true) === hcppOnly) {
        DynamicView({
          model: child as DVModel,
          params: child.params,
          events: child.events,
          children: child.children,
          customBuilder: child.builder
        })
      }
    }, (child: ESObject) => `${child.id_}`)
  }

  @Builder
  buildFlutterSurfaceLayer() {
    FlutterSurface({
      safeAreaEdges: this.safeAreaEdges,
      safeAreaTypes: this.safeAreaTypes,
      viewId: this.viewId,
      xComponentType: this.xComponentType,
      xComponentRenderFit: this.xComponentRenderFit,
      firstFrameDisplayed: this.firstFrameDisplayed,
      xComponentColor: this.xComponentColor,
      forceTransparentBackground: this.hybridCompositionEnabled,
      defaultFocusOnTouch: this.defaultFocusOnTouch
    })
  }

  // HCPP overlay layer: transparent XComponent composited ABOVE platform views.
  // The engine renders Flutter content that sits on top of a native view into
  // this surface (the "overlay slice"). Only rendered in HCPP mode.
  @Builder
  buildOverlayLayer() {
    FlutterOverlayXComponent({ viewId: this.viewId })
  }

  // 局部 Block 节点（最顶层，overlay 之上），几何跟随 overlay rect。
  // 仅 rect.visible 时内部渲染，否则透明 None 不影响下层。
  @Builder
  buildOverlayBlock() {
    FlutterOverlayBlock({ flutterView: this.flutterView, viewId: this.viewId })
  }

  private refreshHybridCompositionState(): void {
    const enabled = this.flutterView?.isHybridCompositionEnabled() ?? false;
    if (enabled != this.hybridCompositionEnabled) {
      this.hybridCompositionEnabled = enabled;
    }
  }

  /**
   * Default page builder that displays Flutter content with XComponent.
   */
  @Builder
  defaultPage() {
    Stack() {
      // HCPP z-order: background slice (bottom) < DISPLAY nodes < overlay slice (top).
      // 仅 HCPP(DISPLAY)节点进 surface 之上的合成层序。
      if (this.hybridCompositionEnabled) {
        this.buildPlatformViewLayer(false)
        this.buildFlutterSurfaceLayer()
        Text("").id("unfocus-xcomponent-node").focusable(true)
        this.buildPlatformViewLayer(true)
        this.buildOverlayLayer()
        this.buildOverlayBlock()
      } else {
        this.buildPlatformViewLayer()
        Text("").id("unfocus-xcomponent-node").focusable(true)
        this.buildFlutterSurfaceLayer()
      }

      if (this.showSplashScreen) {
        this.splashScreenView();
      }
    }
    .defaultFocus(true)
    .onKeyPreIme((event: KeyEvent) => {
      return this.flutterView?.onKeyPreIme(event) ?? false;
    })
    .onKeyEvent((event: KeyEvent) => {
      return this.flutterView?.onKeyEvent(event) ?? false;
    })
    .onDragEnter((event: DragEvent, extraParams: string) => {
      FlutterManager.getInstance().getDragEnterCbs().forEach(dragEnterCb => {
        dragEnterCb.do(event, extraParams);
      });
      Log.d(TAG, "onDragEnter");
    })
    .onDragMove((event: DragEvent, extraParams: string) => {
      FlutterManager.getInstance().getDragMoveCbs().forEach(dragMoveCb => {
        dragMoveCb.do(event, extraParams);
      });
      Log.d(TAG, "onDragMove");
    })
    .onDragLeave((event: DragEvent, extraParams: string) => {
      FlutterManager.getInstance().getDragLeaveCbs().forEach(dragLeaveCb => {
        dragLeaveCb.do(event, extraParams);
      });
      Log.d(TAG, "onDragLeave");
    })
    .onDrop((event: DragEvent, extraParams: string) => {
      FlutterManager.getInstance().getDropCbs().forEach(dropCb => {
        dropCb.do(event, extraParams);
      });
      Log.d(TAG, "onDrop");
    })
    .attributeModifier(this.modifier)
  }

  /**
   * Page builder that supports mouse wheel gestures.
   */
  @Builder
  mouseWheelPage() {
    Stack() {
      // HCPP z-order 与 defaultPage 完全一致：
      // texture PVs < background slice (bottom) < unfocus Text < DISPLAY nodes < overlay slice < overlay Block。
      if (this.hybridCompositionEnabled) {
        this.buildPlatformViewLayer(false)
        this.buildFlutterSurfaceLayer()
        Text("").id("unfocus-xcomponent-node").focusable(true)
        this.buildPlatformViewLayer(true)
        this.buildOverlayLayer()
        this.buildOverlayBlock()
      } else {
        this.buildPlatformViewLayer()
        Text("").id("unfocus-xcomponent-node").focusable(true)
        this.buildFlutterSurfaceLayer()
      }

      if (this.showSplashScreen) {
        this.splashScreenView();
      }
    }
    .defaultFocus(true)
    .onKeyPreIme((event: KeyEvent) => {
      return this.flutterView?.onKeyPreIme(event) ?? false;
    })
    .onKeyEvent((event: KeyEvent) => {
      this.flutterView?.onKeyEvent(event)
    })
    .onDragEnter((event: DragEvent, extraParams: string) => {
      FlutterManager.getInstance().getDragEnterCbs().forEach(dragEnterCb => {
        dragEnterCb.do(event, extraParams);
      });
      Log.d(TAG, "onDragEnter");
    })
    .onDragMove((event: DragEvent, extraParams: string) => {
      FlutterManager.getInstance().getDragMoveCbs().forEach(dragMoveCb => {
        dragMoveCb.do(event, extraParams);
      });
      Log.d(TAG, "onDragMove");
    })
    .onDragLeave((event: DragEvent, extraParams: string) => {
      FlutterManager.getInstance().getDragLeaveCbs().forEach(dragLeaveCb => {
        dragLeaveCb.do(event, extraParams);
      });
      Log.d(TAG, "onDragLeave");
    })
    .onDrop((event: DragEvent, extraParams: string) => {
      FlutterManager.getInstance().getDropCbs().forEach(dropCb => {
        dropCb.do(event, extraParams);
      });
      Log.d(TAG, "onDrop");
    })
    .gesture(
      PanGesture(this.panOption)
        .onActionStart((event: GestureEvent) => {
          this.flutterView?.onMouseWheel("actionStart", event);
        })
        .onActionUpdate((event: GestureEvent) => {
          this.flutterView?.onMouseWheel("actionUpdate", event);
        })
        .onActionEnd((event: GestureEvent) => {
          this.flutterView?.onMouseWheel("actionEnd", event);
        })
    )
    .attributeModifier(this.modifier)
  }

  /** Whether to show the splash screen. */
  @State showSplashScreen: boolean = true;
  /**
   * To address the black(or other color set by usr) flashing frame when switching between ArkUI and Flutter pages,
   * the background color should be kept transparent until the onFirstFrame is called.
   * When the window size changes, modifying the renderFit property in the relevant callback does not take effect immediately.
   * The first frame will use the old renderFit property and the old background color, resulting in visual artifacts (such as stretching or a black screen).
   * Therefore, we cannot automatically change the relevant properties through state variables at this time.
   */
  @State firstFrameDisplayed: boolean = false;
  /** Background color for the XComponent. */
  @State xComponentColor: Color = Color.Black

  /** Whether to check for full screen mode. */
  @State checkFullScreen: boolean = true;
  /** Whether to check for keyboard visibility. */
  @State checkKeyboard: boolean = true;
  /** Whether to check for gesture navigation. */
  @State checkGesture: boolean = true;
  /** Whether to enable mouse wheel gesture support. */
  @State checkMouseWheel: boolean = true;
  /** Whether to check for AI bar. */
  @State checkAiBar: boolean = true;
  /** Top padding value, or undefined if not set. */
  @Prop @Watch("onPaddingChange")paddingTop?: number = undefined;
  /** Storage link for node width. */
  @StorageLink('nodeWidth') storageLinkWidth: number = 0;
  /** Storage link for node height. */
  @StorageLink('nodeHeight') storageLinkHeight: number = 0;

  /** Root dynamic view model children, or undefined if not set. */
  @State rootDvModel: DVModelChildren | undefined = undefined

  private flutterView?: FlutterView | null
  private panOption: PanGestureOptions = new PanGestureOptions({ direction: PanDirection.Up | PanDirection.Down });

  private pushAutofillUiContext(source: string): void {
    if (deviceInfo.sdkApiVersion < AUTOFILL_SUPPORT_API) {
      return;
    }
    try {
      const pageUiContext = this.getUIContext();
      this.flutterView?.setAutofillUiContext(source, pageUiContext);
    } catch (error) {
      Log.w(TAG, 'pushAutofillUiContext(' + source + ') failed: ' + JSON.stringify(error));
    }
  }

  /**
   * Called when the page is about to appear.
   * Initializes the FlutterView and sets up listeners and callbacks.
   */
  aboutToAppear() {
    this.flutterView = FlutterManager.getInstance().getFlutterView(this.viewId);
    if (!this.flutterView) {
      Log.e(TAG, 'getFlutterView failed. viewId is ' + this.viewId.toString());
    }
    this.pushAutofillUiContext('FlutterPage.aboutToAppear');
    this.flutterView?.addFirstFrameListener(this)
    this.flutterView?.addFirstPreloadFrameListener(this)

    // API 18+ supports getDistance() for touch slop detection.
    if (deviceInfo.sdkApiVersion >= 18) {
      this.flutterView?.setTouchSlopCallbackValue(() => {
        return this.panOption.getDistance()
      })
    }

    this.flutterView?.setCheckFullScreen(this.checkFullScreen)
    this.flutterView?.setCheckKeyboard(this.checkKeyboard)
    this.flutterView?.setCheckGesture(this.checkGesture)
    this.flutterView?.setPaddingTop(this.paddingTop)
    this.flutterView?.setCheckAiBar(this.checkAiBar)
    this.flutterView?.enableFrameCache(this.enableFrameCacheForSmooth);

    this.rootDvModel = this.flutterView?.getDVModel().children

    this.modifier = new StackModifier(
      this.shouldPauseWhenInvisible,
      this.flutterView
    );
    this.refreshHybridCompositionState();
  }

  /**
   * Called when the page is about to disappear.
   * Removes frame listeners to clean up resources.
   */
  aboutToDisappear() {
    this.flutterView?.removeFirstFrameListener(this);
    this.flutterView?.removeFirstPreloadFrameListener(this)
  }

  /**
   * Called when the first frame is displayed.
   * Hides the splash screen and marks the first frame as displayed.
   */
  onFirstFrame() {
    this.showSplashScreen = false;
    this.firstFrameDisplayed = true;
    this.refreshHybridCompositionState();
  }

  /**
   * Called when the first preload frame is displayed.
   */
  onFirstPreloadFrame() {
  }

  /**
   * Called when padding changes.
   * Updates the FlutterView's padding.
   */
  onPaddingChange() {
    this.flutterView?.setPaddingTop(this.paddingTop);
  }

  /**
   * Builds the page UI.
   * Selects between mouse wheel page and default page based on configuration.
   */
  build() {
    if (this.checkMouseWheel) {
      this.mouseWheelPage();
    } else {
      this.defaultPage();
    }
  }
}

class StackModifier implements AttributeModifier<StackAttribute> {
  private shouldPauseWhenInvisible: boolean;
  private flutterView?: FlutterView | null;

  constructor (
    shouldPauseWhenInvisible: boolean,
    flutterView?: FlutterView | null
  ) {
    this.shouldPauseWhenInvisible = shouldPauseWhenInvisible;
    this.flutterView = flutterView;
  }

  applyNormalAttribute(instance: StackAttribute): void {
    if (this.shouldPauseWhenInvisible && deviceInfo.sdkApiVersion >= 20) {
      instance.onVisibleAreaChange(
        [0.0],
        (isExpanding: boolean, currentRatio: number) => {
          if (isExpanding && currentRatio > 0.0) { 
            // partially visible
            this.flutterView?.onVisibleAreaChanged(true);
          } else if (!isExpanding && currentRatio <= 0.0){ 
            // completely invisible
            this.flutterView?.onVisibleAreaChanged(false);
          }
        }
      )
    }
  }
}