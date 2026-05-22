import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:ion_sales_app/shared.dart';
import '../../data/phase2_api.dart';

/// Approvals queue — visible to anyone with `crm.plan_change.decide`
/// or `crm.relocation.decide`. Pulls both queues in parallel and shows
/// them on a single screen with a segmented filter at the top so a
/// manager can triage one stream at a time.
class ApprovalsPage extends StatefulWidget {
  const ApprovalsPage({super.key});

  @override
  State<ApprovalsPage> createState() => _ApprovalsPageState();
}

class _ApprovalsPageState extends State<ApprovalsPage> {
  _ApprovalKind _kind = _ApprovalKind.planChange;
  late Future<List<Map<String, dynamic>>> _planChanges;
  late Future<List<Map<String, dynamic>>> _relocations;

  @override
  void initState() {
    super.initState();
    _planChanges = Phase2Api(getIt<ApiClient>()).listPendingPlanChanges();
    _relocations = Phase2Api(getIt<ApiClient>()).listPendingRelocations();
  }

  void _reload() {
    setState(() {
      _planChanges = Phase2Api(getIt<ApiClient>()).listPendingPlanChanges();
      _relocations = Phase2Api(getIt<ApiClient>()).listPendingRelocations();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IonForm.pageBg,
      appBar: IonAppBar(
        title: 'My approvals',
        actions: [
          IonAppBarAction(icon: Icons.refresh_rounded, onTap: _reload),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
        children: [
          const FadeSlideIn(
            child: IonDisplayTitle(
              eyebrow: 'Manager view',
              title: 'My approvals',
              subtitle: 'Plan changes + relocation requests waiting on you.',
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: IonPillSegment<_ApprovalKind>(
              value: _kind,
              options: const [
                IonSegmentedOption(_ApprovalKind.planChange, 'Plan changes'),
                IonSegmentedOption(_ApprovalKind.relocation, 'Relocations'),
              ],
              onChanged: (k) => setState(() => _kind = k),
            ),
          ),
          const IonChipDivider(label: 'Queue'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _kind == _ApprovalKind.planChange
                ? _PlanChangeList(future: _planChanges, onAfter: _reload)
                : _RelocationList(future: _relocations, onAfter: _reload),
          ),
        ],
      ),
    );
  }
}

enum _ApprovalKind { planChange, relocation }

class _PlanChangeList extends StatelessWidget {
  const _PlanChangeList({required this.future, required this.onAfter});
  final Future<List<Map<String, dynamic>>> future;
  final VoidCallback onAfter;
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const IonListSkeleton(
            count: 4,
            padding: EdgeInsets.fromLTRB(0, 8, 0, 16),
          );
        }
        if (snap.hasError) {
          return IonErrorBanner(message: 'Failed: ${snap.error}');
        }
        final items = snap.data ?? const [];
        if (items.isEmpty) {
          return _empty('No pending plan changes', Icons.upgrade_rounded);
        }
        return Column(
          children: [
            for (final it in items) ...[
              _PlanChangeCard(item: it, onAfter: onAfter),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}

class _RelocationList extends StatelessWidget {
  const _RelocationList({required this.future, required this.onAfter});
  final Future<List<Map<String, dynamic>>> future;
  final VoidCallback onAfter;
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const IonListSkeleton(
            count: 4,
            padding: EdgeInsets.fromLTRB(0, 8, 0, 16),
          );
        }
        if (snap.hasError) {
          return IonErrorBanner(message: 'Failed: ${snap.error}');
        }
        final items = snap.data ?? const [];
        if (items.isEmpty) {
          return _empty('No pending relocations', Icons.location_on_outlined);
        }
        return Column(
          children: [
            for (final it in items) ...[
              _RelocationCard(item: it, onAfter: onAfter),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}

Widget _empty(String title, IconData icon) => Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: IonForm.cardShadow,
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: IonColors.inkMuted),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: IonColors.ink,
            ),
          ),
        ],
      ),
    );

class _PlanChangeCard extends StatefulWidget {
  const _PlanChangeCard({required this.item, required this.onAfter});
  final Map<String, dynamic> item;
  final VoidCallback onAfter;
  @override
  State<_PlanChangeCard> createState() => _PlanChangeCardState();
}

class _PlanChangeCardState extends State<_PlanChangeCard> {
  bool _busy = false;

  Future<void> _decide(String decision) async {
    setState(() => _busy = true);
    try {
      await Phase2Api(getIt<ApiClient>()).decidePlanChange(
        id: widget.item['id'] as String? ?? '',
        decision: decision,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Decision recorded: $decision')),
      );
      widget.onAfter();
    } catch (e) {
      // Wave 30 — humanize any thrown error.
      if (!mounted) return;
      IonError.snack(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.item;
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
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: IonColors.ion100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.upgrade_rounded,
                    color: IonColors.ion600, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m['customer_name'] as String? ?? 'Customer',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: IonColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${m['from_code']} → ${m['to_code']} (${m['change_kind']})',
                      style: const TextStyle(
                        fontSize: 12,
                        color: IonColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if ((m['reason'] as String? ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              m['reason'] as String,
              style: const TextStyle(
                fontSize: 12,
                color: IonColors.inkMuted,
                height: 1.3,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: IonSecondaryButton(
                  label: 'Reject',
                  icon: Icons.close_rounded,
                  destructive: true,
                  onPressed: _busy ? null : () => _decide('rejected'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: IonPrimaryButton(
                  label: _busy ? '…' : 'Approve',
                  icon: Icons.check_rounded,
                  loading: _busy,
                  onPressed: () => _decide('approved'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RelocationCard extends StatefulWidget {
  const _RelocationCard({required this.item, required this.onAfter});
  final Map<String, dynamic> item;
  final VoidCallback onAfter;
  @override
  State<_RelocationCard> createState() => _RelocationCardState();
}

class _RelocationCardState extends State<_RelocationCard> {
  bool _busy = false;

  Future<void> _decide(String decision) async {
    setState(() => _busy = true);
    try {
      await Phase2Api(getIt<ApiClient>()).decideRelocation(
        id: widget.item['id'] as String? ?? '',
        decision: decision,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Decision recorded: $decision')),
      );
      widget.onAfter();
    } catch (e) {
      // Wave 30 — humanize any thrown error.
      if (!mounted) return;
      IonError.snack(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.item;
    final requestedAt = DateTime.tryParse(m['requested_at'] as String? ?? '');
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
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: IonColors.ion100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.location_on_outlined,
                    color: IonColors.ion600, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m['customer_name'] as String? ?? 'Customer',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: IonColors.ink,
                      ),
                    ),
                    if (requestedAt != null)
                      Text(
                        DateFormat('MMM d, yyyy').format(requestedAt.toLocal()),
                        style: const TextStyle(
                          fontSize: 11,
                          color: IonColors.inkMuted,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: IonColors.ion100,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  IonHumanize.status(m['status'] as String? ?? '')
                      .toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    color: IonColors.ion700,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${m['from_address']} → ${m['to_address']}',
            style: const TextStyle(
              fontSize: 12,
              color: IonColors.ink,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: IonSecondaryButton(
                  label: 'Survey failed',
                  icon: Icons.close_rounded,
                  destructive: true,
                  onPressed: _busy ? null : () => _decide('survey_failed'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: IonPrimaryButton(
                  label: _busy ? '…' : 'Approve',
                  icon: Icons.check_rounded,
                  loading: _busy,
                  onPressed: () => _decide('approved'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
