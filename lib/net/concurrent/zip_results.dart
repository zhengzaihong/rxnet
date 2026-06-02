
/// author:ZhengZaiHong
/// email:1096877329@qq.com
/// date:2026-06-02 11:27
/// describe: 通过[zipRequest]执行的并发请求聚合结果的容器。
/// Container for aggregated results from concurrent requests executed via [zipRequest].

/// [ZipResults] provides type-safe access to results from multiple concurrent requests,
/// maintaining the original submission order and supporting both index-based and tag-based access.
///
/// ## Features
///
/// - **Order Preservation**: Results are stored in the same order as requests were submitted
/// - **Type Safety**: Generic methods ensure compile-time type checking
/// - **Dual Access**: Access results by index or by optional tag
/// - **Error Handling**: Distinguishes between successful and failed requests
/// - **Partial Success**: When `eagerError: false`, contains both successful results and errors
///
/// ## Usage
///
/// ```dart
/// final results = await RxNet.zipRequest([
///   ZipRequest<UserInfo>(request: getUserAsync, tag: 'user'),
///   ZipRequest<List<Product>>(request: getProductsAsync, tag: 'products'),
/// ]);
///
/// // Access by tag with type safety
/// final user = results.getRequestByTag<UserInfo>('user');
/// final products = results.getRequestByTag<List<Product>>('products');
///
/// // Access by index
/// final firstResult = results.getRequestByIndex<UserInfo>(0);
///
/// // Check success status
/// if (results.isSuccess(0)) {
///   print('First request succeeded');
/// }
///
/// // Get all successful results
/// final successful = results.successfulResults;
/// ```
///
/// ## Error Handling
///
/// When a request fails and `eagerError: false`, the error is stored internally.
/// Attempting to access a failed request's result will throw the original error:
///
/// ```dart
/// try {
///   final result = results.getRequestByIndex<UserInfo>(0);
/// } catch (e) {
///   print('Request failed: $e');
/// }
///
/// // Or check before accessing
/// if (results.isSuccess(0)) {
///   final result = results.getRequestByIndex<UserInfo>(0);
/// }
/// ```
///
/// See also:
/// - [ZipRequest] for creating concurrent request wrappers
/// - [zipRequest] for executing concurrent requests
class ZipResults {
  /// Results stored by index (in order of request submission)
  final List<dynamic> _results;
  
  /// Mapping from tag to index for named access
  final Map<String, int> _tagIndexMap;
  
  /// Error information for failed requests (when eagerError: false)
  final Map<int, dynamic> _errors;
  
  /// Creates a [ZipResults] instance with results, tag mapping, and optional errors.
  ///
  /// This constructor is typically called internally by [zipRequest] and should
  /// not be used directly by application code.
  ///
  /// Parameters:
  /// - [_results]: List of results in submission order
  /// - [_tagIndexMap]: Mapping from tags to result indices
  /// - [_errors]: Map of indices to error objects for failed requests
  ZipResults(this._results, this._tagIndexMap, [this._errors = const {}]);
  
  /// Retrieves the result for a request identified by [tag] with type safety.
  ///
  /// Returns the result cast to type [T]. The type parameter ensures compile-time
  /// type checking and eliminates the need for manual casting.
  ///
  /// Example:
  /// ```dart
  /// final user = results.getRequestByTag<UserInfo>('user');
  /// final products = results.getRequestByTag<List<Product>>('products');
  /// ```
  ///
  /// Throws:
  /// - [ArgumentError] if the tag does not exist in the results
  /// - The original error if the request with this tag failed
  ///
  /// See also:
  /// - [getRequestByIndex] for index-based access
  /// - [isSuccessByTag] to check if a tagged request succeeded
  T getRequestByTag<T>(String tag) {
    final index = _tagIndexMap[tag];
    if (index == null) {
      throw ArgumentError('Tag "$tag" not found in results');
    }
    return getRequestByIndex<T>(index);
  }
  
  /// Retrieves the result at the specified [index] with type safety.
  ///
  /// Returns the result cast to type [T]. Results are stored in the same order
  /// as requests were submitted to [zipRequest].
  ///
  /// Example:
  /// ```dart
  /// final firstResult = results.getRequestByIndex<UserInfo>(0);
  /// final secondResult = results.getRequestByIndex<List<Product>>(1);
  /// ```
  ///
  /// Throws:
  /// - [RangeError] if [index] is out of bounds [0, length)
  /// - The original error if the request at this index failed
  ///
  /// See also:
  /// - [getRequestByTag] for tag-based access
  /// - [isSuccess] to check if a request succeeded before accessing
  T getRequestByIndex<T>(int index) {
    if (index < 0 || index >= _results.length) {
      throw RangeError('Index $index out of range [0, ${_results.length})');
    }
    
    // Check if this request failed
    if (_errors.containsKey(index)) {
      throw _errors[index];
    }
    
    return _results[index] as T;
  }
  
