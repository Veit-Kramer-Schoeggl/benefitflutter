import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:benefitflutter/features/session/domain/gps_point.dart';
import 'package:benefitflutter/presentation/screens/activity/activity_screen.dart';
import 'package:benefitflutter/presentation/screens/wearable/widgets/heart_rate_display.dart';

import '../../helpers/app_harness.dart';

/// A fix that passes the GPS filters: accuracy ≤ 50 m, fresh (≤ 10 s old).
GpsPoint _fix(String id, double lat, double lng) => GpsPoint(
  id: id,
  sessionId: 'live-map',
  latitude: lat,
  longitude: lng,
  accuracyMeters: 5,
  timestamp: DateTime.now(),
);

void main() {
  group('Activity screen', () {
    testWidgets('idle state renders the default content', (tester) async {
      await pumpApp(tester, authenticated: true);
      await pumpUntilFound(tester, find.byType(ActivityScreen));

      expect(find.text('START Running'), findsOneWidget);
      expect(find.text('Ready to start recording'), findsOneWidget);
      expect(find.text('0.0 KM'), findsOneWidget);
      expect(find.text('New running session!'), findsOneWidget);
      expect(find.text('EARNED SO FAR'), findsOneWidget);
      expect(find.byType(HeartRateDisplayCompact), findsOneWidget);
    });

    testWidgets('lifecycle: start → pause → long-press stop → idle', (
      tester,
    ) async {
      await pumpApp(tester, authenticated: true);
      await pumpUntilFound(tester, find.text('START Running'));

      // idle → tracking (starts a real periodic timer)
      await tester.tap(find.text('START Running'));
      await pumpUntilFound(tester, find.text('Pause'));
      expect(find.text('Recording running'), findsOneWidget);

      // tracking → paused (cancels the timer)
      await tester.tap(find.text('Pause'));
      await pumpUntilFound(tester, find.text('Continue / Stop'));
      expect(find.text('Recording paused'), findsOneWidget);

      // paused → idle via long-press (stopSession); ending idle leaves no
      // pending timer.
      await tester.longPress(find.text('Continue / Stop'));
      await pumpUntilFound(tester, find.text('START Running'));
      expect(find.text('Ready to start recording'), findsOneWidget);
    });

    testWidgets('connectivity indicator flips to offline', (tester) async {
      final h = await pumpApp(tester, authenticated: true);
      await pumpUntilFound(tester, find.byType(ActivityScreen));

      // Default is online.
      expect(find.byIcon(Icons.signal_cellular_alt), findsOneWidget);

      h.connectivity.setOnline(false);
      await pumpUntilFound(
        tester,
        find.byIcon(Icons.signal_cellular_connected_no_internet_0_bar),
      );
    });

    testWidgets('shows the EARNED SO FAR bar with total savings', (
      tester,
    ) async {
      final h = await pumpApp(tester, authenticated: true);
      // 50ms seam: the in-flight benefit fetch reads this before resolving.
      h.benefitRepo.mockTotalSavings = 12.5;

      await pumpUntilFound(tester, find.text('12.50 €'));
      expect(find.text('EARNED SO FAR'), findsOneWidget);
    });

    testWidgets('live map: idle builds both maps without a route', (
      tester,
    ) async {
      await pumpApp(tester, authenticated: true);
      await pumpUntilFound(tester, find.text('START Running'));

      // Background + preview card; no route and no fix yet (no GPS in tests).
      expect(find.byType(FlutterMap), findsNWidgets(2));
      expect(find.byType(PolylineLayer), findsNothing);
      // OSM tile policy: attribution always visible (once, on the preview).
      expect(find.text('OpenStreetMap contributors'), findsOneWidget);
      expect(
        find.text('GAIN MORE INDEPENDENT YEARS\nWITH BENEFIT!'),
        findsOneWidget,
      );
      // No position known yet: both cameras sit on the fallback centre, at
      // the background (15) and preview (16) zooms.
      final cameras = tester
          .widgetList<FlutterMap>(find.byType(FlutterMap))
          .map((m) => m.mapController!.camera);
      expect(
        cameras.map((c) => c.center),
        everyElement(const LatLng(47.0697, 15.4086)),
      );
      expect(cameras.map((c) => c.zoom), unorderedEquals([15.0, 16.0]));
      expect(tester.takeException(), isNull);
    });

    testWidgets('live map: GPS fixes after START draw the route', (
      tester,
    ) async {
      final h = await pumpApp(
        tester,
        authenticated: true,
        initializeSensors: true,
      );
      await pumpUntilFound(tester, find.text('START Running'));

      await tester.tap(find.text('START Running'));
      await pumpUntilFound(tester, find.text('Pause'));

      // ~110 m apart, so the second fix clears the 10 m store threshold.
      h.gpsSensor.emitMockPoint(_fix('p1', 47.0697, 15.4086));
      await tester.pump();
      h.gpsSensor.emitMockPoint(_fix('p2', 47.0707, 15.4086));
      await pumpUntilFound(tester, find.byType(PolylineLayer));

      // Route + position dot on both maps (background + preview).
      expect(find.byType(FlutterMap), findsNWidgets(2));
      expect(find.byType(PolylineLayer), findsNWidgets(2));
      expect(find.byType(MarkerLayer), findsNWidgets(2));
      // Both cameras follow the newest fix (moved only after onMapReady).
      expect(
        tester
            .widgetList<FlutterMap>(find.byType(FlutterMap))
            .map((m) => m.mapController!.camera.center),
        everyElement(const LatLng(47.0707, 15.4086)),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
