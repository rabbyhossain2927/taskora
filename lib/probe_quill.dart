import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/translations.dart';

class ProbeImage extends EmbedBuilder {
  @override
  String get key => BlockEmbed.imageType;
  @override
  bool get expanded => false;
  @override
  Widget build(BuildContext context, QuillController controller, Embed node, bool readOnly, bool inline, TextStyle textStyle) {
    final url = node.value.data as String;
    return Image.network(url);
  }
}

Widget probe(BuildContext context, QuillController c, FocusNode f, ScrollController s) {
  c.formatSelection(Attribute.h1);
  c.formatSelection(Attribute.clone(Attribute.h1, null));
  c.formatSelection(Attribute.ul);
  c.formatSelection(Attribute.unchecked);
  c.formatSelection(Attribute.bold);
  c.formatSelection(Attribute.small);
  c.replaceText(c.selection.baseOffset, 0, BlockEmbed.image('x'), null);
  if (c.hasUndo) c.undo();
  if (c.hasRedo) c.redo();
  final st = c.getSelectionStyle();
  final isH1 = st.attributes[Attribute.header.key]?.value == 1;
  final d = Document.fromJson(const [{'insert': 'hi\n'}]);
  final ops = d.toDelta().toJson();
  final base = DefaultStyles.getInstance(context);
  final styles = DefaultStyles(
    h1: DefaultTextBlockStyle(const TextStyle(fontSize: 22), HorizontalSpacing.zero, const VerticalSpacing(10, 4), VerticalSpacing.zero, null),
    paragraph: DefaultTextBlockStyle(const TextStyle(fontSize: 15), HorizontalSpacing.zero, VerticalSpacing.zero, VerticalSpacing.zero, null),
    small: const TextStyle(fontSize: 12),
    placeHolder: DefaultTextBlockStyle(const TextStyle(fontSize: 15), HorizontalSpacing.zero, VerticalSpacing.zero, VerticalSpacing.zero, null),
  );
  return QuillEditor(
    controller: c,
    focusNode: f,
    scrollController: s,
    configurations: QuillEditorConfigurations(
      scrollable: false,
      expands: false,
      autoFocus: false,
      padding: EdgeInsets.zero,
      placeholder: isH1 ? 'x' : 'Start writing… ${ops.length}',
      customStyles: base.merge(styles),
      embedBuilders: [ProbeImage()],
    ),
  );
}

final delegates = FlutterQuillLocalizations.delegate;
