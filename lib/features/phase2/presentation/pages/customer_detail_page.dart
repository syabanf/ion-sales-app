import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ion_sales_app/shared.dart';
import '../../data/phase2_api.dart';
import '../../domain/phase2_models.dart';

/// Customer detail — Phase 2 action surface. The page splits into:
///   - identity card (name, phone, address, plan)
///   - "Sell add-on" CTA which routes to the catalog picker
///   - "Plan change" + "Relocation" entry tiles
///   - History of current add-ons / past plan changes
///
/// Routes used:
///   /customers/:id/sell-addon          → AddonCatalogPage
///   /customers/:id/plan-change         → PlanChangePage
///   /customers/:id/relocation          → RelocationPage
class CustomerDetailPage extends StatefulWidget {
  const CustomerDetailPage({super.key, required this.customer});
  final CustomerSummary customer;

  @override
  State<CustomerDetailPage> createState() => _CustomerDetailPageState();
}

class _CustomerDetailPageState extends State<CustomerDetailPage> {
  late Future<List<CustomerAddon>> _addons;

  @override
  void initState() {
    super.initState();
    _addons = _load();
  }

  Future<List<CustomerAddon>> _load() =>
      Phase2Api(getIt<ApiClient>()).listCustomerAddons(widget.customer.id);

  void _reload() {
    setState(() => _addons = _load());
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.customer;
    return Scaffold(
      backgroundColor: IonForm.pageBg,
      appBar: IonAppBar(
        title: c.fullName,
        actions: [
          IonAppBarAction(icon: Icons.refresh_rounded, onTap: _reload),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          FadeSlideIn(
            child: IonDisplayTitle(
              padding: const EdgeInsets.symmetric(horizontal: 0),
              eyebrow: 'Customer',
              title: c.fullName,
              subtitle: c.productName ?? c.phone,
            ),
          ),
          const SizedBox(height: 14),
          _IdentityCard(customer: c),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'ACTIONS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: IonColors.inkMuted,
                letterSpacing: 1.0,
              ),
            ),
          ),
          _ActionTile(
            icon: Icons.add_box_outlined,
            title: 'Sell add-on',
            subtitle: 'Speed boost, IPTV, CCTV, …',
            onTap: () => GoRouter.of(context)
                .push('/customers/${c.id}/sell-addon')
                .then((_) => _reload()),
          ),
          const SizedBox(height: 10),
          _ActionTile(
            icon: Icons.upgrade_rounded,
            title: 'Plan change',
            subtitle: 'Upgrade or downgrade the current plan',
            onTap: () => GoRouter.of(context)
                .push('/customers/${c.id}/plan-change'),
          ),
          const SizedBox(height: 10),
          _ActionTile(
            icon: Icons.location_on_outlined,
            title: 'Relocation',
            subtitle: 'Move this customer to a new address',
            onTap: () => GoRouter.of(context)
                .push('/customers/${c.id}/relocation'),
          ),
          const SizedBox(height: 18),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'CURRENT ADD-ONS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: IonColors.inkMuted,
                letterSpacing: 1.0,
              ),
            ),
          ),
          FutureBuilder<List<CustomerAddon>>(
            future: _addons,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: CircularProgressIndicator(color: IonColors.ion500),
                  ),
                );
              }
              if (snap.hasError) {
                return IonErrorBanner(message: 'Failed: ${snap.error}');
              }
              final items = snap.data ?? const [];
              if (items.isEmpty) {
                return _emptyAddons();
              }
              return Column(
                children: [
                  for (final a in items) ...[
                    _AddonRow(addon: a),
                    const SizedBox(height: 10),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _emptyAddons() => Container(
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: IonForm.cardShadow,
        ),
        child: const Row(
          children: [
            Icon(Icons.shopping_bag_outlined,
                color: IonColors.inkMuted, size: 22),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'No add-ons yet. Sell the first one above.',
                style: TextStyle(fontSize: 13, color: IonColors.inkMuted),
              ),
            ),
          ],
        ),
      );
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.customer});
  final CustomerSummary customer;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
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
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.person_rounded,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.fullName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      customer.phone,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            customer.address,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (customer.productName != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                customer.productName!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
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
                      style: const TextStyle(
                        fontSize: 12,
                        color: IonColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 20, color: IonColors.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddonRow extends StatelessWidget {
  const _AddonRow({required this.addon});
  final CustomerAddon addon;
  @override
  Widget build(BuildContext context) {
    final c = _color(addon.status);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: IonForm.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: IonColors.ion100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.shopping_bag_rounded,
                color: IonColors.ion600, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  addon.addonName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: IonColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${addon.quantity}× · ${(addon.monthlyFee).toStringAsFixed(0)} IDR/mo',
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
              color: c.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              IonHumanize.status(addon.status).toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                color: c,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _color(String s) {
    switch (s) {
      case 'active':
        return const Color(0xFF15803D);
      case 'pending_install':
        return const Color(0xFFB45309);
      case 'suspended':
        return const Color(0xFF7E22CE);
      case 'cancelled':
        return IonColors.inkMuted;
      default:
        return IonColors.inkMuted;
    }
  }
}
