/// Centre of Abidjan — fallback when geolocation is unavailable or denied.
const double abidjanLat = 5.3599;
const double abidjanLng = -4.0083;

/// Stable amenity keys, ordered to match [L.amenities] (lib/i18n.dart).
const List<String> amenityKeys = [
  'wifi',
  'parking',
  'terrace',
  'clean_toilets',
  'delivery',
  'ac',
  'card',
];

/// Stable cuisine keys for the search-filter sheet, ordered to match
/// [L.cuisines] (lib/i18n.dart).
const List<String> searchCuisineKeys = [
  'ivoirienne',
  'maquis',
  'poisson',
  'libanais',
  'italien',
  'asiatique',
  'brunch_cafe',
  'patisserie',
];

/// Server sort keys (in the same order as [L.sortOptions]).
const List<String> sortKeys = ['relevance', 'top_rated', 'closest', 'newest'];

/// Display string for a price tier in 1..4. Server-side the API also accepts
/// the symbols, but this list is convenient for chip rendering.
const List<String> priceSymbols = ['₣', '₣₣', '₣₣₣', '₣₣₣₣'];

/// Sub-rating server keys (in the same order as [L.reviewCats]).
const List<String> reviewSubKeys = [
  'food',
  'menu',
  'staff',
  'toilet',
  'ambiance',
  'price',
  'wait',
  'wifi',
  'park',
];

/// Canonical (server-side) review tag labels — French-only because the
/// backend ships a FR tag vocabulary in v1. Indexed to match [L.reviewTagList].
const List<String> reviewTagsFr = [
  'Bon rapport qualité-prix',
  'Service rapide',
  'Toilettes propres',
  'Wifi correct',
  'Bonne ambiance',
  'Place pour bébés',
  'Climatisation',
  'CB acceptée',
  'Parking facile',
];
