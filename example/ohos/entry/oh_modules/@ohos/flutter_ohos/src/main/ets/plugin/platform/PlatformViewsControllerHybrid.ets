/*
 * Copyright (c) 2026 Huawei Device Co., Ltd. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE_HW file.
 */

import PlatformViewsChannelHybrid, { PlatformViewsHybridHandler } from '../../embedding/engine/systemchannels/PlatformViewsChannelHybrid';
import {
  PlatformViewCreationRequest,
  PlatformViewTouch
} from '../../embedding/engine/systemchannels/PlatformViewsChannel';
import PlatformView, { Params } from './PlatformView';
import { CustomTouchEvent, CustomTouchObject } from './CustomTouchEvent';
import { DVModel, DVModelParameters } from '../../view/DynamicView/dynamicView';
import { createDVModelFromJson } from '../../view/DynamicView/dynamicViewJson';
import { FlutterView } from '../../view/FlutterView';
import DartExecutor from '../../embedding/engine/dart/DartExecutor';
import Log from '../../util/Log';
import PlatformViewFactory from './PlatformViewFactory';
import { ByteBuffer } from '../../util/ByteBuffer';
import Any from '../common/Any';
import { NodeRenderType } from '@kit.ArkUI';
import matrix4 from '@ohos.matrix4';
import { PlatformViewInfo } from '../../embedding/ohos/PlatformViewInfo';
import { EmbeddingNodeController } from '../../embedding/ohos/EmbeddingNodeController';
import { PlatformViewWrapper } from './PlatformViewWrapper';
import PlatformViewRegistryImpl from './PlatformViewRegistryImpl';
import { HybridCompositionHandler } from '../../embedding/engine/FlutterNapi';
import FlutterNapi from '../../embedding/engine/FlutterNapi';
import { decodePlatformViewCreationParams } from './PlatformViewParamsUtil';
import display from '@ohos.display';

const TAG = "PlatformViewsControllerHybrid";

/** DynamicView 模型的 JSON 表示(本地镜像)。 */
class DVModelJson2 {
  compType: string;
  children: Array<Any>;
  attributes: Any;
  events: Any;
  build: Any;

  constructor(compType: string, children: Array<Any>, attributes: Any, events: Any, build?: Any) {
    this.compType = compType;
    this.children = children;
    this.attributes = attributes;
    this.events = events;
    this.build = build;
  }
}

enum TouchEventType {
  ACTION_DOWN = 0,
  ACTION_UP = 1,
  ACTION_MOVE = 2,
  ACTION_CANCEL = 3,
  // Android MotionEvent 多指编码：action = base | (pointerIndex << 8)。
  // Dart _OhosMotionEventConverter 在 numPointers>1 时把 down/up 编成
  // pointerAction(idx, ACTION_POINTER_DOWN/UP) = 5|6|(idx<<8)（如 261/262）。
  // 值与 PlatformViewsController.ets / Android MotionEvent 对齐。
  ACTION_POINTER_DOWN = 5,
  ACTION_POINTER_UP = 6,
}

// OnDisplayMutatorsHybrid 扁平 double 数组布局,C++/ArkTS 双端共享协议。
// 修改任一偏移必须同步修改 C++ 端 external_view_embedder.cc 的常量。
const OPACITY_INDEX = 0;
const MATRIX_ENTRY_COUNT = 16;
const MATRIX_START = OPACITY_INDEX + 1;                 // = 1
const CLIP_RECTS_COUNT_INDEX = MATRIX_START + MATRIX_ENTRY_COUNT;  // = 17
const CLIP_RECTS_DATA_START = CLIP_RECTS_COUNT_INDEX + 1;          // = 18
const RECT_FIELD_COUNT = 4;                            // x, y, w, h
const RECT_W_OFFSET = 2;                               // bounds 内 w 的偏移
const RECT_H_OFFSET = 3;                               // bounds 内 h 的偏移
const PATH_HEADER_FIELD_COUNT = 5;                     // bounds(4) + cmdLen(1)

// kClipPath 的 path verb 编码,与 C++ 端 PATH_VERB_* 对齐。
enum PathVerb {
  CLOSE = 0,  // 0 args
  MOVE = 1,   // 2 args: x, y
  LINE = 2,   // 2 args: x, y
  QUAD = 3,   // 4 args: cpx, cpy, x, y
  CUBIC = 4,  // 6 args: cp1x, cp1y, cp2x, cp2y, x, y
}
// 每个 verb 后跟的浮点参数个数(点坐标),用于解析时跳过。
const PATH_VERB_MOVE_ARGS = 2;
const PATH_VERB_LINE_ARGS = 2;
const PATH_VERB_QUAD_ARGS = 4;
const PATH_VERB_CUBIC_ARGS = 6;

// clipPath 矩形裁剪阈值(px):viewport 交集相对节点原点的偏移/收窄
// 超过此值才触发 SH 裁剪,避免视口内(无越界)白跑几何运算。
const CLIP_PATH_VIEWPORT_THRESHOLD_PX = 0.5;

// 用途:clipPath(三角形等凸多边形)被 viewport ClipRect 顶/边裁时,把 clip Path
// 本身的几何裁到 viewport 矩形内——单 Path 表达 "三角形∩viewport",不依赖ArkUI 链式 .clip() 交集。
interface PolyVertex { x: number; y: number; }

// 多边形 bbox(显式 interface,ArkTS 禁止对象字面量当类型/无类型字面量返回)。
interface PolyBounds { minX: number; minY: number; maxX: number; maxY: number; }

// 对单条 clip 边裁一次。axis:0=x(垂直边,用 val 比 x),1=y(水平边,用 val 比 y)。
// lowerEdge:true 表示 inside = coord >= val(左/上边),false 表示 inside = coord <= val(右/下边)。
function clipEdgeSH(input: PolyVertex[], axis: number, val: number, lowerEdge: boolean): PolyVertex[] {
  const output: PolyVertex[] = [];
  const n = input.length;
  if (n === 0) return output;
  // inside 判断内联(避免 ArkTS 对局部箭头函数字面量的严格限制):
  // axis=0 比 x, axis=1 比 y;lowerEdge=true 用 >=(左/上边),false 用 <=(右/下边)。
  for (let i = 0; i < n; i++) {
    const cur = input[i];
    const prev = input[(i + n - 1) % n];   // 前一顶点(闭合环)
    const curC = axis === 0 ? cur.x : cur.y;
    const prevC = axis === 0 ? prev.x : prev.y;
    const curIn = lowerEdge ? curC >= val : curC <= val;
    const prevIn = lowerEdge ? prevC >= val : prevC <= val;
    if (curIn) {
      if (!prevIn) {                       // 入边:先加交点
        output.push(intersectSH(prev, cur, axis, val));
      }
      output.push(cur);
    } else if (prevIn) {                   // 出边:加交点
      output.push(intersectSH(prev, cur, axis, val));
    }
  }
  return output;
}

// 线段 (a→b) 与 clip 边的交点(线性插值)。axis 决定沿哪条坐标轴求 t。
function intersectSH(a: PolyVertex, b: PolyVertex, axis: number, val: number): PolyVertex {
  const aCoord = axis === 0 ? a.x : a.y;
  const bCoord = axis === 0 ? b.x : b.y;
  // 分母为 0(线段垂直于 clip 边)时交点理论上是 cur 本身,用 0 兜底防 NaN。
  const denom = bCoord - aCoord;
  const t = denom !== 0 ? (val - aCoord) / denom : 0;
  const p: PolyVertex = { x: a.x + t * (b.x - a.x), y: a.y + t * (b.y - a.y) };
  return p;
}

// 4 条边逐条裁:左(minX, lowerEdge)、右(maxX)、上(minY)、下(maxY)。
function sutherlandHodgmanClip(subject: PolyVertex[],
  minX: number, minY: number, maxX: number, maxY: number): PolyVertex[] {
  if (subject.length < 3) return subject;
  let output: PolyVertex[] = subject.slice();
  output = clipEdgeSH(output, 0, minX, true);   // 左边: x >= minX
  output = clipEdgeSH(output, 0, maxX, false);  // 右边: x <= maxX
  output = clipEdgeSH(output, 1, minY, true);   // 上边: y >= minY
  output = clipEdgeSH(output, 1, maxY, false);  // 下边: y <= maxY
  return output;
}

// 求顶点数组 bbox(显式循环,避免 ArkTS 对 spread 的支持差异)。
function polyBounds(verts: PolyVertex[]): PolyBounds {
  let minX = Infinity;
  let minY = Infinity;
  let maxX = -Infinity;
  let maxY = -Infinity;
  for (const p of verts) {
    if (p.x < minX) minX = p.x;
    if (p.y < minY) minY = p.y;
    if (p.x > maxX) maxX = p.x;
    if (p.y > maxY) maxY = p.y;
  }
  const b: PolyBounds = { minX, minY, maxX, maxY };
  return b;
}

// 曲线展平：将二次/三次贝塞尔曲线细分为折线顶点，
// 使 SH 能裁含曲线的 path（如圆角矩形的圆弧）。展平后所有曲线变为短直线段，
// polyVerts 即为高精度多边形近似，SH 裁剪逻辑无需区分直线/曲线 path。
// 每段 90° 弧细分 FLATTEN_STEPS_PER_ARC 段，在 300+DPI 下折线与真实弧线偏差 < 1px。
const FLATTEN_STEPS_PER_ARC = 16;

// 二次贝塞尔 p0→cp→p1 展平为 steps 段折线顶点（不含起点 p0，含终点 p1）。
function flattenQuad(p0: PolyVertex, cp: PolyVertex, p1: PolyVertex, steps: number): PolyVertex[] {
  const verts: PolyVertex[] = [];
  for (let i = 1; i <= steps; i++) {
    const t = i / steps;
    const mt = 1 - t;
    const x = mt * mt * p0.x + 2 * mt * t * cp.x + t * t * p1.x;
    const y = mt * mt * p0.y + 2 * mt * t * cp.y + t * t * p1.y;
    const v: PolyVertex = { x: x, y: y };
    verts.push(v);
  }
  return verts;
}

// 三次贝塞尔 p0→cp1→cp2→p1 展平为 steps 段折线顶点（不含起点 p0，含终点 p1）。
function flattenCubic(p0: PolyVertex, cp1: PolyVertex, cp2: PolyVertex, p1: PolyVertex,
  steps: number): PolyVertex[] {
  const verts: PolyVertex[] = [];
  for (let i = 1; i <= steps; i++) {
    const t = i / steps;
    const mt = 1 - t;
    const x = mt * mt * mt * p0.x + 3 * mt * mt * t * cp1.x + 3 * mt * t * t * cp2.x + t * t * t * p1.x;
    const y = mt * mt * mt * p0.y + 3 * mt * mt * t * cp1.y + 3 * mt * t * t * cp2.y + t * t * t * p1.y;
    const v: PolyVertex = { x: x, y: y };
    verts.push(v);
  }
  return verts;
}

// 圆角矩形 → 多边形顶点（含展平的圆弧）。
// 坐标空间：局部 px，原点 (0,0)，顺时针 TL→TR→BR→BL。
// w/h/r 均为 px。steps 是每个 90° 弧的细分段数（复用 FLATTEN_STEPS_PER_ARC）。
// 用途：kClipRRect 路径（ClipRRect / ClipPath+addRRect）在 viewport 越界时，
// 把 RRect 展平为多边形后走 SH 裁剪，保留可见区域的圆角近似。
function rrectToPolyVerts(w: number, h: number, r: number, steps: number): PolyVertex[] {
  const verts: PolyVertex[] = [];
  const minDim: number = Math.min(w, h) / 2;
  const rr: number = Math.max(0, Math.min(r, minDim));
  if (rr < 0.5) {
    // 无圆角 → 退化矩形（4 个角顶点）。
    const v0: PolyVertex = { x: 0, y: 0 };
    const v1: PolyVertex = { x: w, y: 0 };
    const v2: PolyVertex = { x: w, y: h };
    const v3: PolyVertex = { x: 0, y: h };
    verts.push(v0);
    verts.push(v1);
    verts.push(v2);
    verts.push(v3);
    return verts;
  }
  // 4 个角圆心 + 弧起止角度（弧度），顺时针 TL→TR→BR→BL。
  // screen coords(y-down): 0°=right 90°=down 180°=left 270°=up
  //   TL: center(r,r),     180°→270°: (0,r)→(r,0)
  //   TR: center(w-r,r),   270°→360°: (w-r,0)→(w,r)
  //   BR: center(w-r,h-r), 0°→90°:   (w,h-r)→(w-r,h)
  //   BL: center(r,h-r),   90°→180°: (r,h)→(0,h-r)
  const cxs: number[] = [rr, w - rr, w - rr, rr];
  const cys: number[] = [rr, rr, h - rr, h - rr];
  const a0s: number[] = [Math.PI, Math.PI * 1.5, 0, Math.PI * 0.5];
  const a1s: number[] = [Math.PI * 1.5, Math.PI * 2, Math.PI * 0.5, Math.PI];
  for (let ci = 0; ci < 4; ci++) {
    // 第一个角(TL)从弧起点开始，其余角跳过与上一段终点重合的首点。
    const startI = ci === 0 ? 0 : 1;
    for (let si = startI; si <= steps; si++) {
      const a = a0s[ci] + (a1s[ci] - a0s[ci]) * (si / steps);
      const x = cxs[ci] + rr * Math.cos(a);
      const y = cys[ci] + rr * Math.sin(a);
      const v: PolyVertex = { x: x, y: y };
      verts.push(v);
    }
  }
  return verts;
}

