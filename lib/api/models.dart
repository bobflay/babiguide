import 'client.dart' show resolveMediaUrl;

class UserPreferences {
  final List<String> cuisines;
  final String lang;
  final bool darkMode;
  final bool locationEnabled;
  final bool notificationsEnabled;

  const UserPreferences({
    this.cuisines = const [],
    this.lang = 'fr',
    this.darkMode = false,
    this.locationEnabled = false,
    this.notificationsEnabled = true,
  });

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      cuisines: (json['cuisines'] as List?)
              ?.map((e) => e.toString())
              .toList(growable: false) ??
          const [],
      lang: json['lang']?.toString() ?? 'fr',
      darkMode: json['dark_mode'] == true,
      locationEnabled: json['location_enabled'] == true,
      notificationsEnabled: json['notifications_enabled'] != false,
    );
  }
}

class User {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? avatarUrl;
  final UserPreferences preferences;

  const User({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.avatarUrl,
    this.preferences = const UserPreferences(),
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final prefs = json['preferences'];
    return User(
      id: json['id'].toString(),
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      avatarUrl: resolveMediaUrl(json['avatar_url']?.toString()),
      preferences: prefs is Map<String, dynamic>
          ? UserPreferences.fromJson(prefs)
          : const UserPreferences(),
    );
  }
}

class AuthResult {
  final String token;
  final User user;
  const AuthResult({required this.token, required this.user});

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    return AuthResult(
      token: json['token'].toString(),
      user: User.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}
