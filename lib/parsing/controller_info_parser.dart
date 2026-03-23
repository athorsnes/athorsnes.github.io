import 'package:xml/xml.dart';
import '../models/backup_file.dart';

DeviceInfo parseControllerInfo(String xmlContent) {
  final doc = XmlDocument.parse(xmlContent);
  final infoMap = <String, String>{};
  for (final el in doc.findAllElements('Info')) {
    final type = el.getAttribute('type');
    final value = el.getAttribute('value');
    if (type != null && value != null) infoMap[type] = value;
  }
  return DeviceInfo(
    plantId: int.tryParse(infoMap['PLANTID'] ?? '') ?? 1,
    label: infoMap['LABEL'] ?? 'Unknown',
    variant: infoMap['VARIANT'] ?? '',
    ipAddress: infoMap['IPADDR'] ?? '',
  );
}
