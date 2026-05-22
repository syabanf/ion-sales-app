import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:ion_sales_app/shared.dart';
import '../../domain/lead.dart';
import '../../domain/lead_repository.dart';
import '../bloc/leads_bloc.dart';

/// Sales App — bottom-tab shell.
///
/// Tabs (mirrors the tech_app shape so the two apps feel like one
/// system):
///   - Home — date pill greeting, stat tiles, latest lead, hot leads
///   - Leads — full list with pill segment filter (All / New /
///     Qualified / Converted)
///   - Pipeline — leads grouped by status bucket
///   - Customers — placeholder for Phase 2 (add-ons, plan changes,
///     relocation requests)
///   - Stats — counters + conversion rate
///
/// Uses the shared widget vocabulary (IonAppBar, IonSection,
/// IonPillSegment, IonAnimatedTabs, FadeSlideIn) so future design
/// changes propagate through both apps at once.
class LeadsPage extends StatefulWidget {
  const LeadsPage({super.key});

  @override
  State<LeadsPage> createState() => _LeadsPageState();
}

class _LeadsPageState extends State<LeadsPage> {
  int _tab = 0;
  late final List<ScrollController> _scrollControllers;

  @override
  void initState() {
    super.initState();
    _scrollControllers = List.generate(5, (_) => ScrollController());
  }

  @override
  void dispose() {
    for (final c in _scrollControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LeadsBloc(getIt<LeadRepository>())
        ..add(const LeadsRefreshRequested()),
      child: Builder(
        builder: (context) => Scaffold(
          backgroundColor: IonForm.pageBg,
          appBar: IonAppBar(
            title: _tabTitle(_tab),
            leading: IonAppBarAction(
              icon: Icons.person_outline_rounded,
              onTap: () => GoRouter.of(context).push('/profile'),
            ),
            actions: [
              IonAppBarAction(
                icon: Icons.search_rounded,
                onTap: () => _openSearch(context),
              ),
              if (_tab == 1)
                IonAppBarAction(
                  icon: Icons.add_rounded,
                  onTap: () => GoRouter.of(context).push('/leads/new'),
                  tooltip: 'New lead',
                ),
              IonAppBarAction(
                icon: Icons.refresh_rounded,
                onTap: () => context
                    .read<LeadsBloc>()
                    .add(const LeadsRefreshRequested()),
              ),
              IonAppBarAction(
                icon: Icons.logout_rounded,
                onTap: () => context
                    .read<AuthBloc>()
                    .add(const AuthLogoutRequested()),
              ),
            ],
          ),
          body: BlocBuilder<LeadsBloc, LeadsState>(
            builder: (context, state) {
              return IonAnimatedTabs(
                index: _tab,
                children: [
                  HomeTab(
                    controller: _scrollControllers[0],
                    state: state,
                    onJumpToLeads: () => setState(() => _tab = 1),
                  ),
                  LeadsTab(
                    controller: _scrollControllers[1],
                    state: state,
                  ),
                  PipelineTab(
                    controller: _scrollControllers[2],
                    state: state,
                  ),
                  CustomersTab(controller: _scrollControllers[3]),
                  StatsTab(
                    controller: _scrollControllers[4],
                    state: state,
                  ),
                ],
              );
            },
          ),
          bottomNavigationBar: _BottomNav(
            index: _tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
        ),
      ),
    );
  }

  String _tabTitle(int t) {
    switch (t) {
      case 0:
        return 'Home';
      case 1:
        return 'Leads';
      case 2:
        return 'Pipeline';
      case 3:
        return 'Customers';
      case 4:
        return 'Stats';
    }
    return '';
  }

  /// Global search — bundles the user's current leads + top-level
  /// destinations into one IonSearchSheet for fast jumping.
  Future<void> _openSearch(BuildContext context) async {
    final state = context.read<LeadsBloc>().state;
    final leads = state.items;

    final entries = <IonSearchEntry>[
      const IonSearchEntry(
        id: 'tab:0',
        title: 'Home',
        subtitle: 'Greeting + stats + hot leads',
        icon: Icons.home_rounded,
        tag: 'PAGE',
      ),
      const IonSearchEntry(
        id: 'tab:1',
        title: 'Leads',
        subtitle: 'Your full lead queue',
        icon: Icons.person_search_rounded,
        tag: 'PAGE',
      ),
      const IonSearchEntry(
        id: 'tab:2',
        title: 'Pipeline',
        subtitle: 'Funnel by stage',
        icon: Icons.timeline_rounded,
        tag: 'PAGE',
      ),
      const IonSearchEntry(
        id: 'tab:3',
        title: 'Customers',
        subtitle: 'Won + active accounts',
        icon: Icons.people_rounded,
        tag: 'PAGE',
      ),
      const IonSearchEntry(
        id: 'route:/leads/new',
        title: 'New lead',
        subtitle: 'Start a fresh opportunity',
        icon: Icons.add_rounded,
        accent: IonColors.mint500,
        tag: 'ACTION',
      ),
      for (final lead in leads.take(20))
        IonSearchEntry(
          id: 'lead:${lead.id}',
          title: lead.fullName,
          subtitle: '${lead.status} · ${lead.productName ?? lead.phone}',
          icon: Icons.person_outline_rounded,
          accent: IonColors.indigo500,
          tag: 'LEAD',
        ),
    ];

    final picked = await IonSearchSheet.show(
      context,
      entries: entries,
      placeholder: 'Search leads, pages, actions…',
    );
    if (picked == null) return;
    if (!mounted) return;
    final id = picked.id;
    if (id.startsWith('tab:')) {
      setState(() => _tab = int.tryParse(id.substring(4)) ?? 0);
    } else if (id.startsWith('route:')) {
      GoRouter.of(context).push(id.substring(6));
    } else if (id.startsWith('lead:')) {
      GoRouter.of(context).push('/leads/${id.substring(5)}');
    }
  }
}

// =============================================================================
// HomeTab — greeting + stats + hot leads
// =============================================================================

class HomeTab extends StatelessWidget {
  const HomeTab({
    super.key,
    required this.controller,
    required this.state,
    required this.onJumpToLeads,
  });
  final ScrollController controller;
  final LeadsState state;
  final VoidCallback onJumpToLeads;

