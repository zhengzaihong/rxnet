/*
* Copyright (c) 2024 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*
*/
import { BuilderNode, FrameNode, NodeController, NodeRenderType } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';
import Any from '../../plugin/common/Any';
import PlatformView, { Params, PlatformViewVisibleAreaEventOptions } from '../../plugin/platform/PlatformView';
import Log from '../../util/Log';
import { DVModel, DVModelChildren, DynamicView } from '../../view/DynamicView/dynamicView';


declare class nodeControllerParams {
  surfaceId: string
  type: string
  renderType: NodeRenderType
  embedId: string
  width: number
  height: number
}

const TAG = 'EmbeddingNodeController'

/**
 * Node controller for embedding platform views in Flutter.
 * This class manages the lifecycle and rendering of platform views using BuilderNode.
 */
export class EmbeddingNodeController extends NodeController {
  private builderNode: BuilderNode<[Params]> | undefined | null = null;
  private wrappedBuilder: WrappedBuilder<[Params]> | null = null;
  private platformView: PlatformView | undefined = undefined;
  private embedId: string = "";
  private surfaceId: string = "";
  private renderType: NodeRenderType = NodeRenderType.RENDER_TYPE_DISPLAY;
  private direction: Direction = Direction.Auto;
  private isDestroy: boolean = false;
  private platformViewVisibleAreaEventOptions: PlatformViewVisibleAreaEventOptions | null = null;

  /**
   * Sets the render options for the platform view.
   * @param platformView - The platform view instance
   * @param surfaceId - The surface ID
   * @param renderType - The render type
   * @param direction - The layout direction
   */
  setRenderOption(platformView: PlatformView, surfaceId: string, renderType: NodeRenderType, direction: Direction) {
    if (platformView == undefined) {
      Log.e(TAG, "platformView undefined");
    } else {
      this.wrappedBuilder = platformView.getView();
    }
    this.platformView = platformView;
    this.surfaceId = surfaceId;
    this.renderType = renderType;
    this.direction = direction;
  }

  /**
   * Notify the PlatformView that it has entered an invisible state, and animations on it need to be inactive.
   */
  notifyPlatformViewInvisible(): void {
    if (!this.platformView || !this.platformViewVisibleAreaEventOptions ||
      this.platformViewVisibleAreaEventOptions.enable === false) {
      return;
    }

    this.platformView.onInactive();
  }

  /**
   * Set up the callback for monitoring changes in the visible area of the external texture.
   */
  setPlatformViewVisibleAreaEventCallback(): void {
    if (!this.platformView) {
      return;
    }

    this.platformViewVisibleAreaEventOptions =
      this.platformView.getPlatformViewVisibleAreaEventOptions();
    if (!this.platformViewVisibleAreaEventOptions) {
      return;
    }

    const options = this.platformViewVisibleAreaEventOptions!;

    Log.i(TAG,
      "setPlatformViewVisibleAreaEventCallback surfaceId:" + this.surfaceId + 
      ", enable:" + options.enable + 
      ", ratios:" + options.ratios +
      ", expectedUpdateInterval:" + options.expectedUpdateInterval +
      ", onInactiveThreshold:" + options.onInactiveThreshold +
      ", onActiveThreshold:" + options.onActiveThreshold);
    if (options.enable === false) {
      return;
    }

    let node: FrameNode | null | undefined = this.builderNode?.getFrameNode();
    if (!node) {
      return;
    }

    node?.commonEvent.setOnVisibleAreaApproximateChange(
      { ratios: options.ratios,
        expectedUpdateInterval: options.expectedUpdateInterval },

      (isExpanding: boolean, currentRatio: number) =>
      {
        if (!this.platformView) {
          return;
        }

        Log.i(TAG,
          "PlatformViewVisibleAreaEventCallback surfaceId:" + this.surfaceId +
          ", isExpanding:" + isExpanding +
          ", currentRatio:" + currentRatio);
        if (!isExpanding &&
          currentRatio <= options.onInactiveThreshold) {
          // Pause the operation of continuous production of textures
          this.platformView.onInactive();
        } else if (isExpanding &&
          currentRatio >= options.onActiveThreshold) {
          // Resume the operation of continuous production of textures
          this.platformView.onActive();
        }
      }
    )
  }

