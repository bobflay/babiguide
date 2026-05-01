import 'app_state.dart';

class L {
  final BgLang lang;
  L(this.lang);

  bool get isFr => lang == BgLang.fr;

  String pick(String fr, String en) => isFr ? fr : en;

  // Splash
  String get splashTagline => pick("Le guide d'Abidjan", 'The Abidjan city guide');
  String get splashSub =>
      pick('Restaurants · Hôtels · Commerces', 'Restaurants · Hotels · Businesses');
  String get loading => pick('Chargement', 'Loading');

  // Onboarding
  String get skip => pick('Passer', 'Skip');
  String get next => pick('Suivant', 'Next');
  String get start => pick('Commencer', 'Get started');
  String get allow => pick('Autoriser', 'Allow');
  String get later => pick('Plus tard', 'Later');

  List<Map<String, String>> get onbSteps => [
        {
          'eyebrow': pick('Bienvenue', 'Welcome'),
          'title': pick(
            "Le guide d'Abidjan, écrit par les Abidjanais.",
            'The Abidjan guide, written by Abidjanais.',
          ),
          'body': pick(
            'Plus de 1 200 restaurants, hôtels et commerces — testés et notés par la communauté. Du maquis du quartier au resto chic du Plateau.',
            'Over 1,200 restaurants, hotels and businesses — tested and rated by the community. From the neighborhood maquis to fine dining in Plateau.',
          ),
        },
        {
          'eyebrow': pick('Localisation', 'Location'),
          'title': pick(
            'Trouvez les meilleures adresses près de vous.',
            'Find the best places near you.',
          ),
          'body': pick(
            "Activez la géolocalisation pour voir ce qui est ouvert maintenant à Cocody, Marcory, Plateau, Riviera et au-delà.",
            "Turn on location to see what's open right now in Cocody, Marcory, Plateau, Riviera and beyond.",
          ),
        },
      ];

  // Home
  String get greeting => pick('Bonsoir', 'Good evening');

  /// Greeting selected from the server's greeting_hint ("morning", "afternoon",
  /// "evening", "night"). Falls back to [greeting] for unknown hints.
  String greetingFor(String? hint) {
    switch (hint) {
      case 'morning':
        return pick('Bonjour', 'Good morning');
      case 'afternoon':
        return pick('Bon après-midi', 'Good afternoon');
      case 'evening':
        return pick('Bonsoir', 'Good evening');
      case 'night':
        return pick('Bonne nuit', 'Good night');
      default:
        return greeting;
    }
  }
  String get greetingSub =>
      pick('Que cherche-t-on ce soir à Abidjan ?', 'What are we hunting tonight in Abidjan?');
  String get searchHint =>
      pick('Rechercher un restaurant, un quartier…', 'Search a restaurant, a neighborhood…');
  String get nearMe => pick('Près de moi', 'Near me');
  String get topRated => pick('Mieux notés', 'Top rated');
  String get openNow => pick('Ouvert', 'Open now');
  String get sectionTrending => pick('Ça bouge cette semaine', 'Trending this week');
  String get sectionNew => pick('Nouveaux sur BabiGuide', 'New on BabiGuide');
  String get sectionNeighborhoods => pick('Par quartier', 'By neighborhood');
  String get seeAll => pick('Tout voir', 'See all');
  String get open => pick('Ouvert', 'Open');
  String get closed => pick('Fermé', 'Closed');
  String distance(double km) => isFr ? 'à $km km' : '$km km away';
  String reviewsCount(int n) => isFr ? '$n avis' : '$n reviews';
  String addresses(int n) => isFr ? '$n adresses' : '$n places';