  @override
  Widget build(BuildContext context) {
    final stats = _Stats.of(state.items);
    final hotLeads = _hotLeads(state.items);
    final greeting = _greeting();
    final name = _displayName(context);

    // Wave 21 — dashboard header. IonDisplayTitle + trend metrics +
    // IonQuickAccessGrid replace the legacy greeting + stat grid +
    // ad-hoc quick-jump row. Keeps the same content; the visual
    // vocabulary lines up with customer + tech home now.
    final today = DateFormat('EEEE, MMM d').format(DateTime.now());
    final total = state.items.length;
    final convPct =
        total == 0 ? 0 : ((stats.converted * 100) / total).round();
    return CustomScrollView(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // 1) Display title — date pill + greeting + name + bell stub.
        SliverToBoxAdapter(
          child: FadeSlideIn(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: IonDisplayTitle(
                eyebrow: today,
                title: '$greeting,\n$name',
                subtitle: total == 0
                    ? 'Add your first lead to get going.'
                    : '$total active leads in your pipeline.',
                trailing: IonCircleIconButton(
                  icon: Icons.add_rounded,
                  onTap: () => GoRouter.of(context).push('/leads/new'),
                ),
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 18)),

        // 2) Trend metric row — pipeline KPIs with green/red arrows.
        SliverToBoxAdapter(
          child: FadeSlideIn(
            delay: const Duration(milliseconds: 80),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: IonMetricTile(
                      icon: Icons.fiber_new_outlined,
                      label: 'New leads',
                      value: '${stats.newCount}',
                      numericValue: stats.newCount,
                      sparkline: _ramp(stats.newCount.toDouble()),
                      accent: IonColors.ion500,
                      delta: stats.newCount > 0 ? 'Worth a call' : 'Quiet day',
                      trend: stats.newCount > 0
                          ? IonTrend.up
                          : IonTrend.flat,
                      onTap: onJumpToLeads,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: IonMetricTile(
                      icon: Icons.verified_outlined,
                      label: 'Qualified',
                      value: '${stats.qualified}',
                      numericValue: stats.qualified,
                      sparkline: _ramp(stats.qualified.toDouble()),
                      accent: IonColors.mint500,
                      delta: stats.qualified > 0 ? 'Ready to push' : 'None yet',
                      trend: stats.qualified > 0
                          ? IonTrend.up
                          : IonTrend.flat,
                      onTap: onJumpToLeads,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        SliverToBoxAdapter(
          child: FadeSlideIn(
            delay: const Duration(milliseconds: 110),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: IonMetricTile(
                      icon: Icons.assignment_late_outlined,
                      label: 'Docs pending',
                      value: '${stats.docsPending}',
                      numericValue: stats.docsPending,
                      sparkline: _ramp(stats.docsPending.toDouble()),
                      accent: IonColors.peach500,
                      delta: stats.docsPending > 0
                          ? 'Chase customers'
                          : 'All clear',
                      trend: stats.docsPending > 0
                          ? IonTrend.down
                          : IonTrend.up,
                      onTap: onJumpToLeads,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: IonMetricTile(
                      icon: Icons.trending_up_rounded,
                      label: 'Conversion',
                      value: '$convPct',
                      suffix: '%',
                      numericValue: convPct,
                      sparkline: _ramp(convPct.toDouble()),
                      accent: IonColors.indigo500,
                      delta:
                          convPct >= 30 ? 'Strong rate' : 'Push harder',
                      trend: convPct >= 30
                          ? IonTrend.up
                          : (convPct >= 15
                              ? IonTrend.flat
                              : IonTrend.down),
                      onTap: () => GoRouter.of(context).push('/commissions'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 3) Quick access — 4-col grid (Approvals / B2B / Customers /
        //    Commissions / Opportunities / Reports …).
        const SliverToBoxAdapter(
          child: IonChipDivider(label: 'Quick access'),
        ),
        SliverToBoxAdapter(
          child: FadeSlideIn(
            delay: const Duration(milliseconds: 160),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: IonQuickAccessGrid(
                items: [
                  IonQuickAccessItem(
                    icon: Icons.add_circle_outline,
                    label: 'New lead',
                    accent: IonColors.ion500,
                    onTap: () => GoRouter.of(context).push('/leads/new'),
                  ),
                  IonQuickAccessItem(
                    icon: Icons.fact_check_outlined,
                    label: 'Approvals',
                    accent: IonColors.plum500,
                    onTap: () => GoRouter.of(context).push('/approvals'),
                  ),
                  IonQuickAccessItem(
                    icon: Icons.business_center_outlined,
                    label: 'B2B',
                    accent: IonColors.indigo500,
                    onTap: () => GoRouter.of(context).push('/opportunities'),
                  ),
                  IonQuickAccessItem(
                    icon: Icons.payments_outlined,
                    label: 'Commission',
                    accent: IonColors.mint500,
                    onTap: () => GoRouter.of(context).push('/commissions'),
                  ),
                  IonQuickAccessItem(
                    icon: Icons.people_outline_rounded,
                    label: 'Customers',
                    accent: IonColors.peach500,
                    onTap: () => GoRouter.of(context).push('/customers'),
                  ),
                  IonQuickAccessItem(
                    icon: Icons.workspaces_outline,
                    label: 'Pipeline',
                    accent: IonColors.ion600,
                    onTap: onJumpToLeads,
                  ),
                  IonQuickAccessItem(
                    icon: Icons.person_outline_rounded,
                    label: 'Profile',
                    accent: IonColors.inkBlack,
                    onTap: () => GoRouter.of(context).push('/profile'),
                  ),
                  IonQuickAccessItem(
                    icon: Icons.bar_chart_rounded,
                    label: 'Stats',
                    accent: IonColors.cream500,
                    onTap: onJumpToLeads,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),

        // Phase 2 — My quota card.
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: _MyQuotaCard(),
          ),
        ),

        // Phase 2 — Overdue leads alert.
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: _OverdueLeadsAlert(),
          ),
        ),

        // Phase 2 — Leaderboard widget (top sales reps this month).
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: _LeaderboardCard(),
          ),
        ),

        // Section header: hot leads → "All leads" link
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Hot leads',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: IonColors.ink,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                _TextChevron(label: 'All Leads', onTap: onJumpToLeads),
              ],
            ),
          ),
        ),

        if (state.loading && state.items.isEmpty)
          const SliverToBoxAdapter(
            child: IonListSkeleton(count: 5),
          )
        else if (state.error != null && state.items.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: IonErrorBanner(message: state.error!),
            ),
          )
        else if (hotLeads.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: _EmptyBlock(
                title: 'No active leads',
                description: 'Tap the + above to add one.',
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            sliver: SliverList.separated(
              itemCount: hotLeads.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) => FadeSlideIn(
                delay: Duration(milliseconds: 160 + (40 * i).clamp(0, 240)),
                child: _LeadCard(lead: hotLeads[i]),
              ),
            ),
          ),
      ],
    );
  }

  // Hot = anything in active sales motion (not converted / lost).
  /// Wave 23 — synthesize a 7-point ramp toward the current value for
  /// the inline sparkline. We don't have historical data per metric,
  /// so the ramp is illustrative rather than literal — gives the tile
  /// a sense of motion without lying about specific history.
  List<double> _ramp(double n) {
    if (n == 0) return const [0, 0, 1, 0, 1, 0, 0];
    return [n * 0.4, n * 0.6, n * 0.55, n * 0.8, n * 0.75, n * 0.95, n];
  }

  List<Lead> _hotLeads(List<Lead> all) {
    final hot = all
        .where((l) => l.status != 'converted' && l.status != 'lost')
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return hot.take(6).toList();
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 18) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _displayName(BuildContext context) {
    final state = context.read<AuthBloc>().state;
    final raw = state.session?.user.fullName ?? '';
    if (raw.isEmpty) return 'Sales Rep';
    return raw.split(RegExp(r'\s+')).first;
  }
}

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({required this.greeting, required this.name});
  final String greeting;
  final String name;
  @override
  Widget build(BuildContext context) {
    final date = DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IonDatePill(label: date, icon: Icons.calendar_today_rounded),
        const SizedBox(height: 10),
        Text(
          greeting,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: IonColors.ink,
            letterSpacing: -0.6,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          name,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: IonColors.inkMuted,
          ),
        ),
      ],
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.stats});
  final _Stats stats;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatTileBig(
                label: 'New leads',
                value: '${stats.newCount}',
                sub: 'awaiting first touch',
                icon: Icons.fiber_new_outlined,
                tint: IonColors.ion100,
                fg: IonColors.ion600,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTileBig(
                label: 'Qualified',
                value: '${stats.qualified}',
                sub: 'in active motion',
                icon: Icons.thumb_up_alt_outlined,
                tint: const Color(0xFFFEF3C7),
                fg: const Color(0xFFB45309),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatTileBig(
                label: 'Docs pending',
                value: '${stats.docsPending}',
                sub: 'needs follow-up',
                icon: Icons.assignment_late_outlined,
                tint: const Color(0xFFF3E8FF),
                fg: const Color(0xFF7E22CE),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTileBig(
                label: 'Converted',
                value: '${stats.converted}',
                sub: 'this period',
                icon: Icons.check_circle_outline,
                tint: const Color(0xFFDCFCE7),
                fg: const Color(0xFF15803D),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatTileBig extends StatelessWidget {
  const _StatTileBig({
    required this.label,
    required this.value,
    required this.sub,
    required this.icon,
    required this.tint,
    required this.fg,
  });
  final String label;
  final String value;
  final String sub;
  final IconData icon;
  final Color tint;
  final Color fg;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: IonForm.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: fg, size: 20),
              ),
              const Spacer(),
              // Wave 24 — wrap the headline metric in IonGradientText
              // so the big number reads with brand colour instead of
              // flat ink. Skips when the value is non-numeric ("—")
              // because the gradient on a dash looks weird.
              value.contains(RegExp(r'[0-9]'))
                  ? IonGradientText(
                      text: value,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    )
                  : Text(
                      value,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: IonColors.ink,
                        height: 1,
                        letterSpacing: -0.6,
                      ),
                    ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: IonColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(sub, style: const TextStyle(fontSize: 11, color: IonColors.inkMuted)),
        ],
      ),
    );
  }
}

