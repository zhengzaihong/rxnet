/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*
* Based on TextInputChannel.java originally written by
* Copyright (C) 2013 The Flutter Authors.
*
*/

import JSONMethodCodec from '../../../plugin/common/JSONMethodCodec';
import MethodCall from '../../../plugin/common/MethodCall';
import MethodChannel, { MethodCallHandler, MethodResult } from '../../../plugin/common/MethodChannel';
import TextInputPlugin from '../../../plugin/editing/TextInputPlugin';
import Log from '../../../util/Log';
import DartExecutor from '../dart/DartExecutor';
import inputMethod from '@ohos.inputMethod';
import ArrayList from '@ohos.util.ArrayList';
import { TextEditingDelta, TextEditingDeltaJson } from '../../../plugin/editing/TextEditingDelta';
import Any from '../../../plugin/common/Any';
import { display, componentUtils } from '@kit.ArkUI'
import { window } from '@kit.ArkUI';
import { BusinessError, print } from '@kit.BasicServicesKit';
import { PointerDeviceKind } from '../../ohos/OhosTouchProcessor';

const TAG = "TextInputChannel";
/// Workaround for newline key type display issue; remove after API is updated
const NEWLINE_KEY_TYPE: number = 8;

/**
 * TextInputChannel is a platform channel between OpenHarmony and Flutter that is used to
 * communicate information about the user's text input.
 *
 * When the user presses an action button like "done" or "next", that action is sent from
 * OpenHarmony to Flutter through this TextInputChannel.
 *
 * When an input system in the Flutter app wants to show the keyboard, or hide it, or configure
 * editing state, etc. a message is sent from Flutter to OpenHarmony through this TextInputChannel.
 *
 * TextInputChannel comes with a default MethodChannel.MethodCallHandler that parses incoming
 * messages from Flutter. Implement TextInputMethodHandler and register it via
 * setTextInputMethodHandler() to respond to standard Flutter text input messages.
 */
export default class TextInputChannel {
  private static CHANNEL_NAME = "flutter/textinput";
  /** The MethodChannel for text input communication with Flutter. */
  public channel: MethodChannel;
  /** The text input method handler for processing text input requests, or null if not set. */
  textInputMethodHandler: TextInputMethodHandler | null = null;
  textInputCallback: TextInputCallback | null = null;

  /**
   * Constructs a new TextInputChannel instance.
   * @param dartExecutor - The DartExecutor for sending messages to Dart
   */
  constructor(dartExecutor: DartExecutor) {
    this.channel = new MethodChannel(dartExecutor, TextInputChannel.CHANNEL_NAME, JSONMethodCodec.INSTANCE);
  }

  /**
   * Sets the text input method handler.
   * @param textInputMethodHandler - The TextInputMethodHandler instance, or null to remove
   */
  setTextInputMethodHandler(textInputMethodHandler: TextInputMethodHandler | null): void {
    if (this.textInputCallback !== null) {
      this.textInputCallback.clearEditingStateDebounce();
    }
    this.textInputMethodHandler = textInputMethodHandler;
    this.textInputCallback = this.textInputMethodHandler == null
      ? null : new TextInputCallback(this.textInputMethodHandler);
    this.channel.setMethodCallHandler(this.textInputCallback);
  }

  /**
   * Requests the existing input state from Flutter.
   */
  requestExistingInputState(): void {
    this.channel.invokeMethod("TextInputClient.requestExistingInputState", null);
  }

  /**
   * Creates an editing state JSON object.
   * @param text - The text content
   * @param selectionStart - The start of the selection
   * @param selectionEnd - The end of the selection
   * @param composingStart - The start of the composing region
   * @param composingEnd - The end of the composing region
   * @returns The editing state object
   */
  createEditingStateJSON(text: string,
    selectionStart: number,
    selectionEnd: number,
    composingStart: number,
    composingEnd: number): EditingState {
    let state: EditingState = {
      text: text,
      selectionBase: selectionStart,
      selectionExtent: selectionEnd,
      composingBase: composingStart,
      composingExtent: composingEnd
    };
    return state;
  }

  /**
   * Creates an editing delta JSON object from a batch of deltas.
   * @param batchDeltas - Array list of text editing deltas
   * @returns The editing delta object
   */
  createEditingDeltaJSON(batchDeltas: ArrayList<TextEditingDelta>): EditingDelta {
    let deltas: TextEditingDeltaJson[] = [];
    batchDeltas.forEach((val, idx, array) => {
      deltas.push(val.toJSON());
    })

    let state: EditingDelta = {
      deltas: deltas,
    };
    return state;
  }

