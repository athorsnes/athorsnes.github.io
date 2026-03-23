# Backup File Format

## Outer Structure

A `.backup` file is a **tar archive** containing four entries:

```
backup_app_.dupdate   — binary update payload (ignored)
version-method        — plain text, BSP/update info (ignored)
metadata.txt          — plain text, key=value device info
xmlfiles.tar          — inner tar with all configuration XMLs
```

## metadata.txt

Key=value format (one per line, some comment lines with `;`).

Relevant fields:

| Key | Example | Use |
|---|---|---|
| `FAMILY` | `Marine` | Device family |
| `TYPE` | `DG` / `SG` / `EDG` | Device type |
| `VARIANT` | `_NA_` | Sub-variant |
| `ML300APP_VERSION` | `2.0.15.0-MP` | Firmware version |
| `BACKUP_VERSION` | `2` | Backup schema version |

## xmlfiles.tar (inner tar)

Contains ~60 XML files. Files of interest:

| File | Description |
|---|---|
| `ControllerInfo.xml` | IP address, PLANTID, LABEL, VARIANT |
| `ModbusConfiguration.xml` | Protocol definitions (id→name) and conversion formulas |
| `Commands.xml` | All command data points (id, pretty_name, group) |
| `ModbusGroups.xml` | Hierarchical register group tree (nodes reference text IDs) |
| `gb.xml` | English text lookup table: `<Text id="7000" value="Start/stop"/>` (9000+ entries) |
| `ModbusMap&protocol_id=1&function_code=1&address=0&quantity=65535.xml` | FC1 coil map (write commands) |
| `ModbusMap&protocol_id=1&function_code=2&address=0&quantity=65535.xml` | FC2 discrete input map (boolean status) |
| `ModbusMap&protocol_id=1&function_code=3&address=0&quantity=65535.xml` | FC3 holding register map (analog read) |
| `ModbusMap&protocol_id=1&function_code=4&address=0&quantity=65535.xml` | FC4 input register map (analog read) |

Protocol ID 1 is always the primary device protocol (DG default, SG default, etc.).

## ControllerInfo.xml

```xml
<ControllerInfo ...>
  <Info type="PLANTID"  value="1"           .../>
  <Info type="LABEL"    value="DG 1"        .../>
  <Info type="VARIANT"  value="DG"          .../>
  <Info type="IPADDR"   value="10.10.103.101" .../>
  ...
</ControllerInfo>
```

- `PLANTID` → JMobile `node_id`
- `LABEL` → used to build tag `name` prefix (e.g. "DG 1" → "DG1")
- `VARIANT` → device type (DG / SG / EDG)

## ModbusConfiguration.xml

```xml
<ModbusConfiguration ...>
  <Protocols>
    <Protocol id="1" name="DG default protocol"/>
    <Protocol id="2" name="SG default protocol"/>
    ...
  </Protocols>
  <Conversions>
    <Conversion id="1" name="X * 1"   formula="x"    />
    <Conversion id="2" name="X * 10"  formula="x*10" />
    <Conversion id="3" name="X * 0.1" formula="x*0.1"/>
    ...
  </Conversions>
</ModbusConfiguration>
```

Conversions are referenced by id in the FC3/FC4 register maps.

## Commands.xml

```xml
<Commands ...>
  <Command id="8000" name_text_id="8000" pretty_name="Start engine"      group_text_id="7000" hidden="false"/>
  <Command id="8001" name_text_id="8001" pretty_name="Stop engine"       group_text_id="7000" hidden="false"/>
  <Command id="8600" name_text_id="8600" pretty_name="Ack all alarms"    group_text_id="7002" hidden="false"/>
  ...
</Commands>
```

## ModbusGroups.xml

Hierarchical tree. Each node is either a `Group` (container) or a `Data` (leaf register reference).

```xml
<Groups ...>
  <Group id="1" pretty_name="Commands" name_text_id="203500000">
    <Group id="2" name_text_id="7000">          <!-- "Start/stop" subgroup -->
      <Data id="8000" source="Command" type="bit"/>
      <Data id="8001" source="Command" type="bit"/>
      ...
    </Group>
    ...
  </Group>
  <Group id="16" pretty_name="Parameters" name_text_id="203005000">
    ...
  </Group>
  ...
</Groups>
```

Leaf `Data` nodes reference register IDs by source:
- `source="Command"` → id is a Command.id, maps to FC1 coil
- `source="LDOBase"` → id is an internal data point, maps to FC2/FC3/FC4
- `source="Parameter"` → settable parameter, maps to FC3 (READ-WRITE)
- `source="AlarmState"` / `source="AlarmActive"` / etc. → alarm-related, maps to FC4

## gb.xml (Text Lookup Table)

Flat list of `<Text id="..." value="..."/>` entries, ~9000 entries. Used to resolve
`name_text_id` attributes on `GroupNode` elements to human-readable English strings.

```xml
<Texts>
  <Text id="7000" value="Start/stop"/>
  <Text id="7001" value="Generator breaker"/>
  <Text id="7002" value="Alarms"/>
  <Text id="203500000" value="Commands"/>
  <Text id="203005000" value="Parameters"/>
  ...
</Texts>
```

Name resolution priority: `pretty_name` attribute first (if non-empty), then `name_text_id`
lookup in `gb.xml`, then fall back to the raw `name_text_id` number in brackets.

## ModbusMap FC1 (Coils — writable bits)

```xml
<ModbusMap ...>
  <Info><FunctionCode>1</FunctionCode>...</Info>
  <Map address="1000"><Bit><Data id="8000" source="Command"/></Bit></Map>
  <Map address="1001"><Bit><Data id="8001" source="Command"/></Bit></Map>
  <Map address="1003"><Bit><Data id="8003" source="Command"/></Bit></Map>
  ...
</ModbusMap>
```

Address range observed: ~1000–47680

## ModbusMap FC2 (Discrete Inputs — readable bits)

```xml
<Map address="8015"><Bit><Data id="11280006" source="LDOBase"/></Bit></Map>
<Map address="8020"><Bit><Data id="..." source="LDOBase"/></Bit></Map>
```

Address range observed: ~8000–53680

## ModbusMap FC3 (Holding Registers — readable 16-bit words)

```xml
<Map address="8000">
  <Value conversion_id="1" data_type="INT16">
    <Data id="11080004" source="LDOBase"/>
  </Value>
</Map>
```

Address range observed: ~8000–53000+. 6801 entries for DG backup.

## Address → JMobile Offset Mapping

| Modbus FC | ModbusMap address | JMobile memory_type | JMobile offset |
|---|---|---|---|
| FC1 (coil) | N | `OUTP` | N (direct) |
| FC2 (discrete input) | N | `INP` | N + 100000 |
| FC3 (holding register) | N | `HREG` | N + 400000 |
| FC4 (input register) | N | `IREG` | N + 300000 |

All four confirmed from example taglist.xml. Tag name suffix = `-F{functionCode:02d}`
(e.g. FC1 → `-F01`, FC4 → `-F04`), not related to plant ID.