// PointerData::Change 枚举值,与 C++ PointerData::Change 对齐。
enum PointerChange {
  CANCEL = 0,
  ADD = 1,
  REMOVE = 2,
  HOVER = 3,
  DOWN = 4,
  MOVE = 5,
  UP = 6,
}

// MotionEvent action 多指编码:action = base | (pointerIndex << 8)。
// 取低 8 位得到 base action。与 PlatformViewsController.ets 对齐。
const MOTION_EVENT_ACTION_MASK = 0xff;

const DEDUP_TIMESTAMP_DELTA_US = 1;

const INJECTED_TIMESTAMP_TTL_MS = 2000;

// PointerData::DeviceKind 枚举值,与 C++ PointerData::DeviceKind 对齐。
enum PointerDeviceKind {
  TOUCH = 0,
  MOUSE = 1,
  STYLUS = 2,
  INVERTED_STYLUS = 3,
}

const TOOL_TYPE_BITS = 3;

// PointerData::SignalKind 枚举值,与 C++ PointerData::SignalKind 对齐。
enum PointerSignalKind {
  NONE = 0,
  SCROLL = 1,
}

// DISPLAY 节点几何(px),来自 onDisplayPlatformViewHybrid。供 onTouch 坐标转换 + clip 尺寸。
interface DisplayOffset {
  x: number;
  y: number;
  w: number;
  h: number;
  viewW: number;
  viewH: number;
  viewX: number;
  viewY: number;
}

/**
 * overlay rect(vp，相对 Flutter view)，来自 SliceViews，存 AppStorage
 * 数组供 FlutterPage ForEach 渲染多个局部 Block 节点。每个 rect 是某 platform view
 * 上方所有 Flutter 控件的 Union 包围盒。id 供 ForEach key 区分。
 */
export interface OverlayRect {
  id: number;       // 唯一 id（= viewId），ForEach key
  viewId: number;
  x: number;        // vp
  y: number;        // vp
  width: number;    // vp
  height: number;   // vp
  visible: boolean;
}

// FlutterPage 按 viewId 取自己的部分，避免固定 key 的跨引擎覆盖。
const OVERLAY_RECT_MAP_KEY: string = 'hcpp_overlay_rects_map';

// 单个 PointerData 字段，对照 native HandleTouchEvent 的 PointerData 构造
interface TouchDataItem {
  change: number;
  device: number;
  embedder_id: number;
  physical_x: number;
  physical_y: number;
  time_stamp: number;
  pressure: number;
  size: number;
  kind: number;
  buttons: number;
  scroll_delta_x: number;
  scroll_delta_y: number;
  signal_kind: number;
}

/**
 * 管理 OpenHarmony 上的 Hybrid Composition++（HCPP）平台视图。
 * 原生视图由 ArkUI 通过 BuilderNode（{@link NodeRenderType.RENDER_TYPE_DISPLAY}）
 * 托管为独立的系统合成层——其像素不流经 Flutter 纹理管线。
 * 它与基于纹理的 {@code PlatformViewsController} 共享 {@link PlatformViewRegistryImpl}，
 * 使插件只需注册一次工厂，且不干扰外置纹理路径。
 */
export default class PlatformViewsControllerHybrid implements HybridCompositionHandler, PlatformViewsHybridHandler {
  private registry: PlatformViewRegistryImpl;
  private context: Context | null = null;
  private flutterView: FlutterView | null = null;
  private channel: PlatformViewsChannelHybrid | null = null;

  private platformViews: Map<number, PlatformView> = new Map();
  private viewInfos: Map<number, PlatformViewInfo> = new Map();
  private nodeControllers: Map<number, EmbeddingNodeController> = new Map();
  private viewWrappers: Map<number, PlatformViewWrapper> = new Map();
  private focusViewId: number = -1;
  // 每个 view 的 DISPLAY 节点物理偏移(px)，来自 onDisplayPlatformViewHybrid，供 onTouch 坐标转换。
  private displayOffsets: Map<number, DisplayOffset> = new Map();
  /**
   * 每个 view 的 overscroll 平移偏移(vp)，来自 Dart 的 setOverscrollOffset。
   * Clamping physics 下 StretchingOverscrollIndicator 走 shader 拉伸(stretch_effect.dart)，
   * 不进 layer matrix → PV 的 finalBoundingRect 不含 stretch 分量 → PV 不跟随挤压。
   * 这里由 Dart 累积 OverscrollNotification.overscroll 后下传，在 onDisplayPlatformViewHybrid
   * 叠加到 top，让 PV 平移近似跟随。负值=顶部挤压(start 侧)。vp 单位(Dart 逻辑像素≈OHOS vp)。
   */
  private overscrollOffsets: Map<number, number> = new Map();
  // [wrapper-touch-block] 触摸完整性门：DOWN 因首帧几何未到被丢弃的 view 集合，
  // 其后续 MOVE/UP 连带丢弃到下一个 DOWN（防残缺指针流进 Dart 竞技场）。dispose 清。
  private orphanedTouchViews: Set<number> = new Set();
  // 本帧已收到的 overlay rect，onDisplayOverlayHybrid 逐条 push，onEndFrameHybrid flush 到 AppStorage。
  private pendingOverlayRects: OverlayRect[] = [];
  /**
   * 本帧引擎合成序（onDisplayPlatformViewHybrid 按引擎 composition_order 逐个
   * 调用，此处按到达顺序记录）。ArkUI 侧 wrapper DVModel 是创建时一次性 push 的，
   * 不会随 Dart 层重排自动更新——两个重叠 PV 的上下关系会停在创建序。每帧
   * onEndFrameHybrid 依据本序列把 wrapper 模型在 FlutterView children 中重排
   */
  private frameDisplayOrder: number[] = [];
  private flutterNapi: FlutterNapi | null = null;
  /**
   * hover 配对跟踪（键 = overlay rect 的 viewId，值 = 该 rect 是否已注入 enter）。
   * 按 rect 跟踪后：exit 仅在"该 rect 确实 enter 过 且 没有其他 rect 仍处于
   * enter 态"时才注入 kRemove——跨 rect 切换交由兄弟 rect 的 kHover 接管，
   * 完整离开所有 rect 才产生 remove。
   */
  private hoverInjectedRects: Set<number> = new Set();

  constructor(registry: PlatformViewRegistryImpl) {
    this.registry = registry;
  }

  public setFlutterNapi(napi: FlutterNapi): void {
    this.flutterNapi = napi;
  }

  /**
   * Dart 侧累积 OverscrollNotification.overscroll 后下传。
   * 存入 overscrollOffsets，由 onDisplayPlatformViewHybrid 每帧叠加到 top，让 PV 平移
   * 近似跟随 stretch shader 的挤压位移。松手时 Dart 发 0 归位。
   */
  public setOverscrollOffset(viewId: number, offsetVp: number): void {
    const prev = this.overscrollOffsets.get(viewId) ?? 0;
    if (Math.abs(offsetVp - prev) > 0.01) {
      this.overscrollOffsets.set(viewId, offsetVp);
    }
  }

  public attach(context: Context, dartExecutor: DartExecutor): void {
    this.context = context;
    this.channel = new PlatformViewsChannelHybrid(dartExecutor);
    this.channel.setPlatformViewsHandler(this);
  }

  public detach(): void {
    this.channel?.setPlatformViewsHandler(null);
    this.channel = null;
    this.context = null;
  }

  public attachToView(flutterView: FlutterView): void {
    if (this.flutterView == flutterView) {
      return;
    }
    this.flutterView = flutterView;

    for (let viewId of this.viewWrappers.keys()) {
      const wrapper = this.viewWrappers.get(viewId);
      if (wrapper && this.flutterView.getDVModel().children.indexOf(wrapper.getDvModel()) < 0) {
        this.flutterView.getDVModel().children.push(wrapper.getDvModel());
      }
    }

    for (let viewId of this.platformViews.keys()) {
      const platformView = this.platformViews.get(viewId);
      if (platformView != undefined) {
        platformView.onFlutterViewAttached(this.flutterView.getDVModel());
      }
    }
  }

  public detachFromView(detachingFlutterView?: FlutterView): void {
    if (this.flutterView == null) {
      return;
    }
    if (detachingFlutterView != undefined && this.flutterView != detachingFlutterView) {
      return;
    }
    for (let viewId of this.viewWrappers.keys()) {
      const wrapper = this.viewWrappers.get(viewId);
      if (!wrapper) {
        continue;
      }
      let index = this.flutterView.getDVModel().children.indexOf(wrapper.getDvModel());
      while (index > -1) {
        this.flutterView.getDVModel().children.splice(index, 1);
        index = this.flutterView.getDVModel().children.indexOf(wrapper.getDvModel());
      }
    }

    this.removeOverlayRectsFromStorage();
    this.flutterView = null;
    for (let viewId of this.platformViews.keys()) {
      const platformView = this.platformViews.get(viewId);
      if (platformView != undefined) {
        platformView.onFlutterViewDetached();
      }
    }
  }

  public getRegistry(): PlatformViewRegistryImpl {
    return this.registry;
  }

  public owns(viewId: number): boolean {
    return this.platformViews.has(viewId);
  }

  public onDetachedFromNapi(): void {
    this.disposeAllViews();
  }

  public onPreEngineRestart(): void {
    this.disposeAllViews();
  }

  createForPlatformViewLayer(request: PlatformViewCreationRequest): void {
    if (this.flutterView == null) {
      throw new Error("Cannot create HCPP platform view before FlutterView is attached.");
    }
    const platformView = this.createPlatformView(request);
    Log.i(TAG, "create hybrid composition for platform view: " + request.viewId);

    const nodeController = new EmbeddingNodeController();
    nodeController.setRenderOption(platformView, /*surfaceId*/ "",
      NodeRenderType.RENDER_TYPE_DISPLAY, request.direction);

    this.viewInfos.set(request.viewId, new PlatformViewInfo(
      platformView, "", 0, 0, request.logicalTop, request.logicalLeft, request.direction));
    this.nodeControllers.set(request.viewId, nodeController);

    // 注入 ohosHcppViewId + touchDispatcher，让 DISPLAY 子树的 onTouch 把事件
    // 转发回本控制器，经 ArkTS 坐标转换后注入引擎 Dart 竞技场。
    platformView.ohosHcppViewId = request.viewId;
    platformView.touchDispatcher = (vid: number, ev: TouchEvent) => {
      this.dispatchTouchToEngine(vid, ev);
    };
    // 滚轮链路：DISPLAY 子树 onAxisEvent 转发至此，注入引擎 signal_kind=kScroll。
    platformView.axisDispatcher = (vid: number, ev: AxisEvent) => {
      this.dispatchAxisToEngine(vid, ev);
    };

    // 创建请求携带尺寸时引导布局，嵌入层经 onDisplayPlatformViewHybrid 驱动几何。
    const bootstrapWidth = request.logicalWidth > 0 ? request.logicalWidth : 0;
    const bootstrapHeight = request.logicalHeight > 0 ? request.logicalHeight : 0;
    const bootstrapLeft = request.logicalLeft;
    const bootstrapTop = request.logicalTop;

    const dvModel = createDVModelFromJson(new DVModelJson2("NodeContainer",
      [],
      {
        "width": bootstrapWidth,
        "height": bootstrapHeight,
        "nodeController": nodeController,
        "left": bootstrapLeft,
        "top": bootstrapTop,
        // HCPP 打标：buildNodeContainer 的 clip 仅对 HCPP wrapper 生效。
        // 无此标的纹理模式 wrapper 保持基础版本无 clip 行为。
        "hcpp": true,
        // [wrapper-touch-block] 恒 true：hitTestBehavior(Block) 截断触摸进原生；
        // 截住的触摸经 events 通道的 onTouch 注入引擎（Flutter 竞技场接手）。
        "touchBlock": true
      },
      {
        // [wrapper-touch-block] 触摸注入走 events 通道（dynamicView 以 getEvents
        // 直挂 onTouch，与既有 onClick 模式一致，避免 ESObject 函数类型 as 断言）；
        // viewId 经闭包捕获，不经 params 传递。
        "onTouch": (event: TouchEvent) => {
          this.dispatchTouchToEngine(request.viewId, event);
        }
      },
      undefined));
    const wrapper = new PlatformViewWrapper();
    wrapper.addDvModel(dvModel);
    this.viewWrappers.set(request.viewId, wrapper);
    this.flutterView.getDVModel().children.push(wrapper.getDvModel());
    platformView.onFlutterViewAttached(this.flutterView.getDVModel());
    this.setParam(wrapper.getDvModel().params, "opacity", 0);
  }