  /**
   * Instructs Flutter to update its text input editing state to reflect the given configuration.
   */
  updateEditingState(inputClientId: number,
    text: string,
    selectionStart: number,
    selectionEnd: number,
    composingStart: number,
    composingEnd: number): void {
    Log.d(TAG, "updateEditingState:"
      + "Text: " + text + " Selection start: " + selectionStart + " Selection end: "
      + selectionEnd + " Composing start: " + composingStart + " Composing end: " + composingEnd);
    const state: Any = this.createEditingStateJSON(text, selectionStart, selectionEnd, composingStart, composingEnd);
    this.channel.invokeMethod('TextInputClient.updateEditingState', [inputClientId, state]);
  }

  /**
   * Updates the editing state with tagged text.
   * @param inputClientId - The input client ID
   * @param editStates - Map of unique identifiers to text edit states
   */
  updateEditingStateWithTag(
    inputClientId: number, editStates: Map<string, TextEditState>): void {
    const json: Map<string, EditingState> = new Map();
    editStates.forEach((state: TextEditState, uniqueIdentifier: string) => {
      json.set(
        uniqueIdentifier,
        this.createEditingStateJSON(state.text, state.selectionStart, state.selectionEnd, -1, -1));
    });
    this.channel.invokeMethod('TextInputClient.updateEditingStateWithTag', [inputClientId, json]);
  }

  /**
   * Updates the editing state with deltas.
   * @param inputClientId - The input client ID
   * @param batchDeltas - Array list of text editing deltas
   */
  updateEditingStateWithDeltas(inputClientId: number, batchDeltas: ArrayList<TextEditingDelta>): void {
    Log.d(TAG, "updateEditingStateWithDeltas:" + "batchDeltas length: " + batchDeltas.length);
    if(batchDeltas.length > 0){
      const state: Any = this.createEditingDeltaJSON(batchDeltas);
      this.channel.invokeMethod('TextInputClient.updateEditingStateWithDeltas', [inputClientId, state]);
    }
  }

  /**
   * Sends a newline action to Flutter.
   * @param inputClientId - The input client ID
   */
  newline(inputClientId: number): void {
    Log.d(TAG, "Sending 'newline' message.");
    this.channel.invokeMethod("TextInputClient.performAction", [inputClientId, "TextInputAction.newline"]);
  }

  /**
   * Sends a go action to Flutter.
   * @param inputClientId - The input client ID
   */
  go(inputClientId: number): void {
    Log.d(TAG, "Sending 'go' message.");
    this.channel.invokeMethod("TextInputClient.performAction", [inputClientId, "TextInputAction.go"]);
  }

  /**
   * Sends a search action to Flutter.
   * @param inputClientId - The input client ID
   */
  search(inputClientId: number): void {
    Log.d(TAG, "Sending 'search' message.");
    this.channel.invokeMethod("TextInputClient.performAction", [inputClientId, "TextInputAction.search"]);
  }

  /**
   * Sends a send action to Flutter.
   * @param inputClientId - The input client ID
   */
  send(inputClientId: number): void {
    Log.d(TAG, "Sending 'send' message.");
    this.channel.invokeMethod("TextInputClient.performAction", [inputClientId, "TextInputAction.send"]);
  }

  /**
   * Sends a done action to Flutter.
   * @param inputClientId - The input client ID
   */
  done(inputClientId: number): void {
    Log.d(TAG, "Sending 'done' message.");
    this.channel.invokeMethod("TextInputClient.performAction", [inputClientId, "TextInputAction.done"]);
  }

  /**
   * Sends a next action to Flutter.
   * @param inputClientId - The input client ID
   */
  next(inputClientId: number): void {
    Log.d(TAG, "Sending 'next' message.");
    this.channel.invokeMethod("TextInputClient.performAction", [inputClientId, "TextInputAction.next"]);
  }

  /**
   * Sends a previous action to Flutter.
   * @param inputClientId - The input client ID
   */
  previous(inputClientId: number): void {
    Log.d(TAG, "Sending 'previous' message.");
    this.channel.invokeMethod("TextInputClient.performAction", [inputClientId, "TextInputAction.previous"]);
  }

  /**
   * Sends an unspecified action to Flutter.
   * @param inputClientId - The input client ID
   */
  unspecifiedAction(inputClientId: number): void {
    Log.d(TAG, "Sending 'unspecifiedAction' message.");
    this.channel.invokeMethod("TextInputClient.performAction", [inputClientId, "TextInputAction.unspecified"]);
  }

  /**
   * Sends a commit content action to Flutter.
   * @param inputClientId - The input client ID
   */
  commitContent(inputClientId: number): void {
    Log.d(TAG, "Sending 'commitContent' message.");
    this.channel.invokeMethod("TextInputClient.performAction", [inputClientId, "TextInputAction.commitContent"]);
  }

