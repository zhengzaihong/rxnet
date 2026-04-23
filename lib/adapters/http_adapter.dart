/// HttpAdapter - Lightweight network adapter using the http package
///
/// This adapter provides a lightweight HTTP client implementation using the standard
/// Dart http package. It's ideal for simple use cases or when you want to minimize
/// dependencies.
///
/// ## Features
///
/// - Basic HTTP methods (GET, POST, PUT, DELETE, PATCH)
/// - Request/Response interceptors
/// - File upload/download with progress
/// - Custom headers and query parameters
/// - Timeout configuration
///
/// ## Usage
///
/// ```dart
/// import 'package:rxnet_plus/adapters/http_adapter.dart';
///
/// final adapter = HttpAdapter();
/// await rxNet.initNet(
///   baseUrl: 'https://api.example.com',
///   adapter: adapter,
/// );
/// ```
///
/// ## Requirements
///
/// This adapter requires the `http` package to be included in your dependencies:
///
/// ```yaml
/// dependencies:
///   http: ^1.2.0
/// ```
///
/// ## Comparison with DioAdapter
///
/// | Feature | HttpAdapter | DioAdapter |
/// |---------|-------------|------------|
/// | Package size | Smaller | Larger |
/// | Features | Basic | Full-featured |
/// | Performance | Good | Excellent |
/// | Interceptors | Yes | Yes |
/// | File upload/download | Yes | Yes |
/// | Advanced features | Limited | Extensive |
///
/// ## See Also
///
/// - [DioAdapter] - Full-featured adapter using Dio
/// - [MockAdapter] - Testing adapter for unit tests
/// - [NetworkAdapter] - Base interface for creating custom adapters

library http_adapter;

export 'package:rxnet_plus/src/adapter/implementations/http_adapter.dart';
