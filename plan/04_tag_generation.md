# Tag Generation Logic

## Overview

For each parsed `BackupFile`, walk the `ModbusGroups` tree and emit one `JMobileTag`
per leaf `DataRef` that has a known Modbus address. Tags from all backups are merged
into one flat list, which becomes the taglist.xml output.

## Address → JMobile Offset Mapping

| FC | Modbus address | JMobile memory_type | JMobile offset formula |
|---|---|---|---|
| FC1 coil | N | `OUTP` | N (direct) |
| FC2 discrete input | N | `INP` | N + 100000 |
| FC3 holding register | N | `HREG` | N + 400000 |
| FC4 input register | N | `IREG` | N + 300000 |

All four mappings are confirmed from the example `taglist.xml`.

## Tag Name Construction

The tag `<name>` field follows the pattern seen in the example:

```
{groupPrefix}/{breadcrumb path} -{deviceSuffix}
```

Examples:
- `DG1/Commands - Start engine -F01`
- `DG1/Functions - Digital output functions - Engine - State - Running -F02`

**Construction algorithm:**

1. `groupPrefix` = `DeviceInfo.groupPrefix` (e.g. "DG1", "SG1")
2. Walk the `GroupNode` path from root to the leaf `DataRef`, collecting `pretty_name`
   values at each level. Join with ` - `.
3. Append a function-code suffix: `-F{functionCode:02d}`
   - FC1 coil → `-F01`
   - FC2 discrete input → `-F02`
   - FC3 holding register → `-F03`
   - FC4 input register → `-F04`
4. Full name: `{groupPrefix}/{path} -{suffix}`

**pretty_name resolution:**
- Some `GroupNode` entries lack `pretty_name` but have `name_text_id`.
  For groups whose pretty_name is absent, fall back to the id as a string.
- `DataRef` names come from `Commands.xml` if `source="Command"`, otherwise
  the `name_text_id` is used as-is (human-readable names for LDOBase points are
  not available from the backup alone — use the id).

## Access Mode and Data Type

| Source | FC | JMobile accessMode | JMobile data_type |
|---|---|---|---|
| Command | FC1 (coil) | `READ-WRITE` | `boolean` |
| LDOBase | FC2 (discrete input) | `READ` | `boolean` |
| Parameter | FC3 (holding register) | `READ-WRITE` | mapped from ModbusMap data_type |
| LDOBase/AlarmState | FC3 (holding register) | `READ` | mapped from ModbusMap data_type |
| LDOBase/AlarmState | FC4 (input register) | `READ` | mapped from ModbusMap data_type |

FC3 holding registers with `source="Parameter"` are writable (setpoints); other FC3
sources are read-only. This matches the example: the SG1 HREG tag `accessMode=READ-WRITE`
corresponds to a `source="Parameter"` entry.

### data_type mapping

| ModbusMap data_type | JMobile data_type |
|---|---|
| `INT16` | `short` |
| `UINT16` | `word` |
| `INT32` | `integer` |
| `UINT32` | `dword` |
| `FLOAT32` | `float` |
| *(absent / bit)* | `boolean` |

## "Most Relevant" Register Selection

The full FC3 map contains 6800+ entries. Exporting all of them would be noisy
and impractical for an HMI operator. The strategy is to use the **ModbusGroups tree**
as the relevance filter: only registers that appear in the groups hierarchy are included.

**Top-level groups and their handling:**

| Group pretty_name | FC | Include by default | Notes |
|---|---|---|---|
| Commands | FC1 | ✓ | All non-hidden commands |
| Functions | FC2 | ✓ | Boolean status, engine/breaker/mode states |
| Measurements | FC3/FC4 | ✓ | Analog values (voltage, current, etc.) |
| Parameters | FC3 | Optional | Setpoints — large group, user-selectable |
| Protections | FC2/FC3 | Optional | Alarm thresholds |

In the UI, each top-level group is shown as a checkbox so the user can include/exclude it.

## Tag Deduplication

When multiple backup files share the same firmware version, registers at the same
address across devices are logically equivalent but belong to different node_ids.
Each device gets its own set of tags (different `node_id` and `name` prefix),
so there is no deduplication needed.

## Output Tag Template

Every generated tag uses these default values for fields that are not register-specific:

```xml
<tag>
  <name>{name}</name>
  <group>{groupPrefix}</group>
  <resourceLocator>
    <protocolName>MODT</protocolName>
    <node_id>{plantId}</node_id>
    <memory_type>{memoryType}</memory_type>
    <offset>{offset}</offset>
    <subindex></subindex>
    <data_type>{dataType}</data_type>
    <arraysize></arraysize>
    <conversion></conversion>
  </resourceLocator>
  <encoding></encoding>
  <refreshTime>500</refreshTime>
  <accessMode>{accessMode}</accessMode>
  <active>false</active>
  <TAGLOCATOR></TAGLOCATOR>
  <comment></comment>
  <simulator>
    <DataSimulator>Variables</DataSimulator>
    <Amplitude></Amplitude>
    <Simulator_offset></Simulator_offset>
    <Period></Period>
  </simulator>
  <scaling>
    <enableScaling>false</enableScaling>
    <scalingType>byFormula</scalingType>
    <enableLimits>false</enableLimits>
    <factors>
      <s1>1</s1><s2>1</s2><s3>0</s3>
      <tagS1></tagS1><tagS2></tagS2><tagS3></tagS3>
    </factors>
    <limits>
      <eumin>0</eumin><eumax>100</eumax>
      <elmin></elmin><elmax></elmax>
    </limits>
  </scaling>
  <decimalDigits><ddTag></ddTag><ddDigits></ddDigits></decimalDigits>
  <castType></castType>
  <default></default>
  <min>0</min>
  <max>{maxValue}</max>
  <statesText></statesText>
</tag>
```

`maxValue` defaults: `1` for boolean, `65535` for INT16/UINT16, `1` otherwise.

## Placeholder Tag

The output taglist must start with the placeholder `<tag>` where all fields are `n/a`,
exactly as in the example file. This is a JMobile import requirement.