  /**
   * Notifies Flutter that the input connection has been closed.
   * @param inputClientId - The input client ID
   */
  onConnectionClosed(inputClientId: number): void {
    Log.d(TAG, "Sending 'onConnectionClosed' message.");
    this.channel.invokeMethod("TextInputClient.onConnectionClosed", [inputClientId]);
    this.textInputMethodHandler?.hide();
  }

  /**
   * Performs a private command.
   * @param inputClientId - The input client ID
   * @param action - The action string
   * @param data - The command data
   */
  performPrivateCommand(inputClientId: number, action: string, data: Any) {

  }

  /**
   * Sets the device pixel ratio.
   * @param devicePixelRatio - The device pixel ratio value
   */
  public setDevicePixelRatio(devicePixelRatio: number) {
    this.textInputCallback?.setDevicePixelRatio(devicePixelRatio);
  }

  /**
   * Gets the keyboard focus state.
   * @returns Whether the keyboard has focus
   */
  getKeyboardFocusState() {
    return this.textInputMethodHandler?.getKeyboardFocusState();
  }
  
}

/**
 * Editing state interface.
 */
interface EditingState {
  text: string;
  selectionBase: number;
  selectionExtent: number;
  composingBase: number;
  composingExtent: number;
}


/**
 * Editing delta interface.
 */
interface EditingDelta {
  deltas: Array<TextEditingDeltaJson>;
}


/**
 * Interface for handling text input method operations.
 */
export interface TextInputMethodHandler {
  show(): void;

  hide(): void;

  requestAutofill(): void;

  finishAutofillContext(shouldSave: boolean): void;

  setClient(textInputClientId: number, configuration: Configuration | null): void;

  updateConfig(configuration: Configuration | null): void;

  setPlatformViewClient(id: number, usesVirtualDisplay: boolean): void;

  setEditableSizeAndTransform(width: number, height: number, transform: number[]): void;

  setCursorSizeAndPosition(cursorInfo: inputMethod.CursorInfo): void;

  setAutoFillFieldRect(left: number, top: number, width: number, height: number): void;

  setAutoFillPageRect(left: number, top: number, width: number, height: number): void;

  setEditingState(editingState: TextEditState): void;

  clearClient(): void;

  handleChangeFocus(focusState: boolean): void;

  getKeyboardFocusState(): boolean;

}

/**
 * A text editing configuration.
 */
export class Configuration {
  /** Whether text should be obscured (e.g., for password fields). */
  obscureText: boolean = false;
  /** Whether autocorrect is enabled. */
  autocorrect: boolean = false;
  /** Autofill metadata for this field, or undefined when autofill is disabled. */
  autofill?: Autofill;
  /** Whether suggestions are enabled. */
  enableSuggestions: boolean = false;
  /** Whether IME personalized learning is enabled. */
  enableIMEPersonalizedLearning: boolean = false;
  /** Whether delta model is enabled for text editing. */
  enableDeltaModel: boolean = false;
  /** The input type for the text field, or null if not set. */
  inputType: InputType | null = null;
  /** The input action to perform when the user submits. */
  inputAction: Number = 0;
  /** The label for the action button. */
  actionLabel: String = "";
  /** MIME types for content commit operations. */
  contentCommitMimeTypes: String[] = [];
  /** The kind of pointer device being used. */
  deviceKind: PointerDeviceKind = PointerDeviceKind.UNKNOWN;
  /** Array of field configurations for autofill. */
  fields: Configuration[] = [];

  /**
   * Constructs a new Configuration instance.
   * @param obscureText - Whether text should be obscured
   * @param autocorrect - Whether autocorrect is enabled
   * @param enableSuggestions - Whether suggestions are enabled
   * @param enableIMEPersonalizedLearning - Whether IME personalized learning is enabled
   * @param enableDeltaModel - Whether delta model is enabled
   * @param inputType - The input type
   * @param inputAction - The input action
   * @param actionLabel - The action label
   * @param autofill - Autofill metadata, or undefined when disabled
   * @param contentListString - Content commit MIME types
   * @param deviceKind - The pointer device kind
   * @param fields - Array of field configurations
   */
  constructor(obscureText: boolean,
    autocorrect: boolean,
    enableSuggestions: boolean,
    enableIMEPersonalizedLearning: boolean,
    enableDeltaModel: boolean,
    inputType: InputType,
    inputAction: Number,
    actionLabel: String,
    autofill: Autofill | undefined,
    contentListString: [],
    deviceKind: PointerDeviceKind,
    fields: Configuration[]
  ) {
    this.obscureText = obscureText;
    this.autocorrect = autocorrect;
    this.enableSuggestions = enableSuggestions;
    this.enableIMEPersonalizedLearning = enableIMEPersonalizedLearning;
    this.enableDeltaModel = enableDeltaModel;
    this.inputType = inputType;
    this.inputAction = inputAction;
    this.actionLabel = actionLabel;
    this.autofill = autofill;
    this.contentCommitMimeTypes = contentListString;
    this.fields = fields
    this.deviceKind = deviceKind
  }

