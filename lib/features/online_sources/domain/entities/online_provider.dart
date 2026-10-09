/// A site whose video servers the app plays from.
enum OnlineProvider {
  /// AniLibria's own releases, in its own voice-over.
  anilibria,

  /// yummy_anime's catalogue: many dubs, played through Kodik and Aksor.
  yummyAnime;

  /// The provider an online source link names, or null for an unknown one.
  static OnlineProvider? named(String name) {
    for (final provider in values) {
      if (provider.name == name) return provider;
    }
    return null;
  }
}