  dispose(viewId: number): void {
    const platformView = this.platformViews.get(viewId);
    if (platformView == null) {
      Log.w(TAG, "dispose: unknown HCPP view id=" + viewId);
      return;
    }

    if (this.focusViewId == viewId) {
      this.focusViewId = -1;
    }

    platformView.touchDispatcher = null;
    platformView.axisDispatcher = null;
    platformView.injectedTimestamps.clear();
    this.orphanedTouchViews.delete(viewId);
    this.platformViews.delete(viewId);
    this.viewInfos.delete(viewId);

    this.nodeControllers.get(viewId)?.disposeFrameNode();
    this.nodeControllers.delete(viewId);

    const wrapper = this.viewWrappers.get(viewId);
    if (wrapper != null && this.flutterView) {
      const index = this.flutterView.getDVModel().children.indexOf(wrapper.getDvModel());
      if (index > -1) {
        this.flutterView.getDVModel().children.splice(index, 1);
        platformView.onFlutterViewDetached();
      }
    }
    this.viewWrappers.delete(viewId);
    this.displayOffsets.delete(viewId);
    this.overscrollOffsets.delete(viewId);
    // 清 hover enter 残留，该 rect 的 Block 节点随 dispose清除
    this.hoverInjectedRects.delete(viewId);

    try {
      platformView.dispose();
    } catch (err) {
      Log.e(TAG, "dispose (HCPP) threw " + err);
    }
    Log.i(TAG, "dispose (HCPP) done id=" + viewId);
  }

  // Dart arena 仲裁赢家把事件回投 native。
  // 把竞技场判给平台视图的触摸经 postEvent → builderNode.postTouchEvent投递给 DISPLAY 节点。
  onTouch(touch: PlatformViewTouch): void {
    this.focusViewId = touch.viewId;
    const wrapper = this.viewWrappers.get(touch.viewId);
    if (wrapper == undefined) {
      Log.w(TAG, `ControllerHybrid.onTouch no wrapper id=${touch.viewId} (dropped)`);
      return;
    }
    const params = wrapper.getDvModel().getLayoutParams() as Record<string, Any>;
    // MASK 后比较：多指 POINTER_DOWN/UP(action=(idx<<8)|5|6) 不参与翻转，
    // down 语义 = "该视图仍持有至少一根手指"——DOWN 置位，UP/CANCEL 复位，
    // POINTER_*(另一指变化，还有指在)保持不变。
    const downBaseAction = touch.action & MOTION_EVENT_ACTION_MASK;
    if (downBaseAction === TouchEventType.ACTION_DOWN) {
      params['down'] = true;
    } else if (downBaseAction === TouchEventType.ACTION_UP ||
      downBaseAction === TouchEventType.ACTION_CANCEL) {
      params['down'] = false;
    }

    const nodeController = this.nodeControllers.get(touch.viewId);
    if (nodeController == undefined) {
      Log.w(TAG, `ControllerHybrid.onTouch no nodeController id=${touch.viewId} (skip post)`);
      return;
    }
    const touchEvent = this.platformViewTouchToTouchEvent(touch);
    if (touchEvent == null) {
      Log.w(TAG, `ControllerHybrid.onTouch touch convert failed id=${touch.viewId} action=${touch.action}`);
      return;
    }

    const platformView = this.platformViews.get(touch.viewId);
    if (platformView != null) {
      const now = Date.now();
      platformView.injectedTimestamps.forEach((addTime: number, ts: number) => {
        if (now - addTime > INJECTED_TIMESTAMP_TTL_MS) {
          platformView.injectedTimestamps.delete(ts);
        }
      });
      platformView.injectedTimestamps.set(touchEvent.timestamp, now);
    }

    nodeController.postEvent(touchEvent, true);
  }

  /**
   * 把回投的 PlatformViewTouch（16 字段序列化，raw 数组编码）
   * 还原为 postEvent 可投递的 CustomTouchEvent。
   */
  private platformViewTouchToTouchEvent(touch: PlatformViewTouch): CustomTouchEvent | null {
    const baseAction = touch.action & MOTION_EVENT_ACTION_MASK;
    // Dart 侧多指编码（OhosViewController.pointerAction，platform_views.dart:1082-1084）：
    // action = (pointerIdx << 8) | baseAction——高 8 位是变化指在
    // pointerProperties/pointerCoords 数组中的序号，POINTER_DOWN/POINTER_UP 用它定位变化指。
    const actionIndex = (touch.action >> 8) & 0xff;
    let type: TouchType;
    if (baseAction === TouchEventType.ACTION_DOWN ||
      baseAction === TouchEventType.ACTION_POINTER_DOWN) {
      type = TouchType.Down;
    } else if (baseAction === TouchEventType.ACTION_UP ||
      baseAction === TouchEventType.ACTION_POINTER_UP) {
      type = TouchType.Up;
    } else if (baseAction === TouchEventType.ACTION_MOVE) {
      type = TouchType.Move;
    } else if (baseAction === TouchEventType.ACTION_CANCEL) {
      type = TouchType.Cancel;
    } else {
      return null;
    }

    const propsArr = touch.rawPointerPropertiesList as Array<Array<number>>;
    const coordsArr = touch.rawPointerCoords as Array<Array<number>>;
    if (propsArr == undefined || coordsArr == undefined ||
      propsArr.length === 0 || coordsArr.length === 0) {
      return null;
    }

    const count = Math.min(propsArr.length, coordsArr.length);
    const dpr = display.getDefaultDisplaySync().densityPixels;

    // changedTouches 对齐 ArkUI 契约（只含本事件变化的触点）：
    //  - POINTER_DOWN / POINTER_UP：仅 actionIndex 指到的变化指；
    //  - DOWN / UP / CANCEL（单指语义）与 MOVE（Dart 批处理整批全量）：全部触点。
    // 越界防御：actionIndex 异常时退化为全部触点（旧行为）。
    const isIndexedPointerAction =
      baseAction === TouchEventType.ACTION_POINTER_DOWN ||
      baseAction === TouchEventType.ACTION_POINTER_UP;
    const changedIdxArr: number[] = [];
    if (isIndexedPointerAction && actionIndex >= 0 && actionIndex < count) {
      changedIdxArr.push(actionIndex);
    } else {
      for (let i = 0; i < count; i++) {
        changedIdxArr.push(i);
      }
    }

    // touches：本事件携带的全部触点（POINTER_UP 时抬起指仍在列表内，对齐
    // Android MotionEvent 批处理语义）。每指独立 type：变化指打事件 type，
    // 其余保持 Move——多指手势识别器靠 changedTouches 里 Down/Up 的配对跟踪
    // 手指；若全部触点统一事件 type，"第二指按下"会被看成"第一指又按下"、
    // "先抬一指"会被看成"全部抬起"，Pinch/Rotation 等多指手势提前终结。
    const objects: CustomTouchObject[] = [];
    for (let i = 0; i < count; i++) {
      const id = propsArr[i][0];          // rawPointerProperties[0] = id
      const coord = coordsArr[i];
      const x = coord[7] * dpr;           // local vp → local px
      const y = coord[8] * dpr;           // local vp → local px
      const objType = changedIdxArr.indexOf(i) >= 0 ? type : TouchType.Move;
      // displayX/windowX/screenX/x 统一填 local px：alignToLocalSpace 会把它们对齐到 local(=x)。
      objects.push(new CustomTouchObject(objType, id, x, y, x, y, x, y, x, y));
    }
    const changedObjects = changedIdxArr.map((i: number) => objects[i]);

    const ts = type === TouchType.Up ? touch.eventTime + DEDUP_TIMESTAMP_DELTA_US : touch.eventTime;
    return new CustomTouchEvent(
      type,
      objects,              // touches（全部活动触点）
      changedObjects,       // changedTouches（仅变化触点）
      ts,
      SourceType.TouchScreen, // source（对齐 TouchEventProcessor:317）
      1.0,                  // pressure
      0.0,                  // tiltX
      0.0,                  // tiltY
      0,                    // sourceTool（OH_NATIVEXCOMPONENT_TOOL_TYPE_UNKNOWN；ArkTS number→enum，对齐 TouchEventProcessor:321）
    );
  }

  setDirection(viewId: number, direction: Direction): void {
    const nodeController = this.nodeControllers.get(viewId);
    const info = this.viewInfos.get(viewId);
    if (nodeController != undefined && info != undefined) {
      info.direction = direction;
      nodeController.setRenderOption(info.platformView, "",
        NodeRenderType.RENDER_TYPE_DISPLAY, direction);
      nodeController.rebuild();
    }
  }

  clearFocus(viewId: number): void {
    focusControl.requestFocus("unfocus-xcomponent-node");
  }

  isSurfaceControlEnabled(): boolean {
    // HCPP 控制器仅在 hybrid composition 启用时存在。
    return true;
  }

  onDisplayPlatformViewHybrid(viewId: number, x: number, y: number, width: number,
    height: number, viewWidth: number, viewHeight: number): void {
    const wrapper = this.viewWrappers.get(viewId);
    if (wrapper == undefined) {
      Log.w(TAG, "onDisplayPlatformViewHybrid: unknown viewId=" + viewId);
      return;
    }
    const params: DVModelParameters | undefined = wrapper.getDvModel().params;
    if (!params) {
      Log.w(TAG, "onDisplayPlatformViewHybrid: no params for viewId=" + viewId);
      return;
    }
    // 按到达顺序记录本帧合成序（引擎按 composition_order 逐个调用本方法），
    // onEndFrameHybrid 据此重排 wrapper 层序（多 PV 上下关系跟随 Dart 重排）。
    if (this.frameDisplayOrder.length === 0 ||
      this.frameDisplayOrder[this.frameDisplayOrder.length - 1] !== viewId) {
      this.frameDisplayOrder.push(viewId);
    }
    // C++ OnDisplayPlatformView2 前四个参数(x/y/width/height)是 physical pixels(px)，
    // ArkUI layout 用 vp，需 px2vp 转换。
    const leftVp = px2vp(x);
    const topVp = px2vp(y);
    const widthVp = px2vp(width);
    const heightVp = px2vp(height);
    // [overscroll-follow] 叠加 Dart 下传的 overscroll 平移(vp)，让 PV 平移近似跟随
    // StretchingOverscrollIndicator 的 shader 拉伸(无该偏移时 PV 几何不含 stretch 分量)。
    // overscroll 负值=顶部挤压；stretch 视觉内容跟着手指走，故 PV top 减去该负值=向下偏移。
    const overscrollOffset = this.overscrollOffsets.get(viewId) ?? 0;
    this.setParam(params, "left", leftVp);
    this.setParam(params, "top", topVp - overscrollOffset);
    this.setParam(params, "width", widthVp);
    this.setParam(params, "height", heightVp);
    const prevOffset = this.displayOffsets.get(viewId);
    const viewX = prevOffset != undefined ? prevOffset.viewX : x;
    const viewY = prevOffset != undefined ? prevOffset.viewY : y;
    const offsetEntry: DisplayOffset = { x: x, y: y, w: width, h: height, viewW: viewWidth, viewH: viewHeight, viewX: viewX, viewY: viewY };
    this.displayOffsets.set(viewId, offsetEntry);
  }

