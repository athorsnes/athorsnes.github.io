import 'package:flutter/material.dart';
import '../app_state.dart';

class FileListTile extends StatelessWidget {
  final BackupFileState state;
  final VoidCallback onRemove;

  const FileListTile({
    super.key,
    required this.state,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final parsed = state.parsed;

    Widget leading;
    String subtitle;

    switch (state.status) {
      case ParseStatus.loading:
        leading = SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
        );
        subtitle = 'Parsing…';
      case ParseStatus.success:
        leading = Icon(Icons.check_circle, color: cs.primary, size: 20);
        final d = parsed!.deviceInfo;
        subtitle =
            '${d.label}  ·  node ${d.plantId}  ·  ${d.ipAddress}  ·  ${d.variant}';
      case ParseStatus.error:
        leading = Icon(Icons.error_outline, color: cs.error, size: 20);
        subtitle = state.errorMessage ?? 'Unknown error';
    }

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      leading: leading,
      title: Text(
        state.fileName,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 11,
          color: state.status == ParseStatus.error ? cs.error : null,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        icon: const Icon(Icons.close, size: 16),
        tooltip: 'Remove',
        onPressed: onRemove,
      ),
    );
  }
}
