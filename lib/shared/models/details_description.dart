import 'package:iris/shared/utils/equality.dart';

typedef DescriptionCharacterLink = ({int start, int end, String characterId});

class DetailsDescription {
  const DetailsDescription(this.text, {this.characterLinks = const []});

  final String text;

  /// Links in reading order, with offsets into [text].
  final List<DescriptionCharacterLink> characterLinks;

  @override
  bool operator ==(Object other) =>
      other is DetailsDescription &&
      other.text == text &&
      sameList(other.characterLinks, characterLinks);

  @override
  int get hashCode => Object.hash(text, Object.hashAll(characterLinks));
}
