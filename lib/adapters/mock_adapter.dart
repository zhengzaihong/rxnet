/// MockAdapter - Testing adapter for unit and integration tests
///
/// This adapter provides a mock implementation of the NetworkAdapter interface,
/// allowing you to test your application without making real network requests.
///
/// ## Features
///
/// - Configure mock responses for specific paths
/// - Simulate network errors
/// - Add artificial delays
/// - Track request history
/// - No external dependencies required
///
/// ## Usage
///
/// ```dart
/// import 'package:rxnet_plus/adapters/mock_adapter.dart';
/// import 'package:rxnet_plus/src/adapter/models/adapter_response.dart';
/// import 'package:rxnet_plus/src/adapter/models/adapter_request.dart';
///
/// void main() {
///   test('should fetch user data', () async {
///     // Arrange
///     final mockAdapter = MockAdapter();
///     mockAdapter.setMockResponse(
///       '/users/123',
///       AdapterResponse(
///         statusCode: 200,
///         data: {'id': 123, 'name': 'John'},
///         headers: {},
///         request: AdapterRequest(
///           baseUrl: 'https://api.example.com',
///           path: '/users/123',
///           method: HttpMethod.get,
///         ),
///       ),
///     );
///
///     await rxNet.initNet(
///       baseUrl: 'https://api.example.com',
///       adapter: mockAdapter,
///     );
///
///     // Act
///     final result = await rxNet.getRequest()
///         .setPath('/users/123')
///         .request();
///
///     // Assert
///     expect(result.isSuccess, true);
///     expect(result.value['name'], 'John');
///     expect(mockAdapter.requestHistory.length, 1);
///   });
/// }
/// ```
///
/// ## Advanced Features
///
/// ### Simulating Errors
///
/// ```dart
/// mockAdapter.setMockError(
///   '/users/123',
///   AdapterException(
///     type: AdapterExceptionType.notFound,
///     message: 'User not found',
///   ),
/// );
/// ```
///
/// ### Adding Delays
///
/// ```dart
/// mockAdapter.setMockDelay('/users/123', Duration(seconds: 2));
/// ```
///
/// ### Tracking Requests
///
/// ```dart
/// final history = mockAdapter.requestHistory;
/// expect(history.length, 3);
/// expect(history[0].method, HttpMethod.get);
/// expect(history[0].path, '/users/123');
/// ```
///
/// ## See Also
///
/// - [DioAdapter] - Production adapter using Dio
/// - [HttpAdapter] - Production adapter using http package
/// - [NetworkAdapter] - Base interface for creating custom adapters

library mock_adapter;

export 'package:rxnet_plus/src/adapter/implementations/mock_adapter.dart';
