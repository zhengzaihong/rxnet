## 0.6.0 

### Added
- **Pluggable Adapter Architecture** - Choose the HTTP client that fits your needs
- **DioAdapter** - Full-featured adapter (default, backward compatible)
- **HttpAdapter** - Lightweight alternative based on dart:http package
- **MockAdapter** - Testing adapter with no network calls
- **Custom Adapter Support** - Implement `NetworkAdapter` interface for custom clients
- **Unified Interceptor System** - Adapter-agnostic interceptor interface
- **Comprehensive Documentation** - Migration guide, API docs, and custom adapter tutorial

### Changed
- RxNet now uses `NetworkAdapter` abstraction instead of direct Dio dependency
- Dio remains the default adapter for 100% backward compatibility
- Interceptor system now uses unified `AdapterInterceptor` interface

### Performance
- < 1% overhead compared to direct library usage
- 213k-370k operations/second for type conversion
- Negligible memory overhead

### Migration
- **No code changes required** for existing users
- Simply update version: `rxnet_plus: ^0.6.0`
- Optional: Explicitly specify adapter for advanced use cases
- See `MIGRATION_GUIDE_0.6.0.md` for details

### Documentation
- Added `MIGRATION_GUIDE_0.6.0.md` - Complete migration guide
- Added `docs/custom_adapter_guide.md` - Custom adapter tutorial with GraphQL example
- Added `lib/adapters/README.md` - Adapter selection guide
- Updated README.md with adapter architecture explanation
- Comprehensive dartdoc comments for all public APIs

### Testing
- 172 tests passing, 0 failures
- ~85-90% test coverage
- Property-based tests for adapter correctness
- Integration tests for backward compatibility

## 0.5.0
- ** Clarify parameter types ** -Separation of path parameters, query parameters, and Body parameters
- **RESTful automatic detection ** -No manual settings required
- **API semantic ** -Method names are more intuitive
- ** Low-level reconstruction ** -update `BuildRequest`
- harmony cache plug-in optimization


## 0.4.3
- Optimize requests support generic requests, which can obtain expected results and eliminate the trouble of generic conversions
- harmony cache plug-in optimization
- 
## 0.4.2
- Support retrofit RESTFul style @path style request
- 
## 0.4.1
- fix bug
- 
## 0.4.0
- The overall architecture has been redesigned to make it more elegant and easier to get started
- 
## 0.3.1
- Fixed some bugs in the callback pattern


## 0.2.2
- Code optimization, api simplification optimization
- Other bug modifications
- 
## 0.2.1
- Fixed post form parameter bug
- Code optimization, new APIs, etc.