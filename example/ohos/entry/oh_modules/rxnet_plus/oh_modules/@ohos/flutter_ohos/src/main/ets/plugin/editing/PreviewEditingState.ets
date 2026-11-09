/*
 * Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE_KHZG file.
 */

import { Configuration } from '../../embedding/engine/systemchannels/TextInputChannel';
import { ListenableEditingState } from './ListenableEditingState';
import { TextEditingDelta } from './TextEditingDelta';
import ArrayList from '@ohos.util.ArrayList';
import { inputMethod } from '@kit.IMEKit';
import deviceInfo from '@ohos.deviceInfo';

/** Minimum SDK API version that supports preview text. */
const PREVIEW_TEXT_SUPPORT_API = 17;

/** Display state pushed to Flutter: text + selection + composing. */
export interface DisplayState {
  text: string;
  selectionStart: number;
  selectionEnd: number;
  composingStart: number;
  composingEnd: number;
}

/** Callback: push the full editing state to Flutter (text + selection + composing, full replacement). */
export type UpdateChannelState = (
  inputClientId: number,
  text: string,
  selectionStart: number,
  selectionEnd: number,
  composingStart: number,
  composingEnd: number
) => void;

/** Callback: push incremental editing state to Flutter (delta mode, only the changed parts). */
export type UpdateChannelWithDeltas = (
  inputClientId: number,
  batchDeltas: ArrayList<TextEditingDelta>
) => void;

/** Callback: notify the IMC of the current selection (changeSelection, so the IME knows the caret position). */
export type NotifySelectionToImc = (text: string, selectionStart: number, selectionEnd: number) => void;

/**
 * Whether the current device supports the preview-text feature.
 * Condition: SDK API version >= 17.
 */
export function isPreviewTextSupported(): boolean {
  return deviceInfo.sdkApiVersion >= PREVIEW_TEXT_SUPPORT_API;
}

/**
 * Preview-text editing state.
 *
 * Contains both instance methods (serving as the setPreviewText merge context)
 * and static methods (preview-text logic operating on ListenableEditingState).
 */
export class PreviewEditingState {

  // ==================== Instance fields (setPreviewText merge context) ====================

  /** Raw text sent by the IME via the setPreviewText callback. */
  public imeText: string = '';
  /** Previous preview text before this merge (snapshot of mPreviewText). */
  public prevPreview: string = '';
  /** Length of the previous preview text (cached prevPreview.length to avoid recomputation). */
  public prevLen: number = 0;
  /** Whether there was an active preview span before the merge (leftIdx !== rightIdx). */
  public hadActivePreview: boolean = false;
  /** Left boundary of the preview span before the merge (document coordinates, i.e. snapshot of leftIdx). */
  public oldLeft: number = 0;
  /** Text to be merged, computed by the pipeline (after splice or full-body processing). */
  public textForMerge: string = '';
  /** Whether the IME sent full-body mode {-1,-1} (range invalid). */
  public imeFullBodyMode: boolean = false;
  /** Final text written to mStringCache and mPreviewText. */
  public effectiveText: string = '';

  // ==================== Instance methods (pipeline) ====================

  /**
   * Pipeline step 1: splice-mode processing.
   *
   * When the IME sends setPreviewText(text, {a, b}) (a >= 0, b >= 0), it means
   * "replace the [a, b) range of the preview text with text".
   *
   * This method converts the document coordinates [a, b) to relative coordinates
   * inside the preview (by subtracting leftIdx), then splices the old preview text:
   *   textForMerge = prevPreview[0..a') + imeText + prevPreview[b'..]
   *
   * Example: mStringCache = "你好nihao", leftIdx=2, preview="nihao"
   *     IME sends setPreviewText("n", {3, 5}) → replace document [3,5)="ih" with "n"
   *     spliceStartInPreview = 3-2 = 1, spliceEndInPreview = 5-2 = 3
   *     textForMerge = "nihao"[0:1] + "n" + "nihao"[3:] = "n" + "n" + "ao" = "nnao"
   *
   * Precondition: an active preview exists (hadActivePreview && prevLen > 0) and the range is valid (>= 0).
   * If not satisfied, textForMerge is left unchanged.
   */
  initPreviewRangeSplice(range: inputMethod.Range): void {
    const rangeStart = range.start;
    const rangeEnd = range.end;
    if (!this.hadActivePreview || this.prevLen <= 0 || rangeStart < 0 || rangeEnd < 0) {
      return;
    }
    const oldLeft = this.oldLeft;
    // Document coordinates → relative coordinates inside the preview (conversion needed when leftIdx > 0)
    let spliceStart = (oldLeft > 0 && rangeStart >= oldLeft) ? rangeStart - oldLeft : rangeStart;
    let spliceEnd = (oldLeft > 0 && rangeEnd >= oldLeft) ? rangeEnd - oldLeft : rangeEnd;
    // clamp to [0, prevLen]
    spliceStart = Math.max(0, Math.min(spliceStart, this.prevLen));
    spliceEnd = Math.max(0, Math.min(spliceEnd, this.prevLen));
    // ensure start <= end
    if (spliceStart > spliceEnd) {
      const tmp = spliceStart;
      spliceStart = spliceEnd;
      spliceEnd = tmp;
    }
    // splice: replace [spliceStart, spliceEnd) with imeText
    this.textForMerge =
      this.prevPreview.substring(0, spliceStart) + this.imeText + this.prevPreview.substring(spliceEnd);
  }

