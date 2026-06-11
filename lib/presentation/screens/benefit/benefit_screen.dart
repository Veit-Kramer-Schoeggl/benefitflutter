import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:benefitflutter/providers/benefit_provider.dart';
import 'package:benefitflutter/providers/user_provider.dart';
import 'package:benefitflutter/presentation/shared/widgets/loading_widget.dart';
import 'package:benefitflutter/presentation/shared/widgets/error_display_widget.dart';
import 'package:benefitflutter/presentation/screens/benefit/widgets/total_savings_card.dart';
import 'package:benefitflutter/presentation/screens/benefit/widgets/benefit_list.dart';
import 'package:benefitflutter/presentation/screens/benefit/widgets/empty_benefits_widget.dart';
import 'package:benefitflutter/core/seed/seed_service.dart';
import 'package:benefitflutter/core/config/repository_config.dart';
import 'package:benefitflutter/presentation/screens/benefit/benefit_qr_screen.dart';
import 'package:benefitflutter/features/benefit/domain/user_benefit.dart';

/// Benefit screen - Tab 3: Benefits, savings & rewards
/// Shows total savings and list of earned benefits
/// Uses Provider pattern for state management
class BenefitScreen extends StatefulWidget {
  const BenefitScreen({super.key});

  @override
  State<BenefitScreen> createState() => _BenefitScreenState();
}

class _BenefitScreenState extends State<BenefitScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch data after first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {});
  }

  /// Handle database reseed with confirmation and feedback
  Future<void> _handleReseedDatabase() async {
    // Step 1: Show confirmation dialog
    final confirmed = await _showReseedConfirmation();
    if (!confirmed) return;

    // Step 2: Show loading indicator
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 16),
            Text('Reseeding database...'),
          ],
        ),
        duration: Duration(seconds: 30), // Long duration for the process
      ),
    );

    try {
      // Step 3: Create SeedService and trigger reseed
      final seedService = await SeedService.create(
        userRepository: RepositoryConfig.getUserRepository(),
        sessionRepository: RepositoryConfig.getSessionRepository(),
        benefitRepository: RepositoryConfig.getBenefitRepository(),
      );

      await seedService.clearAndReseed();

      // Step 4: Show success message
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Database reseeded successfully!\n1 user, 4 benefits, 6 sessions, 8 GPS points',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );

      // Step 5: Refresh the benefits list
      context.read<BenefitProvider>().fetchBenefits();
    } catch (e) {
      // Step 6: Show error message
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 16),
                Expanded(child: Text('Reseed failed: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );

      debugPrint('Reseed error: $e');
    }
  }

  /// Show confirmation dialog before reseeding
  Future<bool> _showReseedConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning, color: Colors.orange, size: 48),
        title: const Text('Reset Seed Data?'),
        content: const Text(
          'This will:\n'
          '• Clear the seed flag\n'
          '• Repopulate database with test data\n'
          '• Override any existing data\n\n'
          'This action cannot be undone.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Reset Data'),
          ),
        ],
      ),
    );

    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BeneFit')),
      body: Consumer<BenefitProvider>(
        builder: (context, provider, child) {
          // Loading state (initial fetch)
          if (provider.isLoading) {
            return const LoadingWidget(message: 'Loading your BeneFits...');
          }

          // Error state
          if (provider.hasError) {
            return ErrorDisplayWidget(
              message: provider.error!,
              onRetry: provider.retry,
            );
          }

          // Empty state (no benefits earned yet)
          if (provider.isEmpty) {
            return const EmptyBenefitsWidget();
          }

          // Success state with data
          return RefreshIndicator(
            onRefresh: provider.refresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Total savings card (prominent display)
                  TotalSavingsCard(totalSavings: provider.totalSavings),

                  // Section header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: Text(
                      'Earned BeneFits',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  // Benefits list
                  BenefitList(
                    benefits: provider.earnedBenefits,
                    // TODO: Navigate to session detail screen
                    // 👉 Öffnet QR Screen wenn Benefit bereits redeemed ist
                    onBenefitTap: (benefitVM) {
                      if (benefitVM.userBenefit.status ==
                          BenefitStatus.redeemed) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                BenefitQrScreen(benefitVM: benefitVM),
                          ),
                        );
                      }
                    },

                    onRedeem: (benefitVM) async {
                      final userId = context.read<UserProvider>().userId;
                      if (userId == null) return;

                      if (benefitVM.userBenefit.status ==
                          BenefitStatus.earned) {
                        await provider.redeemBenefit(
                          userBenefitId: benefitVM.userBenefit.id,
                        );
                      }
                    },
                  ),

                  const SizedBox(height: 24),

                  // Debug section - only visible in debug mode
                  if (kDebugMode) ...[
                    const Divider(),
                    const SizedBox(height: 16),

                    // Debug section header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.bug_report,
                            size: 20,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Developer Tools',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Reseed button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: OutlinedButton.icon(
                        onPressed: _handleReseedDatabase,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reset Seed Data'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange,
                          side: BorderSide(
                            color: Colors.orange.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Help text
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Clears seed flag and repopulates database with test data',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
