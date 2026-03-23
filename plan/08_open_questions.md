# Open Questions & Items to Verify

## 1. FC3/FC4 JMobile Offset Format

**Status: RESOLVED**

User added FC3 and FC4 example tags to `taglist.xml`. Confirmed:
- FC3 (holding registers): `memory_type=HREG`, offset = address + 400000
- FC4 (input registers): `memory_type=IREG`, offset = address + 300000

Additional findings:
- FC3 entries with `source="Parameter"` use `accessMode=READ-WRITE`
- Other FC3/FC4 entries use `accessMode=READ`
- `min=-32768`, `max=32767` for `data_type=short` tags

## 2. LDOBase pretty_name / human-readable labels for FC2/FC3

**Status: Partially understood**

`Commands.xml` provides `pretty_name` for FC1 command registers.
FC2 and FC3 entries have `source="LDOBase"` with numeric data IDs (e.g. `11280006`).
No XML file in the backup seems to contain human-readable names for these IDs.

The example taglist uses descriptions like "Engine - State - Running" and
"GB is closed" — these appear to be constructed from the `ModbusGroups.xml`
hierarchy path, not from a separate name lookup table.

**Action:** Verify that the tag name in the example taglist is derived purely
from the ModbusGroups nested Group path (concatenating `pretty_name` values at
each level) rather than from a separate text map.

If the hierarchy path alone is sufficient, no additional name resolution is needed.

## 3. Protocol_id for non-DG device types

**Status: RESOLVED**

Confirmed: the correct protocol_id depends on device VARIANT, not a fixed value.
Match by finding the Protocol whose `name` starts with the VARIANT string:
- DG → protocol_id=1 ("DG default protocol")
- SG → protocol_id=2 ("SG default protocol")
- EDG → protocol_id=5 ("EDG default protocol")

The SG1 FC3 HREG tag at offset 447082 was confirmed at address 47082 in
`protocol_id=2&function_code=3` (not protocol_id=1). See `plan/03_parsing_logic.md`
for the full algorithm.

## 4. Multiple protocol servers per backup

**Status: To investigate**

`ModbusConfiguration.xml` shows a `<Servers>` section. If a device has multiple
Modbus servers (different ports), each may have different maps. For the initial
implementation, only the first/default server (port 502) is used.

## 5. Hidden commands

**Status: Design decision needed**

`Commands.xml` has `hidden="true"` on some commands (e.g. "Feature toggle accept").
These are excluded by default in the plan. Confirm with user whether to expose
a "show hidden" toggle in the UI.

## 6. Tag ordering in output

**Status: Design decision**

The output taglist tags should probably be grouped by device, then by top-level
group category (Commands first, then Functions, then Measurements). Within each
category, tags follow the ModbusGroups tree order.

The first `<tag>` must always be the all-`n/a` placeholder entry.
