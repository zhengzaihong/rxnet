/// DioAdapter - Network adapter implementation using Dio library
///
/// This adapter provides full-featured HTTP client capabilities using the Dio package.
/// It's the default adapter for RxNet Plus and supports all advanced features including:
/// - Request/Response interceptors
/// - File upload/download with progress
/// - Request cancellation
/// - Timeout configuration
/// - Custom headers and query parameters
///
/// ## Usage
///
/// ```dart
/// import 'package:rxnet_plus/adapters/dio_adapter.dart';
///
/// final adapter = DioAdapter();
/// await rxNet.initNet(
///   baseUrl: 'https://api.example.com',
///   adapter: adapter,
/// );
/// ```
///
/// ## Requirements
///
/// This adapter requires the `dio` package to be included in your dependencies:
///
/// ```yaml
/// dependencies:
///   dio: ^5.8.0+1
/// ```
///
/// ## See Also
///
/// - [HttpAdapter] - Lightweight alternative using the http package
/// - [MockAdapter] - Testing adapter for unit tests
/// - [NetworkAdapter] - Base interface for creating custom adapters

library dio_adapter;

export 'package:rxnet_plus/src/adapter/implementations/dio_adapter.dart';
