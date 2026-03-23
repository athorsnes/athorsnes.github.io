class DataRef {
  final int id;
  final String source; // "Command", "LDOBase", "Parameter", "AlarmState", etc.
  final String type;   // "bit" or "value"

  const DataRef({required this.id, required this.source, required this.type});
}

class GroupNode {
  final int id;
  final String resolvedName;
  final int nameTextId;
  final List<GroupNode> children;
  final List<DataRef> dataRefs;

  const GroupNode({
    required this.id,
    required this.resolvedName,
    required this.nameTextId,
    required this.children,
    required this.dataRefs,
  });

  GroupNode copyWith({
    List<GroupNode>? children,
    List<DataRef>? dataRefs,
  }) {
    return GroupNode(
      id: id,
      resolvedName: resolvedName,
      nameTextId: nameTextId,
      children: children ?? this.children,
      dataRefs: dataRefs ?? this.dataRefs,
    );
  }

  bool get isEmpty => children.isEmpty && dataRefs.isEmpty;
}
