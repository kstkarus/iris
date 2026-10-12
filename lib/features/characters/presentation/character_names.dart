import 'package:iris/features/characters/domain/entities/anime_character.dart';
import 'package:iris/features/characters/domain/entities/character_summary.dart';
import 'package:iris/l10n/generated/app_localizations.dart';

/// The name a reader of [l10n]'s language knows: the Russian one in
/// Russian, where there is one. Both are mostly the same name in another
/// script, so lists show only this one.
String characterName(AppLocalizations l10n, CharacterSummary character) =>
    l10n.localeName == 'ru' && character.russian.trim().isNotEmpty
    ? character.russian.trim()
    : character.name.trim();

/// The name [characterName] leaves out, when it says something else.
String? otherCharacterName(AppLocalizations l10n, CharacterSummary character) {
  final shown = characterName(l10n, character);
  final other = shown == character.name.trim()
      ? character.russian.trim()
      : character.name.trim();
  if (other.isEmpty || other.toLowerCase() == shown.toLowerCase()) return null;
  return other;
}

/// Main characters first, then the rest, each by the name shown.
List<AnimeCharacter> charactersInOrder(
  AppLocalizations l10n,
  List<AnimeCharacter> characters,
) {
  final names = {
    for (final item in characters)
      item: characterName(l10n, item.character).toLowerCase(),
  };
  return characters.toList()..sort((a, b) {
    final byRole = a.role.index.compareTo(b.role.index);
    if (byRole != 0) return byRole;
    return names[a]!.compareTo(names[b]!);
  });
}

String formatCharacterRole(AppLocalizations l10n, CharacterRole role) =>
    switch (role) {
      CharacterRole.main => l10n.characterRoleMain,
      CharacterRole.supporting => l10n.characterRoleSupporting,
    };
