import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ion_sales_app/shared.dart';

import '../../domain/lead.dart';
import '../../domain/lead_repository.dart';

/// Document checklist screen for a single lead.
///
/// The checklist itself is generated server-side from the lead's
/// onboarding schema (KTP, KK, utility bill, etc.). The Sales App lets
/// reps capture a photo, upload it via the shared UploadsGateway, then
/// PATCH the document row to mark it submitted and attach the file_url.
class DocumentsPage extends StatefulWidget {
  const DocumentsPage({super.key, required this.leadId});
  final String leadId;

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  late Future<_DocsBundle> _future;
  String? _busyId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DocsBundle> _load() async {
    final repo = getIt<LeadRepository>();
    final docs = await repo.listDocuments(widget.leadId);
    final lead = await repo.get(widget.leadId);
    Set<String>? visibleKeys;
    String? schemaId = lead.onboardingSchemaId;
    if (schemaId != null && schemaId.isNotEmpty) {
      try {
        final api = getIt<ApiClient>();
        final r = await api.request<Map<String, dynamic>>(
          '/api/crm/onboarding-schemas/$schemaId',
        );
        final body = (r.data?['body'] as Map?)?.cast<String, dynamic>();
        final slots = (body?['docs'] as List?) ?? const [];
        visibleKeys = <String>{};
        for (final raw in slots) {
          final s = (raw as Map).cast<String, dynamic>();
          final key = s['key'] as String?;
          if (key == null) continue;
          final cond = s['show_when_accept_excess'];
          if (cond == null) {
            visibleKeys.add(key);
            continue;
          }
          // honour show_when_accept_excess: true → only when accepted,
          // false → only when NOT accepted.
          if (cond is bool && cond == lead.acceptExcessCable) {
            visibleKeys.add(key);
          }
        }
      } catch (_) {
        // Schema fetch is best-effort; fall back to showing every doc.
      }
    }
    return _DocsBundle(docs: docs, visibleKeys: visibleKeys);
  }

  void _reload() {
    setState(() => _future = _load());
  }

  Future<void> _upload(LeadDocument doc) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 2048,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() {
      _busyId = doc.id;
      _error = null;
    });
    try {
      final bytes = await File(picked.path).readAsBytes();
      final upload = await getIt<UploadsGateway>().uploadPhoto(
        bytes: bytes,
        contentType: 'image/jpeg',
      );
      await getIt<LeadRepository>().updateDocument(
        documentId: doc.id,
        fileUrl: upload.objectUrl,
        submitted: true,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${doc.label} uploaded')),
      );
      _reload();
    } catch (e) {
      // Wave 30 — humanize.
      setState(() => _error = IonError.humanize(e));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IonForm.pageBg,
      appBar: IonAppBar(
        title: 'Documents',
        actions: [
          IonAppBarAction(icon: Icons.refresh_rounded, onTap: _reload),
        ],
      ),
      body: FutureBuilder<_DocsBundle>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const IonListSkeleton(count: 5);
          }
          if (snap.hasError) {
            return Center(child: Text('Failed: ${snap.error}'));
          }
          final bundle = snap.data!;
          // Schema-driven filter: if the lead has an onboarding schema,
          // honour its show_when_accept_excess gates by hiding doc rows
          // that are no longer visible for this lead's accept_excess
          // flag. With no schema, render the full list.
          final docs = bundle.visibleKeys == null
              ? bundle.docs
              : bundle.docs
                  .where((d) => bundle.visibleKeys!.contains(d.docKey))
                  .toList();
          if (docs.isEmpty) {
            return const Center(child: Text('No documents required.'));
          }
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              const FadeSlideIn(
                child: IonDisplayTitle(
                  padding: EdgeInsets.zero,
                  eyebrow: 'Lead',
                  title: 'Documents',
                  subtitle: 'Upload + track every doc the lead needs to convert.',
                ),
              ),
              const SizedBox(height: 14),
              if (bundle.visibleKeys != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, left: 4),
                  child: Text(
                    'Driven by onboarding schema · ${docs.length} doc${docs.length == 1 ? "" : "s"}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: IonColors.inkMuted,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
              ...docs.map((d) => _DocCard(
                    doc: d,
                    busy: _busyId == d.id,
                    onUpload: () => _upload(d),
                  )),
            ],
          );
        },
      ),
    );
  }
}

class _DocsBundle {
  _DocsBundle({required this.docs, required this.visibleKeys});
  final List<LeadDocument> docs;
  /// If non-null, only docs whose `docKey` appears here should be
  /// rendered. The list comes from the lead's onboarding schema with
  /// `show_when_accept_excess` already evaluated against the lead's
  /// accept_excess_cable flag.
  final Set<String>? visibleKeys;
}

class _DocCard extends StatelessWidget {
  const _DocCard({required this.doc, required this.busy, required this.onUpload});
  final LeadDocument doc;
  final bool busy;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    // Wave 26 — migrated from raw Material `ListTile` to IonListCard.
    // Leading icon flips between green check (submitted) and ion upload
    // (pending); trailing wraps the Upload/Replace text button so the
    // entire row reads with the same shape as other lists across the app.
    final submitted = doc.submitted;
    return IonListCard(
      leading: IonLeadingIcon(
        icon: submitted ? Icons.check_circle : Icons.upload_file_outlined,
        tint: submitted ? IonColors.mint500 : IonColors.ion500,
      ),
      title: doc.label,
      subtitle: doc.required ? 'required' : 'optional',
      trailing: busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : TextButton(
              onPressed: onUpload,
              child: Text(submitted ? 'Replace' : 'Upload'),
            ),
    );
  }
}