  private static inputActionFromTextInputAction(inputActionName: string): number {
    switch (inputActionName) {
      case "TextInputAction.previous":
        return inputMethod.EnterKeyType.PREVIOUS
      case "TextInputAction.unspecified":
        return inputMethod.EnterKeyType.UNSPECIFIED
      case "TextInputAction.none":
        return inputMethod.EnterKeyType.NONE
      case "TextInputAction.go":
        return inputMethod.EnterKeyType.GO
      case "TextInputAction.search":
        return inputMethod.EnterKeyType.SEARCH
      case "TextInputAction.send":
        return inputMethod.EnterKeyType.SEND
      case "TextInputAction.next":
        return inputMethod.EnterKeyType.NEXT
      case "TextInputAction.newline":
        return NEWLINE_KEY_TYPE
      case "TextInputAction.done":
        return inputMethod.EnterKeyType.DONE
      default:
      // Present default key if bad input type is given.
        return inputMethod.EnterKeyType.UNSPECIFIED
    }
  }

  /**
   * Creates a Configuration instance from JSON.
   * @param json - The JSON object
   * @returns A new Configuration instance
   * @throws {Error} if the JSON is missing required properties
   */
  static fromJson(json: Any) {
    const inputActionName: string = json.inputAction;
    if (!inputActionName) {
      throw new Error("Configuration JSON missing 'inputAction' property.");
    }

    let fields: Array<Any> = new Array();
    if (json.fields !== null && json.fields !== undefined) {
      fields = json.fields.map((field: Any): Any => Configuration.fromJson(field));
    }

    const inputAction: number = Configuration.inputActionFromTextInputAction(inputActionName);

    // Build list of content commit mime types from the data in the JSON list.
    const contentList: Array<Any> = [];
    if (json.contentCommitMimeTypes !== null && json.contentCommitMimeTypes !== undefined) {
      json.contentCommitMimeTypes.forEach((type: Any) => {
        contentList.push(type);
      });
    }
    return new Configuration(
      json.obscureText ?? false,
      json.autocorrect ?? true,
      json.enableSuggestions ?? false,
      json.enableIMEPersonalizedLearning ?? false,
      json.enableDeltaModel ?? false,
      InputType.fromJson(json.inputType),
      inputAction,
      json.actionLabel ?? null,
      Configuration.parseAutofill(json.autofill),
      contentList as Any,
      json.deviceKind ?? PointerDeviceKind.UNKNOWN,
      fields
    );
  }

  private static parseAutofill(json: Any): Autofill | undefined {
    if (json === null || json === undefined || json === false) {
      return undefined;
    }
    return Autofill.fromJson(json);
  }

  /**
   * Creates a Configuration instance from a map.
   * @param map - The map containing configuration data
   * @returns A new Configuration instance
   */
  static fromMap(map: Map<String, Any>) {
    let inputTypeSrc: Any = map.get('inputType');
    let type = TextInputType.get(inputTypeSrc.name) ?? inputMethod.TextInputType.TEXT;
    let inputType = new InputType(type, inputTypeSrc.decimal, inputTypeSrc.signed);
    let inputAction = Configuration.inputActionFromTextInputAction(map.get('inputAction'));

    let fields: Array<Any> = new Array();
    if (map.get('fields')) {
      fields = map.get('fields').map((field: Any): Any => Configuration.fromJson(field));
    }

    // Build list of content commit mime types from the data in the JSON list.
    const contentList: Array<Any> = [];
    if (map.get('contentCommitMimeTypes')) {
      map.get('contentCommitMimeTypes').forEach((type: Any) => {
        contentList.push(type);
      });
    }
    return new Configuration(
      map.get('obscureText') ?? false,
      map.get('autocorrect') ?? true,
      map.get('enableSuggestions') ?? false,
      map.get('enableIMEPersonalizedLearning') ?? false,
      map.get('enableDeltaModel') ?? false,
      inputType,
      inputAction,
      map.get('actionLabel') ?? null,
      Configuration.parseAutofill(map.get('autofill')),
      contentList as Any,
      map.get('deviceKind') ?? PointerDeviceKind.UNKNOWN,
      fields
    );
  }
}

