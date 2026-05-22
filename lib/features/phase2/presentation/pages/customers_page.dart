import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ion_sales_app/shared.dart';
import '../../data/phase2_api.dart';
import '../../domain/phase2_models.dart';

/// Customers list — Phase 2 entry surface. Tap a row to land on the
/// customer detail page where the sales rep can sell add-ons, request
/// a plan change, or open a relocation request.
class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  late Future<List<CustomerSummary>> _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<CustomerSummary>> _load() =>
      Phase2Api(getIt<ApiClient>()).listCustomers(q: _query);

  void _reload() {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IonForm.pageBg,
      appBar: IonAppBar(
        title: 'Customers',
        actions: [
          IonAppBarAction(icon: Icons.refresh_rounded, onTap: _reload),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
        children: [
          const FadeSlideIn(
            child: IonDisplayTitle(
              eyebrow: 'CRM · Phase 2',
              title: 'Customers',
              subtitle: 'Active subscribers with open add-on potential.',
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: IonField(
              label: 'Search',
              hint: 'Name, phone, or address',
              leading: Icons.search_rounded,
              onChanged: (v) {
                _query = v;
              },
              onSubmitted: (_) => _reload(),
            ),
          ),
          const IonChipDivider(label: 'Directory'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(children: [
          FutureBuilder<List<CustomerSummary>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const IonListSkeleton(
                  count: 5,
                  padding: EdgeInsets.fromLTRB(0, 8, 0, 16),
                );
              }
              if (snap.hasError) {
                return IonErrorBanner(
                  message:
                      'Failed: ${snap.error is ApiException ? (snap.error as ApiException).message : snap.error}',
                );
              }
              final customers = snap.data ?? const [];
              if (customers.isEmpty) {
                return const IonEmptyState(
                  icon: Icons.people_alt_outlined,
                  art: IonArtKind.leads,
                  title: 'No customers yet',
                  hint: 'Convert a lead to see them here.',
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < customers.length; i++) ...[
                    FadeSlideIn(
                      delay:
                          Duration(milliseconds: 40 * i.clamp(0, 10)),
                      child: _CustomerCard(customer: customers[i]),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              );
            },
          ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.customer});
  final CustomerSummary customer;
  @override
  Widget build(BuildContext context) {
    // Wave 26 — migrated to IonListCard with IonLeadingInitials for
    // a people-flavoured leading slot.
    return IonListCard(
      leading: IonLeadingInitials(
        initials: IonLeadingInitials.fromName(customer.fullName),
      ),
      title: customer.fullName,
      subtitle: customer.address,
      meta: customer.productName != null ? [customer.productName!] : const [],
      onTap: () => GoRouter.of(context)
          .push('/customers/${customer.id}', extra: customer),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: IonForm.cardShadow,
      ),
      child: const Column(
        children: [
          Icon(Icons.people_outline, size: 36, color: IonColors.inkMuted),
          SizedBox(height: 8),
          Text(
            'No customers yet',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: IonColors.ink,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Converted leads will land here.',
            style: TextStyle(fontSize: 12, color: IonColors.inkMuted),
          ),
        ],
      ),
    );
  }
}