// =============================================================================
// LeadsTab — full list with pill segmented filter
// =============================================================================

class LeadsTab extends StatelessWidget {
  const LeadsTab({super.key, required this.controller, required this.state});
  final ScrollController controller;
  final LeadsState state;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'All leads',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: IonColors.ink,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${state.items.length} in your queue',
                  style: const TextStyle(
                    fontSize: 13,
                    color: IonColors.inkMuted,
                  ),
                ),
                const SizedBox(height: 16),
                IonPillSegment<String?>(
                  value: _segValue(state.statusFilter),
                  options: const [
                    IonSegmentedOption(null, 'All'),
                    IonSegmentedOption('new', 'New'),
                    IonSegmentedOption('qualified', 'Qualified'),
                    IonSegmentedOption('converted', 'Done'),
                  ],
                  onChanged: (s) => context
                      .read<LeadsBloc>()
                      .add(LeadsStatusFiltered(status: s)),
                ),
              ],
            ),
          ),
        ),
        if (state.loading && state.items.isEmpty)
          const SliverToBoxAdapter(
            child: IonListSkeleton(count: 5),
          )
        else if (state.error != null && state.items.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: IonErrorBanner(message: state.error!),
            ),
          )
        else if (state.items.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: _EmptyBlock(
                title: 'No leads in this view',
                description: 'Try a different filter or tap + to add one.',
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            sliver: SliverList.separated(
              itemCount: state.items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              // Wave 20 — stagger lead cards in as the list renders.
              // Delay caps at index 10 so a long pipeline still lands
              // within ~600 ms.
              itemBuilder: (context, i) => FadeSlideIn(
                delay: Duration(milliseconds: 50 * i.clamp(0, 10)),
                child: _LeadCard(lead: state.items[i]),
              ),
            ),
          ),
      ],
    );
  }

  String? _segValue(String? raw) {
    if (raw == 'new' || raw == 'qualified' || raw == 'converted') return raw;
    return null;
  }
}