  /**
   * 接收 native SliceViews 算出的单个 overlay rect（物理 px），
   * 转 vp push 到 pendingOverlayRects,flush 到 AppStorage 在 onEndFrameHybrid。
   */
  onDisplayOverlayHybrid(viewId: number, x: number, y: number, width: number,
    height: number): void {
    const rect: OverlayRect = {
      id: viewId,
      viewId: viewId,
      x: px2vp(x),
      y: px2vp(y),
      width: px2vp(width),
      height: px2vp(height),
      visible: width > 0 && height > 0,
    };
    this.pendingOverlayRects.push(rect);
  }

  onDisplayMutatorsHybrid(viewId: number, data: number[]): void {
    if (data.length < CLIP_RECTS_DATA_START) {
      Log.w(TAG, `onDisplayMutatorsHybrid viewId=${viewId} truncated len=${data.length}`);
      return;
    }
    const opacityRaw: number = data[OPACITY_INDEX];
    const clipRectsCount: number = data[CLIP_RECTS_COUNT_INDEX];
    // 4x4 列主序矩阵 m[]:m[0]=scaleX m[1]=shearY m[4]=shearX m[5]=scaleY。
    // data[MATRIX_START+i] = m[i],故 m[0]=data[1] m[1]=data[2] m[4]=data[5] m[5]=data[6]。
    const matrixScaleX: number = data[MATRIX_START + 0];
    const matrixShearY: number = data[MATRIX_START + 1];
    const matrixShearX: number = data[MATRIX_START + 4];
    const matrixScaleY: number = data[MATRIX_START + 5];
    // transform 纯平移判断:旋转/剪切分量 m[1]/m[4]≈0 且缩放 m[0]/m[5]≈dpr → M1 已覆盖,跳过。
    const dpr: number = display.getDefaultDisplaySync().densityPixels;
    const EPSILON_ZERO = 0.001;    // 旋转/剪切分量判零容差
    const EPSILON_DPR_EQ = 0.01;   // 缩放判等 dpr 容差
    const isPureTranslate: boolean =
      Math.abs(matrixShearY) < EPSILON_ZERO && Math.abs(matrixShearX) < EPSILON_ZERO &&
      Math.abs(matrixScaleX - dpr) < EPSILON_DPR_EQ && Math.abs(matrixScaleY - dpr) < EPSILON_DPR_EQ;

    // 旋转判定（定夺 viewX/viewY）：用 matrix 剪切分量——纯缩放/平移恒为 0，
    // 仅旋转/斜切非零。旧几何判据(width!==viewWidth)把缩放动画误判为旋转，
    // 导致 viewX/viewY 冻结首帧、视图移动/缩放时裁剪窗口错位。
    // 无旋转→viewX/viewY=x/y 每帧实时跟踪；有旋转→保持几何回调沿用的
    // 上一帧未旋转原点（对齐 §28 修复语义）。本回调同帧紧随
    // onDisplayPlatformViewHybrid 之后，此处定夺即本帧生效。
    const hasRotation: boolean =
      Math.abs(matrixShearY) >= EPSILON_ZERO || Math.abs(matrixShearX) >= EPSILON_ZERO;
    if (!hasRotation) {
      const geoOff = this.displayOffsets.get(viewId);
      if (geoOff != undefined) {
        geoOff.viewX = geoOff.x;
        geoOff.viewY = geoOff.y;
      }
    }

    const rrectsCountIdx: number = CLIP_RECTS_DATA_START + RECT_FIELD_COUNT * clipRectsCount;
    const rrectsCount: number = rrectsCountIdx < data.length ? data[rrectsCountIdx] : 0;
    const radiiStart: number = rrectsCountIdx + 1 + RECT_FIELD_COUNT * rrectsCount;
    const clipPathCountIdx: number = radiiStart + rrectsCount;
    const clipPathCount: number = clipPathCountIdx < data.length ? data[clipPathCountIdx] : 0;

    // opacity 应用到 wrapper DVModel(每帧设,保证 common_attrs .opacity() 恒有值)。
    let opacity: number = opacityRaw;
    if (!(opacity >= 0 && opacity <= 1)) {
      opacity = 1;
    }
    const wrapper = this.viewWrappers.get(viewId);
    if (wrapper != undefined) {
      const params: DVModelParameters | undefined = wrapper.getDvModel().params;
      if (params) {
        this.setParam(params, "opacity", opacity);

        let clipRectWidth: number = 0;
        let clipRectHeight: number = 0;
        let clipRectRadius: number = 0;
        if (rrectsCount > 0) {
          const boundsStart: number = rrectsCountIdx + 1;
          const radiiStart: number = boundsStart + RECT_FIELD_COUNT * rrectsCount;
          clipRectRadius = data[radiiStart];
          // clip 尺寸用节点自身 w/h,不用 rrect bounds。
          // rrect bounds 是 _card 含 border 的外框(344×200)>节点(342×198),
          // 用它裁节点会让右下圆角落在节点边界外→右下角不圆。改用节点尺寸,
          // 4 角圆角都对齐节点 4 角。节点 w/h 存的是 px（off.w 存 C++ 原始 width=px）。
          // 旋转时用 viewW/viewH（原始尺寸），因为节点 width/height 被设为原始尺寸。
          const off = this.displayOffsets.get(viewId);
          if (off != undefined && off.w > 0 && off.h > 0) {
            clipRectWidth = px2vp(off.viewW > 0 ? off.viewW : off.w);
            clipRectHeight = px2vp(off.viewH > 0 ? off.viewH : off.h);
          } else {
            // 首帧几何未到,fallback 用 rrect bounds(px, 来自 TransformBounds → 含 dpr)。
            clipRectWidth = px2vp(data[boundsStart + RECT_W_OFFSET]);
            clipRectHeight = px2vp(data[boundsStart + RECT_H_OFFSET]);
          }
        }
        // rrect radius 是 layer-tree points(=vp),未经 TransformBounds,dpr 未缩放→不用 px2vp。
        this.setParam(params, "rectWidth", clipRectWidth);
        this.setParam(params, "rectHeight", clipRectHeight);
        this.setParam(params, "rectRadius", clipRectRadius);

        // kClipPath 任意路径裁剪(三角形/多边形等):解析 C++ 下发的 verb+args 数值序列,
        // 重建 ArkUI Path commands(SVG)。坐标空间铁律(场景16 验证):commands 用 px,
        // ArkUI 内部 ÷dpr 渲染;pathWidth/Height(视口)用 vp。
        // 数据布局: clipPathCountIdx+1 起,每个 path = [4 bounds][cmdLen][cmdLen 个值]。
        if (clipPathCount > 0) {
          const off = this.displayOffsets.get(viewId);
          const nodeLeft = off != undefined ? off.x : 0;
          const nodeTop = off != undefined ? off.y : 0;
          // 居中偏移:旋转时 bounding box(finalBoundingRect)比原始 view 大,
          // 节点居中放置在 bbox 内。C++ 用 clip_path_root(无旋转)变换 path 坐标,
          // 坐标是相对 bbox 左上角的;需减去居中偏移转为相对节点原点的坐标。
          // 无旋转时 off.w==off.viewW → 偏移=0,不影响。
          const centerOffsetX = off != undefined ? (off.w - off.viewW) / 2 : 0;
          const centerOffsetY = off != undefined ? (off.h - off.viewH) / 2 : 0;
          let pathDataIdx = clipPathCountIdx + 1;
          const pathBoundsX = data[pathDataIdx++];
          const pathBoundsY = data[pathDataIdx++];
          const pathBoundsW = data[pathDataIdx++];
          const pathBoundsH = data[pathDataIdx++];
          const cmdLen = data[pathDataIdx++];
          // 解析 verb+args,转相对节点原点(px 空间减法),重建 SVG commands。
          let svg = '';
          let cmdIdx = 0;
          // 收集多边形顶点(局部 px)——按【轮廓(contour)】分组:每个 MOVE 开新轮廓,
          // 后续 LINE/曲线顶点归入当前轮廓,曲线经 flattenQuad/Cubic 展平为折线。
          // 单一扁平顶点数组会把多轮廓 path(addOval+addOval/镂空)首尾拼接成一个
          // 环,SH 裁剪时跨轮廓搭桥,重建出的多边形在轮廓间隙错误透出内容。
          // 展平后所有 path 统一为多边形近似,SH 可处理任意含曲线的 path(圆角矩形/椭圆等)。
          const contours: PolyVertex[][] = [];
          // svgRaw 保留原始(未裁)commands,曲线/无越界时直接用。
          let svgRaw = '';
          const ensureContour = (): PolyVertex[] => {
            if (contours.length === 0 || contours[contours.length - 1].length === 0) {
              contours.push([]);
            }
            return contours[contours.length - 1];
          };
          while (cmdIdx < cmdLen) {
            const verb = data[pathDataIdx + cmdIdx];
            cmdIdx++;
            // verb 之后的参数起点
            const argBase = pathDataIdx + cmdIdx;
            if (verb === PathVerb.MOVE) {
              const x = data[argBase] - nodeLeft - centerOffsetX;
              const y = data[argBase + 1] - nodeTop - centerOffsetY;
              cmdIdx += PATH_VERB_MOVE_ARGS;
              svgRaw += `M${x.toFixed(2)} ${y.toFixed(2)} `;
              // MOVE 开新轮廓（当前轮廓已有顶点时）,保证多轮廓 path 不被拼接。
              const current = ensureContour();
              if (current.length > 0) {
                contours.push([]);
              }
              const v: PolyVertex = { x: x, y: y };
              contours[contours.length - 1].push(v);
            } else if (verb === PathVerb.LINE) {
              const x = data[argBase] - nodeLeft - centerOffsetX;
              const y = data[argBase + 1] - nodeTop - centerOffsetY;
              cmdIdx += PATH_VERB_LINE_ARGS;
              svgRaw += `L${x.toFixed(2)} ${y.toFixed(2)} `;
              const v: PolyVertex = { x: x, y: y };
              ensureContour().push(v);
              // 画一段曲线：1 个控制点 + 1 个终点，共 4 个参数。用于椭圆弧、波浪线等
            } else if (verb === PathVerb.QUAD) {
              const cpx = data[argBase] - nodeLeft - centerOffsetX;
              const cpy = data[argBase + 1] - nodeTop - centerOffsetY;
              const x = data[argBase + 2] - nodeLeft - centerOffsetX;
              const y = data[argBase + 3] - nodeTop - centerOffsetY;
              cmdIdx += PATH_VERB_QUAD_ARGS;
              svgRaw += `Q${cpx.toFixed(2)} ${cpy.toFixed(2)} ${x.toFixed(2)} ${y.toFixed(2)} `;
              // 展平二次贝塞尔为折线顶点,让 SH 能裁含曲线的 path(如圆角矩形)。
              // 起点是当前轮廓最后一个顶点(上一条 verb 的终点)。
              const currentQ = ensureContour();
              if (currentQ.length > 0) {
                const qStart = currentQ[currentQ.length - 1];
                const qCp: PolyVertex = { x: cpx, y: cpy };
                const qEnd: PolyVertex = { x: x, y: y };
                const qFlat = flattenQuad(qStart, qCp, qEnd, FLATTEN_STEPS_PER_ARC);
                for (let qi = 0; qi < qFlat.length; qi++) {
                  currentQ.push(qFlat[qi]);
                }
              }
              // 2 个控制点 + 1 个终点，共 6 个参数（椭圆）
            } else if (verb === PathVerb.CUBIC) { // Cubic(cp1,cp2,x,y)
              const cp1x = data[argBase] - nodeLeft - centerOffsetX;
              const cp1y = data[argBase + 1] - nodeTop - centerOffsetY;
              const cp2x = data[argBase + 2] - nodeLeft - centerOffsetX;
              const cp2y = data[argBase + 3] - nodeTop - centerOffsetY;
              const x = data[argBase + 4] - nodeLeft - centerOffsetX;
              const y = data[argBase + 5] - nodeTop - centerOffsetY;
              cmdIdx += PATH_VERB_CUBIC_ARGS;
              svgRaw += `C${cp1x.toFixed(2)} ${cp1y.toFixed(2)} ${cp2x.toFixed(2)} ${cp2y.toFixed(2)} ${x.toFixed(2)} ${y.toFixed(2)} `;
              // 展平三次贝塞尔为折线顶点(椭圆/超椭圆等)。
              const currentC = ensureContour();
              if (currentC.length > 0) {
                const cStart = currentC[currentC.length - 1];
                const cCp1: PolyVertex = { x: cp1x, y: cp1y };
                const cCp2: PolyVertex = { x: cp2x, y: cp2y };
                const cEnd: PolyVertex = { x: x, y: y };
                const cFlat = flattenCubic(cStart, cCp1, cCp2, cEnd, FLATTEN_STEPS_PER_ARC);
                for (let ci = 0; ci < cFlat.length; ci++) {
                  currentC.push(cFlat[ci]);
                }
              }
            } else {
              // PathVerb.CLOSE 无参数;未知 verb 也走闭合分支兜底。轮廓闭合由
              // 重建命令时的 Z 隐式表达,这里不新开轮廓（连续 verb 仍属同一子路径）。
              svgRaw += 'Z ';
            }
          }

          // pathWidth/Height 是 ArkUI Path 视口(vp) = bounds 相对节点的尺寸(px→vp)。
          let relX = px2vp(pathBoundsX - nodeLeft - centerOffsetX);
          let relY = px2vp(pathBoundsY - nodeTop - centerOffsetY);
          let relW = px2vp(pathBoundsW);
          let relH = px2vp(pathBoundsH);

          // 裁剪:多边形(含展平后的曲线 path,按轮廓分组) + 有 viewport ClipRect。
          // 算 viewport ClipRect 交集,转局部 px，逐轮廓 SH 裁剪。
          // 裁后顶点重建 svg(每轮廓一条 M..L..Z) + 重算 pathWidth/Height(全轮廓 bbox)。
          // 无越界时 fallback 到 svgRaw(保留原始曲线命令,质量无损)。
          // 旋转时:轮廓在节点本地(未旋转)空间,viewport 在屏幕(旋转后)空间。
          // 需将轮廓正向旋转到屏幕空间做 SH,再将结果逆旋转回本地空间。
          let clipApplied = false;
          let clipHidden = false;
          const totalVertCount = contours.reduce((acc: number, c: PolyVertex[]): number => acc + c.length, 0);
          if (clipRectsCount > 0 && totalVertCount >= 3) {
            let vpLeft = -Infinity;
            let vpTop = -Infinity;
            let vpRight = Infinity;
            let vpBottom = Infinity;
            // 算 clipRect 交集 = viewport 可见矩形
            for (let i = 0; i < clipRectsCount; i++) {
              const idx = CLIP_RECTS_DATA_START + RECT_FIELD_COUNT * i;
              vpLeft = Math.max(vpLeft, data[idx]);
              vpTop = Math.max(vpTop, data[idx + 1]);
              vpRight = Math.min(vpRight, data[idx] + data[idx + 2]);
              vpBottom = Math.min(vpBottom, data[idx + 1] + data[idx + 3]);
            }
            // viewport 交集转"相对节点原点的局部 px"。
            const minX = vpLeft - nodeLeft - centerOffsetX;
            const minY = vpTop - nodeTop - centerOffsetY;
            const maxX = vpRight - nodeLeft - centerOffsetX;
            const maxY = vpBottom - nodeTop - centerOffsetY;

            // 旋转/缩放时:正向变换各轮廓到屏幕空间,SH 后逆变换回本地空间。
            // ArkUI .rotate/.scale 绕节点中心,节点中心 = (viewW/2, viewH/2) px。
            // clip path 定义在未变换本地空间（clip 在变换前生效）——正向必须
            // 同时应用缩放（漏乘会使裁剪区域被 ArkUI 再放大 scale 倍,裁不动）。
            let contoursToClip: PolyVertex[][] = contours;
            let needInverseRotate = false;
            let rotCos = 1;
            let rotSin = 0;
            let rotCx = 0;
            let rotCy = 0;
            // 缩放因子（dpr 归一化）——提升到块外,逆变换段要用。
            let sx = 1;
            let sy = 1;
            if (!isPureTranslate && off != undefined && off.viewW > 0) {
              const rm0 = data[MATRIX_START + 0] / dpr;
              const rm1 = data[MATRIX_START + 1] / dpr;
              const rm4 = data[MATRIX_START + 4] / dpr;
              const rm5 = data[MATRIX_START + 5] / dpr;
              const rsx = Math.sqrt(rm0 * rm0 + rm4 * rm4);
              const rsy = Math.sqrt(rm1 * rm1 + rm5 * rm5);
              if (rsx > 0.001 && rsy > 0.001) {
                const rotAngle = Math.atan2(rm1 / rsy, rm0 / rsx);
                rotCos = Math.cos(rotAngle);
                rotSin = Math.sin(rotAngle);
                rotCx = off.viewW / 2;
                rotCy = off.viewH / 2;
                sx = rsx;
                sy = rsy;
                // 正向变换: local → screen = c + R(θ)·S·(p−c)（逐轮廓,保持分组）
                contoursToClip = contours.map((c: PolyVertex[]): PolyVertex[] =>
                  c.map((v: PolyVertex): PolyVertex => ({
                    x: rotCx + (v.x - rotCx) * sx * rotCos - (v.y - rotCy) * sy * rotSin,
                    y: rotCy + (v.x - rotCx) * sx * rotSin + (v.y - rotCy) * sy * rotCos
                  })));
                needInverseRotate = true;
              }
            }

            // 仅当path有越界才裁,避免视口内白跑（bbox 取全部轮廓并集）。
            const flatToClip: PolyVertex[] = [];
            for (let ci = 0; ci < contoursToClip.length; ci++) {
              for (let vi = 0; vi < contoursToClip[ci].length; vi++) {
                flatToClip.push(contoursToClip[ci][vi]);
              }
            }
            const pb = polyBounds(flatToClip);
            const overflows = pb.minX < minX - CLIP_PATH_VIEWPORT_THRESHOLD_PX ||
              pb.minY < minY - CLIP_PATH_VIEWPORT_THRESHOLD_PX ||
              pb.maxX > maxX + CLIP_PATH_VIEWPORT_THRESHOLD_PX ||
              pb.maxY > maxY + CLIP_PATH_VIEWPORT_THRESHOLD_PX;
            if (overflows && maxX > minX && maxY > minY) {
              // 逐轮廓裁进视口矩形 → 每个轮廓独立得到"轮廓 ∩ 视口"顶点,
              // 轮廓间不搭桥（多轮廓 path 的镂空/双椭圆语义得以保留）。
              const clippedContours: PolyVertex[][] = [];
              for (let ci = 0; ci < contoursToClip.length; ci++) {
                const clipped = sutherlandHodgmanClip(contoursToClip[ci], minX, minY, maxX, maxY);
                if (clipped.length >= 3) {
                  clippedContours.push(clipped);
                }
              }
              if (clippedContours.length > 0) {
                // 逆变换回本地空间(screen → local) = c + S⁻¹·R(−θ)·(p'−c),
                // 仍逐轮廓。除以缩放与正向的乘缩放互逆。
                let finalContours: PolyVertex[][] = clippedContours;
                if (needInverseRotate) {
                  const invCos = rotCos;   // cos(-θ) = cos(θ)
                  const invSin = -rotSin;  // sin(-θ) = -sin(θ)
                  finalContours = clippedContours.map((c: PolyVertex[]): PolyVertex[] =>
                    c.map((v: PolyVertex): PolyVertex => {
                      const dx = v.x - rotCx;
                      const dy = v.y - rotCy;
                      return {
                        x: rotCx + (dx * invCos - dy * invSin) / sx,
                        y: rotCy + (dx * invSin + dy * invCos) / sy
                      };
                    }));
                }
                // 重建已是交集的绘制命令:每轮廓一条 Move + Lines + Close。
                let cSvg = '';
                for (let ci = 0; ci < finalContours.length; ci++) {
                  const fc = finalContours[ci];
                  cSvg += `M${fc[0].x.toFixed(2)} ${fc[0].y.toFixed(2)} `;
                  for (let vi = 1; vi < fc.length; vi++) {
                    cSvg += `L${fc[vi].x.toFixed(2)} ${fc[vi].y.toFixed(2)} `;
                  }
                  cSvg += 'Z ';
                }
                svg = cSvg;
                // pathWidth/Height 用裁后全轮廓 bbox(局部 px→vp),覆盖整个可见区域。
                const flatFinal: PolyVertex[] = [];
                for (let ci = 0; ci < finalContours.length; ci++) {
                  for (let vi = 0; vi < finalContours[ci].length; vi++) {
                    flatFinal.push(finalContours[ci][vi]);
                  }
                }
                const cb = polyBounds(flatFinal);
                relX = px2vp(cb.minX);
                relY = px2vp(cb.minY);
                relW = px2vp(cb.maxX - cb.minX);
                relH = px2vp(cb.maxY - cb.minY);
                clipApplied = true;
              } else {
                // 全部轮廓裁空:path完全在 viewport 外(SH 裁成空/退化点线),应隐藏成零面积。
                svg = 'M0 0 L0 0 Z ';
                relX = 0;
                relY = 0;
                relW = 0;
                relH = 0;
                clipApplied = true;
                clipHidden = true;
              }
            } else if (overflows) {
              // PV 越界但 viewport 交集为空(PV 完全在 viewport 外)→ 裁空保持隐藏,
              // 不回退原始 clipPath(否则全尺寸在标题栏区域闪现)。
              svg = 'M0 0 L0 0 Z ';
              relX = 0;
              relY = 0;
              relW = 0;
              relH = 0;
              clipApplied = true;
            }
          }

          if (!clipApplied) {
            svg = svgRaw;
          }
          // 视口需覆盖整个 path(bounds 相对原点的右下角),用 relX+relW / relY+relH。
          this.setParam(params, "pathCommands", svg.trim());
          this.setParam(params, "pathWidth", relX + relW);
          this.setParam(params, "pathHeight", relY + relH);
          // 清 Rect clip,让 buildNodeContainer 走 Path 分支。
          this.setParam(params, "rectWidth", 0);
          this.setParam(params, "rectHeight", 0);
          this.setParam(params, "rectRadius", 0);
        }

        // clipRect 偏移裁剪 —— 有 clipPath 时跳过(pathCommands 已由 clipPath 设定,
        // 此处会清 pathCommands 覆盖)。
        if (clipPathCount === 0) {
          // clipRect 偏移裁剪 —— 用 position 偏移 + width/height 收窄 + clip 实现偏移裁剪。
          // ArkUI 声明式 .clip(Rect{w,h}) 只从 (0,0) 起，不支持偏移起始点；
          // 采用三合一：节点 position 左上偏移 clipRectX/Y 使裁剪区域对齐原始位置，
          // width/height 收窄为裁剪区域尺寸，.clip() 从 (0,0) 起裁出收窄后的内容。
          // width/height 改变会触发 BuilderNode 子树重排（NodeContainer 约束耦合），
          let clipRectX: number = 0;
          let clipRectY: number = 0;
          let clipW: number = 0;
          let clipH: number = 0;
          let hasClipRectOffset: boolean = false;
          let clipIsEmpty: boolean = false;  // PV 完全移出视口（交集为空）→ 应零面积隐藏

          if (clipRectsCount > 0) {
            const off = this.displayOffsets.get(viewId);
            const srcCount = clipRectsCount;
            const srcBase = CLIP_RECTS_DATA_START;
            const nodeLeft = !isPureTranslate ? (off != undefined ? off.viewX : 0) : (off != undefined ? off.x : 0);
            const nodeTop = !isPureTranslate ? (off != undefined ? off.viewY : 0) : (off != undefined ? off.y : 0);
            const nodeW = !isPureTranslate ? (off != undefined ? off.viewW : 0) : (off != undefined ? off.w : 0);
            const nodeH = !isPureTranslate ? (off != undefined ? off.viewH : 0) : (off != undefined ? off.h : 0);
            // 计算所有 clipRect 的交集（统一 px 空间）
            // C++ data[] 中的 clipRect (x/y/w/h) 是 px
            // displayOffsets 存的 x/y/w/h 也是 px（C++ OnDisplayPlatformView2 前四个参数
            // 是 view_rect.GetX/Y/W/H = finalBoundingRect()，含 dpr 缩放）。
            // 两者同单位(px)，交集在 px 空间算，输出时 px2vp 转 vp 给 ArkUI。
            let interLeft: number = -Infinity;
            let interTop: number = -Infinity;
            let interRight: number = Infinity;
            let interBottom: number = Infinity;
            for (let i = 0; i < srcCount; i++) {
              const idx = srcBase + RECT_FIELD_COUNT * i;
              const rectX = data[idx];
              const rectY = data[idx + 1];
              const rectW = data[idx + 2];
              const rectH = data[idx + 3];
              interLeft = Math.max(interLeft, rectX);
              interTop = Math.max(interTop, rectY);
              interRight = Math.min(interRight, rectX + rectW);
              interBottom = Math.min(interBottom, rectY + rectH);
            }
            // 与节点矩形做交集
            if (nodeW > 0 && nodeH > 0) {
              if (!isPureTranslate) {
                // 非纯平移：实际显示形 = 变换后形状（放大/旋转，大于未缩放
                // viewW/viewH 矩形）。与未缩放矩形求交判空会在"显示形仍在
                // 视口、未缩放矩形已出"的窗口（缩放1.3 每边 ~18px）提前
                // clipIsEmpty → 零面积隐藏 → 提前消失露底。判空只看 clips
                // 交集自身；与实际显示形的求交由 applyRotationAware 的 SH
                // 后 <3 顶点分支自然处理。
                if (!(interRight > interLeft && interBottom > interTop)) {
                  clipIsEmpty = true;
                }
              } else {
                const nodeRight = nodeLeft + nodeW;
                const nodeBottom = nodeTop + nodeH;
                interLeft = Math.max(interLeft, nodeLeft);
                interTop = Math.max(interTop, nodeTop);
                interRight = Math.min(interRight, nodeRight);
                interBottom = Math.min(interBottom, nodeBottom);

                if (interRight > interLeft && interBottom > interTop) {
                // 转相对节点原点（px，clipRect 和 node 都是 px 空间，减法结果也是 px）
                clipRectX = interLeft - nodeLeft;
                clipRectY = interTop - nodeTop;
                clipW = interRight - interLeft;
                clipH = interBottom - interTop;
                // 需要裁剪的条件：有偏移（clipRectX/Y 超过阈值）或尺寸收窄（clipW<nodeW
                // 或 clipH<nodeH，如保留上半 clipRect 从(0,0)起但高度减半）。
                // 0.5px 是亚像素边界——小于半个物理像素的偏移肉眼不可见
                const CLIP_OFFSET_THRESHOLD_PX = 0.5;
                const clippedX = nodeW - clipW > CLIP_OFFSET_THRESHOLD_PX;
                const clippedY = nodeH - clipH > CLIP_OFFSET_THRESHOLD_PX;
                hasClipRectOffset = isPureTranslate &&
                  (clipRectX > CLIP_OFFSET_THRESHOLD_PX || clipRectY > CLIP_OFFSET_THRESHOLD_PX
                  || clippedX || clippedY);
              } else {
                // 交集为空：PV 完全在视口外 → 标记需零面积隐藏
                clipIsEmpty = true;
              }
              }
            }
          }

          if (hasClipRectOffset) {
            // 圆角矩形 + viewport 裁剪：RRect 展平为多边形,SH 裁视口交集。
            // 无此处理时 viewport clipRect 会用直线矩形覆盖 RRect 的圆角 → 方角。
            // 仅在 rrectsCount>0（kClipRRect 路径）且有圆角半径时触发。
            let rrectHandled = false;
            if (rrectsCount > 0 && clipRectRadius > 0) {
              const rrOff = this.displayOffsets.get(viewId);
              const rrNodeW = rrOff != undefined ? rrOff.w : 0;
              const rrNodeH = rrOff != undefined ? rrOff.h : 0;
              const rrRadiusPx = clipRectRadius * dpr; // vp → px
              if (rrNodeW > 0 && rrNodeH > 0 && rrRadiusPx > 0.5) {
                const rrVerts = rrectToPolyVerts(rrNodeW, rrNodeH, rrRadiusPx, FLATTEN_STEPS_PER_ARC);
                const rrClipped = sutherlandHodgmanClip(rrVerts,
                  clipRectX, clipRectY, clipRectX + clipW, clipRectY + clipH);
                if (rrClipped.length >= 3) {
                  let rrSvg = `M${rrClipped[0].x.toFixed(2)} ${rrClipped[0].y.toFixed(2)} `;
                  for (let ri = 1; ri < rrClipped.length; ri++) {
                    rrSvg += `L${rrClipped[ri].x.toFixed(2)} ${rrClipped[ri].y.toFixed(2)} `;
                  }
                  rrSvg += 'Z ';
                  this.setParam(params, "pathCommands", rrSvg.trim());
                  const rrb = polyBounds(rrClipped);
                  this.setParam(params, "pathWidth", px2vp(rrb.maxX));
                  this.setParam(params, "pathHeight", px2vp(rrb.maxY));
                  this.setParam(params, "rectWidth", 0);
                  this.setParam(params, "rectHeight", 0);
                  this.setParam(params, "rectRadius", 0);
                  rrectHandled = true;
                }
              }
            }
            if (!rrectHandled) {
            // clipRectX/Y/W/H 是交集结果(px)，需 px2vp 转 vp 给 ArkUI
            const clipXVp = px2vp(clipRectX);
            const clipYVp = px2vp(clipRectY);
            const clipWVp = px2vp(clipW);
            const clipHVp = px2vp(clipH);
            const hasOffset: boolean = clipRectX > 0.5 || clipRectY > 0.5;
            if (hasOffset) {
              // 带原点偏移：先绘后裁，改用 .clip(Path) 表达
              // 带偏移的矩形（ArkUI .clip(Rect) 只从 (0,0) 起，不支持偏移，故用 Path）。
              // left/top/width/height 保持完整尺寸 → 内容完整绘制（先绘制），
              // ArkUI Path 坐标空间：commands 按 px 解析，内部 ÷dpr 转
              // vp 渲染；而 Path 的 width/height(视口) 直接用 vp。故 commands 必须用 px
              // (clipRectX/Y/W/H)，pathWidth/Height 用 vp——若 commands 也用 vp 会被再
              // ÷dpr，裁剪区缩小 dpr 倍。
              const x2Px: number = clipRectX + clipW;
              const y2Px: number = clipRectY + clipH;
              this.setParam(params, "pathCommands",
                `M ${clipRectX.toFixed(2)} ${clipRectY.toFixed(2)} L ${x2Px.toFixed(2)} ${clipRectY.toFixed(2)} L ${x2Px.toFixed(2)} ${y2Px.toFixed(2)} L ${clipRectX.toFixed(2)} ${y2Px.toFixed(2)} Z`);
              // pathWidth/Height 是 Path 视口尺寸(vp)，= px2vp(右/下边界 px)。px2vp 线性，
              // 故 clipXVp+clipWVp == px2vp(clipRectX+clipW)。
              this.setParam(params, "pathWidth", clipXVp + clipWVp);
              this.setParam(params, "pathHeight", clipYVp + clipHVp);
              // rectWidth/rectHeight 清 0，让 buildNodeContainer 走 Path 分支
              this.setParam(params, "rectWidth", 0);
              this.setParam(params, "rectHeight", 0);
              this.setParam(params, "rectRadius", 0);
            } else {
              // 无偏移（从原点起，仅尺寸收窄，如场景16 裁掉下半）：
              // 不收窄 width/height —— 否则 BuilderNode 的 100% 内容会重排成收窄尺寸
              // （内容压缩而非裁剪）。改为保持完整尺寸（先绘制完整内容），
              // 仅靠 .clip(Rect{w,h}) 裁掉超界区域（后裁剪）。
              this.setParam(params, "rectWidth", clipWVp);
              this.setParam(params, "rectHeight", clipHVp);
              this.setParam(params, "rectRadius", 0);
              // 清 Path 参数：避免上一帧 offset>0 残留 pathCommands 继续走 Path 分支。
              this.setParam(params, "pathCommands", undefined);
              this.setParam(params, "pathWidth", 0);
              this.setParam(params, "pathHeight", 0);
            }
            } // end if (!rrectHandled)
          }
          // hasClipRectOffset=false 时不下发偏移参数，left/top/width/height 保持
          // onDisplayPlatformViewHybrid 设的原始值，rectWidth/rectHeight 走既有 rrects 逻辑。
          // 须清 Path 参数，避免上一帧 clipRect 残留 pathCommands。
          else {
            if (clipIsEmpty) {
              // PV 完全移出视口（clipRect ∩ 节点 = 空）→ 零面积 path 隐藏，
              // 避免清 clip 后 DynamicView fallback 到节点全尺寸导致 AppBar 区域闪现。
              this.setParam(params, "pathCommands", 'M0 0 L0 0 Z');
              this.setParam(params, "pathWidth", 1);
              this.setParam(params, "pathHeight", 1);
            } else if (!isPureTranslate && clipRectsCount > 0) {
              // [rotation-aware viewport clip] 缩放/旋转 PV 的视口裁剪。
              // hasClipRectOffset 的 isPureTranslate 门禁使非纯平移矩阵完全
              // 不裁剪，而 C++ 侧（external_view_embedder 的 per-view viewport
              // clip 循环）对任意矩阵都裁背景孔 → 两侧裁剪分歧：缩放/旋转 PV
              // 半滚出视口时 DISPLAY 层越视口盖相邻内容。此处用与 clipPath 分支
              // 相同的旋转感知 SH 数学（正向旋转→裁→逆旋转）裁节点自身多边形；
              // 纯平移路径不走此分支（保持既有 rect/path 行为）。
              this.applyRotationAwareViewportClip(params, viewId, data,
                clipRectsCount, clipRectRadius, dpr);
            } else {
              this.setParam(params, "pathCommands", undefined);
              this.setParam(params, "pathWidth", 0);
              this.setParam(params, "pathHeight", 0);
            }
          }
        }

        if (!isPureTranslate) {
          // transform: matrix data[1..16](= m[0..15],行主序,engine final_matrix)。
          // engine 的 matrix 是屏幕坐标(相对 Flutter view 原点),含 dpr(m0≈dpr)。
          //
          // 旋转时 onDisplayPlatformViewHybrid 传的 width/height 是 finalBoundingRect
          // （旋转后外接矩形，比原始尺寸大）。
          // 旋转时用原始尺寸(viewW/viewH = sizePoints × dpr)设节点，
          // 并调整 left/top 使节点中心与 finalBoundingRect 中心对齐，
          // 这样 .rotate() 以节点中心为 pivot 旋转时旋转中心正确。
          //
          // 缩放/旋转分量归一化：÷dpr 反 dpr 缩放（Android FlutterMutatorView.java
          // 用 preScale(1/dpr) 反缩放整个 matrix，ArkUI 无 preScale，故逐分量 ÷dpr）。
          // 从归一化后的旋转/缩放分量提取角度和缩放，用 .rotate() + .scale()
          // 分开设，走 RS 2D 渲染路径（PreRotate/PreScale 带 pivot），绕过
          // .transform(matrix4) → DecomposeTransform → quaternion → RS 3D 路径
          // 列主序: m[0]=cos*scaleX, m[1]=sin*scaleY, m[4]=-sin*scaleX, m[5]=cos*scaleY
          const m0 = data[MATRIX_START + 0] / dpr;   // cos*scaleX
          const m1 = data[MATRIX_START + 1] / dpr;   // sin*scaleY
          const m4 = data[MATRIX_START + 4] / dpr;   // -sin*scaleX
          const m5 = data[MATRIX_START + 5] / dpr;   // cos*scaleY
          const scaleX = Math.sqrt(m0 * m0 + m4 * m4);
          const scaleY = Math.sqrt(m1 * m1 + m5 * m5);
          const RAD_TO_DEG = 180 / Math.PI;
          const angleDeg = Math.atan2(m1 / scaleY, m0 / scaleX) * RAD_TO_DEG;
          this.setParam(params, "rotate", angleDeg);
          this.setParam(params, "scaleX", scaleX);
          this.setParam(params, "scaleY", scaleY);
          this.setParam(params, "matrix", undefined);
          // 旋转时：用原始尺寸设节点，调整 left/top 使中心对齐。
          // finalBoundingRect 中心 = 旋转中心 = 原始矩形中心，
          // 原始尺寸节点放在: left = bbox.x + (bbox.w - viewW)/2, top 同理。
          const off = this.displayOffsets.get(viewId);
          if (off != undefined && off.viewW > 0 && off.viewH > 0) {
            const viewWVp = px2vp(off.viewW);
            const viewHVp = px2vp(off.viewH);
            this.setParam(params, "width", viewWVp);
            this.setParam(params, "height", viewHVp);
            // left/top 已在 onDisplayPlatformViewHybrid 中设为 finalBoundingRect 位置(px)，
            // 需偏移使原始尺寸节点中心与外接矩形中心对齐——全部 px2vp 后在 vp 空间算。
            // 注意 off.x/off.y 是 C++ 原始几何（不含 overscroll 偏移）：几何回调
            // 在本回调之前已把 top 设为 topVp - overscrollOffset，此处若直接用
            // off.y 覆写会把该偏移丢掉（旋转帧 PV 不跟随挤压、模式切换瞬间跳变）。
            // 与 onDisplayPlatformViewHybrid 对齐：top 额外减去 Dart 下传的
            // overscroll 平移(vp)。
            const overscrollOffset = this.overscrollOffsets.get(viewId) ?? 0;
            const bboxWVp = px2vp(off.w);
            const bboxHVp = px2vp(off.h);
            const curLeft = px2vp(off.x);
            const curTop = px2vp(off.y);
            this.setParam(params, "left", curLeft + (bboxWVp - viewWVp) / 2);
            this.setParam(params, "top", curTop + (bboxHVp - viewHVp) / 2 - overscrollOffset);
          }
        } else {
          // 纯平移：平移由left/top 负责，清除旋转/缩放参数。
          this.setParam(params, "rotate", 0);
          this.setParam(params, "scaleX", 1);
          this.setParam(params, "scaleY", 1);
          this.setParam(params, "matrix", undefined);
        }
      }
    }
  }

