/*
 * Copyright (c) 2026 Huawei Device Co., Ltd. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE_HW file.
 */

import Any from '../common/Any';
import PlatformViewFactory from './PlatformViewFactory';
import { ByteBuffer } from '../../util/ByteBuffer';
import Log from '../../util/Log';

const TAG = "PlatformViewParamsUtil";

// 把 Uint8Array/ArrayBuffer/ByteBuffer 三种字节形态归一成 ArrayBuffer
// 调插件工厂自带的MessageCodec 把字节还原成 Dart 原始对象
function paramsToArrayBuffer(params: Any): ArrayBuffer | null {
  if (params == null) {
    return null;
  }
  if (params instanceof Uint8Array) {
    const uint8Params = params as Uint8Array;
    return uint8Params.buffer.slice(uint8Params.byteOffset, uint8Params.byteOffset + uint8Params.byteLength);
  }
  if (params instanceof ArrayBuffer) {
    return params as ArrayBuffer;
  }
  const byteBuffer = params as ByteBuffer;
  if (byteBuffer.byteLength > 0) {
    // 从 ByteBuffer 起始偏移 0 读取全部字节。
    const BYTEBUFFER_READ_OFFSET = 0;
    const bufferBytes = byteBuffer.getUint8Array(BYTEBUFFER_READ_OFFSET, byteBuffer.byteLength);
    return bufferBytes.buffer.slice(bufferBytes.byteOffset, bufferBytes.byteOffset + bufferBytes.byteLength);
  }
  return null;
}

/**
 * Decodes {@link PlatformViewCreationRequest.params} for factory.create().
 *
 * OHOS channel args arrive as {@code Uint8Array}; legacy paths may wrap a
 * {@link ByteBuffer}. Do not use {@link ByteBuffer#buffer} for reads — its
 * getter returns bytes written (write cursor), which is empty on decode paths.
 */
export function decodePlatformViewCreationParams(
  factory: PlatformViewFactory,
  params: Any,
  viewId: number
): Any {
  const message = paramsToArrayBuffer(params);
  if (message == null || message.byteLength === 0) {
    Log.w(TAG, "decode: empty params viewId=" + viewId);
    return null;
  }

  const decoded: Any = factory.getCreateArgsCodec().decodeMessage(message);
  return decoded;
}
