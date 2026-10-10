import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/proof_picker.dart';
import '../models/entities.dart';
import '../models/proof_image.dart';
import '../state/errand_store.dart';
import 'components.dart';
import 'motion.dart';

class ProofUploadPanel extends StatefulWidget {
  const ProofUploadPanel({
    super.key,
    required this.store,
    required this.errand,
    this.delivery = false,
    this.picker,
  });
  final ErrandStore store;
  final Errand errand;
  final bool delivery;
  final ProofPicker? picker;
  @override
  State<ProofUploadPanel> createState() => _ProofUploadPanelState();
}

class _ProofUploadPanelState extends State<ProofUploadPanel> {
  final selected = <String, SelectedProof>{};
  late final TextEditingController cost;
  bool picking = false, saving = false;
  String? error;
  Errand get e => widget.errand;
  @override
  void initState() {
    super.initState();
    cost = TextEditingController(
      text: e.actualCost == null ? '' : money(e.actualCost!),
    );
  }

  @override
  void dispose() {
    cost.dispose();
    super.dispose();
  }

  Future<void> choose(String kind) async {
    setState(() {
      picking = true;
      error = null;
    });
    try {
      final image = await (widget.picker ?? pickProofImage)();
      if (image != null && mounted) setState(() => selected[kind] = image);
    } on StateError catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Could not open that image. Choose a valid JPG, PNG or WebP file.',
        );
      }
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  Future<void> save() async {
    FocusScope.of(context).unfocus();
    setState(() {
      saving = true;
      error = null;
    });
    try {
      if (widget.delivery) {
        await widget.store.uploadDeliveryProof(e, selected['delivery']!);
      } else {
        final value = double.tryParse(cost.text.trim());
        if (value == null || !value.isFinite || value < 0 || value > e.budget) {
          throw StateError(
            'Enter the actual cost between 0 and ${e.purchaseAmount(e.budget)}.',
          );
        }
        await widget.store.uploadProof(
          e,
          value,
          receipt: true,
          photo: true,
          receiptFile: selected['receipt'],
          itemFile: selected['item'],
        );
      }
      if (mounted) {
        setState(selected.clear);
        toast(
          context,
          widget.delivery ? 'Delivery photo saved.' : 'Purchase proof saved.',
        );
      }
    } on StateError catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kinds = widget.delivery ? ['delivery'] : ['receipt', 'item'];
    final ready =
        kinds.every(
          (kind) => selected.containsKey(kind) || e.proof(kind) != null,
        ) &&
        (!widget.delivery || selected.containsKey('delivery'));
    final working = picking || saving || widget.store.busy;
    return Panel(
      color: canvas,
      padding: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.delivery ? 'Delivery photo (optional)' : 'Proof of purchase',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            widget.delivery
                ? 'Show the requester what arrived. Add a photo before verifying handoff.'
                : 'Upload a clear receipt and a photo of the purchased items. The requester can open both.',
            style: const TextStyle(fontSize: 11, color: muted),
          ),
          const SizedBox(height: 8),
          const Text(
            'JPG, PNG or WebP · Up to 2 MB each',
            style: TextStyle(fontSize: 10, color: muted),
          ),
          const SizedBox(height: 14),
          if (!widget.delivery)
            field(
              e.pesoPurchase ? 'Actual item cost (₱)' : 'Actual item cost (CY)',
              cost,
              type: const TextInputType.numberWithOptions(decimal: true),
            ),
          for (final kind in kinds) ...[
            if (selected[kind] case final file?) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(
                  file.bytes,
                  height: 150,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Text(
                    'Could not preview this image. Choose another file.',
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                file.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Text(
                'Selected · Save to upload',
                style: TextStyle(fontSize: 10, color: muted),
              ),
            ] else if (e.proof(kind) case final file?) ...[
              Text(
                '${file.label} saved: ${file.name}',
                style: const TextStyle(fontSize: 11, color: teal),
              ),
            ],
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  key: ValueKey('choose-$kind'),
                  onPressed: working ? null : () => choose(kind),
                  icon: Icon(
                    kind == 'receipt'
                        ? Icons.receipt_long_outlined
                        : Icons.add_a_photo_outlined,
                    size: 18,
                  ),
                  label: Text(
                    '${selected.containsKey(kind) || e.proof(kind) != null ? 'Change' : 'Choose'} ${kind == 'receipt'
                        ? 'receipt'
                        : kind == 'item'
                        ? 'item photo'
                        : 'delivery photo'}',
                  ),
                ),
                if (selected.containsKey(kind))
                  TextButton(
                    onPressed: working
                        ? null
                        : () => setState(() => selected.remove(kind)),
                    child: const Text('Remove selected'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (picking) const LinearProgressIndicator(minHeight: 2),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(
              error!,
              style: const TextStyle(color: Color(0xFFA32828), fontSize: 12),
            ),
            const SizedBox(height: 8),
          ],
          AsyncActionButton(
            label: widget.delivery
                ? 'Save delivery photo'
                : e.actualCost == null
                ? 'Save purchase proof'
                : 'Update purchase proof',
            loadingLabel: 'Uploading…',
            enabled: ready && !working,
            onPressed: save,
          ),
          if (!widget.delivery && e.actualCost != null) ...[
            const SizedBox(height: 12),
            note(
              '${e.purchaseAmount(e.refund)} will be refunded to ${widget.store.users[e.ownerId]!.firstName} on completion.',
            ),
          ],
        ],
      ),
    );
  }
}

