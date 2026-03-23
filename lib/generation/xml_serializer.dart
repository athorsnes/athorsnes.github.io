import '../models/jmobile_tag.dart';

String serializeTaglist(List<JMobileTag> tags) {
  final buf = StringBuffer();
  buf.writeln('<?xml version="1.0"?>');
  buf.writeln('<tags>');
  buf.writeln(_placeholder());
  for (final tag in tags) {
    buf.writeln(_tagXml(tag));
  }
  buf.writeln('</tags>');
  return buf.toString();
}

String _placeholder() => '''    <tag>
        <name>n/a</name>
        <group>n/a</group>
        <resourceLocator>
            <protocolName>n/a</protocolName>
            <node_id>n/a</node_id>
            <memory_type>n/a</memory_type>
            <offset>n/a</offset>
            <subindex>n/a</subindex>
            <data_type>n/a</data_type>
            <arraysize>n/a</arraysize>
            <conversion>n/a</conversion>
        </resourceLocator>
        <encoding>n/a</encoding>
        <refreshTime>n/a</refreshTime>
        <accessMode>n/a</accessMode>
        <active>n/a</active>
        <TAGLOCATOR>n/a</TAGLOCATOR>
        <comment>n/a</comment>
        <simulator>
            <DataSimulator>n/a</DataSimulator>
            <Amplitude>n/a</Amplitude>
            <Simulator_offset>n/a</Simulator_offset>
            <Period>n/a</Period>
        </simulator>
        <scaling>
            <enableScaling>n/a</enableScaling>
            <scalingType>n/a</scalingType>
            <enableLimits>n/a</enableLimits>
            <factors>
                <s1>n/a</s1>
                <s2>n/a</s2>
                <s3>n/a</s3>
                <tagS1>n/a</tagS1>
                <tagS2>n/a</tagS2>
                <tagS3>n/a</tagS3>
            </factors>
            <limits>
                <eumin>n/a</eumin>
                <eumax>n/a</eumax>
                <elmin>n/a</elmin>
                <elmax>n/a</elmax>
            </limits>
        </scaling>
        <decimalDigits>
            <ddTag>n/a</ddTag>
            <ddDigits>n/a</ddDigits>
        </decimalDigits>
        <castType>n/a</castType>
        <default>n/a</default>
        <min>n/a</min>
        <max>n/a</max>
        <statesText>n/a</statesText>
    </tag>''';

String _tagXml(JMobileTag t) {
  final name = _esc(t.name);
  return '''    <tag>
        <name>$name</name>
        <group>${_esc(t.group)}</group>
        <resourceLocator>
            <protocolName>MODT</protocolName>
            <node_id>${t.nodeId}</node_id>
            <memory_type>${t.memoryType}</memory_type>
            <offset>${t.offset}</offset>
            <subindex></subindex>
            <data_type>${t.dataType}</data_type>
            <arraysize></arraysize>
            <conversion></conversion>
        </resourceLocator>
        <encoding></encoding>
        <refreshTime>${t.refreshTime}</refreshTime>
        <accessMode>${t.accessMode}</accessMode>
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
                <s1>1</s1>
                <s2>1</s2>
                <s3>0</s3>
                <tagS1></tagS1>
                <tagS2></tagS2>
                <tagS3></tagS3>
            </factors>
            <limits>
                <eumin>0</eumin>
                <eumax>100</eumax>
                <elmin></elmin>
                <elmax></elmax>
            </limits>
        </scaling>
        <decimalDigits>
            <ddTag></ddTag>
            <ddDigits></ddDigits>
        </decimalDigits>
        <castType></castType>
        <default></default>
        <min>${t.min}</min>
        <max>${t.max}</max>
        <statesText></statesText>
    </tag>''';
}

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
