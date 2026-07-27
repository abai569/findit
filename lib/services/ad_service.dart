import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ad_banner.dart';
import 'family_sync_service.dart';

class AdService {
  AdService({http.Client? client}) : _client = client ?? http.Client();

  static const _cacheKeyPrefix = 'ad_cache';
  static const _cacheListKeyPrefix = 'ad_cache_list';
  static const _cacheTimeKeyPrefix = 'ad_cache_time';
  static const _cacheOriginKeyPrefix = 'ad_cache_origin';
  static const _cacheDuration = Duration(minutes: 30);
  static const _maxStaleDuration = Duration(hours: 24);
  static const _requestTimeout = Duration(seconds: 8);
  static const _maxAdsPerPlacement = 5;

  final http.Client _client;
  int _requestId = 0;

  String _cacheKey(String placement) => '$_cacheKeyPrefix:$placement';
  String _cacheListKey(String placement) => '$_cacheListKeyPrefix:$placement';
  String _cacheListTimeKey(String placement) =>
      '$_cacheListKeyPrefix:time:$placement';
  String _cacheListOriginKey(String placement) =>
      '$_cacheListKeyPrefix:origin:$placement';
  String _cacheTimeKey(String placement) =>
      '$_cacheTimeKeyPrefix:$placement';
  String _cacheOriginKey(String placement) =>
      '$_cacheOriginKeyPrefix:$placement';

  Future<AdBanner?> getHomeAd({bool forceRefresh = false}) =>
      getAd('home_top', forceRefresh: forceRefresh);

  Future<AdBanner?> getAd(String placement,
      {bool forceRefresh = false}) async {
    final baseUri = Uri.tryParse(FamilySyncService.pocketBaseUrl);
    if (baseUri == null || baseUri.scheme != 'https' || baseUri.host.isEmpty) {
      return null;
    }
    final baseUrl = baseUri.toString().replaceFirst(RegExp(r'/$'), '');

    final preferences = await SharedPreferences.getInstance();
    final cacheMatchesOrigin =
        preferences.getString(_cacheOriginKey(placement)) == baseUrl;
    final cached =
        cacheMatchesOrigin ? _readCache(preferences, placement) : null;
    final cachedAt = DateTime.tryParse(
      preferences.getString(_cacheTimeKey(placement)) ?? '',
    );
    final now = DateTime.now().toUtc();
    final cacheAge = cacheMatchesOrigin && cachedAt != null
        ? now.difference(cachedAt.toUtc())
        : null;

    if (!forceRefresh &&
        cacheAge != null &&
        !cacheAge.isNegative &&
        cacheAge < _cacheDuration &&
        cached?.isActiveAt(now) == true) {
      return cached;
    }

    final requestId = ++_requestId;
    try {
      final ad = await _fetchAd(placement, baseUrl);
      if (requestId == _requestId) {
        if (ad == null) {
          await preferences.remove(_cacheKey(placement));
        } else {
          await preferences.setString(
              _cacheKey(placement), jsonEncode(ad.toJson()));
        }
        await preferences.setString(_cacheOriginKey(placement), baseUrl);
        await preferences.setString(
            _cacheTimeKey(placement), now.toIso8601String());
      }
      return ad;
    } catch (_) {
      final canUseStaleCache = cacheAge != null &&
          !cacheAge.isNegative &&
          cacheAge < _maxStaleDuration &&
          cached?.isActiveAt(now) == true;
      return canUseStaleCache ? cached : null;
    }
  }

