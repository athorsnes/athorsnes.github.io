import 'package:flutter/material.dart';
import '../../models/group_node.dart';
import '../../models/group_selection.dart';

class GroupTreeNode extends StatefulWidget {
  final GroupNode node;
  final int fc;
  final GroupSelectionState selection;
  final int depth;

  const GroupTreeNode({
    super.key,
    required this.node,
    required this.fc,
    required this.selection,
    this.depth = 0,
  });

  @override
  State<GroupTreeNode> createState() => _GroupTreeNodeState();
}

class _GroupTreeNodeState extends State<GroupTreeNode> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final node = widget.node;
    final hasChildren = node.children.isNotEmpty;
    final state = widget.selection.stateOf(node, widget.fc);
    final indent = widget.depth * 16.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: hasChildren
              ? () => setState(() => _expanded = !_expanded)
              : null,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: EdgeInsets.only(
                left: indent + 4, right: 4, top: 2, bottom: 2),
            child: Row(
              children: [
                // Expand arrow
                SizedBox(
                  width: 20,
                  child: hasChildren
                      ? Icon(
                          _expanded
                              ? Icons.expand_more
                              : Icons.chevron_right,
                          size: 16,
                          color: cs.onSurfaceVariant,
                        )
                      : null,
                ),
                // Checkbox
                SizedBox(
                  width: 20,
                  height: 20,
                  child: _TriStateCheckbox(
                    state: state,
                    onChanged: (v) {
                      widget.selection.setChecked(node, widget.fc, v);
                    },
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    node.resolvedName,
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_expanded && hasChildren)
          ...node.children.map((child) => ListenableBuilder(
                listenable: widget.selection,
                builder: (context, _) => GroupTreeNode(
                  node: child,
                  fc: widget.fc,
                  selection: widget.selection,
                  depth: widget.depth + 1,
                ),
              )),
      ],
    );
  }
}

class _TriStateCheckbox extends StatelessWidget {
  final CheckState state;
  final void Function(bool) onChanged;

  const _TriStateCheckbox({required this.state, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => onChanged(state != CheckState.checked),
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: state == CheckState.unchecked
              ? Colors.transparent
              : cs.primary,
          border: Border.all(
            color: state == CheckState.unchecked
                ? cs.outline
                : cs.primary,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(3),
        ),
        child: state == CheckState.checked
            ? Icon(Icons.check, size: 11, color: cs.onPrimary)
            : state == CheckState.partial
                ? Icon(Icons.remove, size: 11, color: cs.onPrimary)
                : null,
      ),
    );
  }
}
