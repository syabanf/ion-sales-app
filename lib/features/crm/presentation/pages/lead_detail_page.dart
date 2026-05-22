import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:ion_sales_app/shared.dart';
import '../../domain/lead.dart';
import '../../domain/lead_repository.dart';

/// Lead detail surface for the Sales App. Three blocks: header, address +
/// coverage, and the convert CTA (only visible to permission-holders).
class LeadDetailPage extends StatefulWidget {
  const LeadDetailPage({super.key, required this.leadId});
  final String leadId;

  @override
  State<LeadDetailPage> createState() => _LeadDetailPageState();
}

class _LeadDetailPageState extends State<LeadDetailPage> {
  late final Future<Lead> _future;
  bool _converting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _future = getIt<LeadRepository>().get(widget.leadId);
  }

  Future<void> _convert(Lead lead) async {
    setState(() {
      _converting = true;
      _error = null;
    });
    try {
      final conv = await getIt<LeadRepository>().convert(lead.id);
      if (!mounted) return;
      // Wave 25 — confetti + branded snackbar on convert success. The
      // confetti fires BEFORE the pop so it overlays the lead detail
      // for a beat, then the route pops back to the list.
      IonConfetti.celebrate(context);
      final shortId = conv.customerId.length >= 8
          ? conv.customerId.substring(0, 8)
          : conv.customerId;
      IonSnackbar.show(
        context,
        'Customer $shortId created',
        icon: Icons.celebration_outlined,
      );
      // Pop back to the list so it refreshes on next view.
      GoRouter.of(context).pop();
    } catch (e) {
      // Wave 30 — humanize.
      if (!mounted) return;
      setState(() => _error = IonError.humanize(e));
    } finally {
      if (mounted) setState(() => _converting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IonForm.pageBg,
      appBar: const IonAppBar(title: 'Lead'),
      body: FutureBuilder<Lead>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            if (snap.hasError) return Center(child: Text('Failed: ${snap.error}'));
            return const Center(child: CircularProgressIndicator());
          }
          final lead = snap.data!;
          final auth = context.watch<AuthBloc>().state.session;
          final canConvert =
              auth?.hasPermission('crm.lead.convert') ?? false;
          // Wave 22 — lead detail dashboard treatment.
          IonStatusTone statusTone() {
            return switch (lead.status) {
              'converted' => IonStatusTone.success,
              'lost' => IonStatusTone.danger,
              'qualified' || 'ready_to_convert' => IonStatusTone.info,
              'document_pending' => IonStatusTone.warning,
              _ => IonStatusTone.neutral,
            };
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(0, 4, 0, 24),
            children: [
              FadeSlideIn(
                child: IonDisplayTitle(
                  eyebrow: lead.leadNumber,
                  title: lead.fullName,
                  subtitle: '${lead.phone} · ${lead.address}',
                  // Wave 30 — IonStatusPill humanizes the raw enum
                  // internally, so just pass the raw lead.status.
                  trailing: IonStatusPill(
                    label: lead.status,
                    tone: statusTone(),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (lead.source == 'cs_referral' || lead.source == 'self_order')
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      if (lead.source == 'cs_referral')
                        const _SourceChip(
                          label: 'CS Referral',
                          bg: Color(0xFFF3E8FF),
                          fg: Color(0xFF7E22CE),
                        ),
                      if (lead.source == 'self_order')
                        const _SourceChip(
                          label: 'Self order',
                          bg: Color(0xFFE0F2FE),
                          fg: Color(0xFF0369A1),
                        ),
                    ],
                  ),
                ),
              const IonChipDivider(label: 'Details'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: IonSection(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Field(label: 'Phone', value: lead.phone),
                      if ((lead.email ?? '').isNotEmpty)
                        _Field(label: 'Email', value: lead.email!),
                      _Field(label: 'Address', value: lead.address),
                      if ((lead.productName ?? '').isNotEmpty)
                        _Field(label: 'Product', value: lead.productName!),
                      if ((lead.notes ?? '').isNotEmpty)
                        _Field(label: 'Notes', value: lead.notes!),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: IonSecondaryButton(
                  icon: Icons.folder_open_outlined,
                  label: 'Documents',
                  onPressed: () =>
                      GoRouter.of(context).go('/leads/${lead.id}/documents'),
                ),
              ),
              const IonChipDivider(label: 'Activity'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _LeadTimeline(leadId: lead.id),
              ),
              const SizedBox(height: 16),
              if (lead.isConverted)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _ConvertedBanner(lead: lead),
                )
              else if (canConvert)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: IonPrimaryButton(
                    icon: Icons.swap_horiz_rounded,
                    label: _converting
                        ? 'Converting…'
                        : 'Convert to customer',
                    loading: _converting,
                    onPressed: _converting ? null : () => _convert(lead),
                  ),
                ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: IonErrorBanner(message: _error!),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: IonColors.inkMuted, fontWeight: FontWeight.w600)),
          Text(value, style: const TextStyle(fontSize: 14, color: IonColors.ink)),
        ],
      ),
    );
  }
}

