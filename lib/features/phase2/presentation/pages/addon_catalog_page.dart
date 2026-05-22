import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ion_sales_app/shared.dart';
import '../../data/phase2_api.dart';
import '../../domain/phase2_models.dart';

/// AddonCatalogPage — pick an add-on from the catalog and confirm
/// the sale to a given customer. Each row shows fees + install
/// requirement; tapping commits the sale.
class AddonCatalogPage extends StatefulWidget {
  const AddonCatalogPage({super.key, required this.customerId});
  final String customerId;

  @override
  State<AddonCatalogPage> createState() => _AddonCatalogPageState();
}

class _AddonCatalogPageState extends State<AddonCatalogPage> {
  late Future<List<Addon>> _future;
  String? _busyId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _future = Phase2Api(getIt<ApiClient>()).listAddons();
  }

  Future<void> _sell(Addon a) async {
    setState(() {
      _busyId = a.id;
      _error = null;
    });
    try {
      await Phase2Api(getIt<ApiClient>())
          .sellAddon(customerId: widget.customerId, addonId: a.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sold: ${a.name}')),
      );
      GoRouter.of(context).pop(true);
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
      appBar: const IonAppBar(title: 'Sell add-on'),
      body: FutureBuilder<List<Addon>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const IonListSkeleton(count: 5);
          }
          if (snap.hasError) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: IonErrorBanner(message: 'Failed: ${snap.error}'),
            );
          }
          final items = snap.data ?? const [];
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              const FadeSlideIn(
                child: IonDisplayTitle(
                  padding: EdgeInsets.zero,
                  eyebrow: 'Customer · Phase 2',
                  title: 'Sell add-on',
                  subtitle: 'Pitch an upgrade — every sale earns commission.',
                ),
              ),
              const SizedBox(height: 14),
              if (_error != null) ...[
                IonErrorBanner(message: _error!),
                const SizedBox(height: 12),
              ],
              for (var i = 0; i < items.length; i++) ...[
                FadeSlideIn(
                  delay: Duration(milliseconds: 40 * i.clamp(0, 10)),
                  child: _AddonCard(
                    addon: items[i],
                    busy: _busyId == items[i].id,
                    onSell: () => _sell(items[i]),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _AddonCard extends StatelessWidget {
  const _AddonCard({
    required this.addon,
    required this.busy,
    required this.onSell,
  });
  final Addon addon;
  final bool busy;
  final VoidCallback onSell;

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
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: IonColors.ion100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _iconFor(addon.addonType),
                  color: IonColors.ion600,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      addon.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: IonColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      addon.code,
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: IonColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (addon.requiresInstall)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'INSTALL',
                    style: TextStyle(
                      fontSize: 10,
                      color: Color(0xFFB45309),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
            ],
          ),
          if (addon.description != null) ...[
            const SizedBox(height: 10),
            Text(
              addon.description!,
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
              _Pricepiece(
                label: 'One-time',
                amount: addon.oneTimeFee,
              ),
              const SizedBox(width: 16),
              _Pricepiece(
                label: 'Monthly',
                amount: addon.monthlyFee,
              ),
              const Spacer(),
              IonPrimaryButton(
                label: busy ? 'Selling…' : 'Sell',
                icon: Icons.check_rounded,
                loading: busy,
                onPressed: onSell,
                compact: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String t) {
    switch (t) {
      case 'speed_boost':
        return Icons.rocket_launch_outlined;
      case 'iptv':
        return Icons.live_tv_outlined;
      case 'cctv':
        return Icons.videocam_outlined;
      case 'static_ip':
        return Icons.dns_outlined;
      case 'wifi_extender':
        return Icons.wifi_outlined;
      default:
        return Icons.add_box_outlined;
    }
  }
}

class _Pricepiece extends StatelessWidget {
  const _Pricepiece({required this.label, required this.amount});
  final String label;
  final double amount;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: IonColors.inkMuted,
            letterSpacing: 0.5,
          ),
        ),
        Text(
          amount == 0 ? '—' : amount.toStringAsFixed(0),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: IonColors.ink,
          ),
        ),
      ],
    );
  }
}
