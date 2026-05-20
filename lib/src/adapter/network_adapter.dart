import 'dart:async';
import 'models/adapter_request.dart';
import 'models/adapter_response.dart';
import 'interceptor/adapter_interceptor.dart';
import 'cancel_token.dart';

/// author:ZhengZaiHong
/// email:1096877329@qq.com
/// date:2026-05-20 13:58
/// describe: Really requesting an adapter for the network

/// Progress callback function type for file upload/download operations.
///
/// The callback receives two parameters:
/// - [count]: Number of bytes transferred so far
/// - [total]: Total number of bytes to transfer
///
/// Example:
/// ```dart
/// onProgress: (count, total) {
///   final percentage = (count / total * 100).toStringAsFixed(1);
///   print('Progress: $percentage%');
/// }
/// ```
typedef ProgressCallback = void Function(int count, int total);

/// Abstract interface for network adapters in RxNet Plus.
///
/// This interface defines the standard contract that all network adapters must implement.
/// Different HTTP client libraries (Dio, http, etc.) can be integrated by implementing
/// this interface, allowing RxNet to work with any HTTP client seamlessly.
///
/// ## Built-in Adapters
///
/// RxNet Plus provides three built-in adapters:
/// - **DioAdapter**: Full-featured adapter based on Dio (default)
/// - **HttpAdapter**: Lightweight adapter based on dart:http
/// - **MockAdapter**: Testing adapter with no network calls
///
/// ## Creating Custom Adapters
///
/// To create a custom adapter, implement this interface:
///
/// ```dart
/// class MyCustomAdapter implements NetworkAdapter {
///   @override
///   String get name => 'MyCustomAdapter';
///
///   @override
///   String get version => '1.0.0';
///
///   @override
///   Future<AdapterResponse> request(AdapterRequest request) async {
///     // Implement your HTTP logic here
///   }
///
///   // Implement other methods...
/// }
/// ```
///
/// See also:
/// - [AdapterRequest] for request configuration
/// - [AdapterResponse] for response structure
/// - [AdapterInterceptor] for interceptor implementation
abstract class NetworkAdapter {
  /// Executes an HTTP request.
  ///
  /// This is the core method that performs the actual HTTP request using the
  /// underlying HTTP client library.
  ///
  /// Parameters:
  /// - [request]: The request configuration containing URL, method, headers, body, etc.
  ///
  /// Returns a [Future] that completes with an [AdapterResponse] containing the
  /// response data, status code, headers, etc.
  ///
  /// Throws [AdapterException] if the request fails due to timeout, network error,
  /// or other issues.
  ///
  /// Example:
  /// ```dart
  /// final request = AdapterRequest(
  ///   baseUrl: 'https://api.example.com',
  ///   path: '/users/123',
  ///   method: HttpMethod.get,
  /// );
  /// final response = await adapter.request(request);
  /// print('Status: ${response.statusCode}');
  /// print('Data: ${response.data}');
  /// ```
  Future<AdapterResponse> request(AdapterRequest request);
  
  /// Downloads a file from the server.
  ///
  /// This method downloads a file and saves it to the specified path on the device.
  /// Progress can be tracked using the optional [onProgress] callback.
  ///
  /// Parameters:
  /// - [request]: The request configuration for the download
  /// - [savePath]: The local file path where the downloaded file will be saved
  /// - [onProgress]: Optional callback to track download progress
  ///
  /// Returns a [Future] that completes with an [AdapterResponse] when the download
  /// is complete.
  ///
  /// Throws [AdapterException] if the download fails.
  ///
  /// Example:
  /// ```dart
  /// final request = AdapterRequest(
  ///   baseUrl: 'https://example.com',
  ///   path: '/files/document.pdf',
  ///   method: HttpMethod.get,
  /// );
  ///
  /// await adapter.download(
  ///   request,
  ///   '/path/to/save/document.pdf',
  ///   onProgress: (count, total) {
  ///     print('Downloaded: ${(count / total * 100).toStringAsFixed(1)}%');
  ///   },
  /// );
  /// ```
  Future<AdapterResponse> download(
    AdapterRequest request,
    String savePath, {
    ProgressCallback? onProgress,
  });
  
