import 'dart:typed_data';

class SelectedProof {
  SelectedProof({required this.name, required this.bytes}) {
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw StateError('Choose an image up to 2 MB.');
    }
    if (mime == null) throw StateError('Choose a JPG, PNG or WebP image.');
    if (name.isEmpty || name.length > 180) {
      throw StateError('Choose a file with a shorter name.');
    }
  }
  static const maxBytes = 2 * 1024 * 1024;
  final String name;
  final Uint8List bytes;
  String? get mime {
    if (bytes.length >= 8 &&
        bytes[0] == 137 &&
        bytes[1] == 80 &&
        bytes[2] == 78 &&
        bytes[3] == 71 &&
        bytes[4] == 13 &&
        bytes[5] == 10 &&
        bytes[6] == 26 &&
        bytes[7] == 10) {
      return 'image/png';
    }
    if (bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255) {
      return 'image/jpeg';
    }
    if (bytes.length >= 12 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
      return 'image/webp';
    }
    return null;
  }
}

class ProofImage {
  const ProofImage({
    required this.id,
    required this.kind,
    required this.name,
    required this.mime,
    required this.size,
    required this.date,
    this.bytes,
  });
  final String id, kind, name, mime;
  final int size;
  final DateTime date;
  final Uint8List? bytes;
  factory ProofImage.fromJson(Map<String, dynamic> j) => ProofImage(
    id: j['id'],
    kind: j['kind'],
    name: j['name'],
    mime: j['mime'],
    size: j['size'],
    date: DateTime.parse(j['date']).toLocal(),
  );
  String get label => switch (kind) {
    'receipt' => 'Receipt',
    'item' => 'Item photo',
    _ => 'Delivery photo',
  };
}