  /**
   * 将 DISPLAY 子树的 ArkUI TouchEvent 转为 PointerData 并注入引擎。
   * 坐标转换: windowX/windowY(相对 Flutter 窗口的 vp) → 物理px(×dpr)，即
   * PointerData 期望的相对 Flutter view 的物理坐标。用窗口级坐标而非
   * offset(块位置)+ local(块内)叠加，规避块位置渲染延迟导致的 dpr 倍放大。
   */
  dispatchTouchToEngine(viewId: number, event: TouchEvent): void {
    if (this.flutterNapi == null) {
      return;
    }
    if (this.displayOffsets.get(viewId) == undefined) {
      // 首帧几何未到，view 尚未显示，丢弃。DOWN 丢弃后必须连带丢弃该 view 后续
      // MOVE/UP/CANCEL——无 DOWN 的残缺指针流会给 Dart 手势竞技场喂孤儿序列，
      // 直到下一个 DOWN 才重新放行（触摸完整性门）。
      if (event.type === TouchType.Down) {
        this.orphanedTouchViews.add(viewId);
      }
      return;
    }
    if (this.orphanedTouchViews.has(viewId)) {
      if (event.type === TouchType.Down) {
        this.orphanedTouchViews.delete(viewId);
      } else {
        return;
      }
    }
    const dpr = display.getDefaultDisplaySync().densityPixels;

    // ArkUI TouchType → PointerData::Change 枚举值(pointer_data.h)。
    let change = PointerChange.CANCEL;
    if (event.type === TouchType.Down) {
      change = PointerChange.DOWN;
    } else if (event.type === TouchType.Up) {
      change = PointerChange.UP;
    } else if (event.type === TouchType.Move) {
      change = PointerChange.MOVE;
    } else if (event.type === TouchType.Cancel) {
      change = PointerChange.CANCEL;
    } else {
      return;
    }

    // changedTouches: 当前帧变化的触摸点。每点一个 PointerData。
    // 用 windowX/windowY(相对 Flutter 窗口左上角的 vp)直接 ×dpr 得 Flutter view 物理坐标，
    // 即 PointerData 期望的坐标系。不用 offset(块位置)+ local(块内)叠加：块位置由
    // onDisplayPlatformViewHybrid 更新，相对触摸帧有渲染延迟，叠加会把手指位移放大 dpr 倍。
    const points = event.changedTouches;
    const touchData: Object[] = [];
    for (let i = 0; i < points.length; i++) {
      const t = points[i];
      const physicalX = t.windowX * dpr;
      const physicalY = t.windowY * dpr;
      const item: TouchDataItem = {
        change: change,
        device: (t.id << TOOL_TYPE_BITS) | PointerDeviceKind.TOUCH,
        embedder_id: (t.id << TOOL_TYPE_BITS) | PointerDeviceKind.TOUCH,
        physical_x: physicalX,
        physical_y: physicalY,
        time_stamp: Math.floor(event.timestamp / 1000), // ns → μs
        pressure: 1.0,
        size: 0.0,
        kind: PointerDeviceKind.TOUCH, // kTouch
        buttons: 0,
        scroll_delta_x: 0.0,
        scroll_delta_y: 0.0,
        signal_kind: PointerSignalKind.NONE, // kNone（触摸无信号）
      };
      touchData.push(item);
    }
    if (touchData.length > 0) {
      this.flutterNapi.dispatchTouchToEngine(touchData);
    }
  }