class ProofGallery extends StatelessWidget {
  const ProofGallery({super.key, required this.store, required this.errand});
  final ErrandStore store;
  final Errand errand;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 16),
      const Text(
        'Saved proof',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      LayoutBuilder(
        builder: (context, box) => Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final file in errand.proofFiles)
              SizedBox(
                width: box.maxWidth >= 280
                    ? (box.maxWidth - 10) / 2
                    : box.maxWidth,
                child: ProofThumbnail(
                  key: ValueKey(file.id),
                  store: store,
                  file: file,
                ),
              ),
          ],
        ),
      ),
    ],
  );
}

class ProofThumbnail extends StatefulWidget {
  const ProofThumbnail({super.key, required this.store, required this.file});
  final ErrandStore store;
  final ProofImage file;
  @override
  State<ProofThumbnail> createState() => _ProofThumbnailState();
}

class _ProofThumbnailState extends State<ProofThumbnail> {
  late Future<Uint8List> image;
  @override
  void initState() {
    super.initState();
    load();
  }

  void load() {
    image = widget.file.bytes != null
        ? Future.value(widget.file.bytes!)
        : widget.store.api!.proofBytes(widget.file.id);
  }

  void open(Uint8List bytes) => showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Text(
                    widget.file.label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Close proof image',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Flexible(
            child: InteractiveViewer(
              minScale: .5,
              maxScale: 5,
              child: Image.memory(bytes, fit: BoxFit.contain),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              widget.file.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: muted),
            ),
          ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Panel(
    padding: 8,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.file.label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        FutureBuilder<Uint8List>(
          future: image,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return SizedBox(
                height: 110,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Image unavailable',
                      style: TextStyle(fontSize: 11),
                    ),
                    TextButton(
                      onPressed: () => setState(load),
                      child: const Text('Retry image'),
                    ),
                  ],
                ),
              );
            }
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 110,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return InkWell(
              onTap: () => open(snapshot.data!),
              child: Column(
                children: [
                  Image.memory(
                    snapshot.data!,
                    height: 110,
                    width: double.infinity,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const SizedBox(
                      height: 110,
                      child: Center(child: Text('Invalid image')),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Open ${widget.file.label.toLowerCase()}',
                    style: const TextStyle(fontSize: 11, color: teal),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 4),
        Text(
          widget.file.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10, color: muted),
        ),
      ],
    ),
  );
}
