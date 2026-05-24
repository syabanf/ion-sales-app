import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ion_sales_app/shared.dart';
import '../../data/phase2_api.dart';
import '../../domain/phase2_models.dart';

/// Customers list — Phase 2 entry surface. Tap a row to land on the
/// customer detail page where the sales rep can sell add-ons, request
/// a plan change, or open a relocation request.
///
/// Wave 130A — body extracted into [CustomersListBody] so the Sales App's
/// "Customers" bottom-nav tab can render the real list inline instead of
/// the previous placeholder that pushed to this standalone page. The
/// standalone page is kept so the existing `/customers` deep link still
/// works (push notifications, search-sheet jumps, external URLs).
class CustomersPage extends StatelessWidget {
  const CustomersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IonForm.pageBg,
      appBar: const IonAppBar(title: 'Customers'),
      body: const CustomersListBody(),
    );
  }
}

/// CustomersListBody — the customer directory body, embeddable in any
/// scroll surface. Used by [CustomersPage] (full-screen route) and by
/// `CustomersTab` in `leads_page.dart` (bottom-nav inline).
///
/// Keeps a single search field + future-backed list. The IonDisplayTitle
/// header gates on `showHeader` so the embedded variant doesn't double up
/// with the tab's own greeting strip.
class CustomersListBody extends StatefulWidget {
  const CustomersListBody({
    super.key,
    this.showHeader = true,
    this.scrollController,
  });

  /// When true (default), shows the "CRM · Phase 2 / Customers" display
  /// title at the top. The embedded tab variant passes `false` because
  /// the tab itself owns the heading.
  final bool showHeader;

  /// Optional scroll controller — supplied by the tab shell so each tab
  /// keeps its own scroll position across switches.
  final ScrollController? scrollController;

  @override
  State<CustomersListBody> createState() => _CustomersListBodyState();
}

class _CustomersListBodyState extends State<CustomersListBody> {
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
    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
      children: [
        if (widget.showHeader) ...[
          const FadeSlideIn(
            child: IonDisplayTitle(
              eyebrow: 'CRM · Phase 2',
              title: 'Customers',
              subtitle: 'Active subscribers with open add-on potential.',
            ),
          ),
          const SizedBox(height: 18),
        ],
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
          child: FutureBuilder<List<CustomerSummary>>(
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
        ),
      ],
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
