class JMobileTag {
  final String name;
  final String group;
  final int nodeId;
  final String memoryType;
  final int offset;
  final String dataType;
  final String accessMode;
  final int refreshTime;
  final String min;
  final String max;

  const JMobileTag({
    required this.name,
    required this.group,
    required this.nodeId,
    required this.memoryType,
    required this.offset,
    required this.dataType,
    required this.accessMode,
    this.refreshTime = 500,
    required this.min,
    required this.max,
  });
}

class TagGenerationResult {
  final List<JMobileTag> tags;
  final List<String> warnings;
  const TagGenerationResult({required this.tags, required this.warnings});
}