// =============================================================================
// PipelineTab — leads grouped by status bucket
// =============================================================================

class PipelineTab extends StatelessWidget {
  const PipelineTab({super.key, required this.controller, required this.state});
  final ScrollController controller;
  final LeadsState state;

  // Per PRD §6.3 line 1427: pipeline stages are
  // new / active / warm / hot / potential / converted / lost.
  // We render all of them; backend allows the broader enum already.
  static const _bucketOrder = [
    'new',
    'active',
    'warm',
    'hot',
    'qualified',
    'potential',
    'document_pending',
    'ready_to_convert',
    'converted',
    'lost',
  ];

  @override
  Widget build(BuildContext context) {
    final groups = _groupByStatus(state.items);
    return CustomScrollView(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Pipeline',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: IonColors.ink,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Leads grouped by stage',
                  style: TextStyle(fontSize: 13, color: IonColors.inkMuted),
                ),
              ],
            ),
          ),
        ),
        if (state.loading && state.items.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: CircularProgressIndicator(color: IonColors.ion500),
            ),
          )
        else if (state.items.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: _EmptyBlock(
                title: 'Pipeline is empty',
                description: 'New leads will land in the leftmost bucket.',
              ),
            ),
          )
        else
          for (final s in _bucketOrder)
            if ((groups[s] ?? const <Lead>[]).isNotEmpty)
              _PipelineGroupSliver(status: s, items: groups[s]!),
      ],
    );
  }

  Map<String, List<Lead>> _groupByStatus(List<Lead> items) {
    final m = <String, List<Lead>>{};
    for (final l in items) {
      m.putIfAbsent(l.status, () => []).add(l);
    }
    for (final list in m.values) {
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return m;
  }
}

