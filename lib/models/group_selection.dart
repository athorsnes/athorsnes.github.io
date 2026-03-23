import 'package:flutter/foundation.dart';
import 'group_node.dart';

enum CheckState { unchecked, partial, checked }

/// Tracks which GroupNode IDs are selected, independently per FC (1–4).
class GroupSelectionState extends ChangeNotifier {
  final Map<int, Set<int>> _checkedIdsByFc = {1: {}, 2: {}, 3: {}, 4: {}};

  CheckState stateOf(GroupNode node, int fc) {
    final checked = _checkedIdsByFc[fc]!;
    if (checked.contains(node.id)) return CheckState.checked;

    // Check if any descendant is checked
    if (_anyDescendantChecked(node, fc)) return CheckState.partial;
    return CheckState.unchecked;
  }

  bool _anyDescendantChecked(GroupNode node, int fc) {
    final checked = _checkedIdsByFc[fc]!;
    for (final child in node.children) {
      if (checked.contains(child.id)) return true;
      if (_anyDescendantChecked(child, fc)) return true;
    }
    return false;
  }

  void setChecked(GroupNode node, int fc, bool value) {
    final checked = _checkedIdsByFc[fc]!;
    if (value) {
      _addAll(node, checked);
    } else {
      _removeAll(node, checked);
    }
    notifyListeners();
  }

  void _addAll(GroupNode node, Set<int> checked) {
    checked.add(node.id);
    for (final child in node.children) {
      _addAll(child, checked);
    }
  }

  void _removeAll(GroupNode node, Set<int> checked) {
    checked.remove(node.id);
    for (final child in node.children) {
      _removeAll(child, checked);
    }
  }

  bool isGroupSelected(int groupId, int fc) =>
      _checkedIdsByFc[fc]?.contains(groupId) ?? false;

  /// Returns all DataRef IDs selected for the given FC.
  Set<int> selectedDataIds(GroupNode root, int fc) {
    final result = <int>{};
    _collectSelectedRefs(root, fc, result);
    return result;
  }

  void _collectSelectedRefs(GroupNode node, int fc, Set<int> result) {
    final checked = _checkedIdsByFc[fc]!;
    if (checked.contains(node.id)) {
      _collectAllRefs(node, result);
    } else {
      for (final child in node.children) {
        _collectSelectedRefs(child, fc, result);
      }
    }
  }

  void _collectAllRefs(GroupNode node, Set<int> result) {
    for (final ref in node.dataRefs) {
      result.add(ref.id);
    }
    for (final child in node.children) {
      _collectAllRefs(child, result);
    }
  }

  int countSelected(GroupNode root, int fc, Map<int, int> addressMap) {
    final ids = selectedDataIds(root, fc);
    return ids.where((id) => addressMap.containsKey(id)).length;
  }
}
