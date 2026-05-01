import 'package:dio/dio.dart';
import '../data.dart';
import 'api_error.dart';
import 'client.dart';

class HomeFeed {
  final List<Place> trending;
  final List<Place> newPlaces;
  final List<Neighborhood> neighborhoods;
  final String? greetingHint;

  const HomeFeed({
    required this.trending,
    required this.newPlaces,
    required this.neighborhoods,
    this.greetingHint,
  });

  factory HomeFeed.fromJson(Map<String, dynamic> json) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) parse) {
      final raw = json[key];
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => parse(Map<String, dynamic>.from(e)))
          .toList(growable: false);
    }

    return HomeFeed(
      trending: list('trending', Place.fromJson),
      newPlaces: list('new_places', Place.fromJson),
      neighborhoods: list('neighborhoods', Neighborhood.fromJson),
      greetingHint: json['greeting_hint']?.toString(),
    );
  }
}

class PagedList<T> {
  final List<T> items;
  final int total;
  final String? nextCursor;
  const PagedList({required this.items, required this.total, this.nextCursor});
}

class MediaPage {
  final List<GalleryItem> items;
  final Map<String, int> countsByCategory;
  final String? nextCursor;
  const MediaPage({
    required this.items,
    required this.countsByCategory,
    this.nextCursor,
  });
}

class PlacesApi {
  final ApiClient _client;
  PlacesApi(this._client);

  Future<PagedList<Place>> getPlaces({
    String? q,
    double? lat,
    double? lng,
    String? sort,
    bool? openNow,
    double? maxDistanceKm,
    double? minRating,
    List<String>? price,
    List<String>? cuisines,
    List<String>? amenities,
    String? neighborhood,
    String? cursor,
    int? limit,
  }) async {
    try {
      final res = await _client.dio.get(
        '/places',
        queryParameters: {
          'q': ?q,
          'lat': ?lat,
          'lng': ?lng,
          'sort': ?sort,
          'open_now': ?openNow,
          'max_distance_km': ?maxDistanceKm,
          'min_rating': ?minRating,
          'price': ?(price != null && price.isNotEmpty ? price.join(',') : null),
          'cuisines':
              ?(cuisines != null && cuisines.isNotEmpty ? cuisines.join(',') : null),
          'amenities':
              ?(amenities != null && amenities.isNotEmpty ? amenities.join(',') : null),
          'neighborhood': ?neighborhood,
          'cursor': ?cursor,
          'limit': ?limit,
        },
      );
      final data = res.data as Map<String, dynamic>;
      final items = (data['items'] as List?)
              ?.whereType<Map>()
              .map((e) => Place.fromJson(Map<String, dynamic>.from(e)))
              .toList(growable: false) ??
          const [];
      return PagedList<Place>(
        items: items,
        total: (data['total'] as num?)?.toInt() ?? items.length,
        nextCursor: data['next_cursor']?.toString(),
      );
    } on DioException catch (e) {
      throw ApiError.fromDio(e);
    }
  }

  Future<List<SearchSuggestion>> getSuggestions({
    required String q,
    double? lat,
    double? lng,
  }) async {
    try {
      final res = await _client.dio.get(
        '/search/suggestions',
        queryParameters: {
          'q': q,
          'lat': ?lat,
          'lng': ?lng,
        },
      );
      final data = res.data;
      if (data is! Map) return const [];
      final raw = data['suggestions'];
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => SearchSuggestion.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
    } on DioException catch (e) {
      throw ApiError.fromDio(e);
    }
  }

