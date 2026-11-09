/*
 * Copyright (c) 2026 Huawei Device Co., Ltd. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE_HW file.
 */

import Log from '../../util/Log';

const TAG = 'FlutterEngineFlags';

// Module-level const, not a class static: the Flag instances below are
// constructed before the class finishes initializing, and reading
// FlutterEngineFlags.METADATA_PREFIX from there throws
// "ReferenceError: FlutterEngineFlags is not initialized" at module load.
const METADATA_PREFIX = 'flutter.engine.';

/**
 * Represents a Flutter shell flag that can be set via module.json5 metadata.
 */
export class Flag {
  /** The actual argument used to specify the flag in the engine. */
  readonly engineArgument: string;
  /** The metadata key name used to specify the flag in module.json5. */
  readonly metadataKey: string;
  /** Whether this flag is allowed to be set in release mode. */
  readonly allowedInRelease: boolean;

  constructor(engineArgument: string, metaDataName: string, allowedInRelease: boolean) {
    this.engineArgument = engineArgument;
    this.metadataKey = METADATA_PREFIX + metaDataName;
    this.allowedInRelease = allowedInRelease;
  }

  /** Returns true if the command line flag requires a value to be specified. */
  hasCommandLineValue(): boolean {
    return this.engineArgument.endsWith('=');
  }
}

/**
 * Engine flags that can be delivered to the Flutter shell on OHOS.
 *
 * Ported from the Android FlutterEngineFlags registry (flutter/flutter#182522).
 * All flags map to a flag listed in shell/common/switches.cc.
 *
 * Flags can be set via module.json5 metadata with keys prefixed
 * "flutter.engine."; Want-provided args (FlutterShellArgs) take precedence.
 */

// Flag instances live at module level for the same reason as METADATA_PREFIX;
// the class below re-exports them as statics for API parity with Android.

// Flags that also exist in the Want channel, in FlutterShellArgs' order.
// cache-sksl and msaa-samples are intentionally absent.

const FLAG_TRACE_STARTUP: Flag =
  new Flag('--trace-startup', 'TraceStartup', true);

const FLAG_START_PAUSED: Flag =
  new Flag('--start-paused', 'StartPaused', false);

const FLAG_DISABLE_SERVICE_AUTH_CODES: Flag =
  new Flag('--disable-service-auth-codes', 'DisableServiceAuthCodes', false);

const FLAG_ENDLESS_TRACE_BUFFER: Flag =
  new Flag('--endless-trace-buffer', 'EndlessTraceBuffer', false);

const FLAG_USE_TEST_FONTS: Flag =
  new Flag('--use-test-fonts', 'UseTestFonts', false);

const FLAG_ENABLE_DART_PROFILING: Flag =
  new Flag('--enable-dart-profiling', 'EnableDartProfiling', true);

const FLAG_PROFILE_STARTUP: Flag =
  new Flag('--profile-startup', 'ProfileStartup', true);

const FLAG_ENABLE_SOFTWARE_RENDERING: Flag =
  new Flag('--enable-software-rendering', 'EnableSoftwareRendering', false);

const FLAG_SKIA_DETERMINISTIC_RENDERING: Flag =
  new Flag('--skia-deterministic-rendering', 'SkiaDeterministicRendering', false);

const FLAG_TRACE_SKIA: Flag =
  new Flag('--trace-skia', 'TraceSkia', false);

const FLAG_TRACE_SKIA_ALLOWLIST: Flag =
  new Flag('--trace-skia-allowlist=', 'TraceSkiaAllowList', false);

const FLAG_TRACE_SYSTRACE: Flag =
  new Flag('--trace-systrace', 'TraceSystrace', false);

const FLAG_ENABLE_IMPELLER: Flag =
  new Flag('--enable-impeller=', 'EnableImpeller', true);

