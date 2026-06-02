// Core RxNet functionality
export 'package:rxnet_plus/net/rx_net.dart';

// Public data models and enums
export 'package:rxnet_plus/net/mode/cache_mode.dart';
export 'package:rxnet_plus/net/type/http_method.dart';  // New unified HTTP method enum
export 'package:rxnet_plus/net/type/response_type.dart';  // New unified response type enum
export 'package:rxnet_plus/net/type/sources_type.dart';
export 'package:rxnet_plus/net/type/content_types.dart';
export 'package:rxnet_plus/net/result/rx_result.dart';

// Custom error types
export 'package:rxnet_plus/src/error/rx_error.dart';

// ==================== Adapter Architecture (0.6.0) ====================

// Core adapter interface and models
export 'package:rxnet_plus/src/adapter/network_adapter.dart';
export 'package:rxnet_plus/src/adapter/models/adapter_request.dart';
export 'package:rxnet_plus/src/adapter/models/adapter_response.dart';
export 'package:rxnet_plus/src/adapter/exceptions/adapter_exception.dart';


export 'package:rxnet_plus/src/adapter/implementations/dio_adapter.dart';
export 'package:rxnet_plus/src/adapter/implementations/http_adapter.dart';
export 'package:rxnet_plus/src/adapter/implementations/mock_adapter.dart';


export 'package:rxnet_plus/src/adapter/cancel_token.dart';



// Interceptor system
export 'package:rxnet_plus/src/adapter/interceptor/adapter_interceptor.dart';
// New adapter-based log interceptor
export 'package:rxnet_plus/net/interceptor/rxnet_log_adapter_interceptor.dart';
export 'package:rxnet_plus/net/interceptor/rxnet_simple_log_interceptor.dart';

// ==================== Legacy Exports ====================

// Request building and configuration
export 'package:rxnet_plus/src/request/build_request.dart';
export 'package:rxnet_plus/net/fun/fun_apply.dart';

// Dio (for backward compatibility)
// IMPORTANT: Some types are hidden to avoid conflicts with adapter architecture
export 'package:dio/dio.dart' hide
    ResponseType,
    CancelToken,  // Use adapter version: import 'package:rxnet_plus/src/adapter/cancel_token.dart'
    RequestInterceptorHandler,  // Use adapter version
    ResponseInterceptorHandler,  // Use adapter version
    ErrorInterceptorHandler,  // Use adapter version
    ProgressCallback;  // Use adapter version

export 'package:dio/io.dart';
export 'package:http/io_client.dart';

// path_provider
export 'package:rxnet_plus/rxnet_plus.dart';

// utils
export 'package:rxnet_plus/utils/downloader.dart';
export 'package:rxnet_plus/utils/http_error.dart';
export 'package:rxnet_plus/utils/log_util.dart';
export 'package:rxnet_plus/utils/md5_util.dart';
export 'package:rxnet_plus/utils/text_util.dart';
export 'package:rxnet_plus/utils/rx_net_platform.dart';

// ==================== Concurrent Requests ====================

// Concurrent callback-based request support
// export 'package:rxnet_plus/net/concurrent/zip_request.dart';
// export 'package:rxnet_plus/net/concurrent/zip_results.dart';
// export 'package:rxnet_plus/net/concurrent/zip_request_error.dart';
// export 'package:rxnet_plus/net/concurrent/request_state.dart';

export 'package:rxnet_plus/net/concurrent/concurrent.dart';


