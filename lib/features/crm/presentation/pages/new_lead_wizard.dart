import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ion_sales_app/shared.dart';

import '../../data/crm_api.dart';
import '../../domain/lead_repository.dart';
import '../widgets/coverage_map.dart';

/// Three-step lead-create wizard:
///   1. Address + GPS → coverage check; can't continue on out-of-coverage.
///   2. KTP capture → OCR auto-fill (Mode A) with manual override (Mode B).
///   3. Product + review → submit.
///
/// Each step lives in its own widget so the wizard stays scannable;
/// shared state hangs off the [_NewLeadWizardState].
///
/// Wave 19 visual refresh — replaces Material `Stepper` + raw
/// `TextField` / `OutlinedButton` / `FilledButton` with the
/// ION-brand design system (custom step rail, `IonField`,
/// `IonSelect`, `IonPrimaryButton`, `IonSecondaryButton`,
/// `IonSection`, `IonErrorBanner`). No data-flow changes — every
/// controller, validator, API call, navigation, and state value
/// is preserved.
class NewLeadWizard extends StatefulWidget {
  const NewLeadWizard({super.key});

  @override
  State<NewLeadWizard> createState() => _NewLeadWizardState();
}

class _NewLeadWizardState extends State<NewLeadWizard> {
  int _step = 0;
  bool _busy = false;
  String? _error;

  // Step 1 — address + GPS
  final _address = TextEditingController();
  double? _gpsLat;
  double? _gpsLng;
  Map<String, dynamic>? _coverage;

  // Step 2 — KTP
  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _nik = TextEditingController();
  XFile? _ktpPhoto;
  bool _ktpParsed = false;

