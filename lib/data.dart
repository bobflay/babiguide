// Static demo data shared across screens (mirrors the design's hardcoded seeds).
import 'api/client.dart' show resolveMediaUrl;

class Place {
  final String id;
  final String name;
  final String cuisine;
  final String neighborhood;
  final double rating;
  final int reviews;
  final String price;
  final double km;
  final bool open;
  final String seed;
  final String? tag;
  final String photoLabel;
  final String? photoUrl;

  const Place({
    required this.id,
    required this.name,
    required this.cuisine,
    required this.neighborhood,
    required this.rating,
    required this.reviews,
    required this.price,
    required this.km,
    required this.open,
    required this.seed,
    this.tag,
    required this.photoLabel,
    this.photoUrl,
  });

  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      id: json['id'].toString(),
      name: json['name']?.toString() ?? '',
      cuisine: json['cuisine']?.toString() ?? '',
      neighborhood: json['neighborhood']?.toString() ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviews: (json['reviews'] as num?)?.toInt() ?? 0,
      price: json['price']?.toString() ?? '',
      km: (json['km'] as num?)?.toDouble() ?? 0.0,
      open: json['open'] == true,
      seed: json['seed']?.toString() ?? json['id'].toString(),
      tag: json['tag']?.toString(),
      photoLabel: json['photo_label']?.toString() ?? '',
      photoUrl: resolveMediaUrl(json['photo_url']?.toString()),
    );
  }
}

class Neighborhood {
  final String id;
  final String name;
  final int count;
  final String seed;
  final String? photoUrl;
  const Neighborhood({
    required this.id,
    required this.name,
    required this.count,
    required this.seed,
    this.photoUrl,
  });

  factory Neighborhood.fromJson(Map<String, dynamic> json) {
    return Neighborhood(
      id: json['id'].toString(),
      name: json['name']?.toString() ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
      seed: json['seed']?.toString() ?? json['id'].toString(),
      photoUrl: resolveMediaUrl(json['photo_url']?.toString()),
    );
  }
}

const trending = [
  Place(
    id: 'norima',
    name: 'Chez Norima',
    cuisine: 'Cuisine ivoirienne · Attiéké',
    neighborhood: 'Cocody · Angré',
    rating: 4.8,
    reviews: 312,
    price: '₣₣',
    km: 1.2,
    open: true,
    seed: 'norima',
    tag: 'Coup de cœur',
    photoLabel: 'POULET BRAISÉ',
  ),
  Place(
    id: 'maquis17',
    name: 'Le Maquis 17',
    cuisine: 'Maquis · Grillades',
    neighborhood: 'Marcory · Zone 4',
    rating: 4.6,
    reviews: 187,
    price: '₣₣',
    km: 3.4,
    open: true,
    seed: 'maquis17',
    tag: 'Tendance',
    photoLabel: 'TERRASSE',
  ),
  Place(
    id: 'saveurs',
    name: 'Saveurs du Pays',
    cuisine: 'Foutou · Sauce graine',
    neighborhood: 'Yopougon · Selmer',
    rating: 4.7,
    reviews: 256,
    price: '₣',
    km: 5.8,
    open: false,
    seed: 'saveurs',
    tag: 'Local',
    photoLabel: 'FOUTOU SAUCE GRAINE',
  ),
];

const newPlaces = <Place>[
  Place(id: 'lagune', name: 'La Lagune', cuisine: 'Poisson braisé', neighborhood: '', rating: 4.5, reviews: 28, price: '', km: 0, open: true, seed: 'lagune', photoLabel: 'POISSON BRAISÉ'),
  Place(id: 'baoab', name: 'Baobab Café', cuisine: 'Brunch · Café', neighborhood: '', rating: 4.4, reviews: 41, price: '', km: 0, open: true, seed: 'baoab', photoLabel: 'CAFÉ TERRASSE'),
  Place(id: 'kedjenou', name: 'Le Kedjenou', cuisine: 'Cuisine du nord', neighborhood: '', rating: 4.6, reviews: 19, price: '', km: 0, open: true, seed: 'kedjenou', photoLabel: 'KEDJENOU'),
];

