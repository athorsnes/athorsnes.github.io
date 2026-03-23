import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'app_state.dart';
import 'widgets/drop_zone.dart';
import 'widgets/file_list_tile.dart';
import 'widgets/fc_section.dart';
import '../generation/xml_serializer.dart';
import '../utils/file_download.dart';

class HomePage extends StatelessWidget {
  final AppState appState;

  const HomePage({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HMI Tag Generator'),
        centerTitle: false,
      ),
      body: ListenableBuilder(
        listenable: appState,
        builder: (context, _) {
          final isWide = MediaQuery.of(context).size.width >= 800;
          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 340,
                  child: _leftPanel(context),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: _rightPanel(context)),
              ],
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _leftPanel(context),
                const SizedBox(height: 16),
                _rightPanel(context),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _leftPanel(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropZone(
            onFilesAdded: (files) {
              appState.addFiles(
                files.map((f) => (f.$1, Uint8List.fromList(f.$2))).toList(),
              );
            },
          ),
          const SizedBox(height: 16),
          if (appState.backups.isNotEmpty) ...[
            Text(
              'Loaded files',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: appState.backups
                    .map((b) => FileListTile(
                          state: b,
                          onRemove: () => appState.removeBackup(b.fileName),
                        ))
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _rightPanel(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (!appState.hasAnyParsed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Load one or more .backup files to see\nthe register group selector',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Register groups to include',
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ListenableBuilder(
            listenable: appState.selection,
            builder: (context, _) => Column(
              children: appState.fcTrees
                  .map((fcTree) => FcSection(
                        fcTree: fcTree,
                        selection: appState.selection,
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
          ListenableBuilder(
            listenable: appState.selection,
            builder: (context, _) {
              final count = appState.tagCount;
              final deviceCount = appState.parsedBackups.length;
              return _GenerateBar(
                tagCount: count,
                deviceCount: deviceCount,
                enabled: count > 0,
                onGenerate: () {
                  final result = appState.generationResult;
                  final xml = serializeTaglist(result.tags);
                  downloadTextFile(xml, 'taglist.xml');
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _GenerateBar extends StatelessWidget {
  final int tagCount;
  final int deviceCount;
  final bool enabled;
  final VoidCallback onGenerate;

  const _GenerateBar({
    required this.tagCount,
    required this.deviceCount,
    required this.enabled,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            '$tagCount tags from $deviceCount device${deviceCount == 1 ? '' : 's'}',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
          ),
        ),
        FilledButton.icon(
          onPressed: enabled ? onGenerate : null,
          icon: const Icon(Icons.download, size: 18),
          label: Text('Generate taglist.xml ($tagCount tags)'),
        ),
      ],
    );
  }
}
