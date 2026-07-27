import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ad_banner.dart';
import 'family_sync_service.dart';

class AdService {
  AdService({http.Client? client}) : _client = client ?? http.Client();

  static const _cacheKey = 'home_top_ad_cache';
  static const _cacheTimeKey = 'home_top_ad_cache_time';
  static const _cacheOriginKey = 'home_top_ad_cache_origin';
  static const _cacheDuration = Duration(minutes: 30);
  static const _maxStaleDuration = Duration(hours: 24);
  static const _requestTimeout = Duration(seconds: 8);

  final http.Client _client;
  int _requestId = 0;

  Future<AdBanner?> getHomeAd({bool forceRefresh = false}) async {
    final baseUri = Uri.tryParse(FamilySyncService.pocketBaseUrl);
    if (baseUri == null || baseUri.scheme != 'https' || baseUri.host.isEmpty) {
      return null;
    }
    final baseUrl = baseUri.toString().replaceFirst(RegExp(r'/$'), '');

    final preferences = await SharedPreferences.getInstance();
    final cacheMatchesOrigin =
        preferences.getString(_cacheOriginKey) == baseUrl;
    final cached = cacheMatchesOrigin ? _readCache(preferences) : null;
    final cachedAt = DateTime.tryParse(
      preferences.getString(_cacheTimeKey) ?? '',
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
      final ad = await _fetchHomeAd(baseUrl);
      if (requestId == _requestId) {
        if (ad == null) {
          await preferences.remove(_cacheKey);
        } else {
          await preferences.setString(_cacheKey, jsonEncode(ad.toJson()));
        }
        await preferences.setString(_cacheOriginKey, baseUrl);
        await preferences.setString(_cacheTimeKey, now.toIso8601String());
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

  Future<AdBanner?> _fetchHomeAd(String baseUrl) async {
    final filter = [
      'placement = "home_top"',
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

  AdBanner? _readCache(SharedPreferences preferences) {
    final value = preferences.getString(_cacheKey);
    if (value == null) return null;
    try {
      return AdBanner.fromJson(jsonDecode(value) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  void dispose() => _client.close();
}
