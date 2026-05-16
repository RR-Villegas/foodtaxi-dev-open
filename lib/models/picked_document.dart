import 'dart:typed_data';

class PickedDocument {
  final String label;
  final String fileName;
  final String contentType;
  final Uint8List bytes;

  const PickedDocument({
    required this.label,
    required this.fileName,
    required this.contentType,
    required this.bytes,
  });

  int get size => bytes.lengthInBytes;

  String get extension {
    final parts = fileName.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : 'bin';
  }
}
