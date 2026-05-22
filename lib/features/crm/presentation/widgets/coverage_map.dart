// CoverageMap — a tiny `flutter_map` preview for the new-lead wizard's
// coverage step.
//
// We use `flutter_map` (OpenStreetMap tiles, no API key) rather than
// `google_maps_flutter` to keep the binary free of platform-channel
// surprises and avoid the Google Maps billing account dependency.
// Google Maps remains the option of record for the field side because
// the Tech App's navigation flow already deep-links to it; for the
// Sales App's read-only "show me the pin and the nearest ODP"
// surface, OSM is the right tradeoff.
//
// The widget renders three things when data is available:
//   - the customer pin (the GPS we captured)
//   - up to three nearest-ODP candidates from the coverage response
//     (each surfaced as a small dot with a label)
//   - a circle at each candidate showing its coverage radius
//
// When `gpsLat`/`gpsLng` are null we render a placeholder so the
// step's layout doesn't jump when the rep captures GPS.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:ion_sales_app/shared.dart';
import 'package:latlong2/latlong.dart';

class CoverageMap extends StatelessWidget {
  const CoverageMap({
    super.key,
    required this.gpsLat,
    required this.gpsLng,
    required this.coverage,
  });

  final double? gpsLat;
  final double? gpsLng;
  final Map<String, dynamic>? coverage;

  @override
  Widget build(BuildContext context) {
    if (gpsLat == null || gpsLng == null) {
      return _placeholder();
    }
    final center = LatLng(gpsLat!, gpsLng!);
    final candidates = _candidates(coverage);
    return SizedBox(
      height: 180,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: FlutterMap(
          options: MapOptions(
            initialCenter: center,
            initialZoom: 16,
            // Reps can pan + pinch-zoom + double-tap to verify the pin
            // matches the building they're at. The customer marker
            // stays locked to the captured GPS — the rep doesn't
            // reposition by dragging the map. Rotation is excluded so
            // compass-north stays intact for the customer-pin /
            // nearest-ODP relationship.
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.pinchZoom |
                  InteractiveFlag.drag |
                  InteractiveFlag.doubleTapZoom |
                  InteractiveFlag.scrollWheelZoom,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'id.ion.sales',
            ),
            if (candidates.isNotEmpty)
              CircleLayer(
                circles: [
                  for (final c in candidates)
                    CircleMarker(
                      point: LatLng(c.lat, c.lng),
                      radius: c.coverageRadiusM ?? 60,
                      useRadiusInMeter: true,
                      color: const Color(0x331E90FF), // ion 500 @ 20%
                      borderColor: IonColors.ion500,
                      borderStrokeWidth: 1,
                    ),
                ],
              ),
            MarkerLayer(
              markers: [
                Marker(
                  point: center,
                  width: 36,
                  height: 36,
                  child: const Icon(Icons.location_on,
                      color: Color(0xFFDC2626), size: 36),
                ),
                for (final c in candidates)
                  Marker(
                    point: LatLng(c.lat, c.lng),
                    width: 24,
                    height: 24,
                    child: const Icon(Icons.router,
                        color: IonColors.ion500, size: 20),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: IonColors.ion50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: IonColors.ion200),
      ),
      alignment: Alignment.center,
      child: const Text(
        'Capture GPS to preview the address pin',
        style: TextStyle(color: IonColors.inkMuted, fontSize: 12),
      ),
    );
  }

  static List<_Candidate> _candidates(Map<String, dynamic>? coverage) {
    if (coverage == null) return const [];
    final raw = coverage['candidates'] as List<dynamic>? ?? const [];
    final out = <_Candidate>[];
    for (final item in raw) {
      if (item is! Map<String, dynamic>) continue;
      final lat = (item['lat'] as num?)?.toDouble();
      final lng = (item['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      out.add(_Candidate(
        lat: lat,
        lng: lng,
        coverageRadiusM: (item['coverage_radius_m'] as num?)?.toDouble(),
      ));
    }
    return out;
  }
}

class _Candidate {
  const _Candidate({
    required this.lat,
    required this.lng,
    this.coverageRadiusM,
  });
  final double lat;
  final double lng;
  final double? coverageRadiusM;
}
