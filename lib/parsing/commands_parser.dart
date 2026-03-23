import 'package:xml/xml.dart';
import '../models/backup_file.dart';

List<CommandDef> parseCommands(String xmlContent) {
  final doc = XmlDocument.parse(xmlContent);
  return doc
      .findAllElements('Command')
      .map((el) => CommandDef(
            id: int.tryParse(el.getAttribute('id') ?? '') ?? 0,
            prettyName: el.getAttribute('pretty_name') ?? '',
            hidden: el.getAttribute('hidden') == 'true',
          ))
      .toList();
}