/*
/// All possible enum values from flutter.
static const List<TextInputType> values = <TextInputType>[
  text, multiline, number, phone, datetime, emailAddress, url, visiblePassword, name, streetAddress, none,
];

// Corresponding string name for each of the [values].
static const List<String> _names = <String>[
  'text', 'multiline', 'number', 'phone', 'datetime', 'emailAddress', 'url', 'visiblePassword', 'name', 'address', 'none',
];

// Because TextInputType.name and TextInputType.streetAddress do not exist on ohos,
// these two types will be mapped to the default keyboard.
*/
const TextInputType: Map<String, inputMethod.TextInputType> = new Map<String, inputMethod.TextInputType>([
  ["TextInputType.text", inputMethod.TextInputType.TEXT],
  ["TextInputType.multiline", inputMethod.TextInputType.MULTILINE],
  ["TextInputType.number", inputMethod.TextInputType.NUMBER],
  ["TextInputType.phone", inputMethod.TextInputType.PHONE],
  ["TextInputType.datetime", inputMethod.TextInputType.DATETIME],
  ["TextInputType.emailAddress", inputMethod.TextInputType.EMAIL_ADDRESS],
  ["TextInputType.url", inputMethod.TextInputType.URL],
  ["TextInputType.visiblePassword", inputMethod.TextInputType.VISIBLE_PASSWORD],
  ["TextInputType.name", inputMethod.TextInputType.TEXT],
  ["TextInputType.address", inputMethod.TextInputType.TEXT],
  ["TextInputType.none", inputMethod.TextInputType.NONE],
]);

/**
 * A text input type.
 */
export class InputType {
  /** The text input type. */
  type: inputMethod.TextInputType;
  /** Whether the input accepts signed numbers. */
  isSigned: boolean;
  /** Whether the input accepts decimal numbers. */
  isDecimal: boolean;

  /**
   * Constructs a new InputType instance.
   * @param type - The text input type
   * @param isSigned - Whether the input is signed
   * @param isDecimal - Whether the input is decimal
   */
  constructor(type: inputMethod.TextInputType, isSigned: boolean, isDecimal: boolean) {
    this.type = type;
    this.isSigned = isSigned;
    this.isDecimal = isDecimal;
  }

  /**
   * Creates an InputType instance from JSON.
   * @param json - The JSON object
   * @returns A new InputType instance
   * @throws {Error} if the input type is not recognized
   */
  static fromJson(json: Any): InputType {
    if (TextInputType.has(json.name as string)) {
      return new InputType(TextInputType.get(json.name as string) as inputMethod.TextInputType,
        json.signed as boolean, json.decimal as boolean)
    }
    throw new Error("No such TextInputType: " + json.name as string);
  }
}

/**
 * State of an on-going text editing session..
 */
export class TextEditState {
  private static TAG = "TextEditState";
  /** The text content. */
  text: string;
  /** The start position of the text selection. */
  selectionStart: number;
  /** The end position of the text selection. */
  selectionEnd: number;
  /** The start position of the composing region. */
  composingStart: number;
  /** The end position of the composing region. */
  composingEnd: number;

  /**
   * Constructs a new TextEditState instance.
   * @param text - The text content
   * @param selectionStart - The start of the selection
   * @param selectionEnd - The end of the selection
   * @param composingStart - The start of the composing region
   * @param composingEnd - The end of the composing region
   * @throws {Error} if the selection or composing range is invalid
   */
  constructor(text: string,
    selectionStart: number,
    selectionEnd: number,
    composingStart: number,
    composingEnd: number) {
    if ((selectionStart != -1 || selectionEnd != -1)
      && (selectionStart < 0 || selectionEnd < 0)) {
      throw new Error("invalid selection: (" + selectionStart + ", " + selectionEnd + ")");
    }

    if ((composingStart != -1 || composingEnd != -1)
      && (composingStart < 0 || composingStart > composingEnd)) {
      throw new Error("invalid composing range: (" + composingStart + ", " + composingEnd + ")");
    }

    if (composingEnd > text.length) {
      throw new Error("invalid composing start: " + composingStart);
    }

    if (selectionStart > text.length) {
      throw new Error("invalid selection start: " + selectionStart);
    }

    if (selectionEnd > text.length) {
      throw new Error("invalid selection end: " + selectionEnd);
    }

    this.text = text;
    this.selectionStart = selectionStart;
    this.selectionEnd = selectionEnd;
    this.composingStart = composingStart;
    this.composingEnd = composingEnd;
  }

  /**
   * Checks if there is an active text selection.
   * @returns True if a selection exists, false otherwise
   */
  hasSelection(): boolean {
    // When selectionStart == -1, it's guaranteed that selectionEnd will also
    // be -1.
    return this.selectionStart >= 0;
  }

  /**
   * Checks if there is an active composing region.
   * @returns True if there is an active composing region, false otherwise
   */
  hasComposing(): boolean {
    return this.composingStart >= 0 && this.composingEnd > this.composingStart;
  }

