import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:ion_sales_app/shared.dart';
import 'package:path_provider/path_provider.dart';

import 'app/sales_app.dart';
import 'core/theme/app_theme.dart';
import 'features/crm/data/crm_api.dart';
import 'features/crm/domain/lead_repository.dart';

/// Entry point for the ION Sales App.
///
/// 1. Hydrates BLoC storage so the auth session survives restarts.
/// 2. Wires the shared DI (HTTP client, token storage, auth bloc).
/// 3. Registers sales-app-specific feature singletons.
/// 4. Tells the AuthBloc to attempt a session restore before runApp so
///    the first frame already reflects the right route (no login-flash).
///
/// Wave 20 — wraps the whole thing in `runZonedGuarded` + wires
/// `FlutterError.onError` and `PlatformDispatcher.onError` so the
/// page can never blank-canvas on an uncaught exception.
Future<void> main() async {
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (details) {
      FlutterError.dumpErrorToConsole(details);
    };
    ErrorWidget.builder = (details) => _InlineErrorTile(details: details);
    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('UNCAUGHT: $error\n$stack');
      return true;
    };

    // Wave 24 — restore the user's saved Light/Dark/System choice
    // before runApp so the first frame already paints in the right
    // theme. Failure is non-fatal — falls back to ThemeMode.system.
    await loadPersistedThemeMode();

    // Hydrate BLoC storage. On web this is IndexedDB-backed (the
    // `webStorageDirectory` value is a sentinel — hydrated_bloc does
    // not actually open a filesystem path there). In headless / private
    // browsers IndexedDB sometimes fails — we wrap the call so a
    // storage error doesn't deadlock app boot. Without this, every
    // BLoC HydrationListener silently never resolves and the app
    // renders as a blank canvas. Off-device cache loss is fine; the
    // user just re-authenticates next launch.
    try {
      HydratedBloc.storage = await HydratedStorage.build(
        storageDirectory: kIsWeb
            ? HydratedStorage.webStorageDirectory
            : await getApplicationDocumentsDirectory(),
      ).timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint(
          'hydrated_bloc storage init failed ($e); falling back to in-memory');
      HydratedBloc.storage = _InMemoryStorage();
    }

    try {
      await setupCoreDi(
        // Only sales-flavoured roles can use the Sales App. super_admin
        // gets a free pass so QA + ops can still poke at it.
        roleFilter: (s) =>
            s.hasRole('super_admin') ||
            s.hasRole('sales_rep') ||
            s.hasRole('sales_manager'),
        roleFilterErrorMessage:
            'This account is not authorised to use the ION Sales App.',
      );
      _registerSalesFeatures();
      getIt<AuthBloc>().add(const AuthRestoreRequested());
    } catch (e, st) {
      debugPrint('sales setupCoreDi failed: $e\n$st');
    }

    runApp(const IonSalesApp());
  }, (error, stack) {
    debugPrint('ZONE UNCAUGHT: $error\n$stack');
  });
}

/// Sales-app-specific feature registrations sit alongside the shared core.
/// They're declared here (not in shared/) so the package boundary mirrors
/// the binary boundary — the tech app doesn't even know CrmApi exists.
void _registerSalesFeatures() {
  getIt.registerLazySingleton<CrmApi>(() => CrmApi(getIt<ApiClient>()));
  getIt.registerLazySingleton<LeadRepository>(
      () => LeadRepositoryImpl(getIt<CrmApi>()));
}

/// Fallback storage used when HydratedStorage.build fails (private
/// browsing, headless IndexedDB issues, etc.). Implements the
/// `Storage` contract with a process-local Map — state is lost on
/// reload, which is the correct semantics for "we couldn't get
/// durable storage; degrade gracefully" rather than hanging the app.
class _InMemoryStorage implements Storage {
  final _data = <String, dynamic>{};
  @override
  dynamic read(String key) => _data[key];
  @override
  Future<void> write(String key, dynamic value) async {
    _data[key] = value;
  }
  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }
  @override
  Future<void> clear() async {
    _data.clear();
  }
  @override
  Future<void> close() async {}
}

/// Inline error tile shown when a build/layout exception leaks. Keeps
/// the rest of the page interactive instead of blanking the canvas.
class _InlineErrorTile extends StatelessWidget {
  const _InlineErrorTile({required this.details});
  final FlutterErrorDetails details;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            children: [
              Icon(Icons.error_outline_rounded,
                  color: Color(0xFFB91C1C), size: 20),
              SizedBox(width: 8),
              Text(
                'Something went wrong here',
                style: TextStyle(
                  color: Color(0xFFB91C1C),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            kDebugMode
                ? details.exceptionAsString()
                : 'Please reload the page or try again in a moment.',
            style: const TextStyle(
              color: Color(0xFFB91C1C),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
