import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:ion_sales_app/shared.dart';

/// OpportunityDetailPage — three sections in one scroll:
///   1. Summary card (account, stage, sell-total snapshot, forecast)
///   2. BOQs list (versioned, with margin pct)
///   3. Quotations list (with status chips + tap-into detail)
///   4. PO documents (uploaded after a quotation is accepted)
///
/// All read-only; mutations happen on dedicated sub-pages (quotation
/// detail does accept/reject; the PO upload sheet does PO upload).
class OpportunityDetailPage extends StatefulWidget {
  const OpportunityDetailPage({super.key, required this.oppId});
  final String oppId;

  @override
  State<OpportunityDetailPage> createState() => _OpportunityDetailPageState();
}

class _OpportunityDetailPageState extends State<OpportunityDetailPage> {
  late Future<_OppBundle> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_OppBundle> _load() async {
    final api = getIt<ApiClient>();
    final opp = await api.request<Map<String, dynamic>>(
      '/api/enterprise/opportunities/${widget.oppId}',
    );
    final boqs = await api.request<Map<String, dynamic>>(
      '/api/enterprise/boqs',
      queryParameters: {'opportunity_id': widget.oppId, 'page_size': 50},
    );
    final quotations = await api.request<Map<String, dynamic>>(
      '/api/enterprise/quotations',
      queryParameters: {'opportunity_id': widget.oppId, 'page_size': 50},
    );
    Map<String, dynamic>? forecast;
    try {
      final fr = await api.request<Map<String, dynamic>>(
        '/api/enterprise/opportunities/${widget.oppId}/forecast',
      );
      forecast = fr.data;
    } on ApiException {
      // Forecast is best-effort polish; treat as optional.
    }
    Map<String, dynamic>? poDocs;
    try {
      final pr = await api.request<Map<String, dynamic>>(
        '/api/enterprise/opportunities/${widget.oppId}/po-documents',
      );
      poDocs = pr.data;
    } on ApiException {
      // Permission may be missing; ignore.
    }
    return _OppBundle(
      opp: opp.data ?? const <String, dynamic>{},
      boqs: ((boqs.data?['items'] as List<dynamic>?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      quotations: ((quotations.data?['items'] as List<dynamic>?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      forecast: forecast,
      poDocs: poDocs == null
          ? const []
          : ((poDocs['items'] as List<dynamic>?) ?? const [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList(),
    );
  }

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IonForm.pageBg,
      appBar: IonAppBar(
        title: 'Opportunity',
        actions: [
          IonAppBarAction(icon: Icons.refresh_rounded, onTap: _reload),
        ],
      ),
      body: FutureBuilder<_OppBundle>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: IonColors.ion500),
            );
          }
          if (snap.hasError) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: IonErrorBanner(
                message: snap.error is ApiException
                    ? (snap.error as ApiException).message
                    : 'Failed: ${snap.error}',
              ),
            );
          }
          final b = snap.data!;
          final accountName = (b.opp['account_name'] as String?) ?? 'Opportunity';
          final stage = (b.opp['stage'] as String?) ?? '—';
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              FadeSlideIn(
                child: IonDisplayTitle(
                  padding: EdgeInsets.zero,
                  eyebrow: 'B2B opportunity',
                  title: accountName,
                  subtitle: 'Stage · ${stage.toUpperCase()}',
                ),
              ),
              const SizedBox(height: 14),
              _SummaryCard(opp: b.opp, forecast: b.forecast),
              const SizedBox(height: 18),
              _SectionHeader(title: 'BOQs', count: b.boqs.length),
              const SizedBox(height: 8),
              if (b.boqs.isEmpty)
                _EmptyBlock(
                  icon: Icons.list_alt_outlined,
                  text: 'No BOQs yet — start a draft from web.',
                )
              else
                for (final boq in b.boqs) ...[
                  _BOQCard(boq: boq),
                  const SizedBox(height: 8),
                ],
              const SizedBox(height: 18),
              _SectionHeader(title: 'Quotations', count: b.quotations.length),
              const SizedBox(height: 8),
              if (b.quotations.isEmpty)
                _EmptyBlock(
                  icon: Icons.description_outlined,
                  text: 'No quotations issued yet.',
                )
              else
                for (final q in b.quotations) ...[
                  _QuotationCard(quotation: q),
                  const SizedBox(height: 8),
                ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child:
                        _SectionHeader(title: 'PO documents', count: b.poDocs.length),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.upload_file, size: 14),
                    label: const Text('Upload', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: IonColors.ion700,
                    ),
                    onPressed: () => GoRouter.of(context)
                        .push('/opportunities/${widget.oppId}/po-upload')
                        .then((_) => _reload()),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (b.poDocs.isEmpty)
                _EmptyBlock(
                  icon: Icons.attach_file_outlined,
                  text: 'No POs uploaded yet.',
                )
              else
                for (final p in b.poDocs) ...[
                  _PODocCard(doc: p),
                  const SizedBox(height: 8),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _OppBundle {
  _OppBundle({
    required this.opp,
    required this.boqs,
    required this.quotations,
    required this.forecast,
    required this.poDocs,
  });
  final Map<String, dynamic> opp;
  final List<Map<String, dynamic>> boqs;
  final List<Map<String, dynamic>> quotations;
  final Map<String, dynamic>? forecast;
  final List<Map<String, dynamic>> poDocs;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.opp, required this.forecast});
  final Map<String, dynamic> opp;
  final Map<String, dynamic>? forecast;

  @override
  Widget build(BuildContext context) {
    final stage = opp['stage'] as String? ?? 'cold';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [IonColors.ion500, IonColors.ion600],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: IonColors.ion500.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  (opp['account_name'] as String?) ?? 'Opportunity',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  stage.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            (opp['opportunity_number'] as String?) ?? '',
            style: const TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: Colors.white70,
            ),
          ),
          if (forecast != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MetricBlock(
                    label: 'QUOTED',
                    value: _money(forecast!['quoted_total']),
                  ),
                ),
                Container(width: 1, height: 28, color: Colors.white24),
                Expanded(
                  child: _MetricBlock(
                    label: 'FORECAST',
                    value: _money(forecast!['forecast_total']),
                    sublabel:
                        '${((forecast!['stage_probability'] as num?)?.toDouble() ?? 0 * 100).toStringAsFixed(0)}% probability',
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _money(dynamic v) {
    if (v is num) {
      return 'Rp ${v.toStringAsFixed(0)}';
    }
    return '—';
  }
}

class _MetricBlock extends StatelessWidget {
  const _MetricBlock({required this.label, required this.value, this.sublabel});
  final String label;
  final String value;
  final String? sublabel;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              )),
          Text(value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              )),
          if (sublabel != null)
            Text(
              sublabel!,
              style: const TextStyle(color: Colors.white60, fontSize: 9),
            ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});
  final String title;
  final int count;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        '${title.toUpperCase()} ($count)',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: IonColors.inkMuted,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: IonForm.cardShadow,
      ),
      child: Row(
        children: [
          Icon(icon, color: IonColors.inkMuted, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                color: IonColors.inkMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BOQCard extends StatelessWidget {
  const _BOQCard({required this.boq});
  final Map<String, dynamic> boq;
  @override
  Widget build(BuildContext context) {
    final status = boq['status'] as String? ?? '';
    final sell = (boq['sell_total'] as num?)?.toDouble() ?? 0;
    final margin = (boq['margin_pct'] as num?)?.toDouble() ?? 0;
    final rev = (boq['revision'] as num?)?.toInt() ?? 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: IonForm.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  (boq['boq_number'] as String?) ?? '',
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    color: IonColors.ink,
                  ),
                ),
              ),
              _smallChip('REV $rev', IonColors.ion100, IonColors.ion700),
              const SizedBox(width: 4),
              _smallChip(IonHumanize.status(status).toUpperCase(), _statusBg(status), _statusFg(status)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                'Rp ${sell.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: IonColors.ink,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'margin ${margin.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 11,
                  color: IonColors.inkMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _statusBg(String s) {
    switch (s) {
      case 'approved':
        return const Color(0xFFDCFCE7);
      case 'rejected':
      case 'cancelled':
        return const Color(0xFFFEE2E2);
      case 'in_approval':
      case 'submitted':
        return const Color(0xFFFEF3C7);
      default:
        return IonColors.separatorLight;
    }
  }

  Color _statusFg(String s) {
    switch (s) {
      case 'approved':
        return const Color(0xFF15803D);
      case 'rejected':
      case 'cancelled':
        return const Color(0xFFB91C1C);
      case 'in_approval':
      case 'submitted':
        return const Color(0xFFB45309);
      default:
        return IonColors.inkMuted;
    }
  }
}

class _QuotationCard extends StatelessWidget {
  const _QuotationCard({required this.quotation});
  final Map<String, dynamic> quotation;
  @override
  Widget build(BuildContext context) {
    // Wave 26 — migrated to IonListCard. Price = title, quotation
    // number = subtitle, validity = meta. Expired state takes priority
    // in the trailing pill — collapses two chips into one.
    final id = quotation['id'] as String?;
    final status = quotation['status'] as String? ?? '';
    final sell = (quotation['sell_total'] as num?)?.toDouble() ?? 0;
    final validUntil = quotation['valid_until'] as String?;
    final isExpired = quotation['is_expired'] as bool? ?? false;
    final qNum = (quotation['quotation_number'] as String?) ?? '';
    return IonListCard(
      leading: const IonLeadingIcon(
        icon: Icons.receipt_long_outlined,
        tint: IonColors.plum500,
      ),
      title: 'Rp ${sell.toStringAsFixed(0)}',
      subtitle: qNum.isEmpty ? null : qNum,
      meta: validUntil != null
          ? ['Valid until ${_fmtDate(validUntil)}']
          : const [],
      trailing: IonStatusPill(
        label: isExpired ? 'EXPIRED' : status,
        tone: isExpired ? IonStatusTone.danger : _statusTone(status),
        dense: true,
      ),
      onTap: id == null
          ? null
          : () => GoRouter.of(context).push('/quotations/$id'),
    );
  }

  IonStatusTone _statusTone(String s) {
    switch (s) {
      case 'accepted':
        return IonStatusTone.success;
      case 'rejected':
      case 'cancelled':
        return IonStatusTone.danger;
      case 'issued':
        return IonStatusTone.info;
      default:
        return IonStatusTone.neutral;
    }
  }

  String _fmtDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return DateFormat('MMM d, yyyy').format(dt);
  }
}

class _PODocCard extends StatelessWidget {
  const _PODocCard({required this.doc});
  final Map<String, dynamic> doc;
  @override
  Widget build(BuildContext context) {
    // Wave 26 — migrated to IonListCard. PO# = title, filename = subtitle,
    // upload date as trailing caption.
    final uploaded = doc['uploaded_at'];
    return IonListCard(
      leading: const IonLeadingIcon(
        icon: Icons.description_outlined,
        tint: IonColors.ion500,
      ),
      title: (doc['po_number'] as String?) ?? '',
      subtitle: (doc['file_name'] as String?) ?? '',
      meta: uploaded is String
          ? ['Uploaded ${_fmtShort(uploaded)}']
          : const [],
    );
  }

  String _fmtShort(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return DateFormat('MMM d').format(dt);
  }
}

Widget _smallChip(String label, Color bg, Color fg) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w800,
        color: fg,
        letterSpacing: 0.4,
      ),
    ),
  );
}
