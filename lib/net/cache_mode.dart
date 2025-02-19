
///
/// create_user: zhengzaihong
/// email:1096877329@qq.com
/// create_date: 2022/8/11
/// create_time: 9:08
/// describe: RxNet 请求缓存策略模式
///
enum CacheMode {

  //没有缓存，仅仅发起请求
  onlyRequest,

  //只使用缓存
  onlyCache,

  //先请求网络，如果请求网络失败，则读取缓存，如果读取缓存失败，本次请求失败
  requestFailedReadCache,

  //先使用缓存，不管是否存在，仍然请求网络
  firstCacheThenRequest,

  //先使用缓存，无缓存或超过时效则请求网络
  cacheNoneToRequest;
}
