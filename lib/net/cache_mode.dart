
enum CacheMode {

  ///没有缓存
  noCache,

  ///按照HTTP协议的默认缓存规则，例如有304响应头时缓存
  defaultMode,

  ///先请求网络，如果请求网络失败，则读取缓存，如果读取缓存失败，本次请求失败
  requestFailedReadCache,

  ///先使用缓存，不管是否存在，仍然请求网络
  firstCacheThenRequest,

  ///只使用缓存
  onlyCache;
}
