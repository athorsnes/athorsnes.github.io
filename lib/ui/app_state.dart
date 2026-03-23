import 'package:flutter/foundation.dart';
import '../models/backup_file.dart';
import '../models/fc_group_tree.dart';
import '../models/group_selection.dart';
import '../models/jmobile_tag.dart';
import '../parsing/backup_parser.dart';
import '../generation/tag_generator.dart';

enum ParseStatus { loading, success, error }

class BackupFileState {
  final String fileName;
  final ParseStatus status;
  final BackupFile? parsed;
  final String? errorMessage;

  const BackupFileState._({
    required this.fileName,
    required this.status,
    this.parsed,
    this.errorMessage,
  });

  factory BackupFileState.loading(String name) =>
      BackupFileState._(fileName: name, status: ParseStatus.loading);

  factory BackupFileState.success(BackupFile backup) => BackupFileState._(
        fileName: backup.fileName,
        status: ParseStatus.success,
        parsed: backup,
      );

  factory BackupFileState.error(String name, String message) =>
      BackupFileState._(
        fileName: name,
        status: ParseStatus.error,
        errorMessage: message,
      );
}

class AppState extends ChangeNotifier {
  final List<BackupFileState> backups = [];
  List<FcGroupTree> fcTrees = [];
  final GroupSelectionState selection = GroupSelectionState();

  List<BackupFile> get parsedBackups =>
      backups.where((b) => b.parsed != null).map((b) => b.parsed!).toList();

  bool get hasAnyParsed => parsedBackups.isNotEmpty;

  TagGenerationResult get generationResult =>
      generateTags(parsedBackups, selection, fcTrees);

  int get tagCount => generationResult.tags.length;

  Future<void> addFiles(List<(String, Uint8List)> files) async {
    for (final (name, bytes) in files) {
      if (backups.any((b) => b.fileName == name)) continue;
      backups.add(BackupFileState.loading(name));
      notifyListeners();

      BackupFileState result;
      try {
        final parsed = await parseBackupFile(name, bytes);
        result = BackupFileState.success(parsed);
      } catch (e) {
        result = BackupFileState.error(name, e.toString());
      }

      final idx = backups.indexWhere((b) => b.fileName == name);
      if (idx >= 0) backups[idx] = result;
      _rebuildFcTrees();
      notifyListeners();
    }
  }

  void removeBackup(String fileName) {
    backups.removeWhere((b) => b.fileName == fileName);
    _rebuildFcTrees();
    notifyListeners();
  }

  void _rebuildFcTrees() {
    final parsed = parsedBackups;
    if (parsed.isEmpty) {
      fcTrees = [];
      return;
    }
    // Use first parsed backup's tree structure (all same-firmware devices share it)
    final first = parsed.first;
    fcTrees = FcGroupTreeBuilder.build(
      rootGroup: first.rootGroup,
      fc1Ids: first.commandIdToFC1Address.keys.toSet(),
      fc2Ids: first.dataIdToFC2Address.keys.toSet(),
      fc3Ids: first.dataIdToFC3Address.keys.toSet(),
      fc4Ids: first.dataIdToFC4Address.keys.toSet(),
    );
    _applyDefaultSelections();
  }

  bool _defaultsApplied = false;

  void _applyDefaultSelections() {
    if (_defaultsApplied) return;
    _defaultsApplied = true;

    for (final fcTree in fcTrees) {
      // FC1: select "Commands" top-level group
      // FC2: select "Functions" top-level group
      // FC3: select "Functions" top-level group
      // FC4: nothing by default
      final defaultNames = switch (fcTree.fc) {
        1 => ['Commands'],
        2 => ['Functions'],
        3 => ['Functions'],
        _ => <String>[],
      };
      for (final child in fcTree.root.children) {
        if (defaultNames.contains(child.resolvedName)) {
          selection.setChecked(child, fcTree.fc, true);
        }
      }
    }
  }
}
