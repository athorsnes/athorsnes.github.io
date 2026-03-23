import 'package:xml/xml.dart';
import '../models/group_node.dart';

GroupNode parseModbusGroups(String xmlContent, Map<int, String> texts) {
  final doc = XmlDocument.parse(xmlContent);
  final root = doc.rootElement; // <Groups>

  final children = root
      .childElements
      .where((e) => e.name.local == 'Group')
      .map((e) => _parseGroup(e, texts))
      .toList();

  return GroupNode(
    id: 0,
    resolvedName: 'root',
    nameTextId: 0,
    children: children,
    dataRefs: [],
  );
}

GroupNode _parseGroup(XmlElement el, Map<int, String> texts) {
  final id = int.tryParse(el.getAttribute('id') ?? '') ?? 0;
  final nameTextId = int.tryParse(el.getAttribute('name_text_id') ?? '') ?? 0;
  final resolvedName = _resolveName(el, texts);

  final children = <GroupNode>[];
  final dataRefs = <DataRef>[];

  for (final child in el.childElements) {
    if (child.name.local == 'Group') {
      children.add(_parseGroup(child, texts));
    } else if (child.name.local == 'Data') {
      final dataId = int.tryParse(child.getAttribute('id') ?? '') ?? 0;
      final source = child.getAttribute('source') ?? '';
      final type = child.getAttribute('type') ?? 'bit';
      dataRefs.add(DataRef(id: dataId, source: source, type: type));
    }
  }

  return GroupNode(
    id: id,
    resolvedName: resolvedName,
    nameTextId: nameTextId,
    children: children,
    dataRefs: dataRefs,
  );
}

String _resolveName(XmlElement el, Map<int, String> texts) {
  final pretty = (el.getAttribute('pretty_name') ?? '').trim();
  if (pretty.isNotEmpty) return pretty;
  final textId = int.tryParse(el.getAttribute('name_text_id') ?? '');
  if (textId != null && texts.containsKey(textId)) return texts[textId]!;
  return '[${el.getAttribute('name_text_id') ?? '?'}]';
}
