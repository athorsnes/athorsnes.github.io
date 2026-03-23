# HMI From Backups — Project Overview

## Goal

A Flutter WASM web app that:
1. Accepts one or more `.backup` files (from ML350 Marine controllers) as input
2. Extracts and parses the Modbus register maps embedded in each backup
3. Generates a `taglist.xml` compatible with JMobile, containing the most relevant registers from all devices

## Technology Stack

| Concern | Choice | Reason |
|---|---|---|
| Framework | Flutter (WASM target) | Required; runs entirely in browser |
| Tar extraction | `archive` package (pure Dart) | No native tar in WASM |
| XML parsing | `xml` package (pure Dart) | Works in WASM |
| File input | `file_picker` (web) | Multi-file drag & drop |
| File output | `dart:html` Blob download | Browser-native save |
| State management | Flutter `ValueNotifier` / `setState` | Simple enough for this app |

## Document Index

| File | Contents |
|---|---|
| `01_backup_format.md` | Reverse-engineered `.backup` file format |
| `02_data_model.md` | Dart data model for parsed backup data |
| `03_parsing_logic.md` | Step-by-step parsing algorithm |
| `04_tag_generation.md` | How backup data maps to JMobile tag entries |
| `05_ui_design.md` | Screens, widgets, and UX flow |
| `06_file_structure.md` | Dart source file layout |
| `07_dependencies.md` | Package dependencies and WASM compatibility |
