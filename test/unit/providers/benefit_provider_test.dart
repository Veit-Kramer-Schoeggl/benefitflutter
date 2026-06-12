import 'package:flutter_test/flutter_test.dart';
import 'package:benefitflutter/providers/benefit_provider.dart';
import '../../helpers/mock_data.dart';
import '../../helpers/benefit_fakes.dart';

void main() {
  group('BenefitProvider', () {
    late BenefitProvider provider;
    late MockBenefitRepositoryForTest mockRepository;
    const testUserId = 'test-user-123';

    setUp(() async {
      // Reset mock repository before each test
      mockRepository = MockBenefitRepositoryForTest();
      provider = BenefitProvider(mockRepository);
      // Set the user (the ProxyProvider hook). This triggers an initial
      // (empty) fetch — wait for it to settle so each test starts clean.
      provider.updateUserId(testUserId);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });

    group('Initial State', () {
      test('should have correct initial state', () {
        expect(provider.isLoading, false);
        expect(provider.isRefreshing, false);
        expect(provider.error, null);
        expect(provider.hasError, false);
        expect(provider.totalSavings, 0.0);
        expect(provider.earnedBenefits, isEmpty);
        expect(provider.hasEarnedBenefits, false);
        expect(provider.isEmpty, true);
      });
    });

    group('fetchBenefits()', () {
      test('should load benefits successfully', () async {
        // Arrange
        mockRepository.mockBenefits = MockData.sampleBenefits();
        mockRepository.mockUserBenefits = MockData.sampleUserBenefits(
          userId: testUserId,
        );
        mockRepository.mockTotalSavings = 15.0;

        // Track state changes
        final states = <bool>[];
        provider.addListener(() {
          states.add(provider.isLoading);
        });

        // Act
        final future = provider.fetchBenefits();

        // Assert - loading state should be true immediately
        expect(provider.isLoading, true);
        expect(provider.error, null);

        // Wait for completion
        await future;

        // Assert - final state
        expect(provider.isLoading, false);
        expect(provider.error, null);
        expect(provider.hasError, false);
        expect(provider.totalSavings, 15.0);
        expect(provider.earnedBenefits.length, 2);
        expect(provider.hasEarnedBenefits, true);
        expect(provider.isEmpty, false);

        // Verify loading state changed: true -> false
        expect(states, [true, false]);
      });

      test('should handle errors gracefully', () async {
        // Arrange
        mockRepository.shouldThrowError = true;
        mockRepository.errorMessage = 'Network error';

        // Act
        await provider.fetchBenefits();

        // Assert
        expect(provider.isLoading, false);
        expect(provider.hasError, true);
        expect(provider.error, contains('Failed to load benefits'));
        expect(provider.error, contains('Network error'));
        expect(provider.earnedBenefits, isEmpty);
        expect(provider.totalSavings, 0.0);
      });

      test('should reset error state when fetching again', () async {
        // Arrange - first call fails
        mockRepository.shouldThrowError = true;
        await provider.fetchBenefits();
        expect(provider.hasError, true);

        // Act - second call succeeds
        mockRepository.shouldThrowError = false;
        mockRepository.mockBenefits = MockData.sampleBenefits();
        mockRepository.mockUserBenefits = MockData.sampleUserBenefits(
          userId: testUserId,
        );
        await provider.fetchBenefits();

        // Assert - error should be cleared
        expect(provider.hasError, false);
        expect(provider.error, null);
      });

      test('should join UserBenefit and Benefit data correctly', () async {
        // Arrange
        mockRepository.mockBenefits = [
          MockData.createBenefit(
            id: 'benefit-1',
            title: 'Test Benefit',
            discountAmount: 10.0,
          ),
        ];
        mockRepository.mockUserBenefits = [
          MockData.createUserBenefit(
            userId: testUserId,
            benefitId: 'benefit-1',
            sessionId: 'session-abc',
          ),
        ];

        // Act
        await provider.fetchBenefits();

        // Assert - check view model has correct joined data
        final viewModel = provider.earnedBenefits.first;
        expect(viewModel.title, 'Test Benefit');
        expect(viewModel.formattedAmount, '€10.00');
        expect(viewModel.sessionId, 'session-abc');
      });

      test('should handle missing benefit metadata gracefully', () async {
        // Arrange - UserBenefit references non-existent benefit
        mockRepository.mockBenefits = []; // Empty benefits list
        mockRepository.mockUserBenefits = [
          MockData.createUserBenefit(
            userId: testUserId,
            benefitId: 'non-existent',
          ),
        ];

        // Act
        await provider.fetchBenefits();

        // Assert - should create fallback benefit
        final viewModel = provider.earnedBenefits.first;
        expect(viewModel.title, 'Unknown Benefit');
        expect(viewModel.description, 'Benefit details not found');
        expect(viewModel.formattedAmount, '€0.00');
      });
    });

    group('refresh()', () {
      test('should refresh benefits successfully', () async {
        // Arrange - initial state
        mockRepository.mockBenefits = MockData.sampleBenefits();
        mockRepository.mockUserBenefits = MockData.sampleUserBenefits(
          userId: testUserId,
        );
        await provider.fetchBenefits();

        // Act - refresh
        final future = provider.refresh();

        // Assert - refreshing state should be true
        expect(provider.isRefreshing, true);
        expect(provider.isLoading, false); // Should not show loading spinner

        await future;

        // Assert - final state
        expect(provider.isRefreshing, false);
        expect(provider.hasError, false);
      });

      test('should keep existing data on refresh error', () async {
        // Arrange - successful initial fetch
        mockRepository.mockBenefits = MockData.sampleBenefits();
        mockRepository.mockUserBenefits = MockData.sampleUserBenefits(
          userId: testUserId,
        );
        mockRepository.mockTotalSavings = 15.0;
        await provider.fetchBenefits();

        final initialBenefitsCount = provider.earnedBenefits.length;
        final initialSavings = provider.totalSavings;

        // Act - refresh fails
        mockRepository.shouldThrowError = true;
        await provider.refresh();

        // Assert - data should remain unchanged
        expect(provider.isRefreshing, false);
        expect(provider.hasError, true);
        expect(provider.earnedBenefits.length, initialBenefitsCount);
        expect(provider.totalSavings, initialSavings);
      });

      test('should clear error on successful refresh', () async {
        // Arrange - provider in error state
        mockRepository.shouldThrowError = true;
        await provider.fetchBenefits();
        expect(provider.hasError, true);

        // Act - successful refresh
        mockRepository.shouldThrowError = false;
        mockRepository.mockBenefits = MockData.sampleBenefits();
        mockRepository.mockUserBenefits = MockData.sampleUserBenefits(
          userId: testUserId,
        );
        await provider.refresh();

        // Assert - error should be cleared
        expect(provider.hasError, false);
        expect(provider.error, null);
      });
    });

    group('retry()', () {
      test('should retry fetching benefits', () async {
        // Arrange - initial failure
        mockRepository.shouldThrowError = true;
        await provider.fetchBenefits();
        expect(provider.hasError, true);

        // Act - retry with success
        mockRepository.shouldThrowError = false;
        mockRepository.mockBenefits = MockData.sampleBenefits();
        mockRepository.mockUserBenefits = MockData.sampleUserBenefits(
          userId: testUserId,
        );
        await provider.retry();

        // Assert
        expect(provider.hasError, false);
        expect(provider.earnedBenefits, isNotEmpty);
      });
    });

    group('State Getters', () {
      test('isEmpty should be true when no benefits and not loading', () {
        expect(provider.isEmpty, true);
      });

      test('isEmpty should be false when loading', () async {
        // Arrange
        mockRepository.mockBenefits = MockData.sampleBenefits();
        mockRepository.mockUserBenefits = MockData.sampleUserBenefits(
          userId: testUserId,
        );

        // Act
        final future = provider.fetchBenefits();

        // Assert - while loading
        expect(provider.isEmpty, false);

        await future;
      });

      test('isEmpty should be false when has benefits', () async {
        // Arrange
        mockRepository.mockBenefits = MockData.sampleBenefits();
        mockRepository.mockUserBenefits = MockData.sampleUserBenefits(
          userId: testUserId,
        );

        // Act
        await provider.fetchBenefits();

        // Assert
        expect(provider.isEmpty, false);
      });
    });

    group('Listener Notifications', () {
      test('should notify listeners on state changes', () async {
        // Arrange
        mockRepository.mockBenefits = MockData.sampleBenefits();
        mockRepository.mockUserBenefits = MockData.sampleUserBenefits(
          userId: testUserId,
        );

        int notificationCount = 0;
        provider.addListener(() {
          notificationCount++;
        });

        // Act
        await provider.fetchBenefits();

        // Assert - should notify at least twice (loading start, loading end)
        expect(notificationCount, greaterThanOrEqualTo(2));
      });
    });
  });
}
