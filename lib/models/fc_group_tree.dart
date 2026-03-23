import 'group_node.dart';

class FcGroupTree {
  final int fc;
  final String label;
  final String memoryType;
  final GroupNode root; // pruned — only branches with ≥1 address in this FC

  const FcGroupTree({
    required this.fc,
    required this.label,
    required this.memoryType,
    required this.root,
  });

  static const Map<int, String> _labels = {
    1: 'FC1 — Write commands',
    2: 'FC2 — Digital status',
    3: 'FC3 — Holding registers',
    4: 'FC4 — Input registers',
  };
  static const Map<int, String> _memoryTypes = {
    1: 'OUTP',
    2: 'INP',
    3: 'HREG',
    4: 'IREG',
  };

  static String labelFor(int fc) => _labels[fc] ?? 'FC$fc';
  static String memoryTypeFor(int fc) => _memoryTypes[fc] ?? '';
}

/// Builds FC-pruned trees from a full GroupNode root and per-FC id sets.
class FcGroupTreeBuilder {
  static List<FcGroupTree> build({
    required GroupNode rootGroup,
    required Set<int> fc1Ids,
    required Set<int> fc2Ids,
    required Set<int> fc3Ids,
    required Set<int> fc4Ids,
  }) {
    final idsByFc = {1: fc1Ids, 2: fc2Ids, 3: fc3Ids, 4: fc4Ids};
    final result = <FcGroupTree>[];
    for (final fc in [1, 2, 3, 4]) {
      final pruned = _prune(rootGroup, idsByFc[fc]!);
      if (pruned != null) {
        result.add(FcGroupTree(
          fc: fc,
          label: FcGroupTree.labelFor(fc),
          memoryType: FcGroupTree.memoryTypeFor(fc),
          root: pruned,
        ));
      }
    }
    return result;
  }

  static GroupNode? _prune(GroupNode node, Set<int> idSet) {
    final keptRefs =
        node.dataRefs.where((r) => idSet.contains(r.id)).toList();
    final keptChildren = node.children
        .map((c) => _prune(c, idSet))
        .whereType<GroupNode>()
        .toList();
    if (keptRefs.isEmpty && keptChildren.isEmpty) return null;
    return node.copyWith(dataRefs: keptRefs, children: keptChildren);
  }
}