  // 把 ArkUI onAxisEvent 的 AxisEvent 注入引擎 PointerData。
  dispatchAxisToEngine(viewId: number, event: AxisEvent): void {
    if (this.flutterNapi == null) {
      return;
    }
    // 只注入 UPDATE（滚轮增量只在 UPDATE 时有值）。
    const AXIS_ACTION_UPDATE = 2;
    if (event.action !== AXIS_ACTION_UPDATE) {
      return;
    }

    const dpr = display.getDefaultDisplaySync().densityPixels;
    const scrollX = event.getHorizontalAxisValue();
    const scrollY = event.getVerticalAxisValue();

    // 滚轮增量为 0 则无意义，跳过。
    if (scrollX === 0 && scrollY === 0) {
      return;
    }

    const physicalX = event.windowX * dpr;
    const physicalY = event.windowY * dpr;

    const item: TouchDataItem = {
      change: PointerChange.HOVER, // kHover（滚轮时鼠标悬浮）
      device: (0 << TOOL_TYPE_BITS) | PointerDeviceKind.MOUSE,
      embedder_id: (0 << TOOL_TYPE_BITS) | PointerDeviceKind.MOUSE,
      physical_x: physicalX,
      physical_y: physicalY,
      time_stamp: Math.floor(event.timestamp / 1000), // ns → μs
      pressure: 1.0,
      size: 0.0,
      kind: PointerDeviceKind.MOUSE, // kMouse
      buttons: 0, // 悬浮无按键
      scroll_delta_x: scrollX * dpr, // 逻辑像素 → 物理像素
      scroll_delta_y: scrollY * dpr,
      signal_kind: PointerSignalKind.SCROLL, // kScroll
    };
    this.flutterNapi.dispatchTouchToEngine([item]);
  }

