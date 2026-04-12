/// Thrown when protocol structure mutation is blocked (ARM-linked or lifecycle).
class ProtocolEditBlockedException implements Exception {
  final String message;
  ProtocolEditBlockedException(this.message);
  @override
  String toString() => message;
}
