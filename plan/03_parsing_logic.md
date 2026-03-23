# Parsing Logic

## Entry Point

```dart
Future<BackupFile> parseBackupFile(String fileName, Uint8List bytes)
```

## Step 1 — Outer Tar Extraction

Using the `archive` package:

```dart
final outerTar = TarDecoder().decodeBytes(bytes);
final metaFile     = outerTar.findFile('metadata.txt');
final xmlTarFile   = outerTar.findFile('xmlfiles.tar');
```

Parse `metadata.txt` line by line:
```
FAMILY=Marine
TYPE=DG
ML300APP_VERSION=2.0.15.0-MP
```
Store as `Map<String, String>`.

## Step 2 — Inner Tar Extraction

```dart
final innerTar = TarDecoder().decodeBytes(xmlTarFile.content as Uint8List);
```

Build a lookup map for quick access:
```dart
Map<String, ArchiveFile> xmlFiles = {
  for (final f in innerTar.files) f.name: f
};
```

File names use `./` prefix — normalise by stripping leading `./`.

## Step 3 — Parse ControllerInfo.xml

```dart
DeviceInfo parseControllerInfo(String xmlContent)
```

- Find all `<Info type="..." value="..."/>` elements
- Extract `PLANTID` (int), `LABEL` (string), `VARIANT`, `IPADDR`
- Derive `groupPrefix` = label with spaces removed (e.g. "DG 1" → "DG1")

## Step 4 — Parse ModbusConfiguration.xml

```dart
(List<ProtocolDef>, List<ConversionDef>) parseModbusConfiguration(String xmlContent)
```

- Parse `<Protocol id="..." name="..."/>` elements under `<Protocols>`
- Parse `<Conversion id="..." name="..." formula="..."/>` elements under `<Conversions>`

## Step 4b — Parse gb.xml (Text Lookup Table)

```dart
Map<int, String> parseTexts(String xmlContent)
```

- Parse all `<Text id="..." value="..."/>` elements
- Return as `Map<int, String>` (id → English string)
- This map is passed into `parseModbusGroups()` for name resolution

## Step 5 — Parse Commands.xml

```dart
List<CommandDef> parseCommands(String xmlContent)
```

- Each `<Command id="..." pretty_name="..." hidden="..." />` becomes a `CommandDef`
- Skip `hidden="true"` commands (optional, make configurable)

## Step 6 — Parse ModbusGroups.xml

```dart
GroupNode parseModbusGroups(String xmlContent, Map<int, String> texts)
```

Recursive descent over `<Group>` and `<Data>` elements:
- `<Group id pretty_name? name_text_id>` → `GroupNode`
- `<Data id source type>` → `DataRef` leaf attached to nearest parent `GroupNode`
- `<Group>` children that are also `<Group>` → nested `GroupNode.children`

**Name resolution** for each `GroupNode`:
```dart
String resolveName(XmlElement el, Map<int, String> texts) {
  final pretty = el.getAttribute('pretty_name') ?? '';
  if (pretty.isNotEmpty) return pretty;
  final textId = int.tryParse(el.getAttribute('name_text_id') ?? '');
  if (textId != null && texts.containsKey(textId)) return texts[textId]!;
  return '[${el.getAttribute('name_text_id')}]';
}
```

Result is a virtual root `GroupNode` whose direct children are the top-level groups.
Observed top-level groups in DG backup:
**Commands**, **Parameters**, **Functions**, **Priorities**, **ICC**,
**Regulator status**, **Texts**, **Counters**, **Custom alarms**, **Fieldbus**

## Step 7 — Parse ModbusMap files

```dart
ModbusMap parseModbusMap(String xmlContent, int expectedFc)
```

Shared parser for all FC variants.

### FC1 / FC2 (bit entries)
```xml
<Map address="1001"><Bit><Data id="8001" source="Command"/></Bit></Map>
```
→ `ModbusEntry(address: 1001, kind: bit, dataId: 8001, source: "Command")`

