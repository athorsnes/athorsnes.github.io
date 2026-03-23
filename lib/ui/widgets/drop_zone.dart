import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class DropZone extends StatefulWidget {
  final void Function(List<(String, List<int>)> files) onFilesAdded;

  const DropZone({super.key, required this.onFilesAdded});

  @override
  State<DropZone> createState() => _DropZoneState();
}

class _DropZoneState extends State<DropZone> {
  bool _hovering = false;

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
    );
    if (result == null) return;
    final files = result.files
        .where((f) => f.bytes != null)
        .map((f) => (f.name, f.bytes!.toList()))
        .toList();
    if (files.isNotEmpty) widget.onFilesAdded(files);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: _pickFiles,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
          decoration: BoxDecoration(
            color: _hovering
                ? colorScheme.primaryContainer.withValues(alpha: 0.18)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            border: Border.all(
              color: _hovering
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.upload_file_outlined,
                  size: 36,
                  color: _hovering
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant),
              const SizedBox(height: 8),
              Text(
                'Click to select .backup files',
                style: TextStyle(
                  color: _hovering
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
