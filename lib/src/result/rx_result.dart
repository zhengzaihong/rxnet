
import '../../rxnet_lib.dart';

///
/// author: ZhengZaiHong
/// email:1096877329@qq.com
/// date: 2023/9/14
/// time: 16:21
/// describe:  响应结果包装类
///
class RxResult<T> {
  T? _value;
  final Object? error;
  SourcesType model;

  RxResult._({T? value, this.error, this.model = SourcesType.net})
      : _value = value;

  /// 向后兼容的构造方式，value 可能为 null
  factory RxResult({T? value, SourcesType model = SourcesType.net}) {
    return RxResult._(value: value, model: model);
  }

  /// 成功结果的推荐构造方式，value 必定非 null
  factory RxResult.success(T value, {SourcesType model = SourcesType.net}) {
    return RxResult._(value: value, model: model);
  }

  factory RxResult.error(Object error) {
    return RxResult._(error: error);
  }

  /// 获取结果值。
  /// 注意：返回类型为 T?，即使 isSuccess 为 true 也可能为 null（向后兼容）。
  /// 推荐使用 [requiredValue] 代替。
  T? get value => _value;

  /// 获取结果值（非 null 版本）。
  /// 当 [isSuccess] 为 true 时必定返回非 null 值；否则抛出 [StateError]。
  T get requiredValue {
    if (isError) {
      throw StateError('Cannot access requiredValue on an error result: $error');
    }
    if (_value == null) {
      throw StateError(
          'requiredValue is null. Use RxResult.success(value) to ensure non-null, '
          'or check value != null before accessing requiredValue.');
    }
    return _value as T;
  }

  bool get isSuccess => error == null;
  bool get isError => error != null;
}