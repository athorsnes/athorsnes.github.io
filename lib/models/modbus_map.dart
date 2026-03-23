enum ModbusEntryKind { bit, value }

class ModbusEntry {
  final int address;
  final ModbusEntryKind kind;
  final int dataId;
  final String source;
  final String? dataType;
  final int? conversionId;

  const ModbusEntry({
    required this.address,
    required this.kind,
    required this.dataId,
    required this.source,
    this.dataType,
    this.conversionId,
  });
}

class ModbusMap {
  final int functionCode;
  final Map<int, ModbusEntry> entries; // address → entry

  const ModbusMap({required this.functionCode, required this.entries});

  static const ModbusMap empty1 = ModbusMap(functionCode: 1, entries: {});
  static const ModbusMap empty2 = ModbusMap(functionCode: 2, entries: {});
  static const ModbusMap empty3 = ModbusMap(functionCode: 3, entries: {});
  static const ModbusMap empty4 = ModbusMap(functionCode: 4, entries: {});
}
