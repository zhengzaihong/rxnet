## 0.6.1

### Breaking Changes
- **Replaced Hive with Sembast** - Complete migration to pure Dart database solution
  - ⚠️ **Important:** Cache data will be reset after upgrade (old Hive data will not be migrated)
  - ✅ True cross-platform support including Web (IndexedDB) and HarmonyOS
  - ✅ Pure Dart implementation - no native dependencies
  - ✅ Better Web platform support with automatic IndexedDB backend
  - ✅ Simplified API with same interface as before

### Fixed
- **Code Quality Improvements** - Removed unused imports and deprecated code
  - Fixed breakpoint download flow to correctly consume adapter responses and streamed payloads
  - Fixed `breakPointDownload()` so resumed downloads work with `HttpAdapter`
  - Fixed request-body length detection for string/byte payloads in the generic request builder
  - Removed unused `_DioInterceptorBridge` class (deprecated in 0.6.0)
  - Improved code maintainability and reduced warnings
- **URL Path Normalization** - Fixed multiple slashes in request URLs
  - Fixed issue where `baseUrl` ending with `/` and `path` starting with `/` caused double slashes
  - Automatically removes multiple consecutive slashes in paths (e.g., `//api///v1` → `/api/v1`)
  - Preserves protocol double slashes (`://`) correctly
  - Works with both regular and RESTful paths
  - No user code changes required - automatic normalization
- **Web Platform Support** - Fixed adapters on Web platform
  - Fixed DioAdapter on Web platform using platform-specific factory functions
  - Fixed HttpAdapter: Used conditional import for dart:io
  - Fixed "Unsupported operation: Platform._version" error
  - Fixed Chinese character encoding in HttpAdapter using utf8.decode
  - Automatic platform detection, no user code changes required
- **HttpAdapter Compatibility** - Closed several behavior gaps in the lightweight adapter
  - Added multipart upload support for regular `upload()` flows
  - Preserved `ResponseType.stream` instead of forcing it through bytes-only handling
  - Improved upload/download progress accounting and header handling
  - Kept cancellation behavior cooperative while aligning request/response handling with DioAdapter expectations

### Changed
- **Database Backend** - Migrated from Hive to Sembast
  - `RxNetDataBase` now uses Sembast for all platforms
  - Web platform automatically uses IndexedDB
  - Other platforms use file system storage
  - API remains the same - no code changes needed for users
  - Added new methods: `getAllKeys()`, `count()`, `close()`
- **Architecture Simplification** - Removed CacheManager middleware
  - RxNet now directly uses RxNetDataBase instance
  - Simplified architecture with fewer abstraction layers
  - Better performance with reduced method call overhead
  - Added `getDatabase()` and `getDefaultDatabase()` methods

### Documentation
- **Updated Documentation** - Clarified interceptor execution flow
  - Added comments explaining why `_DioInterceptorBridge` was removed
  - Improved inline documentation for adapter architecture
  - Updated README adapter capability notes and breakpoint upload/download examples
  - Corrected `HttpAdapter` limitation notes to match current behavior
  - Added detailed comments for Sembast implementation
  - Removed outdated "Web platform does not support cache" notes
  - Created comprehensive migration guides

### Migration Guide
If you were using custom database configuration:

**Before (0.6.0):**
```dart
await RxNet.init(
  baseUrl: "...",
  // Hive-specific parameters (no longer supported)
);
```

**After (0.6.1):**
```dart
await RxNet.init(
  baseUrl: "...",
  // Sembast works automatically - no configuration needed
  // Cache data will be stored in platform-appropriate location
);
```

**Note:** Existing cache data from Hive will not be automatically migrated. The cache will be rebuilt on first use.

### Performance
- Minor performance improvements from code cleanup
- Reduced package analysis warnings from 14 to 0
- Sembast provides comparable or better performance than Hive on most platforms

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