  /**
   * Creates a TextEditState instance from JSON.
   * @param textEditState - The JSON object or map
   * @returns A new TextEditState instance
   */
  static fromJson(textEditState: Any): TextEditState {
    if (typeof textEditState.get === 'function') {
      return new TextEditState(
        textEditState.get('text') ?? '',
        textEditState.get('selectionBase') ?? -1,
        textEditState.get('selectionExtent') ?? -1,
        textEditState.get('composingBase') ?? -1,
        textEditState.get('composingExtent') ?? -1,
      );
    }
    return new TextEditState(
      textEditState.text ?? '',
      textEditState.selectionBase ?? -1,
      textEditState.selectionExtent ?? -1,
      textEditState.composingBase ?? -1,
      textEditState.composingExtent ?? -1,
    );
  }
}

/**
 * Method call handler for text input channel requests.
 */
class TextInputCallback implements MethodCallHandler {
  /** The text input method handler for processing text input requests. */
  textInputMethodHandler: TextInputMethodHandler;
  /** The cursor position rectangle. */
  cursorPosition: window.Rect = {
    left: 0,
    top: 0,
    width: 0,
    height: 0,
  }
  /** The device pixel ratio for converting logical to physical pixels. */
  devicePixelRatio = display.getDefaultDisplaySync()?.densityPixels as number;
  // 编辑框坐标，不是输入框
 	editInputPosition: ESObject = {
 	  left: 0,
 	  top: 0,
 	  right: 0,
 	  bottom: 0,
 	};
 	// XComponent组件的ID
 	viewId: string = '';
  private pendingEditingState: TextEditState | null = null;
  private setEditingStateDebounceTimer: number = -1;

  /**
   * Constructs a new TextInputCallback instance.
   * @param handler - The TextInputMethodHandler instance
   */
  constructor(handler: TextInputMethodHandler) {
    this.textInputMethodHandler = handler;
  }

 	setViewId(viewId: string) {
 	  this.viewId = viewId;
 	}

  /**
   * Clears the setEditingState debounce timer and pending state.
   * Called when the handler is being removed to prevent stale timer callbacks.
   */
  clearEditingStateDebounce(): void {
    if (this.setEditingStateDebounceTimer !== -1) {
      clearTimeout(this.setEditingStateDebounceTimer);
      this.setEditingStateDebounceTimer = -1;
      this.pendingEditingState = null;
    }
  }

  /**
   * Sets the device pixel ratio.
   * @param devicePixelRatio - The device pixel ratio value
   */
  setDevicePixelRatio(devicePixelRatio: number) {
    this.devicePixelRatio = devicePixelRatio;
  }

  /**
   * Sets the cursor position based on window and input positions.
   */
  setCursorPosition() {
    if (this.viewId.length === 0) {
      return;
    }
    try {
      const xComponentPosition = componentUtils.getRectangleById(this.viewId);
      const screenOffsetX = xComponentPosition.screenOffset.x;
      const screenOffsetY = xComponentPosition.screenOffset.y;
      const dpr = this.devicePixelRatio;
      const caretLeft = screenOffsetX + (this.cursorPosition.left + this.editInputPosition.left) * dpr;
      const caretTop = screenOffsetY + (this.cursorPosition.top + this.editInputPosition.top) * dpr;
      this.textInputMethodHandler.setCursorSizeAndPosition({
        left: caretLeft,
        top: caretTop,
        width: this.cursorPosition.width * dpr,
        height: this.cursorPosition.height * dpr,
      });
      const fieldLeft = screenOffsetX + this.editInputPosition.left * dpr;
      const fieldTop = screenOffsetY + this.editInputPosition.top * dpr;
      const fieldWidth = (this.editInputPosition.right - this.editInputPosition.left) * dpr;
      const fieldHeight = (this.editInputPosition.bottom - this.editInputPosition.top) * dpr;
      this.textInputMethodHandler.setAutoFillFieldRect(
        fieldLeft,
        fieldTop,
        fieldWidth,
        fieldHeight,
      );
      const pageWidth = xComponentPosition.size.width * dpr;
      const pageHeight = xComponentPosition.size.height * dpr;
      this.textInputMethodHandler.setAutoFillPageRect(
        screenOffsetX,
        screenOffsetY,
        pageWidth,
        pageHeight,
      );
    } catch(error) {
      Log.e(TAG, "Exception in setCursorPosition:" + JSON.stringify(error));
    }
  }


