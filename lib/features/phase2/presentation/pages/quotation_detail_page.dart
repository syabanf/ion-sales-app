import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:ion_sales_app/shared.dart';

/// QuotationDetailPage — header (number, status, totals, validity)
/// + accept / reject CTAs. Rejecting opens an inline reason input.
/// Once accepted, the page surfaces an "Upload PO" entry point that
/// hops to the PO upload page.
class QuotationDetailPage extends StatefulWidget {
  const QuotationDetailPage({super.key, required this.quotationId});
  final String quotationId;

  @override
  State<QuotationDetailPage> createState() => _QuotationDetailPageState();
}

class _QuotationDetailPageState extends State<QuotationDetailPage> {
  late Future<Map<String, dynamic>> _future;
  bool _busy = false;
  String? _error;
  final TextEditingController _rejectReason = TextEditingController();
  bool _rejectOpen = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _rejectReason.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _load() async {
    final r = await getIt<ApiClient>().request<Map<String, dynamic>>(
      '/api/enterprise/quotations/${widget.quotationId}',
    );
    return r.data ?? const <String, dynamic>{};
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _accept() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await getIt<ApiClient>().request<Map<String, dynamic>>(
        '/api/enterprise/quotations/${widget.quotationId}/accept',
        options: _post(),
        data: const {},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quotation accepted')),
      );
      _reload();
    } catch (e) {
      // Wave 30 — humanize.
      setState(() => _error = IonError.humanize(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    final reason = _rejectReason.text.trim();
    if (reason.isEmpty) {
      setState(() => _error = 'Reason is required');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await getIt<ApiClient>().request<Map<String, dynamic>>(
        '/api/enterprise/quotations/${widget.quotationId}/reject',
        options: _post(),
        data: {'reason': reason},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quotation rejected')),
      );
      _rejectOpen = false;
      _rejectReason.clear();
      _reload();
    } catch (e) {
      // Wave 30 — humanize.
      setState(() => _error = IonError.humanize(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IonForm.pageBg,
      appBar: const IonAppBar(title: 'Quotation'),
      body: FutureBuilder<Map<String, dynamic>>(
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
          final q = snap.data!;
          final status = q['status'] as String? ?? '';
          final isExpired = q['is_expired'] as bool? ?? false;
          final canAct = status == 'issued' && !isExpired;
          final accepted = status == 'accepted';

          final quoNum = (q['quotation_number'] as String?) ?? 'Quotation';
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              FadeSlideIn(
                child: IonDisplayTitle(
                  padding: EdgeInsets.zero,
                  eyebrow: 'B2B · Phase 2',
                  title: quoNum,
                  subtitle: 'Review pricing, accept or revise.',
                ),
              ),
              const SizedBox(height: 14),
              _Header(quotation: q),
              const SizedBox(height: 16),
              _DetailsCard(quotation: q),
              const SizedBox(height: 16),
              if (_error != null) ...[
                IonErrorBanner(message: _error!),
                const SizedBox(height: 10),
              ],
              if (canAct) ...[
                IonPrimaryButton(
                  label: _busy ? 'Working…' : 'Accept quotation',
                  icon: Icons.check_circle_rounded,
                  loading: _busy,
                  onPressed: _accept,
                ),
                const SizedBox(height: 10),
                if (!_rejectOpen)
                  IonSecondaryButton(
                    label: 'Reject…',
                    onPressed: () => setState(() => _rejectOpen = true),
                  )
                else ...[
                  IonField(
                    label: 'Rejection reason',
                    hint: 'Why is the customer rejecting?',
                    controller: _rejectReason,
                    maxLines: 3,
                    minLines: 2,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: IonSecondaryButton(
                          label: 'Cancel',
                          onPressed: () =>
                              setState(() => _rejectOpen = false),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: IonPrimaryButton(
                          label: _busy ? 'Rejecting…' : 'Confirm reject',
                          icon: Icons.cancel_rounded,
                          loading: _busy,
                          onPressed: _reject,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
              if (accepted) ...[
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline_rounded,
                          color: Color(0xFF15803D), size: 22),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Quotation accepted — upload the customer PO to proceed.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF14532D),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                IonPrimaryButton(
                  label: 'Upload customer PO',
                  icon: Icons.upload_file_rounded,
                  onPressed: () => GoRouter.of(context)
                      .push('/opportunities/${q['opportunity_id']}/po-upload'),
                ),
              ],
              if (status == 'rejected') ...[
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.cancel_outlined,
                          color: Color(0xFFB91C1C), size: 22),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'This quotation was rejected. Issue a new revision from the BOQ to re-quote.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF7F1D1D),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

Options _post() => Options(method: 'POST');

class _Header extends StatelessWidget {
  const _Header({required this.quotation});
  final Map<String, dynamic> quotation;
  @override
  Widget build(BuildContext context) {
    final sell = (quotation['sell_total'] as num?)?.toDouble() ?? 0;
    final status = quotation['status'] as String? ?? '';
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
                  (quotation['quotation_number'] as String?) ?? '',
                  style: const TextStyle(
                    fontSize: 16,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  IonHumanize.status(status).toUpperCase(),
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
          const SizedBox(height: 8),
          Text(
            'Rp ${sell.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.6,
            ),
          ),
          Text(
            '${(quotation['currency'] as String?) ?? 'IDR'} · margin ${((quotation['margin_pct'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)}%',
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.quotation});
  final Map<String, dynamic> quotation;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: IonForm.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row('Version', 'Rev ${quotation['revision'] ?? 0}'),
          _row('Issued', _fmtDate(quotation['issued_at'] as String?)),
          _row('Valid from', _fmtDate(quotation['valid_from'] as String?)),
          _row('Valid until', _fmtDate(quotation['valid_until'] as String?)),
          if (quotation['accepted_at'] != null)
            _row('Accepted', _fmtDate(quotation['accepted_at'] as String?),
                fg: const Color(0xFF15803D)),
          if (quotation['rejected_at'] != null)
            _row('Rejected', _fmtDate(quotation['rejected_at'] as String?),
                fg: const Color(0xFFB91C1C)),
          if ((quotation['notes'] as String?)?.isNotEmpty ?? false) ...[
            const Divider(height: 16),
            const Text(
              'NOTES',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: IonColors.inkMuted,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              quotation['notes'] as String,
              style: const TextStyle(
                fontSize: 13,
                color: IonColors.ink,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value, {Color? fg}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: IonColors.inkMuted,
                letterSpacing: 1.0,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: fg ?? IonColors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDate(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return DateFormat('MMM d, yyyy · h:mm a').format(dt.toLocal());
  }
}