  /**
   * Pipeline step 2: full-body mode processing.
   *
   * When the IME sends setPreviewText(text, {-1, -1}), it means "text is the new full preview text".
   * Use imeText directly as textForMerge, without any splice or correction.
   *
   * Precondition: full-body mode (imeFullBodyMode=true, i.e. range is {-1,-1}; splice is guaranteed not to have run).
   * If not satisfied, textForMerge is left unchanged.
   */
  applyLocalFullBodyPreviewMerge(): void {
    if (!this.imeFullBodyMode) {
      return;
    }
    this.textForMerge = this.imeText;
  }

  /**
   * Write the effectiveText computed by the pipeline into mStringCache and the preview span.
   *
   * Two paths:
   * - First preview-text activation (!hadActivePreview):
   *   Splice into mStringCache using the IMF range
   *   mStringCache = [0..range.start) + effectiveText + [range.end..]
   *   preview span = [range.start, range.start + effectiveText.length)
   *
   *   If the range is invalid, use the current caret position as the start.
   *
   * - Preview update (hadActivePreview):
   *   Replace the contents of span [leftIdx, rightIdx) with effectiveText
   *   mStringCache = [0..leftIdx) + effectiveText + suffixTail
   *   preview span = [leftIdx, leftIdx + effectiveText.length)
   *   suffixTail = text after the span (after the old rightIdx, or after leftIdx+prevLen)
   *
   * Also calls updatePreviewTextRange to update leftIdx/rightIdx.
   */
  applyImePreviewStringCacheAndRange(range: inputMethod.Range, editable: ListenableEditingState): void {
    const prevLen = this.prevLen;
    const effectiveText = this.effectiveText;
    const mStringCache = editable.getStringCache();
    const mStringCacheLen = mStringCache.length;
    if (!this.hadActivePreview) {
      // First preview-text activation: splice into mStringCache using the IMF range
      if (range.start >= 0 && range.end >= 0 && range.start <= range.end && range.start <= mStringCacheLen) {
        const safeEnd = Math.min(range.end, mStringCacheLen);
        editable.setStringCache(
          mStringCache.substring(0, range.start) + effectiveText + mStringCache.substring(safeEnd));
        editable.updatePreviewTextRange(range.start, range.start + effectiveText.length);
      } else {
        // Invalid range: use the current caret position as the start (replace selection if there is one)
        const start = Math.min(editable.getSelectionStart(), editable.getSelectionEnd());
        const end = Math.max(editable.getSelectionStart(), editable.getSelectionEnd());
        editable.setStringCache(mStringCache.substring(0, start) + effectiveText + mStringCache.substring(end));
        editable.updatePreviewTextRange(start, start + effectiveText.length);
      }
    } else {
      // Preview update: replace span [leftIdx, rightIdx) with effectiveText
      const leftIdx = editable.getLeftIdxOfPreviewTextRange();
      const rightIdx = editable.getRightIdxOfPreviewTextRange();
      let suffixTail: string;
      if (prevLen > 0) {
        // Text after the old preview
        const suffixStart = Math.min(leftIdx + prevLen, mStringCacheLen);
        suffixTail = mStringCache.substring(suffixStart);
      } else {
        // prevLen=0: use rightIdx as the suffix start
        suffixTail = mStringCache.substring(
          Math.min(rightIdx, mStringCacheLen),
        );
      }
      const leftCut = Math.min(Math.max(leftIdx, 0), mStringCacheLen);
      editable.setStringCache(mStringCache.substring(0, leftCut) + effectiveText + suffixTail)
      editable.updatePreviewTextRange(leftIdx, leftIdx + effectiveText.length);
    }
  }

  /**
   * Set the caret position based on the IMF range.
   *
   * Two paths:
   * - First preview-text activation (!hadActivePreview) or full-body mode (imeFullBodyMode, {-1,-1}):
   *   Caret at the end of the preview text (leftIdx + effectiveText.length)
   *
   * - Normal {a,b} mode (range is the replacement range):
   *   Caret = range.start + imeText.length
   *   (start of the replacement range + length of the replacement text = end of the replaced text)
   *
   * Example: mStringCache = "你好ni'hao", leftIdx=2
   *     IME sends setPreviewText("n", {3, 5}) → replace [3,5)="ih" with "n"
   *     caret = 3 + 1 = 4 → "你好n|'hao"
   */
  applyImePreviewCaretAfterMerge(range: inputMethod.Range, editable: ListenableEditingState): void {
    const leftIdx = editable.getLeftIdxOfPreviewTextRange();
    const newLen = this.effectiveText.length;

    // First preview-text activation or full-body mode ({-1,-1}) → caret at the end of the preview
    if (!this.hadActivePreview || this.imeFullBodyMode) {
      editable.setSelectionStart(leftIdx + newLen)
      editable.setSelectionEnd(leftIdx + newLen)
      return;
    }
    // range is the replacement range → caret = range.start + len(imeText) = end of the replaced text
    editable.setSelectionStart(range.start + this.imeText.length)
    editable.setSelectionEnd(range.start + this.imeText.length)
  }

