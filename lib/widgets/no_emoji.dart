import 'package:flutter/services.dart';

/// No emoji in any text box (v1.12.49, 18 Nov 2026: "make in any characters
/// typing in every typebox in the app and web cannot be typed by any emoji").
///
/// Every TextField in the app takes [NoEmojiFormatter]
/// (test/no_emoji_test.dart checks that none is missed). Emoji, and what
/// builds them (skin tones, the joiner, presentation selectors, keycaps,
/// flags' letters and tags), are dropped as they are typed or pasted;
/// everything else goes in as typed, Tagalog's ñ included, and the cursor
/// stays where it was among what is left. The same ranges are dropped on the
/// web (the console's lib/noEmoji.js, the residents' site's account.js).
class NoEmojiFormatter extends TextInputFormatter {
  const NoEmojiFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (!containsEmoji(text)) return newValue;
    final kept = StringBuffer();
    // Where each old offset lands in the new text.
    final landing = List<int>.filled(text.length + 1, 0);
    var length = 0;
    final runes = text.runes.iterator;
    while (runes.moveNext()) {
      for (var k = 0; k < runes.currentSize; k++) {
        landing[runes.rawIndex + k] = length;
      }
      if (!isEmojiRune(runes.current)) {
        kept.write(runes.currentAsString);
        length += runes.currentSize;
      }
    }
    landing[text.length] = length;
    int at(int offset) =>
        offset < 0 ? offset : landing[offset.clamp(0, text.length)];
    final selection = newValue.selection;
    return TextEditingValue(
      text: kept.toString(),
      selection: selection.copyWith(
        baseOffset: at(selection.baseOffset),
        extentOffset: at(selection.extentOffset),
      ),
    );
  }
}

/// Whether [text] has anything [NoEmojiFormatter] drops.
bool containsEmoji(String text) => text.runes.any(isEmojiRune);

/// [text] without what [NoEmojiFormatter] drops.
String withoutEmoji(String text) =>
    String.fromCharCodes(text.runes.where((r) => !isEmojiRune(r)));

/// Whether [rune] is an emoji, or part of one.
bool isEmojiRune(int rune) =>
    // Pictographs, emoticons, transport, flags' letters, skin tones.
    (rune >= 0x1F000 && rune <= 0x1FAFF) ||
    // Weather, hearts, stars, checks and the other dingbats.
    (rune >= 0x2600 && rune <= 0x27BF) ||
    // The emoji among arrows, technical symbols, shapes and punctuation.
    (rune >= 0x2194 && rune <= 0x2199) ||
    rune == 0x21A9 ||
    rune == 0x21AA ||
    rune == 0x231A ||
    rune == 0x231B ||
    rune == 0x2328 ||
    rune == 0x23CF ||
    (rune >= 0x23E9 && rune <= 0x23F3) ||
    (rune >= 0x23F8 && rune <= 0x23FA) ||
    rune == 0x24C2 ||
    rune == 0x25AA ||
    rune == 0x25AB ||
    rune == 0x25B6 ||
    rune == 0x25C0 ||
    (rune >= 0x25FB && rune <= 0x25FE) ||
    rune == 0x2934 ||
    rune == 0x2935 ||
    (rune >= 0x2B05 && rune <= 0x2B07) ||
    rune == 0x2B1B ||
    rune == 0x2B1C ||
    rune == 0x2B50 ||
    rune == 0x2B55 ||
    rune == 0x203C ||
    rune == 0x2049 ||
    rune == 0x2139 ||
    rune == 0x3030 ||
    rune == 0x303D ||
    rune == 0x3297 ||
    rune == 0x3299 ||
    // What joins and dresses them: the joiner, presentation selectors, the
    // keycap, and the tag letters of subdivision flags.
    rune == 0x200D ||
    rune == 0xFE0E ||
    rune == 0xFE0F ||
    rune == 0x20E3 ||
    (rune >= 0xE0020 && rune <= 0xE007F);
