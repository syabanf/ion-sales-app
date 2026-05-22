import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ion_sales_app/shared.dart';

/// EnterpriseOpportunityPage — B2B opportunity create from mobile.
///
/// Backend already exposes POST /api/enterprise/opportunities (Phase 1
/// of enterprise-svc); we only build the mobile form here. Fields
/// match `createOpportunityRequest` in the Go DTO (no field renaming).
class EnterpriseOpportunityPage extends StatefulWidget {
  const EnterpriseOpportunityPage({super.key});

  @override
  State<EnterpriseOpportunityPage> createState() =>
      _EnterpriseOpportunityPageState();
}

class _EnterpriseOpportunityPageState
    extends State<EnterpriseOpportunityPage> {
  final _accountName = TextEditingController();
  final _accountIndustry = TextEditingController();
  final _picName = TextEditingController();
  final _picTitle = TextEditingController();
  final _picPhone = TextEditingController();
  final _picEmail = TextEditingController();
  final _notes = TextEditingController();
  final _estValue = TextEditingController();
  String _accountSize = 'mid_market';
  String _source = 'sales_rep';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [
      _accountName,
      _accountIndustry,
      _picName,
      _picTitle,
      _picPhone,
      _picEmail,
      _notes,
      _estValue,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_accountName.text.trim().isEmpty || _picName.text.trim().isEmpty) {
      setState(() => _error = 'Account and PIC name are required.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final api = getIt<ApiClient>();
      final res = await api.request<Map<String, dynamic>>(
        '/api/enterprise/opportunities',
        data: {
          'account_name': _accountName.text.trim(),
          'account_industry': _accountIndustry.text.trim(),
          'account_size': _accountSize,
          'pic_name': _picName.text.trim(),
          'pic_title': _picTitle.text.trim(),
          'pic_phone': _picPhone.text.trim(),
          'pic_email': _picEmail.text.trim(),
          'estimated_value': double.tryParse(_estValue.text.trim()) ?? 0,
          'currency': 'IDR',
          'source': _source,
          'notes': _notes.text.trim(),
        },
        options: Options(method: 'POST', contentType: 'application/json'),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Opportunity created (${res.data?['id'] ?? '—'})'),
        ),
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
      appBar: const IonAppBar(title: 'New enterprise opportunity'),
      body: ListView(
        padding: EdgeInsets.only(
          top: 4,
          bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        children: [
          const FadeSlideIn(
            child: IonDisplayTitle(
              eyebrow: 'B2B · Phase 2',
              title: 'New opportunity',
              subtitle: 'Capture enterprise account + sizing for the quotation desk.',
            ),
          ),
          const SizedBox(height: 12),
          IonSection(
            title: 'Account',
            child: Column(
              children: [
                IonField(
                  label: 'Account name *',
                  hint: 'e.g. Acme Corp',
                  controller: _accountName,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                IonField(
                  label: 'Industry',
                  hint: 'Banking, Manufacturing, …',
                  controller: _accountIndustry,
                ),
                const SizedBox(height: 12),
                IonSelect<String>(
                  label: 'Account size',
                  value: _accountSize,
                  items: const [
                    IonSelectItem('smb', 'Small / SMB'),
                    IonSelectItem('mid_market', 'Mid-market'),
                    IonSelectItem('enterprise', 'Enterprise'),
                    IonSelectItem('corporate', 'Corporate / Custom'),
                  ],
                  onChanged: (v) => setState(() => _accountSize = v),
                ),
              ],
            ),
          ),
          IonSection(
            title: 'Person in charge',
            child: Column(
              children: [
                IonField(
                  label: 'Name *',
                  controller: _picName,
                  leading: Icons.person_outline_rounded,
                ),
                const SizedBox(height: 12),
                IonField(label: 'Title', controller: _picTitle),
                const SizedBox(height: 12),
                IonField(
                  label: 'Phone',
                  controller: _picPhone,
                  keyboardType: TextInputType.phone,
                  leading: Icons.phone_outlined,
                ),
                const SizedBox(height: 12),
                IonField(
                  label: 'Email',
                  controller: _picEmail,
                  keyboardType: TextInputType.emailAddress,
                  leading: Icons.mail_outline_rounded,
                ),
              ],
            ),
          ),
          IonSection(
            title: 'Value',
            child: Column(
              children: [
                IonField(
                  label: 'Estimated value (IDR)',
                  controller: _estValue,
                  keyboardType: TextInputType.number,
                  leading: Icons.attach_money_rounded,
                ),
                const SizedBox(height: 12),
                IonSelect<String>(
                  label: 'Source',
                  value: _source,
                  items: const [
                    IonSelectItem('sales_rep', 'Sales rep prospecting'),
                    IonSelectItem('inbound', 'Inbound lead'),
                    IonSelectItem('referral', 'Referral'),
                    IonSelectItem('partner', 'Partner / Channel'),
                    IonSelectItem('event', 'Event / Trade show'),
                  ],
                  onChanged: (v) => setState(() => _source = v),
                ),
              ],
            ),
          ),
          IonSection(
            title: 'Notes',
            child: IonField(
              label: 'Anything BD/finance should know?',
              controller: _notes,
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
              label: _busy ? 'Creating…' : 'Create opportunity',
              icon: Icons.add_business_rounded,
              loading: _busy,
              onPressed: _submit,
            ),
          ),
        ],
      ),
    );
  }
}
