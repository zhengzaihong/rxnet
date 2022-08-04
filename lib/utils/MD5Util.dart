import 'package:crypto/crypto.dart';

class MD5Util {
  static String generateMd5(String data) {
    var digest = md5.convert(data.codeUnits);
    return digest.toString();
  }
}
