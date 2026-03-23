import 'package:xml/xml.dart';

Map<int, String> parseTexts(String xmlContent) {
  final doc = XmlDocument.parse(xmlContent);
  final result = <int, String>{};
  for (final el in doc.findAllElements('Text')) {
    final id = int.tryParse(el.getAttribute('id') ?? '');
    final value = el.getAttribute('value');
    if (id != null && value != null) result[id] = value;
  }
  return result;
}
