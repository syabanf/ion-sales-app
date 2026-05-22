import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ion_sales_app/shared.dart';
import '../../../crm/data/crm_api.dart';
import '../../data/phase2_api.dart';

class PlanChangePage extends StatefulWidget {
  const PlanChangePage({super.key, required this.customerId});
  final String customerId;

  @override
  State<PlanChangePage> createState() => _PlanChangePageState();
}

class _PlanChangePageState extends State<PlanChangePage> {
  String _kind = 'upgrade';
  String? _toProductId;
  final _reason = TextEditingController();
  late Future<List<Product>> _products;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _products = CrmApi(getIt<ApiClient>()).listProducts();
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_toProductId == null) {
      setState(() => _error = 'Pick a target plan first.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Phase2Api(getIt<ApiClient>()).requestPlanChange(
        customerId: widget.customerId,
        toProductId: _toProductId!,
        changeKind: _kind,
        reason: _reason.text.trim().isEmpty ? null : _reason.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan change requested')),
      );
      GoRouter.of(context).pop(true);
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
      appBar: const IonAppBar(title: 'Plan change'),
      body: ListView(
        padding: EdgeInsets.only(
          top: 4,
          bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        children: [
          const FadeSlideIn(
            child: IonDisplayTitle(
              eyebrow: 'Customer · Phase 2',
              title: 'Plan change',
              subtitle: 'Submit an upgrade or downgrade request for approval.',
            ),
          ),
          const SizedBox(height: 12),
          IonSection(
            title: 'Direction',
            child: IonSegmented<String>(
              value: _kind,
              options: const [
                IonSegmentedOption('upgrade', 'Upgrade'),
                IonSegmentedOption('downgrade', 'Downgrade'),
              ],
              onChanged: (v) => setState(() => _kind = v),
            ),
          ),
          IonSection(
            title: 'Target plan',
            child: FutureBuilder<List<Product>>(
              future: _products,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: CircularProgressIndicator(color: IonColors.ion500),
                    ),
                  );
                }
                final products = snap.data ?? const [];
                if (products.isEmpty) {
                  return const Text('No active products in catalog.');
                }
                return IonSelect<String>(
                  label: 'New plan',
                  value: _toProductId ?? products.first.id,
                  items: [
                    for (final p in products)
                      IonSelectItem(p.id, '${p.code} · ${p.name}'),
                  ],
                  onChanged: (v) => setState(() => _toProductId = v),
                );
              },
            ),
          ),
          IonSection(
            title: 'Reason',
            child: IonField(
              label: 'Why is the customer changing?',
              controller: _reason,
              maxLines: 4,
              minLines: 3,
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: IonErrorBanner(message: _error!),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: IonPrimaryButton(
              label: _busy ? 'Submitting…' : 'Request plan change',
              icon: Icons.upgrade_rounded,
              loading: _busy,
              onPressed: _submit,
            ),
          ),
        ],
      ),
    );
  }
}