  /**
   * Creates a FrameNode for the platform view.
   * @param uiContext - The UI context
   * @returns The created FrameNode, or null if creation fails
   */
  makeNode(uiContext: UIContext): FrameNode | null {
    this.builderNode = new BuilderNode(uiContext, { surfaceId: this.surfaceId, type: this.renderType });

    if (this.platformView && this.wrappedBuilder) {
      this.builderNode.build(this.wrappedBuilder, { direction: this.direction, platformView: this.platformView });
      this.setPlatformViewVisibleAreaEventCallback();
    }
    return this.builderNode.getFrameNode();
  }

  /**
   * Sets the builder node.
   * @param builderNode - The BuilderNode instance, or null
   */
  setBuilderNode(builderNode: BuilderNode<Params[]> | null): void {
    this.builderNode = builderNode;
  }

  /**
   * Gets the builder node.
   * @returns The BuilderNode instance, or null if not set
   */
  getBuilderNode(): BuilderNode<[Params]> | undefined | null {
    return this.builderNode;
  }

  /**
   * Updates the node with new arguments.
   * @param arg - The update arguments
   */
  updateNode(arg: Object): void {
    this.builderNode?.update(arg);
  }

  /**
   * Gets the embed ID.
   * @returns The embed ID string
   */
  getEmbedId(): string {
    return this.embedId;
  }

  /**
   * Sets the destroy state and disposes the builder node if needed.
   * @param isDestroy - Whether the controller is being destroyed
   */
  setDestroy(isDestroy: boolean): void {
    this.isDestroy = isDestroy;
    if (this.isDestroy) {
      this.builderNode?.dispose();
    }
  }

  /**
   * Disposes the frame node and cleans up resources.
   */
  disposeFrameNode() {
    this.builderNode?.getFrameNode()?.getRenderNode()?.dispose();
    this.builderNode?.dispose();

    this.builderNode = null;
    this.wrappedBuilder = null;
  }

  private supportPostInputEventWithStrategy(): boolean {
    return deviceInfo.sdkApiVersion >= 24
      && typeof (this.builderNode as ESObject)?.postInputEventWithStrategy === 'function';
  }

  /**
   * The hit testing of postInputEventWithStrategy / postInputEvent requires
   * the window field of the event to be in node-local coordinates (the
   * official offsetC = offsetA + offsetB, where offsetA of the BuilderNode
   * relative to its parent NodeContainer is 0, so offsetC == offsetB ==
   * local x/y). Passing screen-global coordinates makes the hit test fail:
   * touch events fall back to postTouchEvent where window/screen get
   * remapped to local, while mouse/axis events are dropped outright
   * because they have no fallback.
   *
   * Therefore only windowX/windowY are aligned to the local x/y at the
   * posting layer to keep the hit test working, while displayX/displayY
   * and screenX/screenY keep the screen-global coordinates (including the
   * PlatformView layout offset) and are passed through to the platform
   * view, matching the semantics of Android rawX/rawY and iOS
   * location(in: window).
   */
  private alignWindowToLocalForHitTest(event: TouchEvent): void {
    const alignTouch = (touch: TouchObject) => {
      touch.windowX = touch.x;
      touch.windowY = touch.y;
    };
    for (let i = 0; i < event.changedTouches.length; i++) {
      alignTouch(event.changedTouches[i]);
    }
    for (let i = 0; i < event.touches.length; i++) {
      alignTouch(event.touches[i]);
    }
  }

  /**
   * Posts a mouse event to the builder node.
   * API 24+: prefer postInputEventWithStrategy, fallback to postInputEvent on API 20.
   * @param event - The mouse event to post
   */
  postMouseEvent(event: MouseEvent) {
    // Same as touch events: the hit test requires window to be in
    // node-local coordinates while display/screen keep global coordinates.
    // The construction layer previously assigned local coordinates to
    // window/display, and posting a global window directly would drop the
    // whole event through a failed hit test (the mouse path has no
    // fallback).
    event.windowX = event.x;
    event.windowY = event.y;
    if (this.supportPostInputEventWithStrategy()) {
      (this.builderNode as ESObject)?.postInputEventWithStrategy(event, CompetitionStrategy.DEFAULT);
    } else if (typeof (this.builderNode as ESObject)?.postInputEvent === 'function') {
      (this.builderNode as ESObject)?.postInputEvent(event);
    }
  }

