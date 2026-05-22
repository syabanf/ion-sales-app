import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ion_sales_app/shared.dart';

import '../features/crm/presentation/pages/documents_page.dart';
import '../features/crm/presentation/pages/lead_detail_page.dart';
import '../features/crm/presentation/pages/leads_page.dart';
import '../features/crm/presentation/pages/new_lead_wizard.dart';
import '../features/phase2/domain/phase2_models.dart';
import '../features/phase2/presentation/pages/addon_catalog_page.dart';
import '../features/phase2/presentation/pages/approvals_page.dart';
import '../features/phase2/presentation/pages/commissions_page.dart';
import '../features/phase2/presentation/pages/customer_detail_page.dart';
import '../features/phase2/presentation/pages/customers_page.dart';
import '../features/phase2/presentation/pages/enterprise_opportunity_page.dart';
import '../features/phase2/presentation/pages/opportunities_page.dart';
import '../features/phase2/presentation/pages/opportunity_detail_page.dart';
import '../features/phase2/presentation/pages/po_upload_page.dart';
import '../features/phase2/presentation/pages/quotation_detail_page.dart';
import '../features/phase2/presentation/pages/plan_change_page.dart';
import '../features/phase2/presentation/pages/relocation_page.dart';
import '../features/profile/presentation/pages/profile_page.dart';

/// SalesRouter — declares the full sales-app route table. Auth +
/// redirect glue comes from [AuthGuardListenable] in the shared
/// package; transitions come from `slidePage` / `modalPage` /
/// `instantPage` (also shared) so animations match tech_app.
class SalesRouter {
  SalesRouter(AuthBloc bloc)
      : _guard = AuthGuardListenable(bloc),
        _authedHome = '/leads';

  final AuthGuardListenable _guard;
  final String _authedHome;

  late final GoRouter router = GoRouter(
    initialLocation: '/leads',
    refreshListenable: _guard,
    redirect: (context, state) {
      // Wave 20 — root fallback so a bare '/' (URL-strategy
      // stripped, manifest shortcut, etc.) never hits GoRouter's
      // "no routes for location" error page.
      if (state.matchedLocation == '/') return _authedHome;
      return _guard.redirect(
        matchedLocation: state.matchedLocation,
        authedHome: _authedHome,
      );
    },
    errorBuilder: (context, state) => _RouteFallback(uri: state.uri.toString()),
    routes: [
      GoRoute(
        path: '/login',
        pageBuilder: (_, __) => instantPage(child: const LoginPage()),
      ),
      // Root path — redirect-only.
      GoRoute(
        path: '/',
        redirect: (_, __) => '/leads',
      ),
      GoRoute(
        path: '/leads',
        pageBuilder: (_, __) => instantPage(child: const LeadsPage()),
      ),
      GoRoute(
        path: '/leads/new',
        pageBuilder: (_, __) => modalPage(child: const NewLeadWizard()),
      ),
      GoRoute(
        path: '/leads/:id',
        pageBuilder: (_, s) => slidePage(
          child: LeadDetailPage(leadId: s.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/leads/:id/documents',
        pageBuilder: (_, s) => modalPage(
          child: DocumentsPage(leadId: s.pathParameters['id']!),
        ),
      ),

      // Phase 2 — Customers + add-on / plan-change / relocation flows.
      GoRoute(
        path: '/customers',
        pageBuilder: (_, __) => slidePage(child: const CustomersPage()),
      ),
      GoRoute(
        path: '/customers/:id',
        pageBuilder: (_, s) {
          final extra = s.extra;
          // We expect a CustomerSummary in extra (passed when the user
          // tapped a row). Deep-link without one isn't supported today;
          // we redirect back to the list rather than render a stub.
          if (extra is! CustomerSummary) {
            return slidePage(child: const CustomersPage());
          }
          return slidePage(child: CustomerDetailPage(customer: extra));
        },
      ),
      GoRoute(
        path: '/customers/:id/sell-addon',
        pageBuilder: (_, s) => modalPage(
          child: AddonCatalogPage(customerId: s.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/customers/:id/plan-change',
        pageBuilder: (_, s) => modalPage(
          child: PlanChangePage(customerId: s.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/customers/:id/relocation',
        pageBuilder: (_, s) => modalPage(
          child: RelocationPage(customerId: s.pathParameters['id']!),
        ),
      ),

      // Approvals queue + enterprise opportunity (mobile-only entry).
      GoRoute(
        path: '/approvals',
        pageBuilder: (_, __) => slidePage(child: const ApprovalsPage()),
      ),
      GoRoute(
        path: '/commissions',
        pageBuilder: (_, __) => slidePage(child: const CommissionsPage()),
      ),
      GoRoute(
        path: '/opportunities',
        pageBuilder: (_, __) => slidePage(child: const OpportunitiesPage()),
      ),
      GoRoute(
        path: '/opportunities/new',
        pageBuilder: (_, __) =>
            modalPage(child: const EnterpriseOpportunityPage()),
      ),
      GoRoute(
        path: '/opportunities/:id',
        pageBuilder: (_, s) => slidePage(
          child: OpportunityDetailPage(oppId: s.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/opportunities/:id/po-upload',
        pageBuilder: (_, s) => modalPage(
          child: POUploadPage(oppId: s.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/quotations/:id',
        pageBuilder: (_, s) => slidePage(
          child: QuotationDetailPage(quotationId: s.pathParameters['id']!),
        ),
      ),

      GoRoute(
        path: '/profile',
        pageBuilder: (_, __) => slidePage(child: const ProfilePage()),
      ),
    ],
  );
}

/// Friendly fallback page when GoRouter receives a URL that doesn't
/// match any declared route.
class _RouteFallback extends StatelessWidget {
  const _RouteFallback({required this.uri});
  final String uri;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IonColors.pageBg,
      appBar: const IonAppBar(title: 'Page not found'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.travel_explore_rounded,
                  size: 48, color: IonColors.inkMuted),
              const SizedBox(height: 14),
              const Text(
                'We couldn’t find that page',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: IonColors.ink,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'No route matches "$uri". The link may be out of date.',
                style: const TextStyle(
                  fontSize: 13,
                  color: IonColors.inkMuted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              IonPrimaryButton(
                label: 'Back to leads',
                icon: Icons.home_outlined,
                onPressed: () => GoRouter.of(context).go('/leads'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
