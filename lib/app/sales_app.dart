import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ion_sales_app/shared.dart';

import '../core/theme/app_theme.dart';
import 'router.dart';

/// The Sales App root. Provides the shared AuthBloc to the widget tree
/// and mounts the GoRouter built in [SalesRouter].
class IonSalesApp extends StatefulWidget {
  const IonSalesApp({super.key});

  @override
  State<IonSalesApp> createState() => _IonSalesAppState();
}

class _IonSalesAppState extends State<IonSalesApp> {
  late final SalesRouter _router;

  @override
  void initState() {
    super.initState();
    _router = SalesRouter(getIt<AuthBloc>());
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthBloc>.value(
      value: getIt<AuthBloc>(),
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: themeMode,
        builder: (context, mode, _) => MaterialApp.router(
          title: 'ION Sales',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: mode,
          routerConfig: _router.router,
          builder: (context, child) =>
              IonOfflineBanner.wrap(child ?? const SizedBox.shrink()),
        ),
      ),
    );
  }
}
