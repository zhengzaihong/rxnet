
///
/// create_user: zhengzaihong
/// email:1096877329@qq.com
/// create_date: 2022/8/11
/// create_time: 9:08
/// describe: RxNet 请求缓存策略
/// RxNet request caching strategy
///
enum CacheMode {

  //不做缓存，每次都发起请求
  //No caching, request every time
  ONLY_REQUEST,

  //只使用缓存，通常用于先预加载数据，切换到无网环境做数据显示
  //Only cache is used, which is usually used to preload data first and switch to a network-less environment for data display
  ONLY_CACHE,

  //先请求网络，如果请求网络失败，则读取缓存，如果读取缓存失败，本次请求失败
  //Request the network first. If the network request fails, the cache is read. If the cache fails, the request fails.
  REQUEST_FAILED_READ_CACHE,

  //先使用缓存显示，不管是否存在，仍然请求网络，新数据替换缓存数据，并触发上次数据刷新
  //Use cache display first, no matter whether it exists or not, still request the network, replace the cached data with new data, and trigger page refresh again
  FIRST_USE_CACHE_THEN_REQUEST,

  //先使用缓存，无缓存或缓存过期后再请求网络，否则不会请求网络
  //Use the cache first, and then request the network after there is no cache or the cache expires, otherwise the network will not be requested
  CACHE_EMPTY_OR_EXPIRED_THEN_REQUEST,
}