### FC3 / FC4 (value entries)
```xml
<Map address="8000">
  <Value conversion_id="1" data_type="INT16">
    <Data id="11080004" source="LDOBase"/>
  </Value>
</Map>
```
→ `ModbusEntry(address: 8000, kind: value, dataId: 11080004, source: "LDOBase", dataType: "INT16", conversionId: 1)`

### Protocol ID Selection

The correct `protocol_id` depends on the device type (VARIANT). It is determined
by finding the Protocol in `ModbusConfiguration.xml` whose `name` starts with the
device's VARIANT string (case-insensitive):

```dart
int selectProtocolId(String variant, List<ProtocolDef> protocols) {
  return protocols
    .firstWhere((p) => p.name.toLowerCase().startsWith(variant.toLowerCase()))
    .id;
}
```

| VARIANT | Protocol name | protocol_id |
|---|---|---|
| DG | DG default protocol | 1 |
| SG | SG default protocol | 2 |
| SC | SC default protocol | 3 |
| BTB | BTB default protocol | 4 |
| EDG | EDG default protocol | 5 |

### File name pattern

```dart
String fc1File = 'ModbusMap&protocol_id=${pid}&function_code=1&address=0&quantity=65535.xml';
String fc2File = 'ModbusMap&protocol_id=${pid}&function_code=2&address=0&quantity=65535.xml';
String fc3File = 'ModbusMap&protocol_id=${pid}&function_code=3&address=0&quantity=65535.xml';
String fc4File = 'ModbusMap&protocol_id=${pid}&function_code=4&address=0&quantity=65535.xml';
```

Where `pid` is the selected protocol_id for the device type.

## Step 8 — Build Reverse Lookup Maps

After all maps are parsed:

```dart
// commandId → FC1 address
final commandIdToAddress = <int, int>{
  for (final e in coilMap.entries.values) e.dataId: e.address
};

// LDOBase dataId → FC2 address
final ldobaseToFC2 = <int, int>{
  for (final e in fc2Map.entries.values
    .where((e) => e.source == 'LDOBase'))
  e.dataId: e.address
};

// Similar for FC3 and FC4
```

## Step 9 — Build FcGroupTrees

After reverse lookup maps are built (Step 8), prune the `GroupNode` tree into four
FC-specific views.

```dart
List<FcGroupTree> buildFcTrees(BackupFile backup) {
  return [1, 2, 3, 4].map((fc) {
    final idSet = switch (fc) {
      1 => backup.commandIdToFC1Address.keys.toSet(),
      2 => backup.dataIdToFC2Address.keys.toSet(),
      3 => backup.dataIdToFC3Address.keys.toSet(),
      4 => backup.dataIdToFC4Address.keys.toSet(),
      _ => <int>{},
    };
    final pruned = _pruneTree(backup.rootGroup, idSet);
    return FcGroupTree(fc: fc, root: pruned, ...);
  }).where((t) => t.root.children.isNotEmpty || t.root.dataRefs.isNotEmpty).toList();
}

// Returns null if no DataRef in this subtree has an id in idSet
GroupNode? _pruneTree(GroupNode node, Set<int> idSet) {
  final keptRefs = node.dataRefs.where((r) => idSet.contains(r.id)).toList();
  final keptChildren = node.children
    .map((c) => _pruneTree(c, idSet))
    .whereType<GroupNode>()
    .toList();
  if (keptRefs.isEmpty && keptChildren.isEmpty) return null;
  return node.copyWith(dataRefs: keptRefs, children: keptChildren);
}
```

## Error Handling

- Missing XML files in the inner tar: log a warning, continue with empty data
- Malformed XML: catch parse exceptions, report per-file error in UI
- Missing address mapping for a data ref: add to `TagGenerationResult.warnings`, skip tag

## Performance Notes

- FC3 map can have 6800+ entries — parsing is in-memory and fast for Dart, but all parsing should be `async` to avoid blocking the UI thread
- Use `compute()` or `Isolate.run()` if parsing blocks UI noticeably in WASM