  // Detail
  String get untilTime => pick("jusqu'à", 'until');
  String get overview => pick('Aperçu', 'Overview');
  String get menu => pick('Menu', 'Menu');
  String get photos => pick('Photos', 'Photos');
  String get reviews => pick('Avis', 'Reviews');
  String get sectionRatings => pick('Détails de la note', 'Rating breakdown');
  String get sectionPhotos => pick('Photos & vidéos', 'Photos & videos');
  String get sectionMenu => pick('Plats du moment', 'Today on the menu');
  String get sectionReviews => pick('Avis récents', 'Recent reviews');
  String get viewMenu => pick('Voir le menu complet', 'See full menu');
  String get write => pick('Écrire un avis', 'Write a review');
  String get call => pick('Appeler', 'Call');
  String get directions => pick('Itinéraire', 'Directions');
  String get facts => pick('Infos pratiques', 'Quick facts');
  String get based => pick('Basé sur', 'Based on');
  String get verified => pick('Vérifié', 'Verified');

  Map<String, String> get rateLabels => {
        'food': pick('Plats', 'Food'),
        'menu': pick('Carte', 'Menu'),
        'staff': pick('Service', 'Staff'),
        'toilet': pick('Toilettes', 'Toilets'),
        'ambiance': pick('Ambiance', 'Ambiance'),
        'price': pick('Prix', 'Price'),
        'wait': pick('Attente', 'Wait'),
        'wifi': pick('Wifi', 'Wifi'),
        'park': pick('Parking', 'Parking'),
      };

  String photoCount(int n) => isFr ? '$n photos' : '$n photos';
  String videoCount(int n) => isFr ? '$n vidéos' : '$n videos';

  // Search
  String get cancel => pick('Annuler', 'Cancel');
  String get searchPlaceholder => pick('maquis cocody', 'maquis cocody');
  String resultsFound(int n) =>
      isFr ? '$n adresses trouvées' : '$n places found';
  String get sort => pick('Trier', 'Sort');
  String get filter => pick('Filtrer', 'Filter');
  List<String> get searchChips => isFr
      ? const ['Tous', 'Ouvert', '< 2 km', '4★+', '₣₣ ou moins']
      : const ['All', 'Open now', '< 2 km', '4★+', '₣₣ or less'];
  List<String> get sortOptions => isFr
      ? const ['Pertinence', 'Mieux notés', 'Plus proches', 'Récents']
      : const ['Relevance', 'Top rated', 'Closest', 'Newest'];
  String get filterTitle => pick('Filtres', 'Filters');
  String get fCuisine => pick('Cuisine', 'Cuisine');
  String get fPrice => pick('Prix', 'Price');
  String get fAmenities => pick('Services', 'Amenities');
  String get fDistance => pick('Distance', 'Distance');
  String get apply => pick('Voir 142 résultats', 'See 142 results');
  String get reset => pick('Réinitialiser', 'Reset');
  List<String> get cuisines => isFr
      ? const [
          'Ivoirienne',
          'Maquis',
          'Poisson',
          'Libanais',
          'Italien',
          'Asiatique',
          'Brunch',
          'Pâtisserie'
        ]
      : const [
          'Ivorian',
          'Maquis',
          'Fish',
          'Lebanese',
          'Italian',
          'Asian',
          'Brunch',
          'Pastry'
        ];
  List<String> get amenities => isFr
      ? const [
          'Wifi gratuit',
          'Parking',
          'Terrasse',
          'Toilettes propres',
          'Livraison',
          'Climatisation',
          'Accepte CB'
        ]
      : const [
          'Free wifi',
          'Parking',
          'Terrace',
          'Clean toilets',
          'Delivery',
          'A/C',
          'Card accepted'
        ];
  String get distanceLabel => isFr ? 'à 2,5 km' : '2.5 km away';

