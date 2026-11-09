/*
 * Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE_KHZG file.
 */

import { autoFillManager, bundleManager } from '@kit.AbilityKit';
import Log from '../../util/Log';
import { Autofill, Configuration } from '../../embedding/engine/systemchannels/TextInputChannel';
import deviceInfo from '@ohos.deviceInfo';
import common from '@ohos.app.ability.common';

const TAG = 'OhosAutoFillHelper';
/** Minimum API level required by autoFillManager APIs. Exported so callers can short-circuit. */
export const AUTOFILL_SUPPORT_API = 26;

/**
 * Default host ArkUI page path (main_pages.json), not a Flutter route.
 * Module-level: sufficient when the app has a single FlutterAbility; multi-Ability apps
 * should call setHostInfo from each Ability's onCreate (last writer wins).
 */
let hostPageUrl: string = 'pages/Index';
let hostModuleName: string = 'entry';
let hostAbilityName: string = 'EntryAbility';
/** AutoFillTriggerType.AUTO_REQUEST; literal for API levels without kit export. */
const AUTOFILL_TRIGGER_AUTO_REQUEST = 0;

const AUTOFILL_TYPE_UNSPECIFIED = 0;
const AUTOFILL_TYPE_PASSWORD = 1;
const AUTOFILL_TYPE_USER_NAME = 2;
const AUTOFILL_TYPE_NEW_PASSWORD = 3;
const AUTOFILL_TYPE_FULL_STREET_ADDRESS = 4;
const AUTOFILL_TYPE_HOUSE_NUMBER = 5;
const AUTOFILL_TYPE_DISTRICT_ADDRESS = 6;
const AUTOFILL_TYPE_CITY_ADDRESS = 7;
const AUTOFILL_TYPE_PROVINCE_ADDRESS = 8;
const AUTOFILL_TYPE_COUNTRY_ADDRESS = 9;
const AUTOFILL_TYPE_PERSON_FULL_NAME = 10;
const AUTOFILL_TYPE_PERSON_LAST_NAME = 11;
const AUTOFILL_TYPE_PERSON_FIRST_NAME = 12;
const AUTOFILL_TYPE_PHONE_NUMBER = 13;
const AUTOFILL_TYPE_PHONE_COUNTRY_CODE = 14;
const AUTOFILL_TYPE_FULL_PHONE_NUMBER = 15;
const AUTOFILL_TYPE_EMAIL_ADDRESS = 16;
const AUTOFILL_TYPE_BANK_CARD_NUMBER = 17;
const AUTOFILL_TYPE_ID_CARD_NUMBER = 18;
const AUTOFILL_TYPE_PRECISE_TIME = 19;
const AUTOFILL_TYPE_HOUR_AND_MINUTE = 20;
const AUTOFILL_TYPE_DATE = 21;
const AUTOFILL_TYPE_MONTH = 22;
const AUTOFILL_TYPE_YEAR = 23;
const AUTOFILL_TYPE_NICKNAME = 24;

/** Screen-space rectangle for an autofill field. */
export interface AutoFillFieldRect {
  left: number;
  top: number;
  width: number;
  height: number;
}

/** Host application metadata used to build ViewData. */
export interface AutoFillHostInfo {
  bundleName: string;
  moduleName: string;
  abilityName: string;
  pageUrl: string;
}

/** Mirrors OHOS AbilityBase::Rect used in ViewData. */
export interface OhosAutoFillRect {
  left: number;
  top: number;
  width: number;
  height: number;
}

/** Internal PageNodeInfo; mapped to autoFillManager.ViewData.pageNodeInfos at request time. */
export interface OhosPageNodeInfo {
  id: number;
  depth: number;
  autoFillType: number;
  tag: string;
  value: string;
  placeholder: string;
  enableAutoFill: boolean;
  rect: OhosAutoFillRect;
  isFocus: boolean;
}

/** Internal view snapshot built from Flutter AutofillGroup configuration. */
export interface OhosViewData {
  bundleName: string;
  moduleName: string;
  abilityName: string;
  pageUrl: string;
  pageNodeInfos: OhosPageNodeInfo[];
  pageRect: OhosAutoFillRect;
  isUserSelected: boolean;
  isOtherAccount: boolean;
}