  // 把 ArkUI onHover 回调注入引擎 PointerData（hover 返投）。
  dispatchHoverToEngine(viewId: number, isHover: boolean, event: HoverEvent): void {
    if (this.flutterNapi == null) {
      return;
    }
    const dpr = display.getDefaultDisplaySync().densityPixels;
    const windowX = event.windowX ?? 0;
    const windowY = event.windowY ?? 0;
    const physicalX = windowX * dpr;
    const physicalY = windowY * dpr;

    // enter/exit 配对跟踪（按 rect）：见 hoverInjectedRects 声明处注释。
    // converter 的 kRemove 分支对 states_ 中不存在的 device 直接解引用
    // （断言/UB），故无任何活跃 enter 的 exit 必须拦下；跨 rect 切换时
    // （兄弟 rect 已 enter）exit 吞掉，由兄弟的 kHover 维持引擎悬停态。
    if (isHover) {
      this.hoverInjectedRects.add(viewId);
    } else {
      if (!this.hoverInjectedRects.has(viewId)) {
        // 本 rect 无配对 enter；若全局也无任何活跃 enter，则必须拦下
        // （防止 converter kRemove 踩未知 device），否则也拦（兄弟接管中）。
        return;
      }
      this.hoverInjectedRects.delete(viewId);
      if (this.hoverInjectedRects.size > 0) {
        // 指针移入相邻 rect：不产生 remove，兄弟 rect 的 kHover 已把引擎
        // 悬停态迁到新位置；注入 remove 会误杀其 MouseRegion。
        return;
      }
    }

    const item: TouchDataItem = {
      change: isHover ? PointerChange.HOVER : PointerChange.REMOVE,
      device: (0 << TOOL_TYPE_BITS) | PointerDeviceKind.MOUSE,
      embedder_id: (0 << TOOL_TYPE_BITS) | PointerDeviceKind.MOUSE,
      physical_x: physicalX,
      physical_y: physicalY,
      time_stamp: Math.floor(event.timestamp / 1000),
      pressure: 0.0, // 悬浮无压感
      size: 0.0,
      kind: PointerDeviceKind.MOUSE, // kMouse
      buttons: 0, // 悬浮无按键
      scroll_delta_x: 0.0,
      scroll_delta_y: 0.0,
      signal_kind: PointerSignalKind.NONE, // kNone（纯 hover，非滚轮信号）
    };
    this.flutterNapi.dispatchTouchToEngine([item]);
  }

  hidePlatformViewHybrid(viewId: number): void {
    const wrapper = this.viewWrappers.get(viewId);
    if (wrapper == undefined) {
      Log.d(TAG, "hidePlatformViewHybrid: unknown viewId=" + viewId + " (already disposed)");
      return;
    }
    Log.i(TAG, "hidePlatformViewHybrid id=" + viewId);
    const params: DVModelParameters | undefined = wrapper.getDvModel().params;
    if (!params) {
      return;
    }

    // 多管齐下隐藏 PV，缩短 ArkUI 声明式滞后的可见窗口
    // 恢复显示时 onDisplayMutatorsHybrid 每帧重设 opacity/pathCommands。
    this.setParam(params, "width", 0);
    this.setParam(params, "height", 0);
    this.setParam(params, "opacity", 0);
    this.setParam(params, "pathCommands", 'M0 0 L0 0 Z');
    this.setParam(params, "pathWidth", 1);
    this.setParam(params, "pathHeight", 1);
  }

  showOverlaySurfaceHybrid(): void {
    // overlay XComponent 永久透明（Color.Transparent）且 HitTestMode.None，
    // 故可见 ≡ 隐藏（视觉与输入皆然）。切换 .visibility() 会触发
    // OnSurfaceDestroyed/Created 抖动及伴随的 raster 与 destroy 竞争窗口
  }

  hideOverlaySurfaceHybrid(): void {
  }

  onBeginFrameHybrid(): void {
    // 帧开始时没有需要预热/清零的工作,为后续预留
  }

  onEndFrameHybrid(): void {
    // 帧结束：
    //  1) 依据本帧合成序重排 wrapper DVModel（多 PV 上下关系跟随 Dart 重排，
    //     等价 Android PlatformViewsController2 每帧 bringToFront）。
    //  2) flush 本帧累积的 overlay rect 列表到 AppStorage（本引擎的 slice）。
    //     Map<viewKey, rects> 读-改-写：多引擎各自只更新自己的 slice，
    //     FlutterPage 按 viewId 取自己的部分。每帧替换整个 Map（新实例），
    //     保证 @StorageLink 引用变化触发 ForEach 重新求值（首页/无遮挡帧写空数组）。
    this.applyCompositionOrder();
    const viewKey = this.flutterView?.getId();
    if (viewKey == undefined) {
      // attach 前 flutterView 未知，rects 无消费者，丢弃。
      this.pendingOverlayRects = [];
      return;
    }
    const oldMap = AppStorage.get<Map<string, OverlayRect[]>>(OVERLAY_RECT_MAP_KEY);
    const newMap: Map<string, OverlayRect[]> = new Map();
    if (oldMap != undefined) {
      for (const key of Array.from(oldMap.keys())) {
        const rects = oldMap.get(key);
        if (rects != undefined) {
          newMap.set(key, rects);
        }
      }
    }
    newMap.set(viewKey, this.pendingOverlayRects);
    AppStorage.setOrCreate<Map<string, OverlayRect[]>>(OVERLAY_RECT_MAP_KEY, newMap);
    this.pendingOverlayRects = [];
  }

