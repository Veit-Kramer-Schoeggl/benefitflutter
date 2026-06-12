import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
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

GpsPoint _validPoint(String id, double lat, double lng) => GpsPoint(
  id: id,
  sessionId: 's1',
  latitude: lat,
  longitude: lng,
  accuracyMeters: 5, // ≤ 50m
  timestamp: DateTime.now(), // < 10s old → passes meetsQualityRequirements()
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
          _validPoint('p1', 48.20, 16.30),
          _validPoint('p2', 48.21, 16.31),
        ]);
      await pumpDetail(tester, repo: repo, dao: dao);

      await pumpUntilFound(tester, find.byType(FlutterMap));
      expect(find.byType(PolylineLayer), findsOneWidget);
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