const neighborhoods = [
  Neighborhood(id: 'cocody', name: 'Cocody', count: 142, seed: 'cocody'),
  Neighborhood(id: 'plateau', name: 'Plateau', count: 98, seed: 'plateau'),
  Neighborhood(id: 'marcory', name: 'Marcory', count: 76, seed: 'marcory'),
  Neighborhood(id: 'treichville', name: 'Treichville', count: 64, seed: 'treich'),
  Neighborhood(id: 'yopougon', name: 'Yopougon', count: 53, seed: 'yopo'),
  Neighborhood(id: 'riviera', name: 'Riviera', count: 87, seed: 'riv'),
];

const searchResults = [
  Place(id: 's1', name: 'Chez Norima', cuisine: 'Cuisine ivoirienne · Maquis chic', neighborhood: 'Cocody · Angré', rating: 4.8, reviews: 312, price: '₣₣', km: 1.2, open: true, seed: 'r-norima', photoLabel: 'POULET BRAISÉ'),
  Place(id: 's2', name: 'Le Maquis 17', cuisine: 'Maquis · Grillades', neighborhood: 'Marcory · Zone 4', rating: 4.6, reviews: 187, price: '₣₣', km: 3.4, open: true, seed: 'r-maquis', photoLabel: 'TERRASSE'),
  Place(id: 's3', name: 'Saveurs du Pays', cuisine: 'Foutou · Sauce graine', neighborhood: 'Yopougon · Selmer', rating: 4.7, reviews: 256, price: '₣', km: 5.8, open: false, seed: 'r-saveurs', photoLabel: 'FOUTOU'),
  Place(id: 's4', name: 'La Lagune', cuisine: 'Poisson braisé', neighborhood: 'Plateau · Riviera', rating: 4.5, reviews: 142, price: '₣₣', km: 2.1, open: true, seed: 'r-lagune', photoLabel: 'POISSON'),
  Place(id: 's5', name: 'Le Kedjenou', cuisine: 'Cuisine du nord', neighborhood: 'Cocody · 2 Plateaux', rating: 4.6, reviews: 88, price: '₣₣', km: 0.9, open: true, seed: 'r-kedjenou', photoLabel: 'KEDJENOU'),
];

class SubRating {
  final String id;
  final String labelKey;
  final String iconKey;
  final double value;
  const SubRating(this.id, this.labelKey, this.iconKey, this.value);

