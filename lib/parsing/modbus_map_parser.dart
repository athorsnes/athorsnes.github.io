import 'package:xml/xml.dart';
import '../models/modbus_map.dart';

ModbusMap parseModbusMap(String xmlContent, int expectedFc) {
  final doc = XmlDocument.parse(xmlContent);
  final root = doc.rootElement;
  final entries = <int, ModbusEntry>{};

  for (final mapEl in root.findElements('Map')) {
    final address = int.tryParse(mapEl.getAttribute('address') ?? '');
    if (address == null) continue;

    final bitEl = mapEl.getElement('Bit');
    final valueEl = mapEl.getElement('Value');

    if (bitEl != null) {
      final dataEl = bitEl.getElement('Data');
      if (dataEl == null) continue;
      final dataId = int.tryParse(dataEl.getAttribute('id') ?? '');
      if (dataId == null) continue;
      entries[address] = ModbusEntry(
        address: address,
        kind: ModbusEntryKind.bit,
        dataId: dataId,
        source: dataEl.getAttribute('source') ?? '',
      );
    } else if (valueEl != null) {
      final dataEl = valueEl.getElement('Data');
      if (dataEl == null) continue;
      final dataId = int.tryParse(dataEl.getAttribute('id') ?? '');
      if (dataId == null) continue;
      entries[address] = ModbusEntry(
        address: address,
        kind: ModbusEntryKind.value,
        dataId: dataId,
        source: dataEl.getAttribute('source') ?? '',
        dataType: valueEl.getAttribute('data_type'),
        conversionId: int.tryParse(
            valueEl.getAttribute('conversion_id') ?? ''),
      );
    }
  }

  return ModbusMap(functionCode: expectedFc, entries: entries);
}
