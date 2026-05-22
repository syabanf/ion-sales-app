import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:ion_sales_app/shared.dart';

/// CommissionsPage — read-only self-view of the current sales rep's
/// commission ledger. Sourced from billing.commission_records via
/// the new /api/crm/commissions/mine endpoint.
class CommissionsPage extends StatefulWidget {
  const CommissionsPage({super.key});

  @override
  State<CommissionsPage> createState() => _CommissionsPageState();
}

class _CommissionsPageState extends State<CommissionsPage> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final res = await getIt<ApiClient>().request<Map<String, dynamic>>(
      '/api/crm/commissions/mine',
    );
    return res.data!;
  }

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IonForm.pageBg,
      appBar: IonAppBar(
        title: 'My commissions',
        actions: [
          IonAppBarAction(icon: Icons.refresh_rounded, onTap: _reload),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const IonListSkeleton(count: 4);
          }
          if (snap.hasError) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: IonErrorBanner(message: 'Failed: ${snap.error}'),
            );
          }
          final d = snap.data ?? const {};
          final items = (d['items'] as List<dynamic>?) ?? const [];
          final totalEarned = (d['total_earned'] as num?)?.toDouble() ?? 0;
          final thisMonth = (d['total_this_month'] as num?)?.toDouble() ?? 0;
          return ListView(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
            children: [
              const FadeSlideIn(
                child: IonDisplayTitle(
                  eyebrow: 'Phase 2 · Earnings',
                  title: 'My commissions',
                  subtitle: 'Track every commission earned across leads + addons.',
                ),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _TotalsCard(totalEarned: totalEarned, thisMonth: thisMonth, count: items.length),
              ),
              const IonChipDivider(label: 'Ledger'),
              const Padding(
                padding: EdgeInsets.only(left: 24, bottom: 8),
                child: Text(
                  'LEDGER',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: IonColors.inkMuted,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: items.isEmpty
                    ? const IonEmptyState(
                        icon: Icons.payments_outlined,
                        art: IonArtKind.allDone,
                        title: 'No commissions yet',
                        hint:
                            'Conversion + add-on sales will show up here once they\'re paid out.',
                      )
                    : Column(
                        children: [
                          for (var i = 0;
                              i < items.length;
                              i++) ...[
                            FadeSlideIn(
                              delay: Duration(
                                  milliseconds: 40 * i.clamp(0, 10)),
                              child: _LedgerRow(
                                item: items[i]
                                    as Map<String, dynamic>,
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({
    required this.totalEarned,
    required this.thisMonth,
    required this.count,
  });
  final double totalEarned;
  final double thisMonth;
  final int count;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
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
          const Text(
            'Total earned',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            NumberFormat.decimalPattern('id').format(totalEarned),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
          const Text(
            'IDR',
            style: TextStyle(color: Colors.white70, fontSize: 11),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'THIS MONTH',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                    Text(
                      NumberFormat.decimalPattern('id').format(thisMonth),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 32, color: Colors.white24),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PAYOUTS',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                      Text(
                        '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Disbursement is managed by Finance. This is a read-only view.',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.item});
  final Map<String, dynamic> item;
  @override
  Widget build(BuildContext context) {
    final created = DateTime.tryParse(item['created_at'] as String? ?? '');
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: IonForm.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  (item['customer_name'] as String?) ?? 'Customer',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: IonColors.ink,
                  ),
                ),
              ),
              Text(
                NumberFormat.decimalPattern('id')
                    .format((item['amount'] as num?)?.toDouble() ?? 0),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: IonColors.ion600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                ((item['party_type'] as String?) ?? '').toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: IonColors.inkMuted,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '· ${(item['percentage'] as num?)?.toStringAsFixed(1) ?? '0'}% of base',
                style: const TextStyle(fontSize: 11, color: IonColors.inkMuted),
              ),
              const Spacer(),
              if (created != null)
                Text(
                  DateFormat('MMM d, yyyy').format(created.toLocal()),
                  style: const TextStyle(fontSize: 11, color: IonColors.inkMuted),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
