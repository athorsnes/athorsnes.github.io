import '../models/backup_file.dart';
import '../models/fc_group_tree.dart';
import '../models/group_node.dart';
import '../models/group_selection.dart';
import '../models/jmobile_tag.dart';

/// FC → JMobile offset base
const _offsetBase = {1: 0, 2: 100000, 3: 400000, 4: 300000};

/// ModbusMap data_type → JMobile data_type
String _mapDataType(String? dt) => switch (dt) {
      'INT16' => 'short',
      'UINT16' => 'word',
      'INT32' => 'integer',
      'UINT32' => 'dword',
      'FLOAT32' => 'float',
      _ => 'short',
    };

TagGenerationResult generateTags(
  List<BackupFile> backups,
  GroupSelectionState selection,
  List<FcGroupTree> fcTrees,
) {
  final tags = <JMobileTag>[];
  final warnings = <String>[];

  for (final backup in backups) {
    for (final fcTree in fcTrees) {
      final fc = fcTree.fc;
      final addressMap = switch (fc) {
        1 => backup.commandIdToFC1Address,
        2 => backup.dataIdToFC2Address,
        3 => backup.dataIdToFC3Address,
        _ => backup.dataIdToFC4Address,
      };
      final dataTypeMap = switch (fc) {
        3 => {
            for (final e in backup.holdingRegMap.entries.values)
              e.dataId: e.dataType
          },
        4 => {
            for (final e in backup.inputRegMap.entries.values)
              e.dataId: e.dataType
          },
        _ => <int, String?>{},
      };
      final sourceMap = switch (fc) {
        1 => {
            for (final e in backup.coilMap.entries.values)
              e.dataId: e.source
          },
        3 => {
            for (final e in backup.holdingRegMap.entries.values)
              e.dataId: e.source
          },
        _ => <int, String?>{},
      };

      final selectedIds =
          selection.selectedDataIds(fcTree.root, fc);

      // Walk fc-pruned tree and emit tags for selected nodes
      _walkTree(
        node: fcTree.root,
        fc: fc,
        backup: backup,
        selection: selection,
        selectedIds: selectedIds,
        addressMap: addressMap,
        dataTypeMap: dataTypeMap,
        sourceMap: sourceMap,
        breadcrumb: [],
        tags: tags,
        warnings: warnings,
      );
    }
  }

  return TagGenerationResult(tags: tags, warnings: warnings);
}

void _walkTree({
  required GroupNode node,
  required int fc,
  required BackupFile backup,
  required GroupSelectionState selection,
  required Set<int> selectedIds,
  required Map<int, int> addressMap,
  required Map<int, String?> dataTypeMap,
  required Map<int, String?> sourceMap,
  required List<String> breadcrumb,
  required List<JMobileTag> tags,
  required List<String> warnings,
}) {
  // Skip virtual root
  final crumb = node.id == 0 ? breadcrumb : [...breadcrumb, node.resolvedName];

  for (final ref in node.dataRefs) {
    if (!selectedIds.contains(ref.id)) continue;
    final address = addressMap[ref.id];
    if (address == null) continue;

    final base = _offsetBase[fc] ?? 0;
    final offset = address + base;
    final dt = _mapDataType(dataTypeMap[ref.id]);
    final src = sourceMap[ref.id] ?? '';
    final accessMode = _accessMode(fc, src);
    final suffix = '-F${fc.toString().padLeft(2, '0')}';
    final pathStr = crumb.join(' - ');
    final name = '${backup.deviceInfo.groupPrefix}/$pathStr $suffix';

    tags.add(JMobileTag(
      name: name,
      group: backup.deviceInfo.groupPrefix,
      nodeId: backup.deviceInfo.plantId,
      memoryType: FcGroupTree.memoryTypeFor(fc),
      offset: offset,
      dataType: fc <= 2 ? 'boolean' : dt,
      accessMode: accessMode,
      min: fc <= 2 ? '0' : '-32768',
      max: fc <= 2 ? '1' : '32767',
    ));
  }

  for (final child in node.children) {
    _walkTree(
      node: child,
      fc: fc,
      backup: backup,
      selection: selection,
      selectedIds: selectedIds,
      addressMap: addressMap,
      dataTypeMap: dataTypeMap,
      sourceMap: sourceMap,
      breadcrumb: crumb,
      tags: tags,
      warnings: warnings,
    );
  }
}

String _accessMode(int fc, String source) {
  if (fc == 1) return 'READ-WRITE';
  if (fc == 2) return 'READ';
  if (fc == 3 && source == 'Parameter') return 'READ-WRITE';
  return 'READ';
}
