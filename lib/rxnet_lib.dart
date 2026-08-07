// Core RxNet functionality
export 'package:rxnet_plus/src/rx_net.dart';
export 'package:rxnet_plus/src/config/rx_net_config.dart';
export 'package:rxnet_plus/src/cache/rx_net_cache.dart';
export 'package:rxnet_plus/src/cache/cache_eviction_policy.dart';
export 'package:rxnet_plus/src/cache/cache_metadata.dart';

// Public data models and enums
export 'package:rxnet_plus/src/mode/cache_mode.dart';
export 'package:rxnet_plus/src/type/http_method.dart';  // New unified HTTP method enum
export 'package:rxnet_plus/src/type/response_type.dart';  // New unified response type enum
export 'package:rxnet_plus/src/type/sources_type.dart';
export 'package:rxnet_plus/src/type/content_types.dart';
export 'package:rxnet_plus/src/result/rx_result.dart';

// Custom error types
export 'package:rxnet_plus/src/error/rx_error.dart';

// ==================== Adapter Architecture (0.6.0) ====================

// Core adapter interface and models
export 'package:rxnet_plus/src/adapter/network_adapter.dart';
export 'package:rxnet_plus/src/adapter/models/adapter_request.dart';
export 'package:rxnet_plus/src/adapter/models/adapter_response.dart';
export 'package:rxnet_plus/src/adapter/models/adapter_base_options.dart';
export 'package:rxnet_plus/src/adapter/exceptions/adapter_exception.dart';


export 'package:rxnet_plus/src/adapter/implementations/dio_adapter.dart';
export 'package:rxnet_plus/src/adapter/implementations/http_adapter.dart';
export 'package:rxnet_plus/src/adapter/implementations/mock_adapter.dart';
export 'package:rxnet_plus/src/adapter/cancel_token.dart';

// Interceptor system
export 'package:rxnet_plus/src/adapter/interceptor/adapter_interceptor.dart';
export 'package:rxnet_plus/src/adapter/interceptor/token_refresh_interceptor.dart';
export 'package:rxnet_plus/src/adapter/interceptor/deduplicate_interceptor.dart';
export 'package:rxnet_plus/src/adapter/interceptor/throttle_interceptor.dart';

// New adapter-based log interceptor
export 'package:rxnet_plus/src/adapter/interceptor/rxnet_log_adapter_interceptor.dart';
export 'package:rxnet_plus/src/adapter/interceptor/rxnet_simple_log_interceptor.dart';

// Request building and configuration
export 'package:rxnet_plus/src/request/build_request.dart';
export 'package:rxnet_plus/src/request/retry_policy.dart';
export 'package:rxnet_plus/src/fun/fun_apply.dart';

// Dio (for backward compatibility)
// IMPORTANT: Some types are hidden to avoid conflicts with adapter architecture
export 'package:dio/dio.dart' hide
    ResponseType,
    CancelToken,
    RequestInterceptorHandler,
    ResponseInterceptorHandler,
    ErrorInterceptorHandler,
    ProgressCallback,
    BaseOptions;  // Use RxNetConfig or DioAdapter options instead

export 'package:dio/io.dart';
export 'package:http/io_client.dart';

// path_provider
export 'package:rxnet_plus/rxnet_plus.dart';

// utils
export 'package:rxnet_plus/utils/downloader.dart';
export 'package:rxnet_plus/utils/log_util.dart';
export 'package:rxnet_plus/utils/md5_util.dart';
export 'package:rxnet_plus/utils/text_util.dart';
export 'package:rxnet_plus/utils/rx_net_platform.dart';

// ==================== Concurrent Requests ====================
export 'package:rxnet_plus/src/concurrent/concurrent.dart';