  /**
   * Handles method calls from Dart.
   * @param call - The method call from Dart
   * @param result - The result callback to send a response
   */
  onMethodCall(call: MethodCall, result: MethodResult) {
    if (this.textInputMethodHandler == null) {
      return;
    }
    let method: string = call.method;
    let args: Any = call.args;
    Log.d(TAG, "Received '" + method + "' message.");
    switch (method) {
      case "TextInput.show":
        this.textInputMethodHandler.show();
        Log.d(TAG, "textInputMethodHandler.show()");
        result.success(null);
        break;
      case "TextInput.hide":
        this.textInputMethodHandler.hide();
        result.success(null);
        break;
      case "TextInput.setClient":
        const textInputClientId: number = args[0] as number;
        const jsonConfiguration: string = args[1];
        const config: Configuration | null = Configuration.fromJson(jsonConfiguration);
        this.clearEditingStateDebounce();
        this.textInputMethodHandler.setClient(textInputClientId, config);
        result.success(null);
        break;
      case 'TextInput.updateConfig':
        const newConfig: Configuration | null = Configuration.fromMap(args as Map<String, Any>);
        this.textInputMethodHandler.updateConfig(newConfig);
        result.success(null);
        break;
      case "TextInput.setPlatformViewClient":
        try {
          const platformViewId = call.argument("platformViewId") as number;
          const usesVirtualDisplay = call.hasArgument("usesVirtualDisplay")
            ? call.argument("usesVirtualDisplay") as boolean
            : false;
          this.textInputMethodHandler.setPlatformViewClient(platformViewId, usesVirtualDisplay);
          result.success(null);
        } catch (err) {
          result.error("error", `${err}`, null);
        }
        break;
      case "TextInput.setEditingState":
        // Debounce: when dragging the caret quickly, Flutter sends setEditingState continuously,
        // the IME hasn't finished processing the previous one before the new caret position is sent,
        // and the IME replies with a stale preview state, causing preview candidates to flicker/disappear.
        // First call executes immediately: tapping outside the pinyin needs to commit quickly and can't wait 200ms.
        // Subsequent 200ms debounce: let the IME catch up and reduce the back-and-forth.
        const editingState = TextEditState.fromJson(args);
        if (this.setEditingStateDebounceTimer !== -1) {
          clearTimeout(this.setEditingStateDebounceTimer);
          this.pendingEditingState = editingState;
          this.setEditingStateDebounceTimer = setTimeout(() => {
            this.setEditingStateDebounceTimer = -1;
            if (this.pendingEditingState !== null && this.textInputMethodHandler != null) {
              this.textInputMethodHandler.setEditingState(this.pendingEditingState);
              this.pendingEditingState = null;
            }
          }, 200);
        } else {
          // Not debouncing: execute immediately + start the cooldown
          this.textInputMethodHandler.setEditingState(editingState);
          this.setEditingStateDebounceTimer = setTimeout(() => {
            this.setEditingStateDebounceTimer = -1;
          }, 200);
        }
        result.success(null);
        break;
      case "TextInput.setCaretRect":
        this.cursorPosition.top = args.get('y');
        this.cursorPosition.left = args.get('x');
        this.cursorPosition.width = args.get('width');
        this.cursorPosition.height = args.get('height');
        this.setCursorPosition();
        result.success(null);
        break;
      case "TextInput.setEditableSizeAndTransform":
        this.saveEditableSizeAndTransform(args.get('width'), args.get('height'), args.get('transform'));
        this.setCursorPosition();
        result.success(null);
        break;
      case "TextInput.clearClient":
        this.clearEditingStateDebounce();
        this.textInputMethodHandler.clearClient();
        result.success(null);
        break;
      case "TextInput.sendAppPrivateCommand":
      //TODO:
        result.notImplemented();
        break;
      case "TextInput.requestAutofill":
        this.textInputMethodHandler.requestAutofill();
        result.success(null);
        break;
      case "TextInput.finishAutofillContext":
        this.textInputMethodHandler.finishAutofillContext(args as boolean);
        result.success(null);
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  /**
   * Saves the editable size and transform, computing the input position bounding box.
   * @param width - The editable width
   * @param height - The editable height
   * @param transform - The 4x4 transform matrix
   */
  saveEditableSizeAndTransform(width: number, height: number, transform: Array<number>) {
    const matrix: Array<number> = transform;
 	 
    const minMax: Array<number>  = []; // minX, maxX, minY, maxY.
    const isAffine = matrix[3] == 0 && matrix[7] == 0 && matrix[15] == 1;
    minMax[0] = minMax[1] = matrix[12] / matrix[15]; // minX and maxX.
    minMax[2] = minMax[3] = matrix[13] / matrix[15]; // minY and maxY.
 	 
    const temArr: Array<ESObject> = [{x: width, y: 0}, {x:width, y:height}, {x: width, y:height}]

    for (let i = 0 ; i < temArr.length ; i++) {
      const w = isAffine ? 1 : 1 / (matrix[3] * temArr[i].x + matrix[7] * temArr[i].y + matrix[15]);
      const tx = (matrix[0] * temArr[i].x + matrix[4] * temArr[i].y + matrix[12]) * w;
      const ty = (matrix[1] * temArr[i].x + matrix[5] * temArr[i].y + matrix[13]) * w;

      if (tx < minMax[0]) {
        minMax[0] = tx;
      } else if (tx > minMax[1]) {
        minMax[1] = tx;
      }

      if (ty < minMax[2]) {
        minMax[2] = ty;
      } else if (ty > minMax[3]) {
        minMax[3] = ty;
      }
    }

    this.editInputPosition = {
      left: minMax[0],
      top: minMax[2],
      right: minMax[1],
      bottom: minMax[3]
    }
  }
}

/**
 * Autofill metadata for text input fields.
 */
class Autofill {
  public readonly uniqueIdentifier: string;
  public readonly hints: string[];
  public readonly editState: TextEditState;
  public readonly hintText: string | null;

  /**
   * Creates an Autofill instance from JSON.
   * @param json - The JSON object
   * @returns A new Autofill instance
   * @throws {Error} if the uniqueIdentifier or editingValue property is missing
   */
  static fromJson(json: Any): Autofill {
    const uniqueIdentifier: string = json.uniqueIdentifier;
    if (!uniqueIdentifier) {
      throw new Error("Autofill JSON missing 'uniqueIdentifier' property.");
    }
    let autofillHints: string[] = [];
    if (json.hints !== null && json.hints !== undefined) {
      autofillHints = json.hints.map((hint: Any): string =>
        Autofill.translateAutofillHint(String(hint)),
      );
    }
    const hintText: string | null =
      json.hintText === null || json.hintText === undefined
        ? null
        : String(json.hintText);
    const editingStateJson: Any = (json as Any).editingValue;
    if (editingStateJson === null || editingStateJson === undefined) {
      throw new Error("Autofill JSON missing 'editingValue' property.");
    }
    return new Autofill(
      uniqueIdentifier,
      autofillHints,
      hintText,
      TextEditState.fromJson(editingStateJson),
    );
  }

  /**
   * Translates a Flutter autofill hint string to an OpenHarmony autofill hint string.
   * @param hint - The Flutter autofill hint
   * @returns The corresponding OpenHarmony autofill hint, or the original hint if no mapping exists
   */
  private static translateAutofillHint(hint: string): string {
    switch (hint) {
      case "addressCity":
        return "addressLocality";
      case "addressState":
        return "addressRegion";
      case "birthday":
        return "birthDateFull";
      case "birthdayDay":
        return "birthDateDay";
      case "birthdayMonth":
        return "birthDateMonth";
      case "birthdayYear":
        return "birthDateYear";
      case "countryName":
        return "addressCountry";
      case "creditCardExpirationDate":
        return "creditCardExpirationDate";
      case "creditCardExpirationDay":
        return "creditCardExpirationDay";
      case "creditCardExpirationMonth":
        return "creditCardExpirationMonth";
      case "creditCardExpirationYear":
        return "creditCardExpirationYear";
      case "creditCardNumber":
        return "creditCardNumber";
      case "creditCardSecurityCode":
        return "creditCardSecurityCode";
      case "email":
        return "emailAddress";
      case "familyName":
        return "personFamilyName";
      case "fullStreetAddress":
        return "streetAddress";
      case "gender":
        return "gender";
      case "givenName":
        return "personGivenName";
      case "middleInitial":
        return "personMiddleInitial";
      case "middleName":
        return "personMiddleName";
      case "name":
        return "personName";
      case "namePrefix":
        return "personNamePrefix";
      case "nameSuffix":
        return "personNameSuffix";
      case "newPassword":
        return "newPassword";
      case "newUsername":
        return "newUsername";
      case "oneTimeCode":
        return "smsOTPCode";
      case "password":
        return "password";
      case "postalAddress":
        return "postalAddress";
      case "postalAddressExtended":
        return "extendedAddress";
      case "postalAddressExtendedPostalCode":
        return "extendedPostalCode";
      case "postalCode":
        return "postalCode";
      case "telephoneNumber":
        return "phoneNumber";
      case "telephoneNumberCountryCode":
        return "phoneCountryCode";
      case "telephoneNumberDevice":
        return "phoneNumberDevice";
      case "telephoneNumberNational":
        return "phoneNational";
      case "username":
        return "username";
      default:
        return hint;
    }
  }

  /**
   * Constructs a new Autofill instance.
   * @param uniqueIdentifier - The unique identifier for this autofill field
   * @param hints - Array of autofill hint strings
   * @param hintText - The hint text, or null if not set
   * @param editingState - The text editing state for this field
   */
  constructor(
    uniqueIdentifier: string,
    hints: string[],
    hintText: string | null,
    editingState: TextEditState,
  ) {
    this.uniqueIdentifier = uniqueIdentifier;
    this.hints = hints;
    this.hintText = hintText;
    this.editState = editingState;
  }
}

export { Autofill };
