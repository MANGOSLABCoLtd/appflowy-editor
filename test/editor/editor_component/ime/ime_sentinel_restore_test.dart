import 'package:appflowy_editor/src/editor/editor_component/service/ime/non_delta_input_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// The service prefixes the platform text with a sentinel space so a backspace
// at the very start is still reported. When the platform deletes that sentinel
// and the document does not change (the only paragraph is already empty), the
// platform and the service disagree by one character. The next keystroke then
// re-attaches and pushes `setEditingState` while the IME is composing, which
// resets iOS Korean composition ("값" became "ㄱㅏㅂㅅ").
void main() {
  NonDeltaTextInputService buildService() {
    return NonDeltaTextInputService(
      onInsert: (_) async => true,
      onDelete: (_) async => true,
      onReplace: (_) async => true,
      onNonTextUpdate: (_) async => true,
      onPerformAction: (_) async {},
    );
  }

  List<MethodCall> setEditingStateCalls(WidgetTester tester) {
    return tester.testTextInput.log
        .where((call) => call.method == 'TextInput.setEditingState')
        .toList();
  }

  testWidgets(
      'restores the sentinel as soon as the platform deletes it, '
      'so the first composed character is not overwritten', (tester) async {
    final service = buildService();
    const configuration = TextInputConfiguration();

    // Empty paragraph: the platform holds only the sentinel.
    service.attach(
      const TextEditingValue(selection: TextSelection.collapsed(offset: 0)),
      configuration,
    );
    expect(tester.testTextInput.editingState!['text'], ' ');

    // Backspace at the very start deletes the sentinel on the platform side.
    tester.testTextInput.log.clear();
    service.updateEditingValue(
      const TextEditingValue(selection: TextSelection.collapsed(offset: 0)),
    );
    await tester.pump(const Duration(milliseconds: 20));

    expect(service.currentTextEditingValue?.text, ' ');
    final restorePushes = setEditingStateCalls(tester);
    expect(restorePushes, hasLength(1));
    // What the platform holds now: the restored value if it was pushed.
    final platformText =
        restorePushes.isEmpty ? '' : tester.testTextInput.editingState!['text'];

    // The first jamo of a syllable arrives, then the editor re-attaches with
    // the document value after inserting it.
    tester.testTextInput.log.clear();
    service.updateEditingValue(
      TextEditingValue(
        text: '$platformTextㄱ',
        selection: TextSelection.collapsed(offset: '$platformTextㄱ'.length),
      ),
    );
    await tester.pump(const Duration(milliseconds: 20));
    service.attach(
      const TextEditingValue(
        text: 'ㄱ',
        selection: TextSelection.collapsed(offset: 1),
      ),
      configuration,
    );

    expect(
      setEditingStateCalls(tester),
      isEmpty,
      reason: 'pushing state mid-composition resets the IME',
    );
  });

  testWidgets('does not push while the platform is composing', (tester) async {
    final service = buildService();

    service.attach(
      const TextEditingValue(selection: TextSelection.collapsed(offset: 0)),
      const TextInputConfiguration(),
    );
    tester.testTextInput.log.clear();

    // A platform value without the sentinel but with an active composing
    // range must be left to the IME.
    service.updateEditingValue(
      const TextEditingValue(
        text: 'ㄱ',
        selection: TextSelection.collapsed(offset: 1),
        composing: TextRange(start: 0, end: 1),
      ),
    );
    await tester.pump(const Duration(milliseconds: 20));

    expect(setEditingStateCalls(tester), isEmpty);
  });

  testWidgets('leaves a value that still starts with the sentinel alone',
      (tester) async {
    final service = buildService();

    service.attach(
      const TextEditingValue(
        text: 'A',
        selection: TextSelection.collapsed(offset: 1),
      ),
      const TextInputConfiguration(),
    );
    tester.testTextInput.log.clear();

    // Deleting "A" keeps the sentinel.
    service.updateEditingValue(
      const TextEditingValue(
        text: ' ',
        selection: TextSelection.collapsed(offset: 1),
      ),
    );
    await tester.pump(const Duration(milliseconds: 20));

    expect(setEditingStateCalls(tester), isEmpty);
    expect(service.currentTextEditingValue?.text, ' ');
  });
}
