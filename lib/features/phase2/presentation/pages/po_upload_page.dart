import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:ion_sales_app/shared.dart';

/// POUploadPage — uploads a customer-signed PO document for a B2B
/// opportunity. Flow:
///   1. Rep enters PO number + (optional) issued-by-PIC + notes
///   2. Rep picks an image / camera capture of the signed PO
///   3. We upload bytes via UploadsGateway → object_url
///   4. POST that object_url to /api/enterprise/opportunities/{id}/po-documents
///
/// This is the final on-site action that flips the opportunity into
/// "awaiting EWO" — the operator then takes over on web.
class POUploadPage extends StatefulWidget {
  const POUploadPage({super.key, required this.oppId});
  final String oppId;

  @override
  State<POUploadPage> createState() => _POUploadPageState();
}

class _POUploadPageState extends State<POUploadPage> {
  final _poNumber = TextEditingController();
  final _issuedBy = TextEditingController();
  final _notes = TextEditingController();
  XFile? _picked;
  bool _busy = false;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _poNumber.dispose();
    _issuedBy.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    setState(() => _error = null);
    try {
      final picker = ImagePicker();
      final x = await picker.pickImage(source: source, imageQuality: 80);
      if (x != null) setState(() => _picked = x);
    } catch (e) {
      setState(() => _error = 'Could not access camera/gallery: $e');
    }
  }

  Future<void> _submit() async {
    if (_poNumber.text.trim().isEmpty) {
      setState(() => _error = 'PO number is required.');
      return;
    }
    if (_picked == null) {
      setState(() => _error = 'Take a photo or pick a file of the signed PO.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final file = File(_picked!.path);
      final bytes = await file.readAsBytes();
      final upload = await getIt<UploadsGateway>().uploadPhoto(
        bytes: bytes,
        contentType: 'image/jpeg',
      );
      await getIt<ApiClient>().request<Map<String, dynamic>>(
        '/api/enterprise/opportunities/${widget.oppId}/po-documents',
        options: Options(method: 'POST'),
        data: {
          'po_number': _poNumber.text.trim(),
          'file_url': upload.objectUrl,
          'file_name': _picked!.name,
          'file_size_bytes': bytes.length,
          'content_type': 'image/jpeg',
          'issued_by_pic': _issuedBy.text.trim(),
          'notes': _notes.text.trim(),
        },
      );
      setState(() => _success = _poNumber.text.trim());
    } catch (e) {
      // Wave 30 — humanize ApiException + DioException + generic in
      // one branch.
      setState(() => _error = IonError.humanize(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_success != null) {
      return Scaffold(
        backgroundColor: IonForm.pageBg,
        appBar: const IonAppBar(title: 'PO uploaded'),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline_rounded,
                  size: 64, color: Color(0xFF15803D)),
              const SizedBox(height: 12),
              const Text(
                'PO received',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: IonColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'PO ${_success!} is on file. Finance will validate within 1 business day.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: IonColors.inkSoft, height: 1.4),
              ),
              const SizedBox(height: 24),
              IonPrimaryButton(
                label: 'Back to opportunity',
                icon: Icons.arrow_back_rounded,
                onPressed: () => GoRouter.of(context).pop(),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: IonForm.pageBg,
      appBar: const IonAppBar(title: 'Upload customer PO'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          const FadeSlideIn(
            child: IonDisplayTitle(
              padding: EdgeInsets.zero,
              eyebrow: 'B2B · Phase 2',
              title: 'Upload customer PO',
              subtitle: 'Once Finance validates it, the EWO can be scheduled.',
            ),
          ),
          const SizedBox(height: 14),
          IonField(label: 'PO number *', controller: _poNumber),
          const SizedBox(height: 10),
          IonField(
            label: 'Issued by (PIC name)',
            controller: _issuedBy,
            hint: 'e.g. Pak Anto, Procurement Lead',
          ),
          const SizedBox(height: 10),
          IonField(
            label: 'Notes',
            controller: _notes,
            maxLines: 3,
            minLines: 2,
          ),
          const SizedBox(height: 14),
          if (_picked != null) ...[
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: IonForm.surfaceBorder),
                borderRadius: BorderRadius.circular(14),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.file(File(_picked!.path), fit: BoxFit.cover),
            ),
            const SizedBox(height: 8),
            Text(
              _picked!.name,
              style: const TextStyle(fontSize: 11, color: IonColors.inkMuted),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                child: IonSecondaryButton(
                  label: 'Take photo',
                  icon: Icons.camera_alt_rounded,
                  onPressed: () => _pick(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: IonSecondaryButton(
                  label: 'Choose file',
                  icon: Icons.photo_library_rounded,
                  onPressed: () => _pick(ImageSource.gallery),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            IonErrorBanner(message: _error!),
          ],
          const SizedBox(height: 16),
          IonPrimaryButton(
            label: _busy ? 'Uploading…' : 'Submit PO',
            icon: Icons.send_rounded,
            loading: _busy,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