  /**
   * Posts an axis event to the builder node.
   * API 24+: prefer postInputEventWithStrategy, fallback to postInputEvent on API 20.
   * @param event - The axis event to post
   */
  postAxisEvent(event: AxisEvent) {
    // Same as mouse events: the hit test requires window to be in
    // node-local coordinates.
    event.windowX = event.x;
    event.windowY = event.y;
    if (this.supportPostInputEventWithStrategy()) {
      (this.builderNode as ESObject)?.postInputEventWithStrategy(event, CompetitionStrategy.DEFAULT);
    } else if (typeof (this.builderNode as ESObject)?.postInputEvent === 'function') {
      (this.builderNode as ESObject)?.postInputEvent(event);
    }
  }

  /**
   * Posts a touch event to the builder node.
   * @param event - The touch event to post, or undefined
   * @param isPx - Whether the coordinates are already in pixels (default: false, will convert from vp to px)
   * @returns Whether the event was successfully posted
   */
  postEvent(event: TouchEvent | undefined, isPx: boolean = false): boolean {
    if (event == undefined) {
      return false;
    }

    // change vp to px
    if (!isPx) {
      let changedTouchLen = event.changedTouches.length;
      for (let i = 0; i < changedTouchLen; i++) {
        event.changedTouches[i].displayX = vp2px(event.changedTouches[i].displayX);
        event.changedTouches[i].displayY = vp2px(event.changedTouches[i].displayY);
        event.changedTouches[i].windowX = vp2px(event.changedTouches[i].windowX);
        event.changedTouches[i].windowY = vp2px(event.changedTouches[i].windowY);
        event.changedTouches[i].screenX = vp2px(event.changedTouches[i].screenX);
        event.changedTouches[i].screenY = vp2px(event.changedTouches[i].screenY);
        event.changedTouches[i].x = vp2px(event.changedTouches[i].x);
        event.changedTouches[i].y = vp2px(event.changedTouches[i].y);
        Log.d(TAG, "changedTouches[" + i + "] displayX:" + event.changedTouches[i].displayX + " displayY:" +
          event.changedTouches[i].displayY + " x:" + event.changedTouches[i].x + " y:" + event.changedTouches[i].y);
      }
      let touchesLen = event.touches.length;
      for (let i = 0; i< touchesLen; i++) {
        event.touches[i].displayX = vp2px(event.touches[i].displayX);
        event.touches[i].displayY = vp2px(event.touches[i].displayY);
        event.touches[i].windowX = vp2px(event.touches[i].windowX);
        event.touches[i].windowY = vp2px(event.touches[i].windowY);
        event.touches[i].screenX = vp2px(event.touches[i].screenX);
        event.touches[i].screenY = vp2px(event.touches[i].screenY);
        event.touches[i].x = vp2px(event.touches[i].x);
        event.touches[i].y = vp2px(event.touches[i].y);
        Log.d(TAG, "touches[" + i + "] displayX:" + event.touches[i].displayX + " displayY:" +
          event.touches[i].displayY + " x:" + event.touches[i].x + " y:" + event.touches[i].y);
      }
    }

    // API 24+: prefer postInputEventWithStrategy, fallback to postTouchEvent on API 20
  	  if (this.supportPostInputEventWithStrategy()) {
      this.alignWindowToLocalForHitTest(event);
      if ((this.builderNode as ESObject)?.postInputEventWithStrategy(event, CompetitionStrategy.DEFAULT)) {
        return true;
      } else if (typeof (this.builderNode as ESObject)?.postTouchEvent === 'function') {
        Log.d(TAG, 'postInputEventWithStrategy failed, fallback to postTouchEvent');
        return this.builderNode?.postTouchEvent(event) as boolean;
      }
    }
    return this.builderNode?.postTouchEvent(event) as boolean;
  }
}