  Future<List<AdBanner>> getAds(String placement,
      {bool forceRefresh = false}) async {
    final baseUri = Uri.tryParse(FamilySyncService.pocketBaseUrl);
    if (baseUri == null || baseUri.scheme != 'https' || baseUri.host.isEmpty) {
      return const [];
    }
    final baseUrl = baseUri.toString().replaceFirst(RegExp(r'/$'), '');

    final preferences = await SharedPreferences.getInstance();
    final cacheMatchesOrigin =
        preferences.getString(_cacheListOriginKey(placement)) == baseUrl;
    final cached =
        cacheMatchesOrigin ? _readCacheList(preferences, placement) : null;
    final cachedAt = DateTime.tryParse(
      preferences.getString(_cacheListTimeKey(placement)) ?? '',
    );
    final now = DateTime.now().toUtc();
    final cacheAge = cacheMatchesOrigin && cachedAt != null
        ? now.difference(cachedAt.toUtc())
        : null;

    final hasActiveCache = cached != null &&
        cached.any((ad) => ad.isActiveAt(now));

    if (!forceRefresh &&
        cacheAge != null &&
        !cacheAge.isNegative &&
        cacheAge < _cacheDuration &&
        hasActiveCache) {
      return cached!;
    }

    final requestId = ++_requestId;
    try {
      final ads = await _fetchAds(placement, baseUrl);
      if (requestId == _requestId) {
        if (ads.isEmpty) {
          await preferences.remove(_cacheListKey(placement));
        } else {
          await preferences.setString(
              _cacheListKey(placement),
              jsonEncode(ads.map((a) => a.toJson()).toList()));
        }
        await preferences.setString(_cacheListOriginKey(placement), baseUrl);
        await preferences.setString(
            _cacheListTimeKey(placement), now.toIso8601String());
      }
      return ads;
    } catch (_) {
      return cached ?? const [];
    }
  }

  Future<AdBanner?> _fetchAd(String placement, String baseUrl) async {
    final filter = [
      'placement = "$placement"',
      'enabled = true',
      '(starts_at = "" || starts_at <= @now)',
      '(ends_at = "" || ends_at >= @now)',
    ].join(' && ');
    final uri = Uri.parse('$baseUrl/api/collections/ads/records').replace(
      queryParameters: {
        'page': '1',
        'perPage': '1',
        'sort': '-priority,-updated',
        'filter': filter,
      },
    );
    final response = await _client.get(uri).timeout(_requestTimeout);
    if (response.statusCode != 200) {
      throw http.ClientException('Failed to load advertisement', uri);
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final items = body['items'] as List<dynamic>? ?? const [];
    if (items.isEmpty) return null;
    final ad = AdBanner.fromRecord(
      items.first as Map<String, dynamic>,
      pocketBaseUrl: baseUrl,
    );
    if (ad.id.isEmpty || ad.imageUrl.isEmpty) return null;
    return ad;
  }

  Future<List<AdBanner>> _fetchAds(String placement, String baseUrl) async {
    final filter = [
      'placement = "$placement"',
      'enabled = true',
      '(starts_at = "" || starts_at <= @now)',
      '(ends_at = "" || ends_at >= @now)',
    ].join(' && ');
    final uri = Uri.parse('$baseUrl/api/collections/ads/records').replace(
      queryParameters: {
        'page': '1',
        'perPage': _maxAdsPerPlacement.toString(),
        'sort': '-priority,-updated',
        'filter': filter,
      },
    );
    final response = await _client.get(uri).timeout(_requestTimeout);
    if (response.statusCode != 200) {
      throw http.ClientException('Failed to load advertisements', uri);
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final items = body['items'] as List<dynamic>? ?? const [];
    return items
        .map((item) => AdBanner.fromRecord(
              item as Map<String, dynamic>,
              pocketBaseUrl: baseUrl,
            ))
        .where((ad) => ad.id.isNotEmpty && ad.imageUrl.isNotEmpty)
        .toList();
  }

  AdBanner? _readCache(SharedPreferences preferences, String placement) {
    final value = preferences.getString(_cacheKey(placement));
    if (value == null) return null;
    try {
      return AdBanner.fromJson(jsonDecode(value) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  List<AdBanner>? _readCacheList(
      SharedPreferences preferences, String placement) {
    final value = preferences.getString(_cacheListKey(placement));
    if (value == null) return null;
    try {
      final list = jsonDecode(value) as List<dynamic>;
      return list
          .map((e) => AdBanner.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  void dispose() => _client.close();
}