  /**
   * 把本控制器各 wrapper 的 DVModel 在 FlutterView children 中的相对顺序，
   * 对齐到本帧引擎合成序（frameDisplayOrder，即 Dart 层当前的 PV 上下关系）。
   * 只重排【本控制器 wrapper 占据的位置集合】内的元素——纹理控制器 wrapper、
   * 其他兄弟节点的位置不受影响；顺序已一致时零改动（不触发无谓重渲染）。
   */
  private applyCompositionOrder(): void {
    if (this.frameDisplayOrder.length === 0) {
      return;
    }
    const order = this.frameDisplayOrder;
    this.frameDisplayOrder = [];
    const flutterView = this.flutterView;
    if (flutterView == null) {
      return;
    }
    const children = flutterView.getDVModel().children;
    // 本控制器 wrapper 模型 → 期望序（跳过当前不在树里的，如刚 dispose）。
    const desired: DVModel[] = [];
    for (let i = 0; i < order.length; i++) {
      const wrapper = this.viewWrappers.get(order[i]);
      if (wrapper != undefined) {
        desired.push(wrapper.getDvModel());
      }
    }
    if (desired.length < 2) {
      return; // 0/1 个 wrapper 无相对序可言。
    }
    // wrapper 当前占据的槽位（保持槽位集合不变，只换槽内顺序 → 其他节点不动）。
    const slots: number[] = [];
    for (let i = 0; i < children.length; i++) {
      if (desired.indexOf(children[i]) >= 0) {
        slots.push(i);
      }
    }
    if (slots.length !== desired.length) {
      return; // 树与本控制器状态不同步（attach/detach 过渡帧），不动。
    }
    let changed = false;
    for (let k = 0; k < slots.length; k++) {
      if (children[slots[k]] !== desired[k]) {
        changed = true;
        break;
      }
    }
    if (!changed) {
      return;
    }
    for (let k = 0; k < slots.length; k++) {
      children[slots[k]] = desired[k];
    }
  }

  /**
   * [rotation-aware viewport clip] 缩放/旋转 PV 的视口裁剪（kClipRect 通路）。
   *
   * 节点多边形（rrect 有圆角时带圆角）在节点本地（未旋转）空间构建，正向
   * 旋转到屏幕空间后对 viewport（各 kClipRect 交集，屏幕 px）做 SH 裁剪，
   * 再逆旋转回本地空间重建 pathCommands——与 onDisplayMutatorsHybrid 内
   * clipPath 分支的旋转感知数学一致（.clip 在 .rotate 之前生效，坐标系是
   * 旋转前的）。越界才裁；裁空 → 零面积隐藏；不越界 → 清 path 参数不裁。
   *
   * 坐标换算与 clipPath 分支同源：viewport（屏幕 px）转本地 = 减 off.x/off.y
   * （finalBoundingRect 原点）再减居中偏移（(off.w-off.viewW)/2）。
   */
  private applyRotationAwareViewportClip(params: DVModelParameters, viewId: number,
    data: number[], clipRectsCount: number, clipRectRadiusVp: number, dpr: number): void {
    const off = this.displayOffsets.get(viewId);
    if (off == undefined || off.viewW <= 0 || off.viewH <= 0) {
      return;
    }
    // viewport 交集（屏幕 px）。
    let vpLeft = -Infinity;
    let vpTop = -Infinity;
    let vpRight = Infinity;
    let vpBottom = Infinity;
    for (let i = 0; i < clipRectsCount; i++) {
      const idx = CLIP_RECTS_DATA_START + RECT_FIELD_COUNT * i;
      vpLeft = Math.max(vpLeft, data[idx]);
      vpTop = Math.max(vpTop, data[idx + 1]);
      vpRight = Math.min(vpRight, data[idx] + data[idx + 2]);
      vpBottom = Math.min(vpBottom, data[idx + 1] + data[idx + 3]);
    }
    const centerOffsetX = (off.w - off.viewW) / 2;
    const centerOffsetY = (off.h - off.viewH) / 2;
    // viewport → 节点本地（未旋转）空间。
    const minX = vpLeft - off.x - centerOffsetX;
    const minY = vpTop - off.y - centerOffsetY;
    const maxX = vpRight - off.x - centerOffsetX;
    const maxY = vpBottom - off.y - centerOffsetY;

    // 节点多边形：本地 px，(0,0) 起，viewW×viewH；rrect 半径(vp→px)，无 rrect 则直角。
    const radiusPx = Math.max(0, clipRectRadiusVp * dpr);
    const verts = rrectToPolyVerts(off.viewW, off.viewH, radiusPx, FLATTEN_STEPS_PER_ARC);

    // 旋转/缩放分量（与 clipPath 分支同式）：m 除 dpr 归一化。
    // 角度从归一化矩阵提取；缩放因子保留——clip path 定义在未变换本地
    // 空间（clip 在 .rotate/.scale 之前生效），正向变换必须同时应用缩放。
    const rm0 = data[MATRIX_START + 0] / dpr;
    const rm1 = data[MATRIX_START + 1] / dpr;
    const rm4 = data[MATRIX_START + 4] / dpr;
    const rm5 = data[MATRIX_START + 5] / dpr;
    const rsx = Math.sqrt(rm0 * rm0 + rm4 * rm4);
    const rsy = Math.sqrt(rm1 * rm1 + rm5 * rm5);
    let rotCos = 1;
    let rotSin = 0;
    const rotCx = off.viewW / 2;
    const rotCy = off.viewH / 2;
    let needInverseRotate = false;
    if (rsx > 0.001 && rsy > 0.001) {
      const rotAngle = Math.atan2(rm1 / rsy, rm0 / rsx);
      rotCos = Math.cos(rotAngle);
      rotSin = Math.sin(rotAngle);
      needInverseRotate = true;
    }
    // 正向变换 local → screen = c + R(θ)·S·(p−c)。纯缩放时 θ=0 退化为
    // 绕中心放大——正是漏乘导致"裁剪区域被 ArkUI 再放大 scale 倍"的修复点。
    const vertsToClip = needInverseRotate
      ? verts.map((v: PolyVertex): PolyVertex => ({
        x: rotCx + (v.x - rotCx) * rsx * rotCos - (v.y - rotCy) * rsy * rotSin,
        y: rotCy + (v.x - rotCx) * rsx * rotSin + (v.y - rotCy) * rsy * rotCos
      }))
      : verts;

    // 仅越界才裁。
    const pb = polyBounds(vertsToClip);
    const overflows = pb.minX < minX - CLIP_PATH_VIEWPORT_THRESHOLD_PX ||
      pb.minY < minY - CLIP_PATH_VIEWPORT_THRESHOLD_PX ||
      pb.maxX > maxX + CLIP_PATH_VIEWPORT_THRESHOLD_PX ||
      pb.maxY > maxY + CLIP_PATH_VIEWPORT_THRESHOLD_PX;
    if (!overflows) {
      this.setParam(params, "pathCommands", undefined);
      this.setParam(params, "pathWidth", 0);
      this.setParam(params, "pathHeight", 0);
      return;
    }
    if (!(maxX > minX && maxY > minY)) {
      // viewport 交集为空：PV 完全在视口外 → 零面积隐藏。
      this.setParam(params, "pathCommands", 'M0 0 L0 0 Z');
      this.setParam(params, "pathWidth", 1);
      this.setParam(params, "pathHeight", 1);
      return;
    }
    const clipped = sutherlandHodgmanClip(vertsToClip, minX, minY, maxX, maxY);
    if (clipped.length < 3) {
      this.setParam(params, "pathCommands", 'M0 0 L0 0 Z');
      this.setParam(params, "pathWidth", 1);
      this.setParam(params, "pathHeight", 1);
      return;
    }
    // 逆变换 screen → local = c + S⁻¹·R(−θ)·(p'−c)：除以缩放与正向乘缩放互逆。
    const finalVerts = needInverseRotate
      ? clipped.map((v: PolyVertex): PolyVertex => {
        const invCos = rotCos;   // cos(-θ) = cos(θ)
        const invSin = -rotSin;  // sin(-θ) = -sin(θ)
        const dx = v.x - rotCx;
        const dy = v.y - rotCy;
        return {
          x: rotCx + (dx * invCos - dy * invSin) / rsx,
          y: rotCy + (dx * invSin + dy * invCos) / rsy
        };
      })
      : clipped;
    let svg = `M${finalVerts[0].x.toFixed(2)} ${finalVerts[0].y.toFixed(2)} `;
    for (let i = 1; i < finalVerts.length; i++) {
      svg += `L${finalVerts[i].x.toFixed(2)} ${finalVerts[i].y.toFixed(2)} `;
    }
    svg += 'Z ';
    const cb = polyBounds(finalVerts);
    this.setParam(params, "pathCommands", svg.trim());
    this.setParam(params, "pathWidth", px2vp(cb.maxX));
    this.setParam(params, "pathHeight", px2vp(cb.maxY));
    // 走 Path 分支需清 Rect 裁剪参数。
    this.setParam(params, "rectWidth", 0);
    this.setParam(params, "rectHeight", 0);
    this.setParam(params, "rectRadius", 0);
  }

  private createPlatformView(request: PlatformViewCreationRequest): PlatformView {
    const factory: PlatformViewFactory = this.registry.getFactory(request.viewType);
    if (factory == null) {
      throw new Error("Trying to create an HCPP platform view of unregistered type: " + request.viewType);
    }
    let createParams: Any = null;
    if (request.params != null) {
      createParams = decodePlatformViewCreationParams(factory, request.params, request.viewId);
    }
    if (this.context == null) {
      throw new Error("PlatformViewsControllerHybrid#context is null.");
    }
    const platformView = factory.create(this.context, request.viewId, createParams);
    // 从平台视图实例取回它要渲染的 ArkUI UI 构建器(WrappedBuilder),取不到就抛错中止创建——因为后续挂载到
    // Flutter 树、交给 BuilderNode 渲染都依赖这个构建器,没有它视图无法显示
    const embeddedView: WrappedBuilder<[Params]> = platformView.getView();
    if (embeddedView == null) {
      throw new Error("PlatformView#getView() returned null (HCPP).");
    }
    this.platformViews.set(request.viewId, platformView);
    return platformView;
  }

  private setParam(params: DVModelParameters, key: string, element: Any): void {
    const record = params as Record<string, Any>;
    record[key] = element;
  }

  private disposeAllViews(): void {
    for (let viewId of Array.from(this.platformViews.keys())) {
      this.dispose(viewId);
    }
    this.hoverInjectedRects.clear();
    this.frameDisplayOrder = [];
    // 本引擎（或 isolate restart 后）不再持有 rects，清掉自己的 slice
    this.removeOverlayRectsFromStorage();
  }

  /** 把本 view 的 overlay rects slice 从 AppStorage map 中移除（读-改-写）。 */
  private removeOverlayRectsFromStorage(): void {
    const viewKey = this.flutterView?.getId();
    if (viewKey == undefined) {
      return;
    }
    const oldMap = AppStorage.get<Map<string, OverlayRect[]>>(OVERLAY_RECT_MAP_KEY);
    if (oldMap == undefined || !oldMap.has(viewKey)) {
      return;
    }
    const newMap: Map<string, OverlayRect[]> = new Map();
    for (const key of Array.from(oldMap.keys())) {
      if (key === viewKey) {
        continue;
      }
      const rects = oldMap.get(key);
      if (rects != undefined) {
        newMap.set(key, rects);
      }
    }
    AppStorage.setOrCreate<Map<string, OverlayRect[]>>(OVERLAY_RECT_MAP_KEY, newMap);
  }
}
