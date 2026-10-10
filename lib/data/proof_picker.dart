import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';

import '../models/proof_image.dart';

typedef ProofPicker = Future<SelectedProof?> Function();

Future<SelectedProof?> pickProofImage() async {
  final file = await openFile(
    acceptedTypeGroups: const [
      XTypeGroup(
        label: 'Proof images',
        extensions: ['jpg', 'jpeg', 'png', 'webp'],
        mimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
        uniformTypeIdentifiers: [
          'public.jpeg',
          'public.png',
          'org.webmproject.webp',
        ],
      ),
    ],
  );
  if (file == null) return null;
  if (await file.length() > SelectedProof.maxBytes) {
    throw StateError('Choose an image up to 2 MB.');
  }
  final proof = SelectedProof(name: file.name, bytes: await file.readAsBytes());
  await validateProofImage(proof);
  return proof;
}

Future<void> validateProofImage(SelectedProof proof) async {
  // Decode before showing a preview, rather than trusting the filename or extension.
  final buffer = await ui.ImmutableBuffer.fromUint8List(proof.bytes);
  // Encoded ImageDescriptor dimensions are unavailable on Flutter web.
  // This callback works on both web and native and owns the buffer disposal.
  final codec = await ui.instantiateImageCodecWithSize(
    buffer,
    getTargetSize: (width, height) {
      if (width * height > 20000000) {
        throw StateError('Choose an image with at most 20 megapixels.');
      }
      return ui.TargetImageSize(width: width > 1600 ? 1600 : width);
    },
  );
  try {
    final frame = await codec.getNextFrame();
    frame.image.dispose();
  } finally {
    codec.dispose();
  }
}