class _PipelineGroupSliver extends StatelessWidget {
  const _PipelineGroupSliver({required this.status, required this.items});
  final String status;
  final List<Lead> items;
  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      sliver: SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Text(
                    IonHumanize.status(status).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: IonColors.ion600,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: IonColors.ion100,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${items.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: IonColors.ion700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverList.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => FadeSlideIn(
              delay: Duration(milliseconds: 50 * i.clamp(0, 10)),
              child: _LeadCard(lead: items[i]),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// CustomersTab — Phase 2 placeholder
// =============================================================================

class CustomersTab extends StatelessWidget {
  const CustomersTab({super.key, required this.controller});
  final ScrollController controller;
  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        const Text(
          'Customers',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: IonColors.ink,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'Manage your converted customers',
          style: TextStyle(fontSize: 13, color: IonColors.inkMuted),
        ),
        const SizedBox(height: 18),

        // Primary CTA — opens the full customer list. The cards below
        // are quick-action shortcuts that also land on the list (then
        // the rep picks who the action targets).
        IonPrimaryButton(
          label: 'Browse customers',
          icon: Icons.people_alt_rounded,
          onPressed: () => GoRouter.of(context).push('/customers'),
        ),
        const SizedBox(height: 18),

        _Phase2Card(
          icon: Icons.upgrade_rounded,
          title: 'Plan upgrade / downgrade',
          subtitle:
              'Bump an existing customer to a faster plan, or step them down.',
          onTap: () => GoRouter.of(context).push('/customers'),
        ),
        const SizedBox(height: 12),
        _Phase2Card(
          icon: Icons.add_box_outlined,
          title: 'Add-on selling',
          subtitle:
              'Sell speed boost, CCTV, or IPTV to existing broadband customers.',
          onTap: () => GoRouter.of(context).push('/customers'),
        ),
        const SizedBox(height: 12),
        _Phase2Card(
          icon: Icons.location_on_outlined,
          title: 'Relocation request',
          subtitle:
              'Move a customer to a new address — re-uses the lead wizard.',
          onTap: () => GoRouter.of(context).push('/customers'),
        ),
      ],
    );
  }
}

class _Phase2Card extends StatelessWidget {
  const _Phase2Card({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: IonForm.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: IonColors.ion100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: IonColors.ion600, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: IonColors.ink,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: IonColors.ion50,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'PHASE 2',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: IonColors.ion700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: IonColors.inkMuted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// StatsTab — counts + conversion %
// =============================================================================

class StatsTab extends StatelessWidget {
  const StatsTab({super.key, required this.controller, required this.state});
  final ScrollController controller;
  final LeadsState state;
  @override
  Widget build(BuildContext context) {
    final stats = _Stats.of(state.items);
    final convRate = state.items.isEmpty
        ? 0.0
        : (stats.converted / state.items.length).clamp(0.0, 1.0);
    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        const Text(
          'Stats',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: IonColors.ink,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'Your queue at a glance',
          style: TextStyle(fontSize: 13, color: IonColors.inkMuted),
        ),
        const SizedBox(height: 16),
        _ConversionCard(
          pct: convRate,
          converted: stats.converted,
          total: state.items.length,
        ),
        const SizedBox(height: 12),
        // Wave 68 (S5) — MTD commission tile. Pairs the conversion
        // funnel (above) with the rep's monthly earning signal so the
        // Stats tab matches the PRD §6.1 dashboard intent.
        const _MTDCommissionCard(),
        const SizedBox(height: 12),
        _StatGrid(stats: stats),
      ],
    );
  }
}

/// Wave 68 (S5) — MTD commission earned. Fetches /api/crm/commissions/mine
/// which returns `total_this_month` summed across all commission_records
/// dated in the current calendar month. Tap → navigates to the full
/// ledger page for drill-down.
class _MTDCommissionCard extends StatefulWidget {
  const _MTDCommissionCard();
  @override
  State<_MTDCommissionCard> createState() => _MTDCommissionCardState();
}

class _MTDCommissionCardState extends State<_MTDCommissionCard> {
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
    return res.data ?? const <String, dynamic>{};
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snap) {
        final money = NumberFormat.currency(
          locale: 'id_ID',
          symbol: 'Rp ',
          decimalDigits: 0,
        );
        final thisMonth =
            (snap.data?['total_this_month'] as num?)?.toDouble() ?? 0;
        final totalEarned =
            (snap.data?['total_earned'] as num?)?.toDouble() ?? 0;
        final count = (snap.data?['count'] as num?)?.toInt() ?? 0;
        final loading = snap.connectionState != ConnectionState.done;

        return GestureDetector(
          onTap: () => Navigator.of(context).pushNamed('/commissions'),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: IonForm.surfaceBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: IonColors.mint500.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.payments_outlined,
                    color: IonColors.mint500,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'MTD commission',
                        style: TextStyle(
                          fontSize: 11,
                          color: IonColors.inkMuted,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        loading ? '…' : money.format(thisMonth),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: IonColors.ink,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        loading
                            ? 'Loading earnings…'
                            : 'YTD ${money.format(totalEarned)} · '
                                '$count entr${count == 1 ? "y" : "ies"}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: IonColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: IonColors.inkMuted,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ConversionCard extends StatelessWidget {
  const _ConversionCard({
    required this.pct,
    required this.converted,
    required this.total,
  });
  final double pct;
  final int converted;
  final int total;
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
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Conversion rate',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                total == 0 ? '—' : '${(pct * 100).round()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            total == 0
                ? 'No leads in your queue yet'
                : '$converted of $total leads converted',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Lead card (shadow-style, tappable)
// =============================================================================

class _LeadCard extends StatelessWidget {
  const _LeadCard({required this.lead});
  final Lead lead;
  @override
  Widget build(BuildContext context) {
    // Wave 26 — migrated to IonListCard canonical recipe. Uses
    // IonLeadingInitials (people-flavoured leading) + status badge
    // trailing + meta = created date. Trims ~80 lines of bespoke
    // card chrome.
    return IonListCard(
      leading: IonLeadingInitials(
        initials: IonLeadingInitials.fromName(lead.fullName),
      ),
      title: lead.fullName,
      subtitle: lead.address,
      meta: [DateFormat('MMM d').format(lead.createdAt.toLocal())],
      trailing: _StatusBadge(status: lead.status),
      onTap: () => GoRouter.of(context).push('/leads/${lead.id}'),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final c = _color(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        IonHumanize.status(status).toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          color: c,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Color _color(String s) {
    switch (s) {
      case 'converted':
        return const Color(0xFF15803D);
      case 'ready_to_convert':
        return IonColors.ion600;
      case 'qualified':
        return const Color(0xFFB45309);
      case 'document_pending':
        return const Color(0xFF7E22CE);
      case 'lost':
        return IonColors.inkMuted;
      default:
        return const Color(0xFFB45309);
    }
  }
}

// =============================================================================
// Shared bits
// =============================================================================

class _Stats {
  const _Stats({
    required this.newCount,
    required this.qualified,
    required this.docsPending,
    required this.converted,
  });
  final int newCount;
  final int qualified;
  final int docsPending;
  final int converted;
  factory _Stats.of(List<Lead> items) => _Stats(
        newCount: items.where((l) => l.status == 'new').length,
        qualified: items.where((l) => l.status == 'qualified' || l.status == 'ready_to_convert').length,
        docsPending: items.where((l) => l.status == 'document_pending').length,
        converted: items.where((l) => l.status == 'converted').length,
      );
}

class _TextChevron extends StatelessWidget {
  const _TextChevron({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: IonColors.ion600,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.chevron_right_rounded,
                size: 16, color: IonColors.ion600),
          ],
        ),
      ),
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock({required this.title, required this.description});
  final String title;
  final String description;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: IonForm.cardShadow,
      ),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined,
              size: 36, color: IonColors.inkMuted),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: IonColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: IonColors.inkMuted),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Bottom navigation — mirror tech_app
// =============================================================================

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.index, required this.onChanged});
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const tabs = <_NavTab>[
      _NavTab(icon: Icons.home_outlined, active: Icons.home, label: 'Home'),
      _NavTab(icon: Icons.list_alt_outlined, active: Icons.list_alt, label: 'Leads'),
      _NavTab(icon: Icons.view_kanban_outlined, active: Icons.view_kanban, label: 'Pipeline'),
      _NavTab(icon: Icons.people_outline, active: Icons.people, label: 'Customers'),
      _NavTab(icon: Icons.trending_up_outlined, active: Icons.trending_up, label: 'Stats'),
    ];
    return Container(
      color: IonForm.pageBg,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: IonColors.separatorLight),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            // Wave 25 — smoothly animate the flex transition. The
            // previous `Expanded(flex: selected ? 3 : 2)` jumped on
            // tab change because Flutter doesn't animate int flex.
            // Now each tab gets a TweenAnimationBuilder<double> that
            // interpolates its width between inactive (2 share) and
            // active (3 share) in 280 ms easeOutCubic — same logic,
            // smooth slide instead of cut.
            child: LayoutBuilder(
              builder: (context, c) {
                const inactiveFlex = 2.0;
                const activeFlex = 3.0;
                final totalFlex =
                    tabs.length * inactiveFlex + (activeFlex - inactiveFlex);
                final inactiveW = c.maxWidth * inactiveFlex / totalFlex;
                final activeW = c.maxWidth * activeFlex / totalFlex;
                return Row(
                  children: [
                    for (var i = 0; i < tabs.length; i++)
                      TweenAnimationBuilder<double>(
                        tween:
                            Tween(begin: 0, end: index == i ? 1.0 : 0.0),
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        builder: (ctx, t, _) {
                          final w = inactiveW + (activeW - inactiveW) * t;
                          return SizedBox(
                            width: w,
                            child: _NavItem(
                              tab: tabs[i],
                              selected: index == i,
                              onTap: () => onChanged(i),
                            ),
                          );
                        },
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTab {
  const _NavTab({
    required this.icon,
    required this.active,
    required this.label,
  });
  final IconData icon;
  final IconData active;
  final String label;
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.tab, required this.selected, required this.onTap});
  final _NavTab tab;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: selected ? IonColors.ion500 : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  selected ? tab.active : tab.icon,
                  size: 20,
                  color: selected ? Colors.white : IonColors.inkMuted,
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: selected
                      ? Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            tab.label,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.1,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// QuickJump tile (used by Home for Approvals + B2B shortcuts)
// =============================================================================

class _SalesQuickJump extends StatelessWidget {
  const _SalesQuickJump({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tint,
    required this.fg,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Color tint;
  final Color fg;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: IonForm.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: fg, size: 20),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: IonColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: IonColors.inkMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// Phase 2 — Leaderboard card (top sales reps this month)
// =====================================================================

class _LeaderboardCard extends StatefulWidget {
  const _LeaderboardCard();

  @override
  State<_LeaderboardCard> createState() => _LeaderboardCardState();
}

class _LeaderboardCardState extends State<_LeaderboardCard> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final res = await getIt<ApiClient>().request<Map<String, dynamic>>(
      '/api/crm/sales/leaderboard',
    );
    final items = (res.data?['items'] as List<dynamic>? ?? const <dynamic>[]);
    return items
        .take(3)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: IonForm.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.emoji_events_outlined,
                  size: 18, color: Color(0xFFD97706)),
              SizedBox(width: 6),
              Text(
                'Top performers',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: IonColors.ink,
                ),
              ),
              Spacer(),
              Text(
                'THIS MONTH',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: IonColors.inkMuted,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    color: IonColors.ion500,
                  ),
                );
              }
              if (snap.hasError) {
                return const Text(
                  'Leaderboard unavailable.',
                  style: TextStyle(fontSize: 12, color: IonColors.inkMuted),
                );
              }
              final items = snap.data ?? const [];
              if (items.isEmpty) {
                return const Text(
                  'No conversions yet this month.',
                  style: TextStyle(fontSize: 12, color: IonColors.inkMuted),
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < items.length; i++)
                    _LeaderRow(rank: i + 1, item: items[i]),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LeaderRow extends StatelessWidget {
  const _LeaderRow({required this.rank, required this.item});
  final int rank;
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final medalColor = rank == 1
        ? const Color(0xFFFBBF24)
        : rank == 2
            ? const Color(0xFF94A3B8)
            : const Color(0xFFEA580C);
    final name = (item['full_name'] as String?)?.isNotEmpty == true
        ? item['full_name'] as String
        : (item['email'] as String? ?? 'rep');
    final conversions = (item['conversions'] as num?)?.toInt() ?? 0;
    final revenue = (item['revenue'] as num?)?.toDouble() ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: medalColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: medalColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: IonColors.ink,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '$conversions',
            style: const TextStyle(
              fontSize: 12,
              color: IonColors.inkMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Rp ${revenue.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: IonColors.ion600,
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// Phase 2 — Quota card (mine vs target)
// =====================================================================

class _MyQuotaCard extends StatefulWidget {
  const _MyQuotaCard();
  @override
  State<_MyQuotaCard> createState() => _MyQuotaCardState();
}

class _MyQuotaCardState extends State<_MyQuotaCard> {
  late Future<Map<String, dynamic>?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>?> _load() async {
    try {
      final r = await getIt<ApiClient>().request<Map<String, dynamic>>(
        '/api/crm/sales/my-quota',
      );
      final d = r.data ?? const {};
      if (d['has_quota'] != true) return null;
      return d;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _future,
      builder: (context, snap) {
        final d = snap.data;
        if (d == null) return const SizedBox.shrink();
        final ordersPct = (d['orders_pct'] as num?)?.toDouble() ?? 0;
        final revPct = (d['revenue_pct'] as num?)?.toDouble() ?? 0;
        final ordersSoFar = (d['orders_so_far'] as num?)?.toInt() ?? 0;
        final ordersTarget = (d['target_orders'] as num?)?.toInt() ?? 0;
        final revSoFar = (d['revenue_so_far'] as num?)?.toDouble() ?? 0;
        final revTarget = (d['target_revenue'] as num?)?.toDouble() ?? 0;
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: IonForm.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.flag_outlined, size: 18, color: IonColors.ion600),
                  SizedBox(width: 6),
                  Text(
                    'My quota',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: IonColors.ink,
                    ),
                  ),
                  Spacer(),
                  Text(
                    'THIS MONTH',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: IonColors.inkMuted,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _QuotaBar(
                label: 'Orders',
                value: '$ordersSoFar / $ordersTarget',
                pct: ordersPct,
              ),
              const SizedBox(height: 10),
              _QuotaBar(
                label: 'Revenue (Rp)',
                value:
                    '${revSoFar.toStringAsFixed(0)} / ${revTarget.toStringAsFixed(0)}',
                pct: revPct,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QuotaBar extends StatelessWidget {
  const _QuotaBar({required this.label, required this.value, required this.pct});
  final String label;
  final String value;
  final double pct;
  @override
  Widget build(BuildContext context) {
    final pctClamped = (pct / 100).clamp(0.0, 1.0).toDouble();
    final tone = pct >= 100
        ? const Color(0xFF15803D)
        : pct >= 70
            ? const Color(0xFFB45309)
            : IonColors.ion600;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: IonColors.inkSoft,
              ),
            ),
            const Spacer(),
            Text(
              '${pct.toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: tone,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: pctClamped,
            minHeight: 6,
            backgroundColor: IonColors.separatorLight,
            valueColor: AlwaysStoppedAnimation(tone),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11,
            color: IonColors.inkMuted,
          ),
        ),
      ],
    );
  }
}

// =====================================================================
// Phase 2 — Overdue leads alert (taps open a sheet of stale leads)
// =====================================================================

class _OverdueLeadsAlert extends StatefulWidget {
  const _OverdueLeadsAlert();
  @override
  State<_OverdueLeadsAlert> createState() => _OverdueLeadsAlertState();
}

class _OverdueLeadsAlertState extends State<_OverdueLeadsAlert> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    try {
      final r = await getIt<ApiClient>().request<Map<String, dynamic>>(
        '/api/crm/leads/overdue',
        queryParameters: const {'mine': 'true', 'days': '7'},
      );
      final items = (r.data?['items'] as List<dynamic>? ?? const []);
      return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return const [];
    }
  }

  void _openSheet(BuildContext context, List<Map<String, dynamic>> items) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollCtrl) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Overdue leads (${items.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: IonColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'No activity in the last 7 days. Reach out before they go cold.',
                style: TextStyle(fontSize: 12, color: IonColors.inkMuted),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ListView.separated(
                  controller: scrollCtrl,
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final l = items[i];
                    final updated = DateTime.tryParse(l['updated_at'] as String? ?? '');
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          GoRouter.of(context).push('/leads/${l['id']}');
                        },
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l['full_name'] as String? ?? '',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: IonColors.ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${l['lead_number']} · ${l['status']}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: IonColors.inkMuted,
                                ),
                              ),
                              if (updated != null)
                                Text(
                                  'Last touched ${DateFormat('MMM d').format(updated)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFFB45309),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snap) {
        final items = snap.data ?? const [];
        if (items.isEmpty) return const SizedBox.shrink();
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _openSheet(context, items),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                border: Border.all(color: const Color(0xFFFDE68A)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.schedule_rounded,
                        color: Color(0xFFB45309), size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${items.length} overdue lead${items.length == 1 ? "" : "s"}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF92400E),
                          ),
                        ),
                        const Text(
                          'No activity in 7+ days. Tap to follow up.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded,
                      size: 12, color: Color(0xFF92400E)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
