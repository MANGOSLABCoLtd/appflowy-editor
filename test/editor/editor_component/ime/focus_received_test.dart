import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_editor/src/editor/editor_component/service/ime/non_delta_input_service.dart';
import 'package:appflowy_editor/src/editor/editor_component/service/ime/text_input_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final useDelta in [true, false]) {
    testWidgets(
        'focus callback preserves the active ${useDelta ? 'delta' : 'non-delta'} IME connection',
        (tester) async {
      final callbacks = <String>[];
      final TextInputService service = useDelta
          ? DeltaTextInputService(
              onInsert: (_) async {
                callbacks.add('insert');
                return true;
              },
              onDelete: (_) async {
                callbacks.add('delete');
                return true;
              },
              onReplace: (_) async {
                callbacks.add('replace');
                return true;
              },
              onNonTextUpdate: (_) async {
                callbacks.add('selection');
                return true;
              },
              onPerformAction: (_) async {
                callbacks.add('action');
              },
            )
          : NonDeltaTextInputService(
              onInsert: (_) async {
                callbacks.add('insert');
                return true;
              },
              onDelete: (_) async {
                callbacks.add('delete');
                return true;
              },
              onReplace: (_) async {
                callbacks.add('replace');
                return true;
              },
              onNonTextUpdate: (_) async {
                callbacks.add('selection');
                return true;
              },
              onPerformAction: (_) async {
                callbacks.add('action');
              },
            );
      service.attach(
        const TextEditingValue(
          text: 'ㄱ',
          selection: TextSelection.collapsed(offset: 1),
          composing: TextRange(start: 0, end: 1),
        ),
        TextInputConfiguration(enableDeltaModel: useDelta),
      );
      final editingValue = useDelta
          ? (service as DeltaTextInputService).currentTextEditingValue
          : (service as NonDeltaTextInputService).currentTextEditingValue;
      final composing = service.composingTextRange;
      expect(service.attached, isTrue);
      callbacks.clear();
      tester.testTextInput.log.clear();

      // Call the concrete services so this also compiles on Flutter 3.32.4,
      // whose TextInputClient interface does not yet declare this callback.
      final receivedFocus = useDelta
          ? (service as DeltaTextInputService).onFocusReceived()
          : (service as NonDeltaTextInputService).onFocusReceived();

      expect(receivedFocus, isFalse);
      final currentEditingValue = useDelta
          ? (service as DeltaTextInputService).currentTextEditingValue
          : (service as NonDeltaTextInputService).currentTextEditingValue;
      expect(currentEditingValue, editingValue);
      expect(service.composingTextRange, composing);
      expect(service.attached, isTrue);
      expect(callbacks, isEmpty);
      expect(tester.testTextInput.log, isEmpty);
      service.close();
      await tester.pump(const Duration(milliseconds: 50));
    });
  }
}
