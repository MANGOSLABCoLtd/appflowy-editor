import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> onDelete(
  TextEditingDeltaDeletion deletion,
  EditorState editorState,
) async {
  AppFlowyEditorLog.input.debug('onDelete: $deletion');

  final selection = editorState.selection;
  if (selection == null) {
    return;
  }

  // IME
  if (selection.isSingle) {
    final node = editorState.getNodeAtPath(selection.start.path);
    if (node == null) {
      // The selection can point to a node removed by a previous edit.
      return;
    }

    final delta = node.delta;
    if (delta != null &&
        (deletion.composing.isValid || !deletion.deletedRange.isCollapsed)) {
      final start = deletion.deletedRange.start;
      final length = deletion.deletedRange.end - start;
      if (start < 0 || length < 0 || start + length > delta.length) {
        // The platform can send a delta calculated from text that is older
        // than the current document. Ignore it without rejecting the platform
        // state.
        return;
      }
      final transaction = editorState.transaction;
      final afterSelection = Selection(
        start: Position(
          path: node.path,
          offset: deletion.selection.baseOffset,
        ),
        end: Position(
          path: node.path,
          offset: deletion.selection.extentOffset,
        ),
      );
      transaction
        ..deleteText(node, start, length)
        ..afterSelection = afterSelection;
      await editorState.apply(transaction);
      return;
    }
  }

  // use backspace command instead.
  if (KeyEventResult.ignored ==
      convertToParagraphCommand.execute(editorState)) {
    backspaceCommand.execute(editorState);
  }
}
