import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:ion_sales_app/shared.dart';


/// ProfilePage — full-screen account view, pushed from the navbar's
/// person icon on the home tabs.
///
/// Layout (mirrors the modern mobile pattern in the home page):
///   - Blue gradient hero with a large initials avatar, the user's
///     name, the primary role chip, and an edit button stub.
///   - Account info section (email, employee ID, phone, branch).
///   - Roles section listing every role assigned to this session.
///   - App section (open customer portal, version stub).
///   - Sign-out button at the foot, rendered in destructive red.
///
/// All data comes from the in-memory AuthBloc session; no extra API
/// calls — opening the page is instant.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.read<AuthBloc>().state.session;

    return Scaffold(
      backgroundColor: IonColors.pageBg,
      body: session == null
          ? const _SignedOutFallback()
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _ProfileHero(session: session)),
                SliverToBoxAdapter(
                  child: _Section(
                    title: 'Account',
                    children: [
                      _InfoRow(
                        icon: Icons.mail_outline_rounded,
                        label: 'Email',
                        value: session.user.email,
                      ),
                      _InfoRow(
                        icon: Icons.badge_outlined,
                        label: 'Employee ID',
                        value: session.user.employeeId,
                        valueFont: 'monospace',
                      ),
                      if (session.user.phone.isNotEmpty)
                        _InfoRow(
                          icon: Icons.phone_outlined,
                          label: 'Phone',
                          value: session.user.phone,
                        ),
                      _InfoRow(
                        icon: Icons.account_tree_outlined,
                        label: 'Branch',
                        value: session.user.branchId == null
                            ? '—'
                            : '${session.user.branchId} · ${session.user.branchLevel ?? "?"}',
                      ),
                      _InfoRow(
                        icon: Icons.toggle_on_outlined,
                        label: 'Status',
                        valueWidget: _StatusPill(active: session.user.active),
                      ),
                    ],
                  ),
                ),
                SliverToBoxAdapter(
                  child: _Section(
                    title: 'Roles',
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final r in session.roles) _RoleChip(label: r),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Wave 24 — appearance preference.
                const SliverToBoxAdapter(
                  child: _Section(
                    title: 'Appearance',
                    children: [_ThemeModePicker()],
                  ),
                ),
                SliverToBoxAdapter(
                  child: _Section(
                    title: 'App',
                    children: [
                      _TapRow(
                        icon: Icons.open_in_new_rounded,
                        label: 'Open customer portal',
                        onTap: () async {
                          final ok = await openCustomerPortal();
                          if (!ok && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text("Couldn't open the portal")),
                            );
                          }
                        },
                      ),
                      _InfoRow(
                        icon: Icons.info_outline_rounded,
                        label: 'Version',
                        value: 'ION Sales 0.1.0',
                      ),
                    ],
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                    child: _SignOutButton(
                      onPressed: () {
                        context.read<AuthBloc>().add(
                              const AuthLogoutRequested(),
                            );
                        // Router's auth guard will boot us to /login on
                        // the next refresh tick. The pop is a fallback
                        // for the case where the guard hasn't fired yet.
                        if (GoRouter.of(context).canPop()) {
                          GoRouter.of(context).pop();
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// =============================================================================
// Hero
// =============================================================================

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.session});
  final AuthSession session;
  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final initials = _initials(session.user.fullName);
    final primaryRole = _primaryRole(session.roles);

    return Container(
      padding: EdgeInsets.fromLTRB(20, topInset + 8, 20, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [IonColors.ion500, IonColors.ion600],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top bar — back + title + (placeholder) edit.
          Row(
            children: [
              _CircleIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: () {
                  if (GoRouter.of(context).canPop()) {
                    GoRouter.of(context).pop();
                  }
                },
              ),
              const Spacer(),
              const Text(
                'Profile',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              const Spacer(),
              _CircleIconButton(
                icon: Icons.edit_outlined,
                onTap: () {
                  // Editing comes from the web admin today; surface a
                  // hint rather than mock a half-working form.
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Edit your profile from the ION Core admin portal'),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Avatar — initials in a soft-tinted disc that pops on the
          // gradient. White text + ion-700 background.
          Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: IonColors.ion700,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          Center(
            child: Text(
              session.user.fullName.isEmpty
                  ? '—'
                  : session.user.fullName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _humanRole(primaryRole),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final words =
        name.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words.first[0].toUpperCase();
    return '${words.first[0]}${words[1][0]}'.toUpperCase();
  }

  String _primaryRole(List<String> roles) {
    if (roles.isEmpty) return 'no role';
    // Same logic as the web frontend: super_admin wins, else first.
    final sa = roles.firstWhere((r) => r == 'super_admin', orElse: () => '');
    if (sa.isNotEmpty) return sa;
    return roles.first;
  }

  // Wave 30 — defer to IonStringHumanize extension so role labels
  // get NOC/CS-style acronym preservation for free.
  String _humanRole(String r) => r.humanized;
}

// =============================================================================
// Sections + rows
// =============================================================================

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: IonColors.inkMuted,
                letterSpacing: 1.0,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: IonForm.cardShadow,
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    this.value,
    this.valueWidget,
    this.valueFont,
  });
  final IconData icon;
  final String label;
  final String? value;
  final Widget? valueWidget;
  final String? valueFont;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: IonColors.ion100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: IonColors.ion600, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: IonColors.inkSoft,
              ),
            ),
          ),
          if (valueWidget != null)
            valueWidget!
          else
            Text(
              value ?? '—',
              style: TextStyle(
                fontSize: 13,
                color: IonColors.ink,
                fontWeight: FontWeight.w500,
                fontFamily: valueFont,
              ),
            ),
        ],
      ),
    );
  }
}

