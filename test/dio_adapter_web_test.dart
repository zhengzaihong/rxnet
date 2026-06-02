import 'package:flutter_test/flutter_test.dart';
import 'package:rxnet_plus/rxnet_lib.dart';

void main() {
  test('DioAdapter should be created without Platform._version error', () {
    // 这个测试验证 DioAdapter 可以在不访问 Platform._version 的情况下创建
    // This test verifies that DioAdapter can be created without accessing Platform._version
    
    expect(() {
      final adapter = DioAdapter();
      expect(adapter, isNotNull);
      expect(adapter.name, 'DioAdapter');
    }, returnsNormally);
  });
  
  test('DioAdapter.withOptions should create adapter with BaseOptions', () {
    // 测试使用 BaseOptions 创建 DioAdapter
    // Test creating DioAdapter with BaseOptions
    
    final options = BaseOptions(
      baseUrl: 'https://api.example.com',
      connectTimeout: Duration(seconds: 30),
    );
    
    final adapter = DioAdapter.withOptions(options);
    
    expect(adapter, isNotNull);
    expect(adapter.dio.options.baseUrl, 'https://api.example.com');
    expect(adapter.dio.options.connectTimeout, Duration(seconds: 30));
  });
}
