/// Commercials, promo videos and music clips: listed by Shikimori, but
/// nothing to watch.
bool isPromoAnimeKind(String kind) =>
    const {'cm', 'pv', 'music'}.contains(kind);