class _TapRow extends StatelessWidget {
  const _TapRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: IonColors.ion100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: IonColors.ion600, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: IonColors.ink,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right,
                  size: 18, color: IonColors.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: IonColors.ion100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.humanized,
        style: const TextStyle(
          fontSize: 11,
          color: IonColors.ion700,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.active});
  final bool active;
  @override
  Widget build(BuildContext context) {
    final c = active ? const Color(0xFF15803D) : IonColors.inkMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        active ? 'ACTIVE' : 'INACTIVE',
        style: TextStyle(
          fontSize: 10,
          color: c,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(child: Icon(icon, color: Colors.white, size: 20)),
        ),
      ),
    );
  }
}

class _SignOutButton extends StatelessWidget {
  const _SignOutButton({required this.onPressed});
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.logout_rounded, size: 20),
        label: const Text(
          'Sign out',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFB91C1C),
          side: const BorderSide(color: Color(0xFFFECACA), width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class _SignedOutFallback extends StatelessWidget {
  const _SignedOutFallback();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Not signed in.',
          style: TextStyle(color: IonColors.inkMuted),
        ),
      ),
    );
  }
}

/// Wave 24 — segmented Light/Dark/System picker bound to the global
/// `themeMode` notifier. Flipping changes theme app-wide instantly +
/// persists via `setThemeMode`.
class _ThemeModePicker extends StatelessWidget {
  const _ThemeModePicker();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: themeMode,
        builder: (context, mode, _) => Row(
          children: [
            Expanded(
              child: _ThemeChip(
                label: 'Light',
                icon: Icons.light_mode_rounded,
                active: mode == ThemeMode.light,
                onTap: () => setThemeMode(ThemeMode.light),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ThemeChip(
                label: 'Dark',
                icon: Icons.dark_mode_rounded,
                active: mode == ThemeMode.dark,
                onTap: () => setThemeMode(ThemeMode.dark),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ThemeChip(
                label: 'System',
                icon: Icons.brightness_auto_rounded,
                active: mode == ThemeMode.system,
                onTap: () => setThemeMode(ThemeMode.system),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeChip extends StatelessWidget {
  const _ThemeChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            color: active ? IonColors.inkBlack : IonColors.chipBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: active ? Colors.white : IonColors.inkSoft,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : IonColors.inkSoft,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