  Future<List<Neighborhood>> getNeighborhoods() async {
    try {
      final res = await _client.dio.get('/neighborhoods');
      final body = res.data;
      final list = body is List
          ? body
          : (body is Map && body['data'] is List ? body['data'] as List : null);
      if (list == null) return const [];
      return list
          .whereType<Map>()
          .map((e) => Neighborhood.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
    } on DioException catch (e) {
      throw ApiError.fromDio(e);
    }
  }

  Future<HomeFeed> getHome({double? lat, double? lng}) async {
    try {
      final res = await _client.dio.get(
        '/home',
        queryParameters: {
          'lat': ?lat,
          'lng': ?lng,
        },
      );
      return HomeFeed.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiError.fromDio(e);
    }
  }

  Future<DetailPlace> getPlace(String slug) async {
    try {
      final res = await _client.dio.get('/places/$slug');
      final body = res.data;
      final raw = body is Map && body['data'] is Map
          ? body['data'] as Map
          : body as Map;
      return DetailPlace.fromJson(Map<String, dynamic>.from(raw));
    } on DioException catch (e) {
      throw ApiError.fromDio(e);
    }
  }

  Future<List<SubRating>> getSubRatings(String slug) async {
    try {
      final res = await _client.dio.get('/places/$slug/sub_ratings');
      final data = res.data;
      if (data is! List) return const [];
      return data
          .whereType<Map>()
          .map((e) => SubRating.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
    } on DioException catch (e) {
      throw ApiError.fromDio(e);
    }
  }

  Future<List<MenuHighlight>> getMenu(String slug) async {
    try {
      final res = await _client.dio.get('/places/$slug/menu');
      final body = res.data;
      final list = body is List
          ? body
          : (body is Map && body['data'] is List ? body['data'] as List : null);
      if (list == null) return const [];
      return list
          .whereType<Map>()
          .map((e) => MenuHighlight.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
    } on DioException catch (e) {
      throw ApiError.fromDio(e);
    }
  }

  Future<PagedList<ReviewItem>> getReviews(
    String slug, {
    String sort = 'recent',
    String? cursor,
    int? limit,
  }) async {
    try {
      final res = await _client.dio.get(
        '/places/$slug/reviews',
        queryParameters: {
          'sort': sort,
          'cursor': ?cursor,
          'limit': ?limit,
        },
      );
      final body = res.data;
      final List rawItems;
      int? total;
      String? nextCursor;
      if (body is Map && body['items'] is List) {
        rawItems = body['items'] as List;
        total = (body['total'] as num?)?.toInt();
        nextCursor = body['next_cursor']?.toString();
      } else if (body is Map && body['data'] is List) {
        rawItems = body['data'] as List;
      } else {
        rawItems = const [];
      }
      final items = rawItems
          .whereType<Map>()
          .map((e) => ReviewItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
      return PagedList<ReviewItem>(
        items: items,
        total: total ?? items.length,
        nextCursor: nextCursor,
      );
    } on DioException catch (e) {
      throw ApiError.fromDio(e);
    }
  }

  Future<MediaPage> getMedia(
    String slug, {
    String category = 'all',
    String? cursor,
    int? limit,
  }) async {
    try {
      final res = await _client.dio.get(
        '/places/$slug/media',
        queryParameters: {
          'category': category,
          'cursor': ?cursor,
          'limit': ?limit,
        },
      );
      final data = res.data as Map<String, dynamic>;
      final items = (data['items'] as List?)
              ?.whereType<Map>()
              .map((e) => GalleryItem.fromJson(Map<String, dynamic>.from(e)))
              .toList(growable: false) ??
          const [];
      final counts = <String, int>{};
      final raw = data['counts_by_category'];
      if (raw is Map) {
        raw.forEach((k, v) {
          if (v is num) counts[k.toString()] = v.toInt();
        });
      }
      return MediaPage(
        items: items,
        countsByCategory: counts,
        nextCursor: data['next_cursor']?.toString(),
      );
    } on DioException catch (e) {
      throw ApiError.fromDio(e);
    }
  }

  Future<MapMarkers> getMarkers({
    required double swLat,
    required double swLng,
    required double neLat,
    required double neLng,
    String? q,
    List<String>? cuisines,
    double? minRating,
    bool? openNow,
  }) async {
    try {
      final res = await _client.dio.get(
        '/map/markers',
        queryParameters: {
          'sw_lat': swLat,
          'sw_lng': swLng,
          'ne_lat': neLat,
          'ne_lng': neLng,
          'q': ?q,
          'cuisines':
              ?(cuisines != null && cuisines.isNotEmpty ? cuisines.join(',') : null),
          'min_rating': ?minRating,
          'open_now': ?openNow,
        },
      );
      final data = res.data as Map<String, dynamic>;
      final raw = data['markers'];
      final markers = raw is List
          ? raw
              .whereType<Map>()
              .map((e) => MapMarker.fromJson(Map<String, dynamic>.from(e)))
              .toList(growable: false)
          : const <MapMarker>[];
      return MapMarkers(
        markers: markers,
        truncated: data['truncated'] == true,
      );
    } on DioException catch (e) {
      throw ApiError.fromDio(e);
    }
  }

  Future<String> sharePlace(String slug) async {
    try {
      final res = await _client.dio.post('/places/$slug/share');
      final data = res.data;
      if (data is Map && data['share_url'] != null) {
        return data['share_url'].toString();
      }
      throw ApiError(message: 'Missing share_url in response');
    } on DioException catch (e) {
      throw ApiError.fromDio(e);
    }
  }
}

class MapMarkers {
  final List<MapMarker> markers;
  final bool truncated;
  const MapMarkers({required this.markers, required this.truncated});
}

class SearchSuggestion {
  /// "place" | "neighborhood" | "cuisine" | "query"
  final String type;
  final String? id;
  final String label;
  final String? sub;

  const SearchSuggestion({
    required this.type,
    required this.label,
    this.id,
    this.sub,
  });

  factory SearchSuggestion.fromJson(Map<String, dynamic> json) {
    return SearchSuggestion(
      type: json['type']?.toString() ?? 'query',
      id: json['id']?.toString(),
      label: json['label']?.toString() ?? '',
      sub: json['sub']?.toString(),
    );
  }
}
