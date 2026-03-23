# UI Design

## Overall Layout

Two-panel layout on wide screens, single-column on narrow screens.

```
┌─────────────────────────────────────────────────────────────────────┐
│  AppBar: "HMI Tag Generator"                                        │
├───────────────────────────────────┬─────────────────────────────────┤
│  LEFT PANEL                       │  RIGHT PANEL                    │
│                                   │                                 │
│  ┌───────────────────────────┐    │  ┌──── FC1 — Write commands ──┐ │
│  │  DROP ZONE / FILE PICKER  │    │  │ ▼ ☑ Commands               │ │
│  └───────────────────────────┘    │  │     ☑ Start/stop           │ │
│                                   │  │     ☑ Generator breaker    │ │
│  Loaded files:                    │  │     ☑ Modes                │ │
│  ┌─────────────────────────────┐  │  │     ☐ Lamp test            │ │
│  │ ✓ DG 1  node=1  423 tags   │  │  │ ▶ ─ Functions              │ │
│  │ ✓ DG 2  node=2  423 tags   │  │  │ ▶ ─ Parameters             │ │
│  │ ✓ SG 1  node=3  387 tags   │  │  └────────────────────────────┘ │
│  │ ✗ EDG 1 (parse error)      │  │  ┌──── FC2 — Digital status ──┐ │
│  └─────────────────────────────┘  │  │ ▶ ☑ Functions              │ │
│                                   │  │     ☑ Digital out          │ │
│                                   │  │ ▶ ☐ ICC                    │ │
│                                   │  │ ▶ ─ Parameters             │ │
│                                   │  └────────────────────────────┘ │
│                                   │  ┌──── FC3 — Holding regs ───┐  │
│                                   │  │ ▶ ─ Functions              │  │
│                                   │  │ ▶ ☐ Parameters             │  │
│                                   │  │ ▶ ☐ Counters               │  │
│                                   │  └────────────────────────────┘  │
│                                   │  ┌──── FC4 — Input regs ─────┐  │
│                                   │  │ ▶ ─ Functions              │  │
│                                   │  │ ▶ ☐ Counters               │  │
│                                   │  │ ▶ ☐ Regulator status       │  │
│                                   │  └────────────────────────────┘  │
│                                   │  ─────────────────────────────   │
│                                   │  847 tags from 3 devices         │
│                                   │  [ Generate taglist.xml ]        │
└───────────────────────────────────┴─────────────────────────────────┘
```

Legend: `▼` = expanded, `▶` = collapsed, `☑` = all selected, `─` = partial, `☐` = none

## Widgets

### DropZone

- Uses `DragTarget<Object>` + `GestureDetector` for click
- On click: opens file picker via `file_picker` package
- Accepts `.backup` files (any mime type — browser doesn't distinguish)
- Shows visual feedback (highlighted border) on drag-over

### FileListTile

One row per loaded backup. Shows:
- Status icon: ✓ parsed / ✗ error / spinner loading
- Device label and node_id (e.g. "DG 1 — node 1")
- Estimated tag count for this device (based on current group selection)
- Remove button (×)

### GroupTreePanel

A scrollable panel containing **four FC sections**, each with its own independent
tri-state checkbox tree. Sections are collapsible at the FC level.

**FC sections and their labels:**

| Section header | memory_type | Typical groups |
|---|---|---|
| FC1 — Write commands | `OUTP` | Commands, Functions/Digital in, parts of Parameters |
| FC2 — Digital status | `INP` (bool) | Functions/Digital out, ICC, parts of Parameters |
| FC3 — Holding registers | `HREG` | Functions/Analogue in+out, Parameters, Counters |
| FC4 — Input registers | `IREG` | Functions/Analogue out, Counters, Regulator status |

**FC-aware group tree (confirmed from DG backup analysis):**

| Group | FC1 | FC2 | FC3 | FC4 |
|---|---|---|---|---|
| Commands | ✓ all | — | — | — |
| Functions / Digital in | ✓ | — | — | — |
| Functions / Digital out | ✓ | ✓ | — | — |
| Functions / Analogue in | — | — | ✓ | — |
| Functions / Analogue out | — | — | ✓ | ✓ |
| Parameters | ✓ | ✓ | ✓ | ✓ |
| ICC | — | ✓ | — | — |
| Priorities | — | — | ✓ | ✓ |
| Counters | — | — | ✓ | ✓ |
| Regulator status | — | — | — | ✓ |
| Custom alarms | ✓ | ✓ | ✓ | ✓ |

A group node only appears in an FC section if it contains ≥1 DataRef resolvable
to that FC's Modbus map.

**Checkbox behavior (per section, independent):**
- Tri-state per node: `CheckState.checked` / `partial` / `unchecked`
- Checking a parent → recursively checks all descendants **within that FC section**
- Unchecking a parent → recursively unchecks all descendants **within that FC section**
- Parent shows `partial` when some children are checked

**Expand/collapse:**
- Each non-leaf node has an expand toggle (`▶` / `▼`)
- Default: FC section headers expanded, top-level group nodes collapsed
- Small "Expand all" / "Collapse all" link per section

**Default selections (checked on first load):**
- FC1: `Commands` → all subgroups checked
- FC2: `Functions / Digital out` → checked
- FC3: `Functions / Analogue in` → checked
- FC4: nothing checked by default
- All else → unchecked

### TagCountSummary

`"{N} tags from {M} devices"` — recalculates live as selections change.

### GenerateButton

- Disabled until ≥ 1 backup parsed and ≥ 1 group selected
- Label shows tag count: "Generate taglist.xml (847 tags)"
- On press: calls `generateXml(tags)`, triggers Blob download

## State

```dart
class BackupFileState {
  final String fileName;
  BackupParseStatus status; // loading / success / error
  BackupFile? parsed;
  String? errorMessage;
}
```

`GroupSelectionState` (see `02_data_model.md`) is a `ChangeNotifier` shared
between `GroupTreePanel` and `GenerateButton`.

## UX Notes

- Parsing is async — show per-file progress indicator in FileListTile
- Multiple files can be added incrementally
- If two backups have different group trees (DG vs SG), the group panel rebuilds
  to show the union of groups; selections are preserved by `resolvedName` key
- Output filename is always `taglist.xml`
- Responsive: on screens < 800px wide, panels stack vertically
