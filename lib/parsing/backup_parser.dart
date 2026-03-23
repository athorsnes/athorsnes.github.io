import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import '../models/backup_file.dart';
import '../models/modbus_map.dart';
import 'controller_info_parser.dart';
import 'modbus_config_parser.dart';
import 'commands_parser.dart';
import 'texts_parser.dart';
import 'modbus_groups_parser.dart';
import 'modbus_map_parser.dart';

/// Parses a .backup file (outer tar) into a [BackupFile].
/// Throws a descriptive [Exception] on failure.
Future<BackupFile> parseBackupFile(String fileName, Uint8List bytes) async {
  // --- Outer tar ---
  final ArchiveFile xmlTarFile;
  try {
    final outerTar = TarDecoder().decodeBytes(bytes);
    final candidate = outerTar.files.where((f) => f.name == 'xmlfiles.tar').firstOrNull;
    if (candidate == null) throw Exception('xmlfiles.tar not found in backup');
    xmlTarFile = candidate;
  } catch (e) {
    throw Exception('Failed to read outer tar: $e');
  }

  // --- Inner tar ---
  final Map<String, ArchiveFile> xmlFiles;
  try {
    final innerTar = TarDecoder().decodeBytes(xmlTarFile.content as Uint8List);
    xmlFiles = {
      for (final f in innerTar.files)
        f.name.replaceFirst('./', ''): f,
    };
  } catch (e) {
    throw Exception('Failed to read xmlfiles.tar: $e');
  }

  String readXml(String name) {
    final f = xmlFiles[name];
    if (f == null) throw Exception('Missing $name in backup');
    return utf8.decode(f.content as Uint8List);
  }

  String? tryReadXml(String name) {
    final f = xmlFiles[name];
    if (f == null) return null;
    try {
      return utf8.decode(f.content as Uint8List);
    } catch (_) {
      return null;
    }
  }

  // --- Parse device info & config ---
  final deviceInfo = parseControllerInfo(readXml('ControllerInfo.xml'));
  final config = parseModbusConfiguration(readXml('ModbusConfiguration.xml'));
  final commands = parseCommands(readXml('Commands.xml'));
  final texts = parseTexts(readXml('gb.xml'));

  // --- Determine protocol_id for this device type ---
  final pid = selectProtocolId(deviceInfo.variant, config.protocols);

  String mapFileName(int fc) =>
      'ModbusMap&protocol_id=$pid&function_code=$fc&address=0&quantity=65535.xml';

  // --- Parse ModbusGroups ---
  final rootGroup = parseModbusGroups(readXml('ModbusGroups.xml'), texts);

  // --- Parse Modbus maps ---
  ModbusMap parseMap(int fc) {
    final content = tryReadXml(mapFileName(fc));
    if (content == null) {
      return switch (fc) {
        1 => ModbusMap.empty1,
        2 => ModbusMap.empty2,
        3 => ModbusMap.empty3,
        _ => ModbusMap.empty4,
      };
    }
    return parseModbusMap(content, fc);
  }

  return BackupFile(
    fileName: fileName,
    deviceInfo: deviceInfo,
    protocols: config.protocols,
    conversions: config.conversions,
    commands: commands,
    texts: texts,
    rootGroup: rootGroup,
    coilMap: parseMap(1),
    discreteInputMap: parseMap(2),
    holdingRegMap: parseMap(3),
    inputRegMap: parseMap(4),
  );
}
