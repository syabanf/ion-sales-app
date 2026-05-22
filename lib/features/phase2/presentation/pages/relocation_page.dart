import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ion_sales_app/shared.dart';
import '../../data/phase2_api.dart';

class RelocationPage extends StatefulWidget {
  const RelocationPage({super.key, required this.customerId});
  final String customerId;

  @override
  State<RelocationPage> createState() => _RelocationPageState();
}

class _RelocationPageState extends State<RelocationPage> {
  final _address = TextEditingController();
  final _notes = TextEditingController();
  GpsFix? _fix;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _address.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _captureGps() async {
    try {
      final fix = await getIt<GpsService>().currentPosition();
      setState(() => _fix = fix);
    } on GpsError catch (e) {
      setState(() => _error = 'GPS unavailable: ${e.kind.name}');
    }
  }

  Future<void> _submit() async {
    if (_address.text.trim().isEmpty) {
      setState(() => _error = 'Enter the new address.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Phase2Api(getIt<ApiClient>()).requestRelocation(
        customerId: widget.customerId,
        toAddress: _address.text.trim(),
        toGpsLat: _fix?.lat,
        toGpsLng: _fix?.lng,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Relocation request submitted')),
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
      appBar: const IonAppBar(title: 'Relocation'),
      body: ListView(
        padding: EdgeInsets.only(
          top: 4,
          bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        children: [
          const FadeSlideIn(
            child: IonDisplayTitle(
              eyebrow: 'Customer · Phase 2',
              title: 'Relocation',
              subtitle: 'Submit a move-address request for survey + approval.',
            ),
          ),
          const SizedBox(height: 12),
          IonSection(
            title: 'New address',
            child: Column(
              children: [
                IonField(
                  label: 'Where to?',
                  hint: 'Full street + city',
                  controller: _address,
                  maxLines: 3,
                  minLines: 2,
                  leading: Icons.place_outlined,
                ),
                const SizedBox(height: 10),
                IonInfoRow(
                  icon: Icons.gps_fixed_rounded,
                  label: 'GPS pin',
                  value: _fix == null
                      ? 'Not captured'
                      : '${_fix!.lat.toStringAsFixed(5)}, ${_fix!.lng.toStringAsFixed(5)}',
                ),
                const SizedBox(height: 6),
                IonSecondaryButton(
                  label: _fix == null ? 'Capture GPS' : 'Re-capture GPS',
                  icon: Icons.my_location_rounded,
                  onPressed: _busy ? null : _captureGps,
                ),
              ],
            ),
          ),
          IonSection(
            title: 'Notes',
            child: IonField(
              label: 'Anything the survey team should know?',
              controller: _notes,
              maxLines: 3,
              minLines: 2,
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
              label: _busy ? 'Submitting…' : 'Request relocation',
              icon: Icons.location_on_outlined,
              loading: _busy,
              onPressed: _submit,
            ),
          ),
        ],
      ),
    );
  }
}