class _ConvertedBanner extends StatelessWidget {
  const _ConvertedBanner({required this.lead});
  final Lead lead;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Converted', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.green)),
          if (lead.convertedCustomerId != null)
            Text(
                'Customer ${lead.convertedCustomerId!.length >= 8 ? lead.convertedCustomerId!.substring(0, 8) : lead.convertedCustomerId!}…',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          if (lead.convertedOrderId != null)
            Text(
                'Order    ${lead.convertedOrderId!.length >= 8 ? lead.convertedOrderId!.substring(0, 8) : lead.convertedOrderId!}…',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
        ],
      ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.label, required this.bg, required this.fg});
  final String label;
  final Color bg;
  final Color fg;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: fg,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _LeadTimeline extends StatefulWidget {
  const _LeadTimeline({required this.leadId});
  final String leadId;
  @override
  State<_LeadTimeline> createState() => _LeadTimelineState();
}

class _LeadTimelineState extends State<_LeadTimeline> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final r = await getIt<ApiClient>().request<Map<String, dynamic>>(
      '/api/crm/leads/${widget.leadId}/events',
    );
    final items = (r.data?['items'] as List<dynamic>? ?? const []);
    return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  @override
  Widget build(BuildContext context) {
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
              const Text(
                'TIMELINE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: IonColors.inkMuted,
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              // Wave 24 — show distinct event-actor avatars at the
              // header, mirroring the conversation pattern from
              // customer ticket detail.
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _future,
                builder: (context, snap) {
                  final items = snap.data ?? const [];
                  if (items.isEmpty) return const SizedBox.shrink();
                  final avatars = _actorAvatars(items);
                  if (avatars.isEmpty) return const SizedBox.shrink();
                  return IonAvatarStack(
                    avatars: avatars,
                    size: 22,
                    overlap: 8,
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: LinearProgressIndicator(minHeight: 2),
                );
              }
              final items = snap.data ?? const [];
              if (items.isEmpty) {
                return const Text(
                  'No events yet.',
                  style: TextStyle(fontSize: 12, color: IonColors.inkMuted),
                );
              }
              return Column(
                children: [
                  for (final e in items.take(20))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(top: 6, right: 8),
                            decoration: const BoxDecoration(
                              color: IonColors.ion500,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e['summary'] as String? ?? '',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: IonColors.ink,
                                  ),
                                ),
                                Text(
                                  '${e['kind']} · ${e['created_at']}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: IonColors.inkMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// Distinct event-actor avatars across the timeline. Tries
  /// actor/sales/system kinds and tops out at 3 visible chips.
  List<IonAvatar> _actorAvatars(List<Map<String, dynamic>> items) {
    final seen = <String>{};
    final avatars = <IonAvatar>[];
    for (final e in items) {
      final rawActor =
          (e['actor'] as String?) ?? (e['kind'] as String?) ?? 'system';
      final actor = rawActor.isEmpty ? 'system' : rawActor;
      if (!seen.add(actor)) continue;
      avatars.add(IonAvatar(
        initials: actor.substring(0, 1).toUpperCase(),
        color: switch (actor) {
          'sales' => IonColors.indigo500.withValues(alpha: 0.18),
          'system' => IonColors.inkMuted.withValues(alpha: 0.18),
          'customer' => IonColors.mint500.withValues(alpha: 0.18),
          _ => IonColors.peach500.withValues(alpha: 0.18),
        },
      ));
      if (avatars.length >= 3) break;
    }
    return avatars;
  }
}