  /// Uploads data to the server.
  ///
  /// This method uploads data (typically files) to the server. Progress can be
  /// tracked using the optional [onProgress] callback.
  ///
  /// Parameters:
  /// - [request]: The request configuration for the upload, including the data to upload
  /// - [onProgress]: Optional callback to track upload progress
  ///
  /// Returns a [Future] that completes with an [AdapterResponse] when the upload
  /// is complete.
  ///
  /// Throws [AdapterException] if the upload fails.
  ///
  /// Example:
  /// ```dart
  /// final request = AdapterRequest(
  ///   baseUrl: 'https://api.example.com',
  ///   path: '/upload',
  ///   method: HttpMethod.post,
  ///   bodyParams: {'file': File('/path/to/file.jpg')},
  /// );
  ///
  /// await adapter.upload(
  ///   request,
  ///   onProgress: (count, total) {
  ///     print('Uploaded: ${(count / total * 100).toStringAsFixed(1)}%');
  ///   },
  /// );
  /// ```
  Future<AdapterResponse> upload(
    AdapterRequest request, {
    ProgressCallback? onProgress,
  });
  
  /// Cancels an ongoing request.
  ///
  /// This method cancels a request that is currently in progress. The request
  /// is identified by the [token] parameter.
  ///
  /// Parameters:
  /// - [token]: The cancel token associated with the request to cancel
  ///
  /// After calling this method, the request will be aborted and an
  /// [AdapterException] with type [AdapterExceptionType.cancel] will be thrown.
  ///
  /// Example:
  /// ```dart
  /// final cancelToken = CancelToken();
  ///
  /// // Start a request
  /// final request = AdapterRequest(
  ///   baseUrl: 'https://api.example.com',
  ///   path: '/data',
  ///   method: HttpMethod.get,
  ///   cancelToken: cancelToken,
  /// );
  ///
  /// // Cancel the request
  /// adapter.cancel(cancelToken);
  /// ```
  void cancel(CancelToken token);
  
  /// Adds an interceptor to the adapter.
  ///
  /// Interceptors can modify requests before they are sent, modify responses
  /// before they are returned, or handle errors.
  ///
  /// Parameters:
  /// - [interceptor]: The interceptor to add
  ///
  /// Interceptors are executed in the order they are added.
  ///
  /// Example:
  /// ```dart
  /// class AuthInterceptor extends AdapterInterceptor {
  ///   @override
  ///   Future<void> onRequest(
  ///     AdapterRequest request,
  ///     RequestInterceptorHandler handler,
  ///   ) async {
  ///     final modifiedRequest = request.copyWith(
  ///       headers: {...request.headers, 'Authorization': 'Bearer token'},
  ///     );
  ///     handler.next(modifiedRequest);
  ///   }
  /// }
  ///
  /// adapter.addInterceptor(AuthInterceptor());
  /// ```
  ///
  /// See also:
  /// - [AdapterInterceptor] for interceptor implementation details
  /// - [removeInterceptor] to remove an interceptor
  void addInterceptor(AdapterInterceptor interceptor);
  
  /// Removes an interceptor from the adapter.
  ///
  /// Parameters:
  /// - [interceptor]: The interceptor to remove
  ///
  /// If the interceptor is not found, this method does nothing.
  ///
  /// Example:
  /// ```dart
  /// final authInterceptor = AuthInterceptor();
  /// adapter.addInterceptor(authInterceptor);
  ///
  /// // Later, remove it
  /// adapter.removeInterceptor(authInterceptor);
  /// ```
  void removeInterceptor(AdapterInterceptor interceptor);
  
  /// Gets the name of the adapter.
  ///
  /// This is used for identification and debugging purposes.
  ///
  /// Example return values:
  /// - 'DioAdapter'
  /// - 'HttpAdapter'
  /// - 'MockAdapter'
  String get name;
  
  /// Gets the version of the adapter.
  ///
  /// This is used for compatibility checking and debugging.
  ///
  /// Example return value: '1.0.0'
  String get version;
}
