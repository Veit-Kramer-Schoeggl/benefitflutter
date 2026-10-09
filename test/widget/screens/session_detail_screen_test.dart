import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:benefitflutter/core/config/theme.dart';
import 'package:benefitflutter/core/enums/activity_type.dart';
import 'package:benefitflutter/core/enums/session_status.dart';
import 'package:benefitflutter/core/enums/tracking_mode.dart';
import 'package:benefitflutter/features/session/domain/gps_point.dart';
import 'package:benefitflutter/features/session/domain/session.dart';
import 'package:benefitflutter/presentation/screens/session/session_detail_screen.dart';

import '../../helpers/app_harness.dart'; // pumpUntilFound, harnessUserId
import '../../helpers/session_fakes.dart';

/// Canonical 1x1 transparent PNG — lets FlutterMap render without any network.
final _kTransparentPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, //
  0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, //
  0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, //
  0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, //
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, //
  0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, //
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

class _FakeTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(_kTransparentPng);
}

Session _session({DateTime? startTime}) => Session(
  id: 's1',
  userId: harnessUserId,
  trackingMode: TrackingMode.manual,
  activityType: ActivityType.running,
  status: SessionStatus.completed,
  startTime: startTime ?? DateTime(2026, 6, 12, 14, 30),
  durationSeconds: 1800,
  distanceMeters: 5000,
);

/// A stored GPS point. The screen re-checks only the accuracy (≤ 50m, null
/// kept), not the fix age, so [timestamp] may lie anywhere in the past.
GpsPoint _point(
  String id,
  double lat,
  double lng, {
  double? accuracyMeters = 5,
  DateTime? timestamp,
}) => GpsPoint(
  id: id,
  sessionId: 's1',
  latitude: lat,
  longitude: lng,
  accuracyMeters: accuracyMeters,
  timestamp: timestamp ?? DateTime.now(),
);

Future<void> pumpDetail(
  WidgetTester tester, {
  required MockSessionRepository repo,
  required FakeGpsPointDao dao,
  String sessionId = 's1',
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: SessionDetailScreen(
        sessionId: sessionId,
        repository: repo,
        gpsPointDao: dao,
        tileProvider: _FakeTileProvider(),
      ),
    ),
  );
}