const FLAG_DUMP_SKP_ON_SHADER_COMPILATION: Flag =
  new Flag('--dump-skp-on-shader-compilation', 'DumpSkpOnShaderCompilation', false);

const FLAG_PURGE_PERSISTENT_CACHE: Flag =
  new Flag('--purge-persistent-cache', 'PurgePersistentCache', false);

const FLAG_VERBOSE_LOGGING: Flag =
  new Flag('--verbose-logging', 'VerboseLogging', false);

/** In the Want channel this is the legacy key "observatory-port". */
const FLAG_VM_SERVICE_PORT: Flag =
  new Flag('--vm-service-port=', 'VMServicePort', false);

const FLAG_DART_FLAGS: Flag =
  new Flag('--dart-flags=', 'DartFlags', false);

/** Fake flag used for testing of the embedding's engine flags processing. */
const FLAG_TEST_FLAG: Flag =
  new Flag('--test-flag', 'TestFlag', false);

const FLAG_LIST: Flag[] = [
  FLAG_TRACE_STARTUP,
  FLAG_START_PAUSED,
  FLAG_DISABLE_SERVICE_AUTH_CODES,
  FLAG_ENDLESS_TRACE_BUFFER,
  FLAG_USE_TEST_FONTS,
  FLAG_ENABLE_DART_PROFILING,
  FLAG_PROFILE_STARTUP,
  FLAG_ENABLE_SOFTWARE_RENDERING,
  FLAG_SKIA_DETERMINISTIC_RENDERING,
  FLAG_TRACE_SKIA,
  FLAG_TRACE_SKIA_ALLOWLIST,
  FLAG_TRACE_SYSTRACE,
  FLAG_ENABLE_IMPELLER,
  FLAG_DUMP_SKP_ON_SHADER_COMPILATION,
  FLAG_PURGE_PERSISTENT_CACHE,
  FLAG_VERBOSE_LOGGING,
  FLAG_VM_SERVICE_PORT,
  FLAG_DART_FLAGS,
  FLAG_TEST_FLAG,
];

export default class FlutterEngineFlags {
  public static readonly METADATA_PREFIX: string = METADATA_PREFIX;

  public static readonly TRACE_STARTUP: Flag = FLAG_TRACE_STARTUP;

  public static readonly START_PAUSED: Flag = FLAG_START_PAUSED;

  public static readonly DISABLE_SERVICE_AUTH_CODES: Flag = FLAG_DISABLE_SERVICE_AUTH_CODES;

  public static readonly ENDLESS_TRACE_BUFFER: Flag = FLAG_ENDLESS_TRACE_BUFFER;

  public static readonly USE_TEST_FONTS: Flag = FLAG_USE_TEST_FONTS;

  public static readonly ENABLE_DART_PROFILING: Flag = FLAG_ENABLE_DART_PROFILING;

  public static readonly PROFILE_STARTUP: Flag = FLAG_PROFILE_STARTUP;

  public static readonly ENABLE_SOFTWARE_RENDERING: Flag = FLAG_ENABLE_SOFTWARE_RENDERING;

  public static readonly SKIA_DETERMINISTIC_RENDERING: Flag = FLAG_SKIA_DETERMINISTIC_RENDERING;

  public static readonly TRACE_SKIA: Flag = FLAG_TRACE_SKIA;

  public static readonly TRACE_SKIA_ALLOWLIST: Flag = FLAG_TRACE_SKIA_ALLOWLIST;

  public static readonly TRACE_SYSTRACE: Flag = FLAG_TRACE_SYSTRACE;

  public static readonly ENABLE_IMPELLER: Flag = FLAG_ENABLE_IMPELLER;

  public static readonly DUMP_SKP_ON_SHADER_COMPILATION: Flag = FLAG_DUMP_SKP_ON_SHADER_COMPILATION;

  public static readonly PURGE_PERSISTENT_CACHE: Flag = FLAG_PURGE_PERSISTENT_CACHE;

