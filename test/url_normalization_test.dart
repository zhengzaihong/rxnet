import 'package:flutter_test/flutter_test.dart';
import 'package:rxnet_plus/rxnet_lib.dart';

void main() {
  group('URL Normalization Tests', () {
    test('should handle single slash between baseUrl and path', () {
      final request = AdapterRequest(
        baseUrl: 'https://ylhh.vip',
        path: '/api/v1/music/findKWMusicById3',
        method: HttpMethod.GET,
      );
      
      expect(
        request.buildFullUrl(),
        'https://ylhh.vip/api/v1/music/findKWMusicById3',
      );
    });
    
    test('should remove double slash when baseUrl ends with slash', () {
      final request = AdapterRequest(
        baseUrl: 'https://ylhh.vip/',
        path: '/api/v1/music/findKWMusicById3',
        method: HttpMethod.GET,
      );
      
      expect(
        request.buildFullUrl(),
        'https://ylhh.vip/api/v1/music/findKWMusicById3',
      );
    });
    
    test('should remove multiple slashes in path', () {
      final request = AdapterRequest(
        baseUrl: 'https://ylhh.vip',
        path: '//api///v1//music/findKWMusicById3',
        method: HttpMethod.GET,
      );
      
      expect(
        request.buildFullUrl(),
        'https://ylhh.vip/api/v1/music/findKWMusicById3',
      );
    });
    
    test('should handle baseUrl with trailing slash and path with leading slashes', () {
      final request = AdapterRequest(
        baseUrl: 'https://ylhh.vip/',
        path: '//api/v1/music/findKWMusicById3',
        method: HttpMethod.GET,
      );
      
      expect(
        request.buildFullUrl(),
        'https://ylhh.vip/api/v1/music/findKWMusicById3',
      );
    });
    
    test('should handle path without leading slash', () {
      final request = AdapterRequest(
        baseUrl: 'https://ylhh.vip',
        path: 'api/v1/music/findKWMusicById3',
        method: HttpMethod.GET,
      );
      
      expect(
        request.buildFullUrl(),
        'https://ylhh.vip/api/v1/music/findKWMusicById3',
      );
    });
    
    test('should preserve protocol double slash', () {
      final request = AdapterRequest(
        baseUrl: 'https://ylhh.vip/',
        path: '/api/v1/music',
        method: HttpMethod.GET,
      );
      
      final url = request.buildFullUrl();
      expect(url.startsWith('https://'), true);
      expect(url, 'https://ylhh.vip/api/v1/music');
    });
    
    test('should handle full URL in path', () {
      final request = AdapterRequest(
        baseUrl: 'https://ylhh.vip',
        path: 'https://other.com//api///v1/music',
        method: HttpMethod.GET,
      );
      
      expect(
        request.buildFullUrl(),
        'https://other.com/api/v1/music',
      );
    });
    
    test('should handle RESTful parameters with normalization', () {
      final request = AdapterRequest(
        baseUrl: 'https://ylhh.vip/',
        path: '//api/v1/users/{id}//posts/{postId}',
        method: HttpMethod.GET,
        pathParams: {'id': '123', 'postId': '456'},
      );
      
      expect(
        request.buildFullUrl(),
        'https://ylhh.vip/api/v1/users/123/posts/456',
      );
    });
    
    test('should handle trailing slash in path', () {
      final request = AdapterRequest(
        baseUrl: 'https://ylhh.vip',
        path: '/api/v1/music/',
        method: HttpMethod.GET,
      );
      
      expect(
        request.buildFullUrl(),
        'https://ylhh.vip/api/v1/music/',
      );
    });
    
    test('should handle http protocol', () {
      final request = AdapterRequest(
        baseUrl: 'http://ylhh.vip/',
        path: '//api/v1/music',
        method: HttpMethod.GET,
      );
      
      expect(
        request.buildFullUrl(),
        'http://ylhh.vip/api/v1/music',
      );
    });
  });
}
