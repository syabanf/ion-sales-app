// Widget smoke test for CoverageMap.
//
// We can't paint OSM tiles in a flutter_test environment (no network,
// no GPU surface) but we can verify the widget builds without throwing
// for all three states:
//
//   - GPS missing -> placeholder banner
//   - GPS present, coverage null -> map shell with customer pin only
//   - GPS present, coverage with candidates -> map shell + ODP pins
//
// This catches API drift between flutter_map versions (e.g. the rename
// of `center`->`initialCenter`, the InteractionOptions move) without
// requiring a device. Run with: flutter test test/coverage_map_widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ion_sales_app/features/crm/presentation/widgets/coverage_map.dart';

void main() {
  group('CoverageMap', () {
    testWidgets('renders placeholder when GPS is missing', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: CoverageMap(gpsLat: null, gpsLng: null, coverage: null),
        ),
      ));
      expect(find.textContaining('Capture GPS'), findsOneWidget);
    });

    testWidgets('builds map shell when GPS is set, no coverage', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: CoverageMap(
            gpsLat: -6.2,
            gpsLng: 106.8,
            coverage: null,
          ),
        ),
      ));
      // No exception during pump = compile + build path is healthy.
      // We don't assert on tile pixels — the OSM TileLayer will fail to
      // fetch in a unit test sandbox, which is fine.
      expect(tester.takeException(), isNull);
    });

    testWidgets('builds map with candidates', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CoverageMap(
            gpsLat: -6.2,
            gpsLng: 106.8,
            coverage: const <String, dynamic>{
              'candidates': <Map<String, dynamic>>[
                {'lat': -6.2001, 'lng': 106.8002, 'coverage_radius_m': 80},
                {'lat': -6.1998, 'lng': 106.7995, 'coverage_radius_m': 120},
              ],
            },
          ),
        ),
      ));
      expect(tester.takeException(), isNull);
    });
  });
}
