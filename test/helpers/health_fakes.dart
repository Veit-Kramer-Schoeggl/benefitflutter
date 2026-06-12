import 'package:benefitflutter/features/session/domain/session.dart';
import 'package:benefitflutter/features/wearable_integration/data/services/health_sync_service.dart';

/// Fake [HealthSyncService] so providers are constructible on the test host
/// (the real one throws in its constructor on non-Android/iOS platforms).
/// Everything reports "unavailable / empty" — a disconnected health platform.
class FakeHealthSyncService implements HealthSyncService {
  @override
  Future<bool> isAvailable() async => false;
  @override
  Future<bool> isHealthConnectInstalled() async => false;
  @override
  Future<bool> hasPermissions() async => false;
  @override
  Future<bool> requestPermissions() async => false;
  @override
  Future<bool> syncAll(String userId, {int daysBack = 7}) async => false;
  @override
  Future<void> syncSteps(
    String userId,
    DateTime startTime,
    DateTime endTime,
  ) async {}
  @override
  Future<void> syncHeartRate(
    String userId,
    DateTime startTime,
    DateTime endTime,
  ) async {}
  @override
  Future<bool> connect() async => false;
  @override
  Future<void> syncDistance(
    String userId,
    DateTime startTime,
    DateTime endTime,
  ) async {}
  @override
  Future<void> syncCalories(
    String userId,
    DateTime startTime,
    DateTime endTime,
  ) async {}
  @override
  Future<void> syncWeight(
    String userId,
    DateTime startTime,
    DateTime endTime,
  ) async {}
  @override
  Future<void> syncRestingHeartRate(
    String userId,
    DateTime startTime,
    DateTime endTime,
  ) async {}
  @override
  Future<Session> enrichSession(Session session) async => session;
  @override
  Future<int> getDailySteps(String userId, DateTime date) async => 0;
  @override
  Future<double?> getAverageHeartRate(
    String userId,
    DateTime startTime,
    DateTime endTime,
  ) async => null;
  @override
  Future<double?> getLatestWeight(String userId) async => null;
  @override
  Future<int?> getLatestRestingHeartRate(String userId) async => null;
  @override
  Future<Map<String, dynamic>> getWeeklySummary(
    String userId,
    DateTime weekStart,
  ) async => {'steps': 0, 'distance': 0.0, 'calories': 0.0};
  @override
  Future<void> cleanupOldData(DateTime cutoffDate) async {}
  @override
  Future<void> dispose() async {}
}
