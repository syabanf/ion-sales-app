import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:ion_sales_app/shared.dart';

/// OpportunitiesPage — list of every enterprise opportunity the rep
/// can see. PRD §5 — replaces the web-only browse so the rep can
/// chase a quote from their phone.
///
/// Tap a row → /opportunities/:id for BOQ + quotation tabs.
class OpportunitiesPage extends StatefulWidget {
  const OpportunitiesPage({super.key});

  @override
  State<OpportunitiesPage> createState() => _OpportunitiesPageState();
}

class _OpportunitiesPageState extends State<OpportunitiesPage> {
  late Future<List<Map<String, dynamic>>> _future;
  String? _stageFilter;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final r = await getIt<ApiClient>().request<Map<String, dynamic>>(
      '/api/enterprise/opportunities',
      queryParameters: {
        if (_stageFilter != null && _stageFilter!.isNotEmpty)
          'stage': _stageFilter!,
        'page_size': 100,
      },
    );
    final items = (r.data?['items'] as List<dynamic>? ?? const []);
    return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IonForm.pageBg,
      appBar: IonAppBar(
        title: 'B2B Opportunities',
        actions: [
          IonAppBarAction(
            icon: Icons.add_rounded,
            onTap: () => GoRouter.of(context).push('/opportunities/new'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
        children: [
          const FadeSlideIn(
            child: IonDisplayTitle(
              eyebrow: 'B2B · Phase 2',
              title: 'Opportunities',
              subtitle: 'Enterprise pipeline — quote, win, convert.',
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: IonPillSegment<String?>(
            value: _stageFilter,
            options: const [
              IonSegmentedOption(null, 'All'),
              IonSegmentedOption('cold', 'Cold'),
              IonSegmentedOption('warm', 'Warm'),
              IonSegmentedOption('hot', 'Hot'),
              IonSegmentedOption('won', 'Won'),
            ],
            onChanged: (s) {
              _stageFilter = s;
              _reload();
            },
          ),
          ),
          const IonChipDivider(label: 'Pipeline'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const IonListSkeleton(
                  count: 4,
                  padding: EdgeInsets.fromLTRB(0, 8, 0, 16),
                );
              }
              if (snap.hasError) {
                return IonErrorBanner(
                  message: snap.error is ApiException
                      ? (snap.error as ApiException).message
                      : 'Failed: ${snap.error}',
                );
              }
              final items = snap.data ?? const [];
              if (items.isEmpty) {
                return const IonEmptyState(
                  icon: Icons.business_center_outlined,
                  art: IonArtKind.tasks,
                  title: 'No opportunities',
                  hint: 'Tap + in the top bar to create one.',
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    FadeSlideIn(
                      delay:
                          Duration(milliseconds: 40 * i.clamp(0, 10)),
                      child: _OppCard(item: items[i]),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              );
            },
          ),
          ),
        ],
      ),
    );
  }
}

class _OppCard extends StatelessWidget {
  const _OppCard({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    // Wave 26 — migrated to IonListCard. Account name = title, opp
    // number = subtitle, close date = meta, stage chip = trailing.
    final id = item['id'] as String?;
    final stage = item['stage'] as String? ?? 'cold';
    final accountName = (item['account_name'] as String?) ?? 'Opportunity';
    final oppNumber = (item['opportunity_number'] as String?) ?? '';
    final expectedClose = item['expected_close_at'] as String?;
    return IonListCard(
      leading: const IonLeadingIcon(
        icon: Icons.business_center_outlined,
        tint: IonColors.indigo500,
      ),
      title: accountName,
      subtitle: oppNumber.isEmpty ? null : oppNumber,
      meta: expectedClose != null
          ? ['Close ${_fmtDate(expectedClose)}']
          : const [],
      trailing: _StageChip(stage: stage),
      onTap: id == null
          ? null
          : () => GoRouter.of(context).push('/opportunities/$id'),
    );
  }

  String _fmtDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return DateFormat('MMM d').format(dt);
  }
}

class _StageChip extends StatelessWidget {
  const _StageChip({required this.stage});
  final String stage;
  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (stage) {
      case 'won':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF15803D);
        break;
      case 'hot':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFB91C1C);
        break;
      case 'warm':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        break;
      case 'lost':
        bg = IonColors.separatorLight;
        fg = IonColors.inkMuted;
        break;
      default:
        bg = IonColors.ion100;
        fg = IonColors.ion700;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        stage.toUpperCase(),
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