  /// Provides index-based access to results using bracket notation.
  ///
  /// Returns the result as [dynamic]. For type-safe access, use [getRequestByIndex<T>].
  ///
  /// Example:
  /// ```dart
  /// final result = results[0]; // Returns dynamic
  /// final typedResult = results.getRequestByIndex<UserInfo>(0); // Type-safe
  /// ```
  ///
  /// Throws:
  /// - [RangeError] if [index] is out of bounds [0, length)
  /// - The original error if the request at this index failed
  ///
  /// Note: Prefer [getRequestByIndex<T>] for type safety.
  dynamic operator [](int index) {
    // Delegate to getRequestByIndex for consistent behavior
    return getRequestByIndex<dynamic>(index);
  }
  
  /// Checks whether the request at the specified [index] succeeded.
  ///
  /// Returns `true` if the request completed successfully, `false` if it failed.
  ///
  /// Example:
  /// ```dart
  /// if (results.isSuccess(0)) {
  ///   final result = results.getRequestByIndex<UserInfo>(0);
  ///   print('Request succeeded: $result');
  /// } else {
  ///   print('Request failed');
  /// }
  /// ```
  ///
  /// Parameters:
  /// - [index]: The zero-based index of the request
  ///
  /// See also:
  /// - [isSuccessByTag] for tag-based success checking
  /// - [errors] to get all error information
  bool isSuccess(int index) => !_errors.containsKey(index);
  
  /// Checks whether the request identified by [tag] succeeded.
  ///
  /// Returns `true` if the tagged request completed successfully, `false` if it
  /// failed or if the tag does not exist.
  ///
  /// Example:
  /// ```dart
  /// if (results.isSuccessByTag('user')) {
  ///   final user = results.getRequestByTag<UserInfo>('user');
  ///   print('User loaded: $user');
  /// }
  /// ```
  ///
  /// Parameters:
  /// - [tag]: The tag identifying the request
  ///
  /// See also:
  /// - [isSuccess] for index-based success checking
  /// - [getRequestByTag] to retrieve the result
  bool isSuccessByTag(String tag) {
    final index = _tagIndexMap[tag];
    return index != null && isSuccess(index);
  }
  
  /// Returns a list of all successful results, excluding failed requests.
  ///
  /// This is useful when using `eagerError: false` to collect all successful
  /// results while ignoring failures.
  ///
  /// Example:
  /// ```dart
  /// final results = await RxNet.zipRequest(requests, eagerError: false);
  /// final successful = results.successfulResults;
  /// print('${successful.length} out of ${results.length} requests succeeded');
  /// ```
  ///
  /// Returns: A list containing only the results from successful requests,
  /// in their original submission order.
  ///
  /// See also:
  /// - [errors] to get information about failed requests
  /// - [length] to get the total number of requests
  List<dynamic> get successfulResults {
    return _results
        .asMap()
        .entries
        .where((entry) => !_errors.containsKey(entry.key))
        .map((entry) => entry.value)
        .toList();
  }
  
  /// Returns an unmodifiable map of all errors from failed requests.
  ///
  /// The map keys are request indices, and values are the error objects.
  /// This property is only populated when using `eagerError: false`.
  ///
  /// Example:
  /// ```dart
  /// final results = await RxNet.zipRequest(requests, eagerError: false);
  /// if (results.errors.isNotEmpty) {
  ///   print('${results.errors.length} requests failed:');
  ///   results.errors.forEach((index, error) {
  ///     print('  Request $index: $error');
  ///   });
  /// }
  /// ```
  ///
  /// Returns: An unmodifiable map of index to error object.
  ///
  /// See also:
  /// - [successfulResults] to get only successful results
  /// - [isSuccess] to check if a specific request succeeded
  Map<int, dynamic> get errors => Map.unmodifiable(_errors);
  
  /// Returns the total number of requests in this result set.
  ///
  /// This includes both successful and failed requests.
  ///
  /// Example:
  /// ```dart
  /// print('Executed ${results.length} concurrent requests');
  /// print('${results.successfulResults.length} succeeded');
  /// print('${results.errors.length} failed');
  /// ```
  int get length => _results.length;
}