void main() {
  group('SessionDetailScreen', () {
    testWidgets('summary card shows the F1 date format (no seconds)', (
      tester,
    ) async {
      final repo = MockSessionRepository()..seedSessions([_session()]);
      final dao = FakeGpsPointDao();
      await pumpDetail(tester, repo: repo, dao: dao);

      await pumpUntilFound(tester, find.text('Session Details'));

      expect(find.text('12.06.2026, 14:30'), findsOneWidget);
      // Regression guard: the old toString() would have rendered '14:30:00.000'.
      expect(find.textContaining('14:30:'), findsNothing);
      expect(find.text('5.00 km'), findsOneWidget);
      expect(find.text('00:30:00'), findsOneWidget);
    });

    testWidgets('shows "not enough GPS data" with fewer than 2 points', (
      tester,
    ) async {
      final repo = MockSessionRepository()..seedSessions([_session()]);
      final dao = FakeGpsPointDao(); // no GPS points
      await pumpDetail(tester, repo: repo, dao: dao);

      await pumpUntilFound(
        tester,
        find.text('Not enough GPS data to display route.'),
      );
    });

    testWidgets('renders the route map with >= 2 valid GPS points', (
      tester,
    ) async {
      final repo = MockSessionRepository()..seedSessions([_session()]);
      final dao = FakeGpsPointDao()
        ..seedGpsPoints('s1', [
          _point('p1', 48.20, 16.30),
          _point('p2', 48.21, 16.31),
        ]);
      await pumpDetail(tester, repo: repo, dao: dao);

      await pumpUntilFound(tester, find.byType(FlutterMap));
      expect(find.byType(PolylineLayer), findsOneWidget);
    });

    // BL-072: stored points are always older than the 10s live fix-age limit,
    // so re-running the full quality check hid the route of every session.
    testWidgets('renders the route of a past session (points from yesterday)', (
      tester,
    ) async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final repo = MockSessionRepository()
        ..seedSessions([_session(startTime: yesterday)]);
      final dao = FakeGpsPointDao()
        ..seedGpsPoints('s1', [
          _point('p1', 48.20, 16.30, timestamp: yesterday),
          _point(
            'p2',
            48.21,
            16.31,
            timestamp: yesterday.add(const Duration(minutes: 5)),
          ),
        ]);
      await pumpDetail(tester, repo: repo, dao: dao);

      await pumpUntilFound(tester, find.byType(FlutterMap));
      expect(find.byType(PolylineLayer), findsOneWidget);
      expect(find.text('Not enough GPS data to display route.'), findsNothing);
    });

    testWidgets('drops inaccurate points, keeps points without accuracy', (
      tester,
    ) async {
      final repo = MockSessionRepository()..seedSessions([_session()]);
      final dao = FakeGpsPointDao()
        ..seedGpsPoints('s1', [
          _point('p1', 48.20, 16.30, accuracyMeters: null), // unknown → kept
          _point('p2', 48.21, 16.31, accuracyMeters: 80), // > 50m → dropped
          _point('p3', 48.22, 16.32, accuracyMeters: 50), // = limit → kept
        ]);
      await pumpDetail(tester, repo: repo, dao: dao);

      await pumpUntilFound(tester, find.byType(PolylineLayer));
      final layer = tester.widget<PolylineLayer>(find.byType(PolylineLayer));
      expect(layer.polylines.single.points, const [
        LatLng(48.20, 16.30),
        LatLng(48.22, 16.32),
      ]);
    });

    testWidgets('fits the camera to the whole route, marks start and end', (
      tester,
    ) async {
      // ~2.6km north-east: the old fixed zoom 14 around the start point
      // left the end of this route off-screen.
      const start = LatLng(52.5200, 13.4050);
      const end = LatLng(52.5430, 13.4280);
      final repo = MockSessionRepository()..seedSessions([_session()]);
      final dao = FakeGpsPointDao()
        ..seedGpsPoints('s1', [
          _point('p1', start.latitude, start.longitude),
          _point('p2', 52.5310, 13.4150),
          _point('p3', end.latitude, end.longitude),
        ]);
      await pumpDetail(tester, repo: repo, dao: dao);

      await pumpUntilFound(tester, find.byType(PolylineLayer));
      await tester.pump();
      final camera = MapCamera.of(tester.element(find.byType(PolylineLayer)));
      expect(camera.visibleBounds.contains(start), isTrue);
      expect(camera.visibleBounds.contains(end), isTrue);

      final markers = tester.widget<MarkerLayer>(find.byType(MarkerLayer));
      expect(markers.markers.map((m) => m.point), [start, end]);
    });

    testWidgets('caps the zoom when all points share one position', (
      tester,
    ) async {
      final repo = MockSessionRepository()..seedSessions([_session()]);
      final dao = FakeGpsPointDao()
        ..seedGpsPoints('s1', [
          _point('p1', 48.20, 16.30),
          _point('p2', 48.20, 16.30),
        ]);
      await pumpDetail(tester, repo: repo, dao: dao);

      await pumpUntilFound(tester, find.byType(PolylineLayer));
      await tester.pump();
      final camera = MapCamera.of(tester.element(find.byType(PolylineLayer)));
      // A zero-size route would otherwise fit to an infinite zoom.
      expect(camera.zoom, 17);
    });

    testWidgets('meets the OSM tile policy (attribution + User-Agent)', (
      tester,
    ) async {
      // A system navigation-bar inset (edge-to-edge) must not lift the
      // attribution off the bottom edge of the map.
      tester.view.padding = const FakeViewPadding(bottom: 144); // 48 logical
      addTearDown(tester.view.resetPadding);
      final repo = MockSessionRepository()..seedSessions([_session()]);
      final dao = FakeGpsPointDao()
        ..seedGpsPoints('s1', [
          _point('p1', 48.20, 16.30),
          _point('p2', 48.21, 16.31),
        ]);
      await pumpDetail(tester, repo: repo, dao: dao);

      await pumpUntilFound(tester, find.byType(FlutterMap));
      expect(find.text('OpenStreetMap contributors'), findsOneWidget);
      final attributionBox = find.descendant(
        of: find.byType(SimpleAttributionWidget),
        matching: find.byType(ColoredBox),
      );
      expect(
        tester.getBottomRight(attributionBox),
        tester.getBottomRight(find.byType(FlutterMap)),
      );

      final tiles = tester.widget<TileLayer>(find.byType(TileLayer));
      expect(
        tiles.tileProvider.headers['User-Agent'],
        'flutter_map (us.benefit4.benefitflutter)',
      );
    });

    testWidgets('shows an error when the session cannot be loaded', (
      tester,
    ) async {
      // 's1' is not seeded → getSessionById throws → error state.
      final repo = MockSessionRepository();
      final dao = FakeGpsPointDao();
      await pumpDetail(tester, repo: repo, dao: dao);

      await pumpUntilFound(tester, find.textContaining('Error'));
    });
  });
}
