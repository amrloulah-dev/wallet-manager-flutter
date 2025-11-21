class CacheManager {
  static final CacheManager _instance = CacheManager._internal();
  factory CacheManager() => _instance;
  CacheManager._internal();

  final Map<String, CachedData> _cache = {};
  static const Duration defaultCacheDuration = Duration(minutes: 5);

  void set<T>(String key, T data, {Duration? duration}) {
    _cache[key] = CachedData(
      data: data,
      duration: duration ?? defaultCacheDuration,
    );
  }

  T? get<T>(String key) {
    final cachedData = _cache[key];
    if (cachedData != null && !cachedData.isExpired) {
      return cachedData.data as T?;
    }
    _cache.remove(key);
    return null;
  }

  void clear(String key) {
    _cache.remove(key);
  }

  void clearAll() {
    _cache.clear();
  }

  void clearWhere(bool Function(String key) test) {
    _cache.removeWhere((key, value) => test(key));
  }

  void clearExpired() {
    _cache.removeWhere((key, value) => value.isExpired);
  }
}

class CachedData {
  final dynamic data;
  final DateTime timestamp;
  final Duration duration;

  CachedData({
    required this.data,
    required this.duration,
  }) : timestamp = DateTime.now();

  bool get isExpired => DateTime.now().difference(timestamp) > duration;
}
