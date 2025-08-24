///
/// create_user: zhengzaihong
/// email:1096877329@qq.com
/// create_date: 2025/8/24
/// create_time: 18:29
/// describe: Content-Type 类型
///
class ContentTypes {
  ContentTypes._();
  static const String json = 'application/json';
  static const String formUrlEncoded = 'application/x-www-form-urlencoded';
  static const String multipartFormData = 'multipart/form-data';
  static const String plainText = 'text/plain';
  static const String html = 'text/html';
  static const String xml = 'application/xml';
  static const String octetStream = 'application/octet-stream';
  static const String pdf = 'application/pdf';
  static const String zip = 'application/zip';
  static const String csv = 'text/csv';
  static const String eventStream = 'text/event-stream';
  static const String javascript = 'application/javascript';
  static const String graphql = 'application/graphql';
  static const String ndJson = 'application/x-ndjson';
  static const String svg = 'image/svg+xml';
  static const String png = 'image/png';
  static const String jpeg = 'image/jpeg';
  static const String gif = 'image/gif';

  /// 可扩展自定义类型
  static String custom(String mimeType) => mimeType;
}
