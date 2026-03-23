# Data Model

Dart classes that represent parsed backup data, intermediate structures, and output tags.

## BackupFile

Top-level container for a parsed `.backup` file.

```dart
class BackupFile {
  final String fileName;
  final DeviceInfo deviceInfo;        // from ControllerInfo.xml
  final List<ProtocolDef> protocols;  // from ModbusConfiguration.xml
  final List<ConversionDef> conversions;
  final List<CommandDef> commands;    // from Commands.xml
  final GroupNode rootGroup;          // from ModbusGroups.xml (names resolved via gb.xml)
  final Map<int, String> texts;       // from gb.xml: text_id → English string
  final ModbusMap coilMap;            // FC1
  final ModbusMap discreteInputMap;   // FC2
  final ModbusMap holdingRegMap;      // FC3
  final ModbusMap inputRegMap;        // FC4 (may be empty)
}
```

## DeviceInfo

```dart
class DeviceInfo {
  final int plantId;       // PLANTID — used as JMobile node_id
  final String label;      // LABEL e.g. "DG 1"
  final String variant;    // VARIANT e.g. "DG", "SG", "EDG"
  final String ipAddress;  // IPADDR
  final String groupPrefix; // derived: label without spaces e.g. "DG1"
}
```

## ProtocolDef / ConversionDef

```dart
class ProtocolDef {
  final int id;
  final String name;
}

class ConversionDef {
  final int id;
  final String name;     // e.g. "X * 0.1"
  final String formula;  // e.g. "x*0.1"
}
```

## CommandDef

```dart
class CommandDef {
  final int id;
  final String prettyName;
  final int groupTextId;
  final bool hidden;
}
```

## GroupNode

Recursive tree matching the ModbusGroups.xml hierarchy.
Names are resolved at parse time from gb.xml.

```dart
class GroupNode {
  final int id;
  final String resolvedName;   // resolved from pretty_name or name_text_id via gb.xml
  final int nameTextId;
  final List<GroupNode> children;
  final List<DataRef> dataRefs; // leaf register references in this node
}

class DataRef {
  final int id;
  final String source;   // "Command", "LDOBase", "Parameter", "AlarmState", etc.
  final String type;     // "bit" or "value"
}
```

## GroupSelectionState

Tracks which `GroupNode`s are selected **per function code**.
The same group node can be independently checked in FC1, FC2, FC3, FC4 sections.

```dart
/// The three-state value for a checkbox node in the tree.
enum CheckState { unchecked, partial, checked }

/// Key for selection: (groupNodeId, functionCode)
typedef FcGroupKey = (int groupId, int fc);

class GroupSelectionState extends ChangeNotifier {
  // Independently tracked per FC
  final Map<int, Set<int>> _checkedIdsByFc = {1: {}, 2: {}, 3: {}, 4: {}};

  CheckState stateOf(GroupNode node, int fc) { ... }
  void toggle(GroupNode node, int fc, GroupNode root) { ... }

  // Returns all DataRef leaves under checked nodes for a given fc
  // DataRef must resolve to an address in that fc's ModbusMap to be included
  List<DataRef> selectedRefsForFc(GroupNode root, int fc) { ... }
}
```

## FcGroupTree

A pruned view of the `GroupNode` tree containing only nodes relevant to one FC.
Built after all backups are parsed.

```dart
class FcGroupTree {
  final int fc;
  final String label;        // e.g. "FC1 — Write commands"
  final String memoryType;   // "OUTP", "INP", "HREG", "IREG"
  final GroupNode root;      // pruned tree — only branches with ≥1 address in this FC
}
```

Built by `GroupTreeBuilder.buildFcTrees(BackupFile backup)`:
1. For each FC (1–4): collect the set of dataIds that have an address in that FC's map
2. Recursively prune the `GroupNode` tree, keeping only nodes where any descendant
   `DataRef.id` is in that FC's id set
3. Return 4 `FcGroupTree` instances (skip any with empty root)

## ModbusMap

```dart
class ModbusMap {
  final int functionCode;
  final Map<int, ModbusEntry> entries; // address → entry
}

class ModbusEntry {
  final int address;
  final ModbusEntryKind kind; // bit or value
  final int dataId;
  final String source;       // "Command" or "LDOBase"
  final String? dataType;    // "INT16", "UINT16", etc. (value entries only)
  final int? conversionId;   // (value entries only)
}

enum ModbusEntryKind { bit, value }
```

## Reverse lookup maps (built during parsing)

```dart
// For each BackupFile, build these after parsing:
Map<int, int> commandIdToFC1Address;     // Command.id → coil address
Map<int, int> dataIdToFC2Address;        // LDOBase id → discrete input address
Map<int, int> dataIdToFC3Address;        // LDOBase id → holding register address
Map<int, int> dataIdToFC4Address;        // LDOBase id → input register address
```

## JMobileTag (output)

Represents one `<tag>` element in the output taglist.xml.

```dart
class JMobileTag {
  final String name;         // e.g. "DG1/Commands - Start engine -F01"
  final String group;        // e.g. "DG1"
  final String protocolName; // "MODT"
  final int nodeId;          // PLANTID
  final String memoryType;   // "OUTP", "INP", "REG"
  final int offset;          // JMobile-format address
  final String dataType;     // "boolean", "integer", "short", etc.
  final String accessMode;   // "READ-WRITE" or "READ"
  final int refreshTime;     // ms, default 500
}
```

## TagGenerationResult

```dart
class TagGenerationResult {
  final List<JMobileTag> tags;
  final List<String> warnings; // e.g. skipped registers without address mapping
}
```

## AppState

```dart
class AppState extends ChangeNotifier {
  final List<BackupFileState> backups = [];

  // Built/rebuilt when backups are added or removed
  // One merged FcGroupTree per FC (union of all loaded backup group trees)
  List<FcGroupTree> fcTrees = [];

  // Shared selection across all devices (keyed by group resolvedName, not id,
  // since different device types may have different node IDs for same logical group)
  final GroupSelectionState selection = GroupSelectionState();

  List<JMobileTag> get filteredTags { ... }
  int get tagCount => filteredTags.length;
}
```
