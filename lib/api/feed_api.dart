import 'package:dio/dio.dart';
import 'api_error.dart';
import 'client.dart';

class FeedAuthor {
  final String id;
  final String type;
  final String name;
  final String? avatarUrl;
  final bool verified;

  const FeedAuthor({
    required this.id,
    required this.type,
    required this.name,
    this.avatarUrl,
    this.verified = false,
  });

  bool get isPlace => type == 'place';

  factory FeedAuthor.fromJson(Map<String, dynamic> json) {
    return FeedAuthor(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'user',
      name: json['name']?.toString() ?? '',
      avatarUrl: resolveMediaUrl(json['avatar_url']?.toString()),
      verified: json['verified'] == true,
    );
  }
}

class FeedPlace {
  final String id;
  final String slug;
  final String name;
  final String? photoUrl;
  final String? cuisine;
  final String? neighborhood;
  final String? address;
  final double rating;
  final int reviewsCount;
  final int? priceTier;
  final String? priceLabel;
  final bool verified;
  final bool isOpenNow;
  final double? lat;
  final double? lng;
  final String? shareUrl;

  const FeedPlace({
    required this.id,
    required this.slug,
    required this.name,
    this.photoUrl,
    this.cuisine,
    this.neighborhood,
    this.address,
    this.rating = 0.0,
    this.reviewsCount = 0,
    this.priceTier,
    this.priceLabel,
    this.verified = false,
    this.isOpenNow = false,
    this.lat,
    this.lng,
    this.shareUrl,
  });

  factory FeedPlace.fromJson(Map<String, dynamic> json) {
    return FeedPlace(
      id: json['id']?.toString() ?? '',
      slug: json['slug']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      photoUrl: resolveMediaUrl(json['photo_url']?.toString()),
      cuisine: json['cuisine']?.toString(),
      neighborhood: json['neighborhood']?.toString(),
      address: json['address']?.toString(),
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviewsCount: (json['reviews_count'] as num?)?.toInt() ?? 0,
      priceTier: (json['price_tier'] as num?)?.toInt(),
      priceLabel: json['price_label']?.toString(),
      verified: json['verified'] == true,
      isOpenNow: json['is_open_now'] == true,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      shareUrl: json['share_url']?.toString(),
    );
  }
}

class FeedVideo {
  final String id;
  final String url;
  final String? thumbUrl;
  final String? seed;
  final String? label;
  final String kind;
  final int? duration;
  final String? category;
  final FeedAuthor author;
  final FeedPlace place;
  final String? when;
  final String? createdAt;

  const FeedVideo({
    required this.id,
    required this.url,
    required this.author,
    required this.place,
    this.thumbUrl,
    this.seed,
    this.label,
    this.kind = 'video',
    this.duration,
    this.category,
    this.when,
    this.createdAt,
  });

  factory FeedVideo.fromJson(Map<String, dynamic> json) {
    final authorMap = json['author'];
    final placeMap = json['place'];
    return FeedVideo(
      id: json['id']?.toString() ?? '',
      url: resolveMediaUrl(json['url']?.toString()) ?? '',
      thumbUrl: resolveMediaUrl(json['thumb_url']?.toString()),
      seed: json['seed']?.toString(),
      label: json['label']?.toString(),
      kind: json['kind']?.toString() ?? 'video',
      duration: (json['duration'] as num?)?.toInt(),
      category: json['category']?.toString(),
      author: authorMap is Map
          ? FeedAuthor.fromJson(Map<String, dynamic>.from(authorMap))
          : const FeedAuthor(id: '', type: 'user', name: ''),
      place: placeMap is Map
          ? FeedPlace.fromJson(Map<String, dynamic>.from(placeMap))
          : const FeedPlace(id: '', slug: '', name: ''),
      when: json['when']?.toString(),
      createdAt: json['created_at']?.toString(),
    );
  }
}

class FeedPage {
  final List<FeedVideo> items;
  final int total;
  final String? nextCursor;

  const FeedPage({
    required this.items,
    required this.total,
    this.nextCursor,
  });
}

class FeedApi {
  final ApiClient _client;
  FeedApi(this._client);

  Future<FeedPage> getVideos({int? page, int? limit}) async {
    try {
      final res = await _client.dio.get(
        '/feed/videos',
        queryParameters: {
          'page': ?page,
          'limit': ?limit,
        },
      );
      final data = res.data;
      final body = data is Map<String, dynamic>
          ? data
          : (data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{});
      final items = (body['items'] as List?)
              ?.whereType<Map>()
              .map((e) => FeedVideo.fromJson(Map<String, dynamic>.from(e)))
              .where((v) => v.url.isNotEmpty)
              .toList(growable: false) ??
          const <FeedVideo>[];
      return FeedPage(
        items: items,
        total: (body['total'] as num?)?.toInt() ?? items.length,
        nextCursor: body['next_cursor']?.toString(),
      );
    } on DioException catch (e) {
      throw ApiError.fromDio(e);
    }
  }
}