  public static readonly VERBOSE_LOGGING: Flag = FLAG_VERBOSE_LOGGING;

  public static readonly VM_SERVICE_PORT: Flag = FLAG_VM_SERVICE_PORT;

  public static readonly DART_FLAGS: Flag = FLAG_DART_FLAGS;

  public static readonly TEST_FLAG: Flag = FLAG_TEST_FLAG;

  public static readonly ALL_FLAGS: Flag[] = FLAG_LIST;

  /**
   * Computes the shell args contributed by module.json5 metadata. Pure
   * function so the classification logic can be unit tested.
   *
   * Semantics ported from Android FlutterLoader (#182522): unknown keys are
   * ignored; flags not allowed in release are dropped with an error log;
   * boolean flags are only enabled when the value is exactly "true"; value
   * flags require a non-empty value.
   */
  public static computeMetadataArgs(metadata: Map<string, string>, isRelease: boolean): string[] {
    const args: string[] = [];
    for (const flag of FlutterEngineFlags.ALL_FLAGS) {
      const metadataKey = flag.metadataKey;
      if (!metadata.has(metadataKey)) {
        continue;
      }

      // Check if flag is valid:
      if (flag === FlutterEngineFlags.TEST_FLAG) {
        Log.w(TAG, 'For testing purposes only: test flag specified in the metadata was loaded.');
        continue;
      } else if (!flag.allowedInRelease && isRelease) {
        Log.e(TAG, 'Flag with metadata key ' + metadataKey +
          ' is not allowed in release builds and will be ignored if specified in module.json5.');
        continue;
      }

      // Add flag to args.
      if (flag.hasCommandLineValue()) {
        const value = metadata.get(metadataKey);
        if (value === undefined || value.length === 0) {
          Log.e(TAG, 'Flag with metadata key ' + metadataKey +
            ' requires a value, but no value was found. Please specify a value.');
          continue;
        }
        args.push(flag.engineArgument + value);
        continue;
      }

      // Only enable boolean flags when the value is exactly "true".
      if (metadata.get(metadataKey) === 'true') {
        args.push(flag.engineArgument);
      }
    }
    return args;
  }

  /**
   * Merges metadata args in front of the Want args so the Want takes
   * precedence (duplicate switches resolve last-wins, as on Android).
   */
  public static mergeMetadataArgs(shellArgs: string[], metadataArgs: string[]): string[] {
    const merged: string[] = [];
    for (const arg of metadataArgs) {
      merged.push(arg);
    }
    for (const arg of shellArgs) {
      merged.push(arg);
    }
    return merged;
  }

  /**
   * Finds the registry flag matching an engine argument, or null if the
   * argument is not part of the registry. Value flags match by prefix
   * ("--enable-impeller=false" matches "--enable-impeller="); boolean flags
   * match exactly.
   */
  public static getFlagByEngineArgument(arg: string): Flag | null {
    for (const flag of FlutterEngineFlags.ALL_FLAGS) {
      if (flag.hasCommandLineValue()) {
        if (arg.startsWith(flag.engineArgument)) {
          return flag;
        }
      } else if (arg === flag.engineArgument) {
        return flag;
      }
    }
    return null;
  }

  /**
   * Drops args whose registry flag is not allowed in release builds,
   * ported from the Android args-channel filter (flutter/flutter#182522).
   * Args outside the registry pass through unchanged (flutter/flutter#182557).
   */
  public static filterArgsForRelease(args: string[], isRelease: boolean): string[] {
    if (!isRelease) {
      return args;
    }
    const filtered: string[] = [];
    for (const arg of args) {
      const flag = FlutterEngineFlags.getFlagByEngineArgument(arg);
      if (flag !== null && !flag.allowedInRelease) {
        Log.e(TAG, 'Flag ' + arg +
          ' is not allowed in release builds and will be ignored.');
        continue;
      }
      filtered.push(arg);
    }
    return filtered;
  }
}