  // Review
  String get reviewTitle => pick('Écrire un avis', 'Write a review');
  String get publish => pick('Publier', 'Publish');
  String get overall => pick('Note globale', 'Overall rating');
  String get breakdown => pick('Détail par catégorie', 'Category breakdown');
  String get reviewMedia => pick('Photos & vidéos', 'Photos & videos');
  String get reviewText => pick('Votre avis', 'Your review');
  String get reviewPlaceholder => pick(
      "Qu'avez-vous aimé ? Le service ? Les toilettes ? La cuisine ? Soyez concret pour aider la communauté.",
      'What did you like? The service? The toilets? The food? Be specific so others know what to expect.');
  String get reviewTags => pick('Étiquettes (optionnel)', 'Tags (optional)');
  String get pickFromGallery => pick('Photothèque', 'Photo Library');
  String get pickFromCamera => pick('Prendre une photo', 'Take a Photo');
  String get removePhoto => pick('Retirer', 'Remove');
  String get photoLimitReached => pick(
      'Vous pouvez ajouter jusqu’à 4 photos.',
      'You can add up to 4 photos.');
  String get photoUploadFailed => pick(
      'Échec du téléversement. Réessayez.',
      'Upload failed. Try again.');
  List<String> get reviewTagList => isFr
      ? const [
          'Bon rapport qualité-prix',
          'Service rapide',
          'Toilettes propres',
          'Wifi correct',
          'Bonne ambiance',
          'Place pour bébés',
          'Climatisation',
          'CB acceptée',
          'Parking facile'
        ]
      : const [
          'Good value',
          'Quick service',
          'Clean toilets',
          'Decent wifi',
          'Nice ambiance',
          'Baby-friendly',
          'A/C',
          'Cards accepted',
          'Easy parking'
        ];
  List<String> get reviewCats => isFr
      ? const [
          'Plats',
          'Carte',
          'Service',
          'Toilettes',
          'Ambiance',
          'Prix',
          'Attente',
          'Wifi',
          'Parking'
        ]
      : const [
          'Food',
          'Menu',
          'Staff',
          'Toilets',
          'Ambiance',
          'Price',
          'Wait',
          'Wifi',
          'Parking'
        ];
  String overallLabel(int v) {
    final fr = ['—', 'Décevant', 'Moyen', 'Correct', 'Très bien', 'Excellent'];
    final en = ['—', 'Disappointing', 'Average', 'Decent', 'Very good', 'Excellent'];
    final list = isFr ? fr : en;
    return list[v.clamp(0, 5)];
  }

  // Map
  String get listView => pick('Liste', 'List');
  String get mapHere => pick('Vous êtes ici', 'You are here');
  String get sponsored => pick('Sponsorisé', 'Sponsored');
  String get searchTheMap => pick('Rechercher sur la carte', 'Search the map');

  // Media
  String get mediaTitle => pick('Photos & vidéos', 'Photos & videos');
  List<String> get mediaTabs => isFr
      ? const ['Tous', 'Plats', 'Lieu', 'Toilettes', 'Staff', 'Vidéos']
      : const ['All', 'Food', 'Place', 'Toilets', 'Staff', 'Videos'];
  String get mediaBy => pick('par', 'by');
  String get of => pick('sur', 'of');

  // Tab bar labels
  String get tabHome => pick('Accueil', 'Home');
  String get tabDiscover => pick('Explorer', 'Discover');
  String get tabSaved => pick('Sauvés', 'Saved');
  String get tabProfile => pick('Profil', 'Profile');

  // For You (video feed)
  String get fypFor => pick('Pour toi', 'For you');
  String get fypFollow => pick('Suivis', 'Following');
  String get fypNear => pick('Près de moi', 'Near me');
  String get fypVisit => pick('Voir le restaurant', 'View restaurant');
  String get fypFollowAction => pick('Suivre', 'Follow');
  String get fypFollowing => pick('Suivi', 'Following');
  String get fypMore => pick('plus', 'more');
  String get fypCommentsTitle => pick('Commentaires', 'Comments');
  String get fypCommentPlaceholder =>
      pick('Ajouter un commentaire bienveillant…', 'Add a kind comment…');
  String get fypSend => pick('Envoyer', 'Send');
  String get fypReply => pick('Répondre', 'Reply');
}
