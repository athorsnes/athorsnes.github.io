# Source File Structure

```
lib/
├── main.dart                     # runApp entry point
│
├── models/
│   ├── backup_file.dart          # BackupFile, DeviceInfo, ProtocolDef, ConversionDef
│   ├── modbus_map.dart           # ModbusMap, ModbusEntry, ModbusEntryKind
│   ├── group_node.dart           # GroupNode, DataRef
│   ├── fc_group_tree.dart        # FcGroupTree, GroupTreeBuilder (prunes tree per FC)
│   ├── group_selection.dart      # GroupSelectionState, CheckState (per-FC selection)
│   └── jmobile_tag.dart          # JMobileTag, TagGenerationResult
│
├── parsing/
│   ├── backup_parser.dart        # Top-level parseBackupFile() entry point
│   ├── controller_info_parser.dart
│   ├── modbus_config_parser.dart
│   ├── commands_parser.dart
│   ├── texts_parser.dart         # gb.xml → Map<int, String>
│   ├── modbus_groups_parser.dart # takes Map<int,String> for name resolution
│   └── modbus_map_parser.dart
│
├── generation/
│   ├── tag_generator.dart        # Walks GroupNode tree → List<JMobileTag>
│   └── xml_serializer.dart       # List<JMobileTag> → taglist.xml string
│
├── ui/
│   ├── app.dart                  # MaterialApp root, theme
│   ├── home_page.dart            # Two-panel layout
│   ├── app_state.dart            # ChangeNotifier holding BackupFileStates
│   └── widgets/
│       ├── drop_zone.dart
│       ├── file_list_tile.dart
│       ├── group_tree_panel.dart  # 4 FC sections, each with a checkbox tree
│       ├── fc_section.dart        # Collapsible FC section header + tree
│       ├── group_tree_node.dart   # Single expandable tri-state checkbox node
│       └── generate_button.dart
│
└── utils/
    └── file_download.dart        # Browser Blob download helper (package:web)
```

## Key Dependencies Between Files

```
home_page.dart
  ├─ uses AppState (app_state.dart)
  │     └─ holds List<BackupFileState>
  │           └─ BackupFile (models/backup_file.dart)
  │                └─ parsed by backup_parser.dart
  │                     └─ delegates to controller_info_parser, texts_parser,
  │                                     commands_parser, modbus_groups_parser,
  │                                     modbus_config_parser, modbus_map_parser
  │
  └─ uses GroupSelectionState (models/group_selection.dart)
        └─ built from GroupNode tree (from BackupFile.rootGroup)

group_tree_panel.dart
  └─ renders 4 × fc_section.dart (one per FC)
       └─ renders group_tree_node.dart (recursive)
            └─ reads/writes GroupSelectionState (per fc)

home_page.dart → [Generate] → tag_generator.dart → xml_serializer.dart → file_download.dart
                                    ↑ uses GroupSelectionState.selectedRefsForFc(root, fc)
                                         ↑ cross-references ModbusMap to resolve addresses
```

## Notes

- All parsing is pure Dart, no platform channels — WASM compatible
- `xml_serializer.dart` builds the XML string manually (not via xml package) for
  full control over formatting and whitespace
- `file_download.dart` uses `dart:js_interop` / `package:web` to trigger a browser
  download of a Blob — the approach that replaces the deprecated `dart:html` API