  // Step 3 — product
  List<Product> _products = const [];
  String? _productId;
  bool _acceptExcess = false;
  final _notes = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _address.dispose();
    _fullName.dispose();
    _phone.dispose();
    _email.dispose();
    _nik.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    try {
      final list = await getIt<LeadRepository>().listProducts();
      if (mounted) setState(() => _products = list);
    } catch (e) {
      // Wave 30 — humanize.
      if (mounted) setState(() => _error = IonError.humanize(e));
    }
  }

  Future<void> _captureGps() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final fix = await getIt<GpsService>().currentPosition();
      setState(() {
        _gpsLat = fix.lat;
        _gpsLng = fix.lng;
      });
      await _runCoverage();
    } on GpsError catch (e) {
      setState(() => _error = 'GPS unavailable: ${e.kind.name}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runCoverage() async {
    if (_gpsLat == null || _gpsLng == null) return;
    try {
      final res = await getIt<LeadRepository>()
          .coverageCheck(lat: _gpsLat!, lng: _gpsLng!);
      setState(() => _coverage = res);
    } catch (e) {
      // Wave 30 — humanize.
      setState(() => _error = IonError.humanize(e));
    }
  }

  Future<void> _captureKtp() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 2048,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() {
      _ktpPhoto = picked;
      _busy = true;
      _error = null;
    });
    try {
      final bytes = await File(picked.path).readAsBytes();
      final parsed = await getIt<UploadsGateway>().parseKtpImage(
        bytes: bytes,
        contentType: 'image/jpeg',
      );
      setState(() {
        _ktpParsed = true;
        if (_fullName.text.isEmpty) _fullName.text = parsed.fullName;
        if (_nik.text.isEmpty) _nik.text = parsed.nik;
        // KTP doesn't carry phone/email — those stay manual.
      });
    } catch (e) {
      // Wave 30 — humanize.
      setState(() => _error = IonError.humanize(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final created = await getIt<LeadRepository>().create(
        fullName: _fullName.text.trim(),
        phone: _phone.text.trim(),
        email: _email.text.trim().isEmpty ? null : _email.text.trim(),
        nik: _nik.text.trim().isEmpty ? null : _nik.text.trim(),
        address: _address.text.trim(),
        gpsLat: _gpsLat,
        gpsLng: _gpsLng,
        productId: _productId,
        acceptExcessCable: _acceptExcess,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lead ${created.leadNumber} created')),
      );
      GoRouter.of(context).go('/leads/${created.id}');
    } catch (e) {
      // Wave 30 — humanize.
      setState(() => _error = IonError.humanize(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool get _canNext {
    switch (_step) {
      case 0:
        return _address.text.trim().isNotEmpty &&
            _gpsLat != null &&
            (_coverage?['verdict'] != 'no_coverage');
      case 1:
        return _fullName.text.trim().isNotEmpty &&
            _phone.text.trim().length >= 8;
      case 2:
        return _productId != null;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IonForm.pageBg,
      appBar: const IonAppBar(title: 'New lead'),
      body: Column(
        children: [
          // Custom ION step rail — replaces Material Stepper. Three pills
          // labelled Coverage / KTP / Product, with a leading numbered
          // chip that shows a checkmark once the step is past.
          _IonStepRail(
            currentIndex: _step,
            labels: const ['Coverage', 'KTP', 'Product'],
            onTap: (i) => setState(() => _step = i),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(0, 6, 0, 12),
              child: _buildStepBody(),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: IonErrorBanner(message: _error!),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              4,
              20,
              16 + MediaQuery.of(context).padding.bottom,
            ),
            child: Row(
              children: [
                if (_step > 0)
                  Expanded(
                    child: IonSecondaryButton(
                      label: 'Back',
                      icon: Icons.arrow_back_rounded,
                      onPressed:
                          _busy ? null : () => setState(() => _step -= 1),
                    ),
                  ),
                if (_step > 0) const SizedBox(width: 10),
                Expanded(
                  child: IonPrimaryButton(
                    label: _step == 2
                        ? (_busy ? 'Submitting…' : 'Submit lead')
                        : 'Next',
                    icon: _step == 2
                        ? Icons.check_rounded
                        : Icons.arrow_forward_rounded,
                    loading: _busy && _step == 2,
                    onPressed: _busy || !_canNext
                        ? null
                        : (_step == 2
                            ? _submit
                            : () => setState(() => _step += 1)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepBody() {
    switch (_step) {
      case 0:
        return _Step1(
          addressCtrl: _address,
          gpsLat: _gpsLat,
          gpsLng: _gpsLng,
          coverage: _coverage,
          busy: _busy,
          onCaptureGps: _captureGps,
        );
      case 1:
        return _Step2(
          photoPath: _ktpPhoto?.path,
          parsed: _ktpParsed,
          fullName: _fullName,
          phone: _phone,
          email: _email,
          nik: _nik,
          busy: _busy,
          onCapture: _captureKtp,
        );
      case 2:
        return _Step3(
          products: _products,
          productId: _productId,
          onProductChanged: (id) => setState(() => _productId = id),
          acceptExcess: _acceptExcess,
          onAcceptExcessChanged: (v) => setState(() => _acceptExcess = v),
          notes: _notes,
          coverage: _coverage,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

/// Three-pill horizontal step indicator — ION brand. Numbered circle
/// pre-fills with ion-blue once the step is active or past; pre-step
/// pills are quiet gray. Tappable so the user can jump back to a
/// completed step (matching the legacy Stepper's onStepTapped).
class _IonStepRail extends StatelessWidget {
  const _IonStepRail({
    required this.currentIndex,
    required this.labels,
    required this.onTap,
  });
  final int currentIndex;
  final List<String> labels;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      color: IonForm.pageBg,
      child: Row(
        children: [
          for (int i = 0; i < labels.length; i++) ...[
            Expanded(
              child: _StepPill(
                index: i,
                label: labels[i],
                active: i == currentIndex,
                done: i < currentIndex,
                onTap: () {
                  // Only allow tapping current or earlier steps so the
                  // user can't skip ahead past validation gates.
                  if (i <= currentIndex) onTap(i);
                },
              ),
            ),
            if (i < labels.length - 1)
              Container(
                width: 10,
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: i < currentIndex
                      ? IonColors.ion500
                      : IonColors.separator,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _StepPill extends StatelessWidget {
  const _StepPill({
    required this.index,
    required this.label,
    required this.active,
    required this.done,
    required this.onTap,
  });
  final int index;
  final String label;
  final bool active;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = active
        ? IonColors.ion50
        : (done ? Colors.white : IonForm.fieldFill);
    final border = active ? IonColors.ion500 : IonColors.separator;
    final tileFg = active || done ? Colors.white : IonColors.inkMuted;
    final tileBg = active
        ? IonColors.ion500
        : (done ? IonColors.ion600 : IonColors.separator);
    final labelColor = active
        ? IonColors.ion700
        : (done ? IonColors.ink : IonColors.inkMuted);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border, width: active ? 1.5 : 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: tileBg,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: done
                      ? Icon(Icons.check_rounded, size: 14, color: tileFg)
                      : Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: tileFg,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: labelColor,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step1 extends StatelessWidget {
  const _Step1({
    required this.addressCtrl,
    required this.gpsLat,
    required this.gpsLng,
    required this.coverage,
    required this.busy,
    required this.onCaptureGps,
  });
  final TextEditingController addressCtrl;
  final double? gpsLat;
  final double? gpsLng;
  final Map<String, dynamic>? coverage;
  final bool busy;
  final VoidCallback onCaptureGps;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IonSection(
          title: 'Address',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IonField(
                label: 'Street + landmark',
                hint: 'Jl. Sudirman No. 12, near the post office',
                controller: addressCtrl,
                maxLines: 2,
                minLines: 2,
              ),
              const SizedBox(height: 14),
              IonSecondaryButton(
                label: gpsLat == null
                    ? 'Capture GPS pin'
                    : '${gpsLat!.toStringAsFixed(5)}, ${gpsLng!.toStringAsFixed(5)}',
                icon: Icons.gps_fixed_rounded,
                onPressed: busy ? null : onCaptureGps,
              ),
            ],
          ),
        ),
        IonSection(
          title: 'Coverage',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CoverageMap(gpsLat: gpsLat, gpsLng: gpsLng, coverage: coverage),
              if (coverage != null) ...[
                const SizedBox(height: 14),
                _CoverageBanner(coverage: coverage!),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _CoverageBanner extends StatelessWidget {
  const _CoverageBanner({required this.coverage});
  final Map<String, dynamic> coverage;
  @override
  Widget build(BuildContext context) {
    final verdict = coverage['verdict'] as String? ?? 'unknown';
    final cable = coverage['cable_distance_m'] as num?;
    // ION-brand verdict palette — soft tints matching the design
    // language used by the rest of the wizard (no shade.X grays).
    final (Color bg, Color fg, IconData glyph) = switch (verdict) {
      'covered' => (
          const Color(0xFFE6F4EA),
          const Color(0xFF15803D),
          Icons.check_circle_rounded,
        ),
      'covered_with_excess' => (
          const Color(0xFFFFFBEB),
          const Color(0xFFB45309),
          Icons.warning_amber_rounded,
        ),
      'no_coverage' => (
          const Color(0xFFFFE5E3),
          IonColors.danger,
          Icons.cancel_rounded,
        ),
      _ => (IonForm.fieldFill, IonColors.inkMuted, Icons.help_outline_rounded),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(glyph, size: 19, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  verdict,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: fg,
                    letterSpacing: -0.1,
                  ),
                ),
                if (cable != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Cable distance: ${cable.toStringAsFixed(0)} m',
                      style: TextStyle(
                        color: fg,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Step2 extends StatelessWidget {
  const _Step2({
    required this.photoPath,
    required this.parsed,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.nik,
    required this.busy,
    required this.onCapture,
  });
  final String? photoPath;
  final bool parsed;
  final TextEditingController fullName;
  final TextEditingController phone;
  final TextEditingController email;
  final TextEditingController nik;
  final bool busy;
  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IonSection(
          title: 'KTP photo',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (photoPath != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: IonForm.fieldFill,
                      border: Border.all(color: IonColors.separator),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Image.file(File(photoPath!), fit: BoxFit.cover),
                  ),
                ),
              if (photoPath != null) const SizedBox(height: 12),
              IonSecondaryButton(
                label: photoPath == null ? 'Capture KTP' : 'Retake',
                icon: Icons.camera_alt_rounded,
                onPressed: busy ? null : onCapture,
              ),
              if (parsed) ...[
                const SizedBox(height: 10),
                const Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded,
                        size: 14, color: IonColors.ion600),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Auto-filled from KTP — review before submitting.',
                        style: TextStyle(
                          color: IonColors.inkMuted,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        IonSection(
          title: 'Customer details',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IonField(
                label: 'Full name',
                hint: 'As printed on the KTP',
                controller: fullName,
              ),
              const SizedBox(height: 14),
              IonField(
                label: 'Phone',
                hint: '08xx-xxxx-xxxx',
                controller: phone,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 14),
              IonField(
                label: 'Email (optional)',
                hint: 'name@example.com',
                controller: email,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 14),
              IonField(
                label: 'NIK (KTP)',
                hint: '16-digit identity number',
                controller: nik,
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _Step3 extends StatelessWidget {
  const _Step3({
    required this.products,
    required this.productId,
    required this.onProductChanged,
    required this.acceptExcess,
    required this.onAcceptExcessChanged,
    required this.notes,
    required this.coverage,
  });
  final List<Product> products;
  final String? productId;
  final ValueChanged<String?> onProductChanged;
  final bool acceptExcess;
  final ValueChanged<bool> onAcceptExcessChanged;
  final TextEditingController notes;
  final Map<String, dynamic>? coverage;

  @override
  Widget build(BuildContext context) {
    final excess = coverage?['verdict'] == 'covered_with_excess';
    // Build the IonSelect items lazily so an empty product list (still
    // loading) doesn't blow up. We render a single disabled placeholder
    // row in that case.
    final items = products.isEmpty
        ? <IonSelectItem<String?>>[
            const IonSelectItem<String?>(null, 'Loading products…'),
          ]
        : <IonSelectItem<String?>>[
            const IonSelectItem<String?>(null, 'Select a product'),
            for (final p in products)
              IonSelectItem<String?>(
                p.id,
                '${p.name} · Rp ${p.monthlyPrice.toStringAsFixed(0)} / mo',
              ),
          ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IonSection(
          title: 'Product',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IonSelect<String?>(
                label: 'Plan',
                value: productId,
                items: items,
                onChanged: (v) => onProductChanged(v),
              ),
              if (excess) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.straighten_rounded,
                              size: 18, color: Color(0xFFB45309)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Address is ${_distM(coverage)} m from nearest node',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF92400E),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Beyond the standard coverage radius. The customer must '
                        'agree to a one-time cable cost of '
                        'Rp ${_excessCharge(coverage)} before this lead can be converted.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF92400E),
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: const Text(
                          'Customer accepts the excess-cable charge',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF92400E),
                          ),
                        ),
                        value: acceptExcess,
                        onChanged: onAcceptExcessChanged,
                        activeThumbColor: const Color(0xFFB45309),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        IonSection(
          title: 'Notes',
          child: IonField(
            label: 'Free-form notes (optional)',
            hint: 'Site quirks, gate codes, scheduling constraints…',
            controller: notes,
            maxLines: 4,
            minLines: 3,
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  String _distM(Map<String, dynamic>? c) {
    final v = c?['cable_distance_m'];
    if (v is num) return v.toStringAsFixed(0);
    return '—';
  }

  String _excessCharge(Map<String, dynamic>? c) {
    final v = c?['excess_charge'];
    if (v is num) return v.toStringAsFixed(0);
    return '—';
  }
}
