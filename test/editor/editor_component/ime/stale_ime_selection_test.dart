import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:appflowy_editor/src/editor/editor_component/service/ime/delta_input_impl.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../new/util/util.dart';

void main() {
  group('stale IME selection', () {
    test('ignores a replacement after the selected node has been removed',
        () async {
      final document = Document.blank().addParagraphs(1, initialText: 'A');
      final editorState = EditorState(document: document)
        ..selection = Selection.collapsed(Position(path: [99]));

      await onReplace(
        const TextEditingDeltaReplacement(
          oldText: 'A',
          replacementText: 'B',
          replacedRange: TextRange(start: 0, end: 1),
          selection: TextSelection.collapsed(offset: 1),
          composing: TextRange.empty,
        ),
        editorState,
        const [],
      );

      expect(document.first!.delta!.toPlainText(), 'A');
    });

    test('ignores a deletion after the selected node has been removed',
        () async {
      final document = Document.blank().addParagraphs(1, initialText: 'A');
      final editorState = EditorState(document: document)
        ..selection = Selection.collapsed(Position(path: [99]));

      await onDelete(
        const TextEditingDeltaDeletion(
          oldText: 'A',
          deletedRange: TextRange(start: 0, end: 1),
          selection: TextSelection.collapsed(offset: 0),
          composing: TextRange(start: 0, end: 1),
        ),
        editorState,
      );

      expect(document.first!.delta!.toPlainText(), 'A');
    });

    test('does not apply a deletion range outside the current text', () async {
      final document = Document.blank().addParagraphs(1, initialText: 'A');
      final editorState = EditorState(document: document)
        ..selection = Selection.collapsed(Position(path: [0], offset: 1));

      await onDelete(
        const TextEditingDeltaDeletion(
          oldText: 'AB',
          deletedRange: TextRange(start: 1, end: 2),
          selection: TextSelection.collapsed(offset: 1),
          composing: TextRange(start: 1, end: 2),
        ),
        editorState,
      );

      expect(document.first!.delta!.toPlainText(), 'A');
    });

    test('does not apply a replacement range outside the current text',
        () async {
      final document = Document.blank().addParagraphs(1, initialText: 'A');
      final editorState = EditorState(document: document)
        ..selection = Selection.collapsed(Position(path: [0], offset: 1));

      await onReplace(
        const TextEditingDeltaReplacement(
          oldText: 'AB',
          replacementText: '\n',
          replacedRange: TextRange(start: 1, end: 2),
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange.empty,
        ),
        editorState,
        const [],
      );

      expect(document.first!.delta!.toPlainText(), 'A');
    });
  });
}
