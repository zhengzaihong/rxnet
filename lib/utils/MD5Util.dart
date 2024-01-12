import 'package:crypto/crypto.dart';

class MD5Util {
  MD5Util._();
  static String generateMd5(String data) {
    var digest = md5.convert(data.codeUnits);
    return digest.toString();
  }
}
