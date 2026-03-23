import 'group_node.dart';
import 'modbus_map.dart';

class DeviceInfo {
  final int plantId;
  final String label;
  final String variant;
  final String ipAddress;

  DeviceInfo({
    required this.plantId,
    required this.label,
    required this.variant,
    required this.ipAddress,
  });

  /// e.g. "DG 1" → "DG1"
  String get groupPrefix => label.replaceAll(' ', '');
}

class ProtocolDef {
  final int id;
  final String name;
  ProtocolDef({required this.id, required this.name});
}

class ConversionDef {
  final int id;
  final String name;
  final String formula;
  ConversionDef({required this.id, required this.name, required this.formula});
}

class CommandDef {
  final int id;
  final String prettyName;
  final bool hidden;
  CommandDef({required this.id, required this.prettyName, required this.hidden});
}

class BackupFile {
  final String fileName;
  final DeviceInfo deviceInfo;
  final List<ProtocolDef> protocols;
  final List<ConversionDef> conversions;
  final List<CommandDef> commands;
  final Map<int, String> texts;
  final GroupNode rootGroup;
  final ModbusMap coilMap;
  final ModbusMap discreteInputMap;
  final ModbusMap holdingRegMap;
  final ModbusMap inputRegMap;

  // Reverse lookups: dataId → modbus address
  late final Map<int, int> commandIdToFC1Address;
  late final Map<int, int> dataIdToFC2Address;
  late final Map<int, int> dataIdToFC3Address;
  late final Map<int, int> dataIdToFC4Address;

  BackupFile({
    required this.fileName,
    required this.deviceInfo,
    required this.protocols,
    required this.conversions,
    required this.commands,
    required this.texts,
    required this.rootGroup,
    required this.coilMap,
    required this.discreteInputMap,
    required this.holdingRegMap,
    required this.inputRegMap,
  }) {
    commandIdToFC1Address = {
      for (final e in coilMap.entries.values) e.dataId: e.address,
    };
    dataIdToFC2Address = {
      for (final e in discreteInputMap.entries.values) e.dataId: e.address,
    };
    dataIdToFC3Address = {
      for (final e in holdingRegMap.entries.values) e.dataId: e.address,
    };
    dataIdToFC4Address = {
      for (final e in inputRegMap.entries.values) e.dataId: e.address,
    };
  }
}
