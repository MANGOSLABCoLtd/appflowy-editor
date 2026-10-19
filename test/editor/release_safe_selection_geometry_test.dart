import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

class _BeforeLayout extends SingleChildRenderObjectWidget
    implements BlockComponentWidget {
  const _BeforeLayout({required this.onLayout, required this.component})
      : super(child: component as Widget);
  final BlockComponentWidget component;
  final VoidCallback onLayout;
  @override
  Node get node => component.node;
  @override
  BlockComponentConfiguration get configuration => component.configuration;
  @override
  BlockComponentActionBuilder? get actionBuilder => component.actionBuilder;
  @override
  BlockComponentActionTrailingBuilder? get actionTrailingBuilder =>
      component.actionTrailingBuilder;
  @override
  bool get showActions => component.showActions;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _LayoutProbe(onLayout);
}

class _LayoutProbe extends RenderProxyBox {
  _LayoutProbe(this.onLayout);
  final VoidCallback onLayout;
  bool didProbe = false;
  @override
  void performLayout() {
    if (!didProbe) {
      didProbe = true;
      onLayout();
    }
    super.performLayout();
  }
}

class _ProbeParagraphBuilder extends ParagraphBlockComponentBuilder {
  _ProbeParagraphBuilder(this.onLayout);
  final VoidCallback onLayout;
  @override
  BlockComponentWidget build(BlockComponentContext context) =>
      _BeforeLayout(onLayout: onLayout, component: super.build(context));
}

Future<EditorState> _mountEditor(
  WidgetTester tester,
  String text, {
  VoidCallback? beforeLayout,
  Node? node,
}) async {
  final state = EditorState(
    document: Document(
      root: pageNode(children: [node ?? paragraphNode(text: text)]),
    ),
  );
  final scroll = EditorScrollController(editorState: state);
  addTearDown(scroll.dispose);
  addTearDown(state.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AppFlowyEditor(
          editorState: state,
          editorScrollController: scroll,
          editorStyle: const EditorStyle.desktop(padding: EdgeInsets.zero),
          blockComponentBuilders: {
            ...standardBlockComponentBuilderMap,
            if (beforeLayout != null)
              ParagraphBlockKeys.type: _ProbeParagraphBuilder(beforeLayout),
          },
        ),
      ),
    ),
  );
  return state;
}

SelectableMixin _selectable(WidgetTester tester) =>
    tester.state(find.byType(AppFlowyRichText, skipOffstage: false))
        as SelectableMixin;

List<RenderParagraph> _paragraphs(WidgetTester tester) => tester
    .renderObjectList<RenderParagraph>(
      find.descendant(
        of: find.byType(AppFlowyRichText, skipOffstage: false),
        matching: find.byType(RichText, skipOffstage: false),
        skipOffstage: false,
      ),
    )
    .toList();

void main() {
  for (final text in ['Hello world', '']) {
    testWidgets('geometry is empty before first layout for "$text"', (
      tester,
    ) async {
      final selection = Selection.single(
        path: [0],
        startOffset: 0,
        endOffset: text.isEmpty ? 0 : 1,
      );
      final position = Position(path: [0], offset: 0);
      var probed = false;
      final state = await _mountEditor(
        tester,
        text,
        beforeLayout: () {
          probed = true;
          final selectable = _selectable(tester);
          expect(selectable.getCursorRectInPosition(position), isNull);
          expect(selectable.getRectsInSelection(selection), isEmpty);
        },
      );
      expect(probed, isTrue);
      expect(tester.takeException(), isNull);
      final selectable = _selectable(tester);
      expect(selectable.getCursorRectInPosition(position), isNotNull);
      state.selection = selection;
      if (text.isNotEmpty) {
        expect(selectable.getRectsInSelection(selection), isNotEmpty);
        expect(state.selectionRects(), isNotEmpty);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('dirty laid-out paragraphs keep debug protection for "$text"', (
      tester,
    ) async {
      final state = await _mountEditor(tester, text);
      final selectable = _selectable(tester);
      final position = Position(path: [0], offset: 0);
      final selection = Selection.single(
        path: [0],
        startOffset: 0,
        endOffset: text.isEmpty ? 0 : 1,
      );
      for (final paragraph in _paragraphs(tester)) {
        expect(paragraph.hasSize, isTrue);
        paragraph.markNeedsLayout();
      }
      expect(selectable.getCursorRectInPosition(position), isNull);
      expect(selectable.getRectsInSelection(selection), isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pump();
      expect(selectable.getCursorRectInPosition(position), isNotNull);
      state.selection = selection;
      expect(state.selectionRects(), isNotEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final placeholder in [false, true]) {
    testWidgets(
        'detached ${placeholder ? 'placeholder' : 'text'} paragraph '
        'does not expose cursor geometry', (tester) async {
      await _mountEditor(tester, '');
      final selectable = _selectable(tester);
      final paragraphs = _paragraphs(tester);
      expect(paragraphs, hasLength(2));
      final paragraph = paragraphs[placeholder ? 0 : 1];
      final parent = paragraph.parent! as RenderStack;
      final previous =
          (paragraph.parentData! as StackParentData).previousSibling;
      expect(paragraph.hasSize, isTrue);
      parent.remove(paragraph);
      try {
        expect(
          selectable.getCursorRectInPosition(Position(path: [0], offset: 0)),
          isNull,
        );
        if (!placeholder) {
          expect(
            selectable.getRectsInSelection(
              Selection.single(path: [0], startOffset: 0, endOffset: 0),
            ),
            isEmpty,
          );
        }
      } finally {
        parent.insert(paragraph, after: previous);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final collapsed in [false, true]) {
    testWidgets(
      'selectionRects skips a detached node (collapsed: $collapsed)',
      (tester) async {
        final state = await _mountEditor(tester, '', node: dividerNode());
        state.selection = Selection.single(
          path: [0],
          startOffset: 0,
          endOffset: collapsed ? 0 : 5,
        );
        expect(state.selectionRects(), isNotEmpty);
        final root = tester.binding.renderViews.single;
        final owner = root.owner!;
        root.detach();
        try {
          expect(state.selectionRects(), isEmpty);
        } finally {
          root.attach(owner);
        }
        expect(state.selectionRects(), isNotEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
