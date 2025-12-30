///
/// create_user: optimization
/// create_date: 2024-12-30
/// describe: 请求体类型枚举，明确参数发送方式
///
enum RequestBodyType {
  /// 默认：根据HTTP方法自动判断（GET/DELETE用query，POST/PUT/PATCH用body）
  auto,
  
  /// Query参数：拼接在URL后面 ?key=value
  query,
  
  /// JSON Body：application/json
  json,
  
  /// Form Data：multipart/form-data（文件上传）
  formData,
  
  /// URL Encoded：application/x-www-form-urlencoded
  urlEncoded,
}