interface AutoFillManagerPageNodeInfo {
  id: number;
  depth: number;
  autoFillType: autoFillManager.AutoFillType;
  tag: string;
  value: string;
  placeholder: string;
  enableAutoFill: boolean;
  rect: OhosAutoFillRect;
  isFocus: boolean;
}

interface AutoFillManagerViewData {
  bundleName: string;
  moduleName: string;
  abilityName: string;
  pageUrl: string;
  pageNodeInfos: AutoFillManagerPageNodeInfo[];
  pageRect: OhosAutoFillRect;
  isUserSelected: boolean;
  isOtherAccount: boolean;
}

interface AutoFillCustomData {
  data: Record<string, string>;
}

/**
 * Bridges Flutter AutofillGroup configuration to OpenHarmony autoFillManager APIs.
 */
export class OhosAutoFillHelper {
  private static hostInfoCache: AutoFillHostInfo | null = null;

  static logViewDataSummary(viewData: OhosViewData, label: string): void {
    const nodeSummaries: string[] = [];
    for (let i = 0; i < viewData.pageNodeInfos.length; i++) {
      const node = viewData.pageNodeInfos[i];
      nodeSummaries.push(
        `id=${node.id} type=${node.autoFillType} valueLen=${node.value.length} focus=${node.isFocus} ` +
        `rect=[${node.rect.left},${node.rect.top},${node.rect.width}x${node.rect.height}]`,
      );
    }
    Log.i(TAG, `${label}: bundle=${viewData.bundleName} pageUrl=${viewData.pageUrl} ` +
      `nodeCount=${viewData.pageNodeInfos.length} nodes=[${nodeSummaries.join('; ')}]`);
  }

  static setHostPageUrl(pageUrl: string): void {
    hostPageUrl = pageUrl;
    OhosAutoFillHelper.hostInfoCache = null;
  }

  /**
   * Records the real moduleName / abilityName from the running Ability so loadHostInfo can pass
   * them to autoFillManager. Without this, autofill falls back to 'entry' / 'EntryAbility'.
   */
  static setHostAbilityContext(context: common.UIAbilityContext): void {
    try {
      const abilityInfo = context.abilityInfo;
      if (abilityInfo !== undefined && abilityInfo !== null) {
        if (abilityInfo.moduleName !== undefined && abilityInfo.moduleName.length > 0) {
          hostModuleName = abilityInfo.moduleName;
        }
        if (abilityInfo.name !== undefined && abilityInfo.name.length > 0) {
          hostAbilityName = abilityInfo.name;
        }
        OhosAutoFillHelper.hostInfoCache = null;
      }
    } catch (error) {
      Log.w(TAG, 'setHostAbilityContext failed: ' + JSON.stringify(error));
    }
  }

  static getCachedHostInfo(): AutoFillHostInfo | null {
    if (OhosAutoFillHelper.hostInfoCache !== null &&
      OhosAutoFillHelper.hostInfoCache.bundleName.length > 0) {
      return OhosAutoFillHelper.hostInfoCache;
    }
    return null;
  }

