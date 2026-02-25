import 'package:flutter_test/flutter_test.dart';
import 'package:benefitflutter/features/benefit/domain/benefit_view_model.dart';
import '../../../helpers/mock_data.dart';

void main() {
  group('BenefitViewModel', () {
    group('Constructor and Basic Properties', () {
      test('should create view model with required properties', () {
        // Arrange
        final benefit = MockData.createBenefit(
          id: 'benefit-1',
          title: 'Test Benefit',
          description: 'Test Description',
          discountAmount: 10.0,
        );
        final userBenefit = MockData.createUserBenefit(
          id: 'ub-1',
          benefitId: 'benefit-1',
          sessionId: 'session-1',
        );

        // Act
        final viewModel = BenefitViewModel(
          userBenefit: userBenefit,
          benefit: benefit,
        );

        // Assert
        expect(viewModel.id, 'ub-1');
        expect(viewModel.title, 'Test Benefit');
        expect(viewModel.description, 'Test Description');
        expect(viewModel.sessionId, 'session-1');
      });
    });

    group('formattedAmount', () {
      test('should format discount amount correctly', () {
        // Arrange
        final benefit = MockData.createBenefit(discountAmount: 5.50);
        final userBenefit = MockData.createUserBenefit();
        final viewModel = BenefitViewModel(
          userBenefit: userBenefit,
          benefit: benefit,
        );

        // Act & Assert
        expect(viewModel.formattedAmount, '€5.50');
      });

      test('should format whole numbers with two decimal places', () {
        // Arrange
        final benefit = MockData.createBenefit(discountAmount: 10.0);
        final userBenefit = MockData.createUserBenefit();
        final viewModel = BenefitViewModel(
          userBenefit: userBenefit,
          benefit: benefit,
        );

        // Act & Assert
        expect(viewModel.formattedAmount, '€10.00');
      });

      test('should handle large amounts', () {
        // Arrange
        final benefit = MockData.createBenefit(discountAmount: 999.99);
        final userBenefit = MockData.createUserBenefit();
        final viewModel = BenefitViewModel(
          userBenefit: userBenefit,
          benefit: benefit,
        );

        // Act & Assert
        expect(viewModel.formattedAmount, '€999.99');
      });
    });

    group('formattedDate', () {
      test('should return "Today" for benefits earned today', () {
        // Arrange
        final benefit = MockData.createBenefit();
        final userBenefit = MockData.createUserBenefit(
          earnedAt: DateTime.now(),
        );
        final viewModel = BenefitViewModel(
          userBenefit: userBenefit,
          benefit: benefit,
        );

        // Act & Assert
        expect(viewModel.formattedDate, 'Today');
      });

      test('should return "Yesterday" for benefits earned yesterday', () {
        // Arrange
        final benefit = MockData.createBenefit();
        final userBenefit = MockData.createUserBenefit(
          earnedAt: DateTime.now().subtract(Duration(days: 1)),
        );
        final viewModel = BenefitViewModel(
          userBenefit: userBenefit,
          benefit: benefit,
        );

        // Act & Assert
        expect(viewModel.formattedDate, 'Yesterday');
      });

      test('should return "X days ago" for benefits earned within last week', () {
        // Arrange
        final benefit = MockData.createBenefit();
        final userBenefit = MockData.createUserBenefit(
          earnedAt: DateTime.now().subtract(Duration(days: 3)),
        );
        final viewModel = BenefitViewModel(
          userBenefit: userBenefit,
          benefit: benefit,
        );

        // Act & Assert
        expect(viewModel.formattedDate, '3 days ago');
      });

      test('should return formatted date (DD.MM.YYYY) for older benefits', () {
        // Arrange
        final benefit = MockData.createBenefit();
        final earnedDate = DateTime(2024, 1, 15);
        final userBenefit = MockData.createUserBenefit(
          earnedAt: earnedDate,
        );
        final viewModel = BenefitViewModel(
          userBenefit: userBenefit,
          benefit: benefit,
        );

        // Act & Assert
        expect(viewModel.formattedDate, '15.01.2024');
      });

      test('should pad single digit days and months with zero', () {
        // Arrange
        final benefit = MockData.createBenefit();
        final earnedDate = DateTime(2024, 3, 5);
        final userBenefit = MockData.createUserBenefit(
          earnedAt: earnedDate,
        );
        final viewModel = BenefitViewModel(
          userBenefit: userBenefit,
          benefit: benefit,
        );

        // Act & Assert
        expect(viewModel.formattedDate, '05.03.2024');
      });

      test('should handle benefits earned exactly 7 days ago', () {
        // Arrange
        final benefit = MockData.createBenefit();
        final earnedDate = DateTime.now().subtract(Duration(days: 7));
        final userBenefit = MockData.createUserBenefit(
          earnedAt: earnedDate,
        );
        final viewModel = BenefitViewModel(
          userBenefit: userBenefit,
          benefit: benefit,
        );

        // Act & Assert
        // Should format as date since it's >= 7 days
        expect(viewModel.formattedDate, matches(r'\d{2}\.\d{2}\.\d{4}'));
      });
    });

    group('earnedAt', () {
      test('should return the correct earnedAt date', () {
        // Arrange
        final benefit = MockData.createBenefit();
        final earnedDate = DateTime(2024, 6, 15, 10, 30);
        final userBenefit = MockData.createUserBenefit(
          earnedAt: earnedDate,
        );
        final viewModel = BenefitViewModel(
          userBenefit: userBenefit,
          benefit: benefit,
        );

        // Act & Assert
        expect(viewModel.earnedAt, earnedDate);
      });
    });

    group('toString()', () {
      test('should return formatted string representation', () {
        // Arrange
        final benefit = MockData.createBenefit(
          title: 'Test Benefit',
          discountAmount: 10.0,
        );
        final userBenefit = MockData.createUserBenefit(
          earnedAt: DateTime.now(),
        );
        final viewModel = BenefitViewModel(
          userBenefit: userBenefit,
          benefit: benefit,
        );

        // Act
        final result = viewModel.toString();

        // Assert
        expect(result, contains('BenefitViewModel'));
        expect(result, contains('title: Test Benefit'));
        expect(result, contains('amount: €10.00'));
        expect(result, contains('earned: Today'));
      });
    });

    group('Data Joining', () {
      test('should correctly join userBenefit and benefit data', () {
        // Arrange
        final benefit = MockData.createBenefit(
          id: 'benefit-123',
          title: 'Premium Reward',
          description: 'Special discount',
          discountAmount: 25.0,
        );
        final userBenefit = MockData.createUserBenefit(
          id: 'ub-456',
          userId: 'user-789',
          benefitId: 'benefit-123',
          sessionId: 'session-101',
          earnedAt: DateTime(2024, 3, 20),
        );
        final viewModel = BenefitViewModel(
          userBenefit: userBenefit,
          benefit: benefit,
        );

        // Assert - UserBenefit properties
        expect(viewModel.id, 'ub-456');
        expect(viewModel.sessionId, 'session-101');
        expect(viewModel.earnedAt, DateTime(2024, 3, 20));

        // Assert - Benefit properties
        expect(viewModel.title, 'Premium Reward');
        expect(viewModel.description, 'Special discount');
        expect(viewModel.formattedAmount, '€25.00');
      });
    });

    group('Edge Cases', () {
      test('should handle zero discount amount', () {
        // Arrange
        final benefit = MockData.createBenefit(discountAmount: 0.0);
        final userBenefit = MockData.createUserBenefit();
        final viewModel = BenefitViewModel(
          userBenefit: userBenefit,
          benefit: benefit,
        );

        // Act & Assert
        expect(viewModel.formattedAmount, '€0.00');
      });

      test('should handle very small amounts', () {
        // Arrange
        final benefit = MockData.createBenefit(discountAmount: 0.01);
        final userBenefit = MockData.createUserBenefit();
        final viewModel = BenefitViewModel(
          userBenefit: userBenefit,
          benefit: benefit,
        );

        // Act & Assert
        expect(viewModel.formattedAmount, '€0.01');
      });

      test('should handle empty strings in benefit properties', () {
        // Arrange
        final benefit = MockData.createBenefit(
          title: '',
          description: '',
        );
        final userBenefit = MockData.createUserBenefit();
        final viewModel = BenefitViewModel(
          userBenefit: userBenefit,
          benefit: benefit,
        );

        // Act & Assert
        expect(viewModel.title, '');
        expect(viewModel.description, '');
      });

      test('should handle future dates gracefully', () {
        // Arrange
        final benefit = MockData.createBenefit();
        final futureDate = DateTime.now().add(Duration(days: 1));
        final userBenefit = MockData.createUserBenefit(
          earnedAt: futureDate,
        );
        final viewModel = BenefitViewModel(
          userBenefit: userBenefit,
          benefit: benefit,
        );

        // Act & Assert - should still format correctly
        expect(viewModel.formattedDate, isNotEmpty);
      });
    });
  });
}