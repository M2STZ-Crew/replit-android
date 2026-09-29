import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:replit/models/ph_mobile.dart';

/// A mobile number shapes itself into 09XX XXX XXXX as it is typed.
void main() {
  const formatter = PhMobileFormatter();

  /// Type [chars] one at a time at the end, as a person would.
  TextEditingValue typed(String chars) {
    var value = TextEditingValue.empty;
    for (final ch in chars.split('')) {
      final text = value.text + ch;
      value = formatter.formatEditUpdate(
        value,
        TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        ),
      );
    }
    return value;
  }

  /// Paste or autofill [text] into an empty field in one go.
  TextEditingValue pasted(String text) => formatter.formatEditUpdate(
    TextEditingValue.empty,
    TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    ),
  );

  test('typed digit by digit, it groups itself 4-3-4', () {
    expect(typed('0').text, '0');
    expect(typed('0917').text, '0917');
    expect(typed('09171').text, '0917 1');
    expect(typed('0917123').text, '0917 123');
    expect(typed('09171234').text, '0917 123 4');
    final full = typed('09171234567');
    expect(full.text, '0917 123 4567');
    expect(full.selection.baseOffset, full.text.length);
    expect(looksLikePhMobile(full.text), isTrue);
  });

  test('a number started without its 0 gets one', () {
    expect(typed('9171234567').text, '0917 123 4567');
  });

  test('+63 pasted or autofilled becomes 09', () {
    expect(pasted('+63 917-123-4567').text, '0917 123 4567');
    expect(pasted('639171234567').text, '0917 123 4567');
  });

  test('only digits, and never more than eleven', () {
    expect(typed('0917abc1234567').text, '0917 123 4567');
    expect(pasted('091712345678999').text, '0917 123 4567');
  });

  test('backspace over a space removes the digit before it', () {
    // "0917 123" with the cursor just after the space; backspace deletes it.
    final result = formatter.formatEditUpdate(
      const TextEditingValue(
        text: '0917 123',
        selection: TextSelection.collapsed(offset: 5),
      ),
      const TextEditingValue(
        text: '0917123',
        selection: TextSelection.collapsed(offset: 4),
      ),
    );
    expect(result.text, '0911 23');
    expect(result.selection.baseOffset, 3, reason: 'right where the 7 was');
  });

  test('typing in the middle keeps the cursor after the new digit', () {
    final result = formatter.formatEditUpdate(
      const TextEditingValue(
        text: '0917 123',
        selection: TextSelection.collapsed(offset: 2),
      ),
      const TextEditingValue(
        text: '09517 123',
        selection: TextSelection.collapsed(offset: 3),
      ),
    );
    expect(result.text, '0951 712 3');
    expect(result.selection.baseOffset, 3);
  });

  testWidgets('in a real field, and with the 09XX XXX XXXX placeholder', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: TextField(
            controller: controller,
            inputFormatters: const [PhMobileFormatter()],
            decoration: const InputDecoration(hintText: kPhMobileHint),
          ),
        ),
      ),
    );
    expect(find.text('09XX XXX XXXX'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '09171234567');
    expect(controller.text, '0917 123 4567');
  });
}