  static async loadHostInfo(): Promise<AutoFillHostInfo> {
    const cached = OhosAutoFillHelper.getCachedHostInfo();
    if (cached !== null) {
      return cached;
    }
    try {
      const bundleInfo: bundleManager.BundleInfo = bundleManager.getBundleInfoForSelfSync(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
      OhosAutoFillHelper.hostInfoCache = {
        bundleName: bundleInfo.name ?? '',
        moduleName: hostModuleName,
        abilityName: hostAbilityName,
        pageUrl: hostPageUrl,
      };
      return OhosAutoFillHelper.hostInfoCache;
    } catch (error) {
      OhosAutoFillHelper.hostInfoCache = null;
      throw error as Error;
    }
  }

  private static toSdkAutoFillType(value: number): autoFillManager.AutoFillType {
    return value as autoFillManager.AutoFillType;
  }

  static hintToAutoFillType(hint: string): number {
    switch (hint) {
      case 'password':
        return AUTOFILL_TYPE_PASSWORD;
      case 'newPassword':
        return AUTOFILL_TYPE_NEW_PASSWORD;
      case 'username':
      case 'newUsername':
        return AUTOFILL_TYPE_USER_NAME;
      case 'emailAddress':
        return AUTOFILL_TYPE_EMAIL_ADDRESS;
      case 'phoneNumber':
      case 'phoneNumberDevice':
        return AUTOFILL_TYPE_PHONE_NUMBER;
      case 'phoneCountryCode':
        return AUTOFILL_TYPE_PHONE_COUNTRY_CODE;
      case 'phoneNational':
      case 'fullPhoneNumber':
        return AUTOFILL_TYPE_FULL_PHONE_NUMBER;
      case 'streetAddress':
      case 'fullStreetAddress':
        return AUTOFILL_TYPE_FULL_STREET_ADDRESS;
      case 'addressLocality':
        return AUTOFILL_TYPE_CITY_ADDRESS;
      case 'addressRegion':
        return AUTOFILL_TYPE_PROVINCE_ADDRESS;
      case 'addressCountry':
        return AUTOFILL_TYPE_COUNTRY_ADDRESS;
      case 'postalCode':
        return AUTOFILL_TYPE_DISTRICT_ADDRESS;
      case 'personName':
        return AUTOFILL_TYPE_PERSON_FULL_NAME;
      case 'personGivenName':
        return AUTOFILL_TYPE_PERSON_FIRST_NAME;
      case 'personFamilyName':
        return AUTOFILL_TYPE_PERSON_LAST_NAME;
      case 'creditCardNumber':
        return AUTOFILL_TYPE_BANK_CARD_NUMBER;
      case 'nickname':
        return AUTOFILL_TYPE_NICKNAME;
      default:
        return AUTOFILL_TYPE_UNSPECIFIED;
    }
  }

  static primaryAutoFillType(autofill: Autofill): number {
    if (autofill.hints.length === 0) {
      return AUTOFILL_TYPE_UNSPECIFIED;
    }
    for (const hint of autofill.hints) {
      const type = OhosAutoFillHelper.hintToAutoFillType(hint);
      if (type !== AUTOFILL_TYPE_UNSPECIFIED) {
        return type;
      }
    }
    return OhosAutoFillHelper.hintToAutoFillType(autofill.hints[0]);
  }

  private static primaryHintTag(autofill: Autofill): string {
    if (autofill.hints.length > 0) {
      return autofill.hints[0];
    }
    return autofill.hintText ?? '';
  }

  private static defaultFieldRect(): AutoFillFieldRect {
    return { left: 0, top: 0, width: 1, height: 1 };
  }

  static isValidRect(rect: AutoFillFieldRect | null): boolean {
    return rect !== null && rect.width > 0 && rect.height > 0;
  }

  private static toAutoFillRect(rect: AutoFillFieldRect): OhosAutoFillRect {
    return {
      left: rect.left,
      top: rect.top,
      width: rect.width > 0 ? rect.width : 1,
      height: rect.height > 0 ? rect.height : 1,
    };
  }

  private static resolvePageRect(
    pageRect: AutoFillFieldRect | null,
    focusedFieldRect: AutoFillFieldRect | null,
  ): OhosAutoFillRect {
    if (OhosAutoFillHelper.isValidRect(pageRect)) {
      return OhosAutoFillHelper.toAutoFillRect(pageRect as AutoFillFieldRect);
    }
    if (OhosAutoFillHelper.isValidRect(focusedFieldRect)) {
      return OhosAutoFillHelper.toAutoFillRect(focusedFieldRect as AutoFillFieldRect);
    }
    return OhosAutoFillHelper.toAutoFillRect(OhosAutoFillHelper.defaultFieldRect());
  }

  private static rectForField(
    autofill: Autofill,
    isFocused: boolean,
    focusedFieldRect: AutoFillFieldRect | null,
    fieldRects?: Map<string, AutoFillFieldRect>,
  ): AutoFillFieldRect {
    const stored = fieldRects?.get(autofill.uniqueIdentifier);
    if (stored !== undefined && OhosAutoFillHelper.isValidRect(stored)) {
      return stored;
    }
    if (isFocused && OhosAutoFillHelper.isValidRect(focusedFieldRect)) {
      return focusedFieldRect as AutoFillFieldRect;
    }
    if (OhosAutoFillHelper.isValidRect(focusedFieldRect)) {
      return focusedFieldRect as AutoFillFieldRect;
    }
    return OhosAutoFillHelper.defaultFieldRect();
  }

  private static buildPageNodeInfo(
    autofill: Autofill,
    nodeId: number,
    isFocused: boolean,
    rect: AutoFillFieldRect,
  ): OhosPageNodeInfo {
    const autoFillType = OhosAutoFillHelper.primaryAutoFillType(autofill);
    return {
      id: nodeId,
      depth: 0,
      autoFillType: autoFillType,
      tag: OhosAutoFillHelper.primaryHintTag(autofill),
      value: autofill.editState.text,
      placeholder: autofill.hintText ?? '',
      enableAutoFill: true,
      rect: OhosAutoFillHelper.toAutoFillRect(rect),
      isFocus: isFocused,
    };
  }

  /**
   * Assigns a stable, collision-free id to each autofill field. The same uniqueIdentifier always
   * receives the same id within one mapping; ids are dense small integers starting at 0, which
   * avoids the rare hash-collision risk of stringHash and makes them easy to inspect in logs.
   */
  static buildNodeIdMap(configuration: Configuration): Map<string, number> {
    const map = new Map<string, number>();
    let counter = 0;
    const fields = configuration.fields;
    if (fields !== null && fields.length > 0) {
      for (const fieldConfig of fields) {
        const fieldAutofill = fieldConfig.autofill;
        if (fieldAutofill === undefined) {
          continue;
        }
        if (!map.has(fieldAutofill.uniqueIdentifier)) {
          map.set(fieldAutofill.uniqueIdentifier, counter++);
        }
      }
    }
    const currentAutofill = configuration.autofill;
    if (currentAutofill !== undefined && !map.has(currentAutofill.uniqueIdentifier)) {
      map.set(currentAutofill.uniqueIdentifier, counter++);
    }
    return map;
  }

  /**
   * Builds the view data payload for an autofill session.
   * @param hostInfo - The autofill host info
   * @param configuration - The input configuration
   * @param nodeIdMap - Map of unique identifiers to node ids
   * @param focusedFieldRect - The focused field rect, possibly null
   * @param pageRect - The page rect, possibly null
   * @param fieldRects - Optional map of field rects
   * @returns The built OhosViewData
   * @throws {Error} if the configuration has no autofill section
   */
  static buildViewData(
    hostInfo: AutoFillHostInfo,
    configuration: Configuration,
    nodeIdMap: Map<string, number>,
    focusedFieldRect: AutoFillFieldRect | null,
    pageRect: AutoFillFieldRect | null,
    fieldRects?: Map<string, AutoFillFieldRect>,
  ): OhosViewData {
    const currentAutofill = configuration.autofill;
    if (currentAutofill === undefined) {
      throw new Error('buildViewData requires autofill configuration');
    }
    const focusedId: string = currentAutofill.uniqueIdentifier;
    const pageNodeInfos: OhosPageNodeInfo[] = [];

    const fields = configuration.fields;
    if (fields === null || fields.length === 0) {
      const rect = OhosAutoFillHelper.rectForField(
        currentAutofill, true, focusedFieldRect, fieldRects);
      pageNodeInfos.push(OhosAutoFillHelper.buildPageNodeInfo(
        currentAutofill, nodeIdMap.get(currentAutofill.uniqueIdentifier) ?? 0, true, rect));
    } else {
      for (const fieldConfig of fields) {
        if (fieldConfig.autofill === undefined) {
          continue;
        }
        const isFocused = fieldConfig.autofill.uniqueIdentifier === focusedId;
        const rect = OhosAutoFillHelper.rectForField(
          fieldConfig.autofill, isFocused, focusedFieldRect, fieldRects);
        const nodeId = nodeIdMap.get(fieldConfig.autofill.uniqueIdentifier) ?? 0;
        pageNodeInfos.push(OhosAutoFillHelper.buildPageNodeInfo(
          fieldConfig.autofill, nodeId, isFocused, rect));
      }
    }
    const resolvedPageRect = OhosAutoFillHelper.resolvePageRect(pageRect, focusedFieldRect);
    return {
      bundleName: hostInfo.bundleName,
      moduleName: hostInfo.moduleName,
      abilityName: hostInfo.abilityName,
      pageUrl: hostInfo.pageUrl,
      pageNodeInfos: pageNodeInfos,
      pageRect: deviceInfo.deviceType === '2in1'
        ? { left: 0, top: 0, width: resolvedPageRect.width, height: resolvedPageRect.height }
        : resolvedPageRect,
      isUserSelected: false,
      isOtherAccount: false,
    };
  }

  /**
   * Builds save ViewData from accumulated field texts + configs.
   * Mirrors native demo: password field keeps isFocus=true when login triggers save.
   */
  static buildViewDataForSave(
    hostInfo: AutoFillHostInfo,
    fieldConfigs: Map<string, Configuration>,
    fieldTexts: Map<string, string>,
    nodeIdMap: Map<string, number>,
    focusedUniqueId: string,
    focusedFieldRect: AutoFillFieldRect | null,
    pageRect: AutoFillFieldRect | null,
    fieldRects?: Map<string, AutoFillFieldRect>,
  ): OhosViewData {
    const pageNodeInfos: OhosPageNodeInfo[] = [];
    let emptyValueCount = 0;
    fieldConfigs.forEach((fieldConfig: Configuration, uniqueIdentifier: string) => {
      if (fieldConfig.autofill === undefined) {
        return;
      }
      let text = fieldTexts.get(uniqueIdentifier);
      if (text === undefined || text.length === 0) {
        text = fieldConfig.autofill.editState.text;
      }
      if (text.length === 0) {
        emptyValueCount++;
      }
      const isFocused = uniqueIdentifier === focusedUniqueId;
      const rect = OhosAutoFillHelper.rectForField(
        fieldConfig.autofill, isFocused, focusedFieldRect, fieldRects);
      const nodeId = nodeIdMap.get(uniqueIdentifier) ?? 0;
      const node = OhosAutoFillHelper.buildPageNodeInfo(fieldConfig.autofill, nodeId, isFocused, rect);
      node.value = text;
      pageNodeInfos.push(node);
    });
    Log.i(TAG, 'buildViewDataForSave: configCount=' + fieldConfigs.size +
      ' textCount=' + fieldTexts.size + ' nodeCount=' + pageNodeInfos.length +
      ' emptyValue=' + emptyValueCount + ' focusedUniqueId=' + focusedUniqueId);
    const resolvedPageRect = OhosAutoFillHelper.resolvePageRect(pageRect, focusedFieldRect);
    return {
      bundleName: hostInfo.bundleName,
      moduleName: hostInfo.moduleName,
      abilityName: hostInfo.abilityName,
      pageUrl: hostInfo.pageUrl,
      pageNodeInfos: pageNodeInfos,
      pageRect: deviceInfo.deviceType === '2in1'
        ? { left: 0, top: 0, width: resolvedPageRect.width, height: resolvedPageRect.height }
        : resolvedPageRect,
      isUserSelected: false,
      isOtherAccount: false,
    };
  }

  static validateSaveViewData(viewData: OhosViewData): string {
    let hasUsername = false;
    let hasPassword = false;
    for (let i = 0; i < viewData.pageNodeInfos.length; i++) {
      const node = viewData.pageNodeInfos[i];
      if (node.autoFillType === AUTOFILL_TYPE_USER_NAME && node.value.length > 0) {
        hasUsername = true;
      }
      if (node.autoFillType === AUTOFILL_TYPE_PASSWORD && node.value.length > 0) {
        hasPassword = true;
      }
    }
    if (viewData.pageNodeInfos.length < 2) {
      return 'nodeCount_lt_2(' + viewData.pageNodeInfos.length + ')';
    }
    if (!hasUsername) {
      return 'missing_username_value';
    }
    if (!hasPassword) {
      return 'missing_password_value';
    }
    return 'ok';
  }

  private static toManagerPageNodeInfo(node: OhosPageNodeInfo): AutoFillManagerPageNodeInfo {
    return {
      id: node.id,
      depth: node.depth,
      autoFillType: OhosAutoFillHelper.toSdkAutoFillType(node.autoFillType),
      tag: node.tag,
      value: node.value,
      placeholder: node.placeholder,
      enableAutoFill: node.enableAutoFill,
      rect: node.rect,
      isFocus: node.isFocus,
    };
  }

  private static toManagerViewData(viewData: OhosViewData): autoFillManager.ViewData {
    const pageNodeInfos: AutoFillManagerPageNodeInfo[] = [];
    for (const node of viewData.pageNodeInfos) {
      pageNodeInfos.push(OhosAutoFillHelper.toManagerPageNodeInfo(node));
    }
    const managerViewData: AutoFillManagerViewData = {
      bundleName: viewData.bundleName,
      moduleName: viewData.moduleName,
      abilityName: viewData.abilityName,
      pageUrl: viewData.pageUrl,
      pageNodeInfos: pageNodeInfos,
      pageRect: viewData.pageRect,
      isUserSelected: viewData.isUserSelected,
      isOtherAccount: viewData.isOtherAccount,
    };
    return managerViewData as autoFillManager.ViewData;
  }

  static parseFillResult(viewData: autoFillManager.ViewData): Map<number, string> {
    const values: Map<number, string> = new Map();
    const pageNodeInfos: OhosPageNodeInfo[] =
      (viewData as AutoFillManagerViewData).pageNodeInfos;
    for (const node of pageNodeInfos) {
      if (node.value.length > 0) {
        values.set(node.id, node.value);
      }
    }
    return values;
  }

  private static createEmptyCustomData(): AutoFillCustomData {
    const data: Record<string, string> = {};
    const customData: AutoFillCustomData = { data: data };
    return customData;
  }

  static requestAutoFill(
    uiContext: UIContext,
    viewData: OhosViewData,
    autoFillType: number,
    onSuccess: (values: Map<number, string>) => void,
    onFailure: (errCode: number) => void,
  ): void {
    if (deviceInfo.sdkApiVersion < AUTOFILL_SUPPORT_API) {
      onFailure(-1);
      return;
    }
    OhosAutoFillHelper.logViewDataSummary(viewData, 'requestAutoFill before invoke');
    const managerViewData = OhosAutoFillHelper.toManagerViewData(viewData);
    const fillRequest = {
      type: OhosAutoFillHelper.toSdkAutoFillType(autoFillType),
      viewData: managerViewData,
      customData: OhosAutoFillHelper.createEmptyCustomData(),
      isPopup: false,
      triggerType: AUTOFILL_TRIGGER_AUTO_REQUEST as autoFillManager.AutoFillTriggerType,
    } as autoFillManager.FillRequest;
    const callback: autoFillManager.AutoFillCallback = {
      onSuccess: (filledViewData: autoFillManager.ViewData): void => {
        const values = OhosAutoFillHelper.parseFillResult(filledViewData);
        onSuccess(values);
      },
      onFailure: (result: autoFillManager.FillFailureResult): void => {
        Log.e(TAG, 'requestAutoFill onFailure: ' + JSON.stringify(result));
        onFailure(result.errCode);
      },
    };
    try {
      autoFillManager.requestAutoFill(uiContext, fillRequest, callback);
    } catch (error) {
      const businessError = error as BusinessError;
      Log.e(TAG, 'requestAutoFill error code=' + businessError?.code +
        ' message=' + businessError?.message);
      onFailure(businessError?.code ?? -1);
    }
  }

  static requestAutoSave(
    uiContext: UIContext,
    viewData: OhosViewData,
    napiCallback: autoFillManager.AutoSaveCallback,
  ): void {
    if (deviceInfo.sdkApiVersion < AUTOFILL_SUPPORT_API) {
      napiCallback.onFailure();
      return;
    }
    const saveRequest: autoFillManager.SaveRequest = {
      viewData: OhosAutoFillHelper.toManagerViewData(viewData),
    };
    const validation = OhosAutoFillHelper.validateSaveViewData(viewData);
    if (validation !== 'ok') {
      Log.e(TAG, 'requestAutoSave aborted: invalid ViewData reason=' + validation);
      napiCallback.onFailure();
      return;
    }
    try {
      autoFillManager.requestAutoSave(uiContext, saveRequest, napiCallback);
    } catch (error) {
      const businessError = error as BusinessError;
      Log.e(TAG, 'requestAutoSave error code=' + businessError?.code +
        ' message=' + businessError?.message + ' raw=' + JSON.stringify(error));
      napiCallback.onFailure();
    }
  }
}
