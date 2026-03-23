import 'package:flutter/material.dart';
import '../../models/fc_group_tree.dart';
import '../../models/group_selection.dart';
import 'group_tree_node.dart';

class FcSection extends StatefulWidget {
  final FcGroupTree fcTree;
  final GroupSelectionState selection;

  const FcSection({
    super.key,
    required this.fcTree,
    required this.selection,
  });

  @override
  State<FcSection> createState() => _FcSectionState();
}

class _FcSectionState extends State<FcSection> {
  bool _expanded = true;

  static const _fcColors = {
    1: Color(0xFF1565C0), // blue
    2: Color(0xFF2E7D32), // green
    3: Color(0xFF6A1B9A), // purple
    4: Color(0xFFE65100), // orange
  };

  @override
  Widget build(BuildContext context) {
    final fc = widget.fcTree.fc;
    final color = _fcColors[fc] ?? Colors.grey;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Section header
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              color: color.withValues(alpha: 0.1),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    _expanded ? Icons.expand_more : Icons.chevron_right,
                    size: 18,
                    color: color,
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      widget.fcTree.memoryType,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.fcTree.label,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: color,
                      ),
                    ),
                  ),
                  // Select all / none
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      for (final child
                          in widget.fcTree.root.children) {
                        widget.selection.setChecked(child, fc, true);
                      }
                    },
                    child: Text('All',
                        style: TextStyle(fontSize: 11, color: color)),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      for (final child
                          in widget.fcTree.root.children) {
                        widget.selection.setChecked(child, fc, false);
                      }
                    },
                    child: Text('None',
                        style: TextStyle(fontSize: 11, color: color)),
                  ),
                ],
              ),
            ),
          ),
          // Tree nodes
          if (_expanded)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widget.fcTree.root.children
                    .map((node) => ListenableBuilder(
                          listenable: widget.selection,
                          builder: (context, _) => GroupTreeNode(
                            node: node,
                            fc: fc,
                            selection: widget.selection,
                          ),
                        ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}