  /// Server returns `{id, label, icon, value}`. Per the backend gotchas, the
  /// `label` is French-only — we ignore it and let the client localize from
  /// `id` via `L.rateLabels`.
  factory SubRating.fromJson(Map<String, dynamic> json) {
    final id = json['id'].toString();
    return SubRating(
      id,
      id,
      json['icon']?.toString() ?? id,
      (json['value'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

const subRatings = <SubRating>[
  SubRating('food', 'food', 'fork', 4.9),
  SubRating('menu', 'menu', 'money', 4.6),
  SubRating('staff', 'staff', 'staff', 4.8),
  SubRating('toilet', 'toilet', 'toilet', 4.4),
  SubRating('ambiance', 'ambiance', 'ambiance', 4.7),
  SubRating('price', 'price', 'money', 4.3),
  SubRating('wait', 'wait', 'clock', 4.2),
  SubRating('wifi', 'wifi', 'wifi', 4.0),
  SubRating('park', 'park', 'park', 4.5),
];

class GalleryItem {
  final String seed;
  final String label;
  final String kind; // photo / video
  final String? duration;
  final String cat;
  final String author;
  final String? when;
  final bool verified;
  final int span;
  // From the API:
  final String? id;
  final String? url;
  final String? thumbUrl;
  final String? category;

  const GalleryItem({
    required this.seed,
    required this.label,
    required this.kind,
    this.duration,
    required this.cat,
    required this.author,
    this.when,
    this.verified = false,
    this.span = 1,
    this.id,
    this.url,
    this.thumbUrl,
    this.category,
  });

  factory GalleryItem.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString();
    final author = json['author'];
    final authorName = author is Map ? author['name']?.toString() ?? '' : '';
    final authorVerified = author is Map ? author['verified'] == true : false;
    final categoryKey = json['category']?.toString();
    return GalleryItem(
      id: id,
      seed: json['seed']?.toString() ?? id ?? '',
      label: json['label']?.toString() ?? '',
      kind: json['kind']?.toString() ?? 'photo',
      duration: json['duration']?.toString(),
      cat: categoryKey ?? '',
      category: categoryKey,
      author: authorName,
      when: json['when']?.toString() ?? json['created_at']?.toString(),
      verified: authorVerified,
      span: (json['span'] as num?)?.toInt() ?? 1,
      url: resolveMediaUrl(json['url']?.toString()),
      thumbUrl: resolveMediaUrl(json['thumb_url']?.toString()),
    );
  }
}

const detailGallery = <GalleryItem>[
  GalleryItem(seed: 'g1', label: 'POULET BRAISÉ', kind: 'photo', cat: 'Plats', author: ''),
  GalleryItem(seed: 'g2', label: 'TERRASSE · SOIR', kind: 'video', duration: '0:24', cat: 'Lieu', author: ''),
  GalleryItem(seed: 'g3', label: 'ATTIÉKÉ POISSON', kind: 'photo', cat: 'Plats', author: ''),
  GalleryItem(seed: 'g4', label: 'SALLE · INTÉRIEUR', kind: 'photo', cat: 'Lieu', author: ''),
  GalleryItem(seed: 'g5', label: 'TOILETTES', kind: 'photo', cat: 'Toilettes', author: ''),
  GalleryItem(seed: 'g6', label: 'STAFF · CUISINE', kind: 'video', duration: '0:38', cat: 'Staff', author: ''),
  GalleryItem(seed: 'g7', label: 'ALLOCO', kind: 'photo', cat: 'Plats', author: ''),
  GalleryItem(seed: 'g8', label: 'KEDJENOU', kind: 'photo', cat: 'Plats', author: ''),
];

class MenuHighlight {
  final String? id;
  final String name;
  final String desc;
  final String price;
  final String seed;
  final String label;
  final String? photoUrl;
  final String? category;

  const MenuHighlight({
    required this.name,
    required this.desc,
    required this.price,
    required this.seed,
    required this.label,
    this.id,
    this.photoUrl,
    this.category,
  });

  factory MenuHighlight.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString();
    final rawCategory = json['category']?.toString();
    return MenuHighlight(
      id: id,
      name: json['name']?.toString() ?? '',
      desc: json['description']?.toString() ?? '',
      price: json['price']?.toString() ?? '',
      seed: json['seed']?.toString() ?? id ?? '',
      label: json['label']?.toString() ?? '',
      photoUrl: resolveMediaUrl(json['photo_url']?.toString()),
      category: (rawCategory != null && rawCategory.isNotEmpty)
          ? rawCategory
          : null,
    );
  }
}

const menuHighlights = <MenuHighlight>[
  MenuHighlight(
    category: 'Entrées',
    name: "Salade d'avocat & crevettes",
    desc: 'Avocat mûr, crevettes grillées, vinaigrette citron',
    price: '4 500 F',
    seed: 'm0',
    label: 'SALADE AVOCAT',
  ),
  MenuHighlight(
    category: 'Entrées',
    name: 'Aloko piquant',
    desc: 'Bananes plantains frites, sauce tomate pimentée',
    price: '2 500 F',
    seed: 'm0b',
    label: 'ALOKO',
  ),
  MenuHighlight(
    category: 'Plats principaux',
    name: 'Poulet braisé entier',
    desc: "Mariné 24h, accompagné d'attiéké et alloco",
    price: '8 500 F',
    seed: 'm1',
    label: 'POULET BRAISÉ',
  ),
  MenuHighlight(
    category: 'Plats principaux',
    name: 'Kedjenou de pintade',
    desc: "Mijoté à l'étouffée, légumes du marché",
    price: '11 000 F',
    seed: 'm2',
    label: 'KEDJENOU',
  ),
  MenuHighlight(
    category: 'Plats principaux',
    name: 'Poisson braisé du jour',
    desc: 'Capitaine ou tilapia · sauce piment vert',
    price: '9 500 F',
    seed: 'm3',
    label: 'POISSON BRAISÉ',
  ),
  MenuHighlight(
    category: 'Desserts',
    name: 'Beignets coco',
    desc: 'Servis tièdes, sucre vanillé',
    price: '2 000 F',
    seed: 'm4',
    label: 'BEIGNETS',
  ),
  MenuHighlight(
    category: 'Boissons',
    name: 'Bissap maison',
    desc: 'Hibiscus infusé, gingembre, citron vert',
    price: '1 500 F',
    seed: 'm5',
    label: 'BISSAP',
  ),
  MenuHighlight(
    category: 'Boissons',
    name: 'Gnamakoudji',
    desc: 'Jus de gingembre frais, ananas',
    price: '1 500 F',
    seed: 'm6',
    label: 'GNAMAKOUDJI',
  ),
];

class ReviewItem {
  final String name;
  final String when;
  final int rating;
  final String text;
  final Map<String, int> sub;
  final List<String> pics;
  final String avatar;
  // From the API:
  final String? id;
  final String? authorId;
  final String? avatarUrl;
  final List<String> tags;
  final List<GalleryItem> media;
  final int helpfulCount;
  final bool userMarkedHelpful;

  const ReviewItem({
    required this.name,
    required this.when,
    required this.rating,
    required this.text,
    required this.sub,
    required this.pics,
    required this.avatar,
    this.id,
    this.authorId,
    this.avatarUrl,
    this.tags = const [],
    this.media = const [],
    this.helpfulCount = 0,
    this.userMarkedHelpful = false,
  });

  factory ReviewItem.fromJson(Map<String, dynamic> json) {
    final author = json['author'];
    final authorMap = author is Map ? Map<String, dynamic>.from(author) : null;
    final authorName = authorMap?['name']?.toString() ?? '';
    final avatarChar = authorMap?['avatar']?.toString();
    final fallbackAvatar =
        avatarChar ?? (authorName.isNotEmpty ? authorName[0].toUpperCase() : '?');

    final subRaw = json['sub'];
    final sub = <String, int>{};
    if (subRaw is Map) {
      subRaw.forEach((k, v) {
        if (v is num) sub[k.toString()] = v.toInt();
      });
    }

    final mediaRaw = json['media'];
    final media = mediaRaw is List
        ? mediaRaw
            .whereType<Map>()
            .map((e) => GalleryItem.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false)
        : const <GalleryItem>[];

    final tagsRaw = json['tags'];
    final tags = tagsRaw is List
        ? tagsRaw.map((e) => e.toString()).toList(growable: false)
        : const <String>[];

    return ReviewItem(
      id: json['id']?.toString(),
      authorId: authorMap?['id']?.toString(),
      avatarUrl: authorMap?['avatar_url']?.toString(),
      name: authorName,
      when: json['when']?.toString() ?? json['created_at']?.toString() ?? '',
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      text: json['text']?.toString() ?? '',
      sub: sub,
      pics: media.map((m) => m.seed).toList(growable: false),
      media: media,
      avatar: fallbackAvatar,
      tags: tags,
      helpfulCount: (json['helpful_count'] as num?)?.toInt() ?? 0,
      userMarkedHelpful: json['user_marked_helpful'] == true,
    );
  }
}

const reviews = <ReviewItem>[
  ReviewItem(
    name: 'Mariam K.',
    when: 'il y a 3 jours',
    rating: 5,
    text:
        "Le poulet braisé est juste parfait, mariné comme il faut. Service souriant et toilettes impeccables — détail qui change tout. Cadre cosy en terrasse le soir.",
    sub: {'food': 5, 'staff': 5, 'toilet': 5},
    pics: ['r1a', 'r1b'],
    avatar: 'M',
  ),
  ReviewItem(
    name: 'Yao D.',
    when: 'il y a 1 sem.',
    rating: 4,
    text:
        "Très bonne ambiance, le kedjenou vaut le détour. Petit bémol sur l'attente du dimanche — prévoir 20 minutes. Wifi correct.",
    sub: {'food': 5, 'ambiance': 5, 'wait': 3},
    pics: ['r2a'],
    avatar: 'Y',
  ),
];

const mediaItems = <GalleryItem>[
  GalleryItem(seed: 'mg1', label: 'POULET BRAISÉ', kind: 'photo', cat: 'Plats', author: 'Mariam K.', when: '3j', span: 2),
  GalleryItem(seed: 'mg2', label: 'TERRASSE SOIR', kind: 'video', duration: '0:24', cat: 'Lieu', author: 'Yao D.', when: '1sem'),
  GalleryItem(seed: 'mg3', label: 'ATTIÉKÉ POISSON', kind: 'photo', cat: 'Plats', author: 'Sandra A.'),
  GalleryItem(seed: 'mg4', label: 'SALLE INTÉRIEUR', kind: 'photo', cat: 'Lieu', author: 'Norima', verified: true),
  GalleryItem(seed: 'mg5', label: 'TOILETTES', kind: 'photo', cat: 'Toilettes', author: 'Mariam K.'),
  GalleryItem(seed: 'mg6', label: 'STAFF CUISINE', kind: 'video', duration: '0:38', cat: 'Staff', author: 'Norima', verified: true, span: 2),
  GalleryItem(seed: 'mg7', label: 'ALLOCO', kind: 'photo', cat: 'Plats', author: 'Kouadio J.'),
  GalleryItem(seed: 'mg8', label: 'KEDJENOU', kind: 'photo', cat: 'Plats', author: 'Yao D.'),
  GalleryItem(seed: 'mg9', label: 'BAR', kind: 'photo', cat: 'Lieu', author: 'Norima', verified: true),
  GalleryItem(seed: 'mg10', label: 'POISSON BRAISÉ', kind: 'photo', cat: 'Plats', author: 'Aïcha B.'),
  GalleryItem(seed: 'mg11', label: 'CHEF AU TRAVAIL', kind: 'photo', cat: 'Staff', author: 'Norima', verified: true, span: 2),
  GalleryItem(seed: 'mg12', label: 'JUS DE GINGEMBRE', kind: 'photo', cat: 'Plats', author: 'Sandra A.'),
  GalleryItem(seed: 'mg13', label: 'LAVABO', kind: 'photo', cat: 'Toilettes', author: 'Mariam K.'),
  GalleryItem(seed: 'mg14', label: 'GARÇON', kind: 'photo', cat: 'Staff', author: 'Yao D.'),
  GalleryItem(seed: 'mg15', label: 'DEVANTURE NUIT', kind: 'video', duration: '0:18', cat: 'Lieu', author: 'Aïcha B.'),
  GalleryItem(seed: 'mg16', label: 'RIZ GRAS', kind: 'photo', cat: 'Plats', author: 'Kouadio J.'),
  GalleryItem(seed: 'mg17', label: 'GÂTEAU', kind: 'photo', cat: 'Plats', author: 'Sandra A.'),
  GalleryItem(seed: 'mg18', label: 'TABLE DRESSÉE', kind: 'photo', cat: 'Lieu', author: 'Mariam K.', span: 2),
];

const Map<String, int> mediaCountsByTab = {
  'Tous': 34, 'Plats': 18, 'Lieu': 7, 'Toilettes': 3, 'Staff': 4, 'Vidéos': 6,
  'All': 34, 'Food': 18, 'Place': 7, 'Toilets': 3, 'Videos': 6,
};

class MapMarker {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final double rating;
  final String price;
  final bool verified;
  final bool open;
  final bool sponsored;

  const MapMarker({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.rating,
    required this.price,
    required this.verified,
    required this.open,
    required this.sponsored,
  });

  factory MapMarker.fromJson(Map<String, dynamic> json) {
    return MapMarker(
      id: json['id'].toString(),
      name: json['name']?.toString() ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      price: json['price']?.toString() ?? '',
      verified: json['verified'] == true,
      open: json['open'] == true,
      sponsored: json['sponsored'] == true,
    );
  }
}

class DayHours {
  final int day;
  final String open;
  final String close;
  const DayHours({required this.day, required this.open, required this.close});

  factory DayHours.fromJson(Map<String, dynamic> json) {
    return DayHours(
      day: (json['day'] as num?)?.toInt() ?? 0,
      open: json['open']?.toString() ?? '',
      close: json['close']?.toString() ?? '',
    );
  }
}

class DetailPlace {
  final String id;
  final String name;
  final String cuisine;
  final String neighborhood;
  final double rating;
  final int reviews;
  final String price;
  final bool verified;
  final int photoCount;
  final int videoCount;
  final String? tag;
  final String? address;
  final String? phone;
  final bool openNow;
  final String? todayUntil;
  final List<DayHours> weeklyHours;
  final double? lat;
  final double? lng;
  final List<String> amenities;
  final bool isFavorited;
  final String? shareUrl;
  final String? coverPhotoUrl;
  final String seed;
  final String? photoLabel;

  const DetailPlace({
    required this.name,
    required this.cuisine,
    required this.neighborhood,
    required this.rating,
    required this.reviews,
    required this.price,
    required this.verified,
    required this.photoCount,
    required this.videoCount,
    this.id = '',
    this.tag,
    this.address,
    this.phone,
    this.openNow = false,
    this.todayUntil,
    this.weeklyHours = const [],
    this.lat,
    this.lng,
    this.amenities = const [],
    this.isFavorited = false,
    this.shareUrl,
    this.coverPhotoUrl,
    this.seed = '',
    this.photoLabel,
  });

  factory DetailPlace.fromJson(Map<String, dynamic> json) {
    final hours = json['hours'];
    bool openNow = false;
    String? todayUntil;
    final List<DayHours> weekly = [];
    if (hours is Map) {
      openNow = hours['open_now'] == true;
      todayUntil = hours['today_until']?.toString();
      final w = hours['weekly'];
      if (w is List) {
        for (final e in w) {
          if (e is Map) {
            weekly.add(DayHours.fromJson(Map<String, dynamic>.from(e)));
          }
        }
      }
    }
    final loc = json['location'];
    double? lat;
    double? lng;
    if (loc is Map) {
      lat = (loc['lat'] as num?)?.toDouble();
      lng = (loc['lng'] as num?)?.toDouble();
    }
    final amenities = json['amenities'];
    return DetailPlace(
      id: json['id'].toString(),
      name: json['name']?.toString() ?? '',
      cuisine: json['cuisine']?.toString() ?? '',
      neighborhood: json['neighborhood']?.toString() ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviews: (json['reviews'] as num?)?.toInt() ?? 0,
      price: json['price']?.toString() ?? '',
      verified: json['verified'] == true,
      photoCount: (json['photo_count'] as num?)?.toInt() ?? 0,
      videoCount: (json['video_count'] as num?)?.toInt() ?? 0,
      tag: json['tag']?.toString(),
      address: json['address']?.toString(),
      phone: json['phone']?.toString(),
      openNow: openNow,
      todayUntil: todayUntil,
      weeklyHours: weekly,
      lat: lat,
      lng: lng,
      amenities: amenities is List
          ? amenities.map((e) => e.toString()).toList(growable: false)
          : const [],
      isFavorited: json['is_favorited'] == true,
      shareUrl: json['share_url']?.toString(),
      coverPhotoUrl: resolveMediaUrl(json['photo_url']?.toString() ??
          json['cover_photo_url']?.toString()),
      seed: json['seed']?.toString() ?? json['id'].toString(),
      photoLabel: json['photo_label']?.toString(),
    );
  }
}

const detailPlace = DetailPlace(
  name: 'Chez Norima',
  cuisine: 'Cuisine ivoirienne · Maquis chic',
  neighborhood: 'Cocody · Angré · 8e tranche',
  rating: 4.8,
  reviews: 312,
  price: '₣₣',
  verified: true,
  photoCount: 28,
  videoCount: 6,
);