  // ==================== Static methods (operating on ListenableEditingState) ====================

  /**
   * Compute the display state pushed to Flutter (text + selection + composing).
   * Updates the editable's composing cache.
   * Preview branch (staging active):
   * - text = mStringCache (contains the preview text, written by applyImePreviewStringCacheAndRange)
   * - composing = [leftIdx, rightIdx) (lets Flutter show the underline + bypass maxLength)
   * - selection = current caret position (clamped to [0, text.length])
   *
   * fallback (staging inactive):
   * - text = mStringCache (committed text)
   * - composing = -1 (no preview)
   */
  static composeDisplayState(editable: ListenableEditingState): DisplayState {
    const cache = editable.getStringCache();
    const len = cache.length;
    if (isPreviewTextSupported() && editable.isPreviewStagingActive()) {
      // Preview branch: staging active → text contains the preview, composing = [leftIdx, rightIdx)
      const selStart = Math.max(0, Math.min(editable.getSelectionStart(), len));
      const selEnd = Math.max(0, Math.min(editable.getSelectionEnd(), len));
      const leftIdx = editable.getLeftIdxOfPreviewTextRange();
      const rightIdx = editable.getRightIdxOfPreviewTextRange();
      const previewText = editable.getPreviewText();
      // composing active condition: preview text non-empty + valid span + within text bounds
      const composingActive = previewText.length > 0 &&
        leftIdx >= 0 &&
        rightIdx > leftIdx &&
        rightIdx <= len;
      const composingStart = composingActive ? leftIdx : -1;
      const composingEnd = composingActive ? rightIdx : -1;
      editable.setComposingStart(composingStart);
      editable.setComposingEnd(composingEnd);
      return {
        text: cache,
        selectionStart: selStart,
        selectionEnd: selEnd,
        composingStart: composingStart,
        composingEnd: composingEnd
      };
    }
    // fallback: staging inactive → text = mStringCache, composing = -1
    editable.setComposingStart(-1);
    editable.setComposingEnd(-1);
    return {
      text: cache,
      selectionStart: Math.max(0, Math.min(editable.getSelectionStart(), len)),
      selectionEnd: Math.max(0, Math.min(editable.getSelectionEnd(), len)),
      composingStart: -1,
      composingEnd: -1
    };
  }

  /**
   * Sync the editing state to Flutter and the IMC after a state change.
   *
   * Three paths:
   * 1. Preview path: staging active → composeDisplayState → updateChannel + notifyImc
   *    - Push text (with preview) + composing=[leftIdx,rightIdx) to Flutter
   *    - Push changeSelection to the IMC (so the IME knows the caret position)
   *
   * 2. Delta path: enableDeltaModel → updateChannelWithDeltas
   *    - Push incremental changes (delta mode, only the changed parts)
   *
   * 3. Normal path: directly push mStringCache + selection + composing
   *    - Push the full text + selection + composing to Flutter
   *    - Push changeSelection to the IMC
   *
   * Called from didChangeEditingState (listener callback),
   * i.e. triggered after handleInsertTextEvent/handleDeleteEvent/handleInsertPreviewTextEvent etc.
   * modify the state.
   */
  static syncEditingState(
    editable: ListenableEditingState,
    inputTargetId: number,
    configuration: Configuration | null,
    updateChannel: UpdateChannelState,
    updateChannelWithDeltas: UpdateChannelWithDeltas,
    notifySelectionToImc: NotifySelectionToImc,
  ): void {
    if (isPreviewTextSupported() && editable.isPreviewStagingActive()) {
      // Preview path: push text (with preview) + composing
      const display = PreviewEditingState.composeDisplayState(editable);
      updateChannel(inputTargetId, display.text, display.selectionStart, display.selectionEnd,
        display.composingStart, display.composingEnd);
      notifySelectionToImc(display.text, display.selectionStart, display.selectionEnd);
      editable.clearBatchDeltas();
      return;
    }

    const cache = editable.getStringCache();
    const selStart = editable.getSelectionStart();
    const selEnd = editable.getSelectionEnd();
    if (configuration != null && configuration.enableDeltaModel) {
      // Delta path: push incremental changes
      updateChannelWithDeltas(inputTargetId, editable.extractBatchTextEditingDeltas());
    } else {
      // Normal path: push full text + selection + composing
      updateChannel(inputTargetId, cache, selStart, selEnd,
        editable.getComposingStart(), editable.getComposingEnd());
    }
    notifySelectionToImc(cache, selStart, selEnd);
    editable.clearBatchDeltas();
  }
}
