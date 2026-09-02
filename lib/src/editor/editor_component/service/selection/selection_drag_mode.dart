enum MobileSelectionDragMode {
  none,
  leftSelectionHandle,
  rightSelectionHandle,
  cursor,
}

/// The value stored in [EditorState.selectionExtraInfo] for mobile handle drag.
const String selectionDragModeKey = 'selection_drag_mode';
