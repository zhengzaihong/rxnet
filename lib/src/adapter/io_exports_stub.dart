/// Web/Wasm 平台不导出 dart:io 专用适配器。
///
/// 该文件仅用于 `rxnet_lib.dart` 的条件导出，
/// 保持 IO 平台仍可导出 `IOHttpClientAdapter` / `IOClient`。
library;