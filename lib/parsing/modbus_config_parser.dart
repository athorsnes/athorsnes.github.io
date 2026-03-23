import 'package:xml/xml.dart';
import '../models/backup_file.dart';

typedef ModbusConfig = ({
  List<ProtocolDef> protocols,
  List<ConversionDef> conversions,
});

ModbusConfig parseModbusConfiguration(String xmlContent) {
  final doc = XmlDocument.parse(xmlContent);

  final protocols = doc
      .findAllElements('Protocol')
      .map((el) => ProtocolDef(
            id: int.tryParse(el.getAttribute('id') ?? '') ?? 0,
            name: el.getAttribute('name') ?? '',
          ))
      .toList();

  final conversions = doc
      .findAllElements('Conversion')
      .map((el) => ConversionDef(
            id: int.tryParse(el.getAttribute('id') ?? '') ?? 0,
            name: el.getAttribute('name') ?? '',
            formula: el.getAttribute('formula') ?? 'x',
          ))
      .toList();

  return (protocols: protocols, conversions: conversions);
}

/// Returns the protocol_id whose name starts with the given variant string.
/// Falls back to 1 if no match found.
int selectProtocolId(String variant, List<ProtocolDef> protocols) {
  if (variant.isEmpty) return 1;
  final lower = variant.toLowerCase();
  for (final p in protocols) {
    if (p.name.toLowerCase().startsWith(lower)) return p.id;
  }
  return 1;
}
