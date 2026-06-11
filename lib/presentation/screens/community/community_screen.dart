import 'package:flutter/material.dart';

class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  Color get _primaryGreen => const Color(0xFF71B33A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: _primaryGreen,
        title: const Text(
          'Community',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: CustomScrollView(
        slivers: [
          // --------- HEADER ---------
          SliverToBoxAdapter(
            child: _HeaderBanner(
              primaryGreen: _primaryGreen,
              image: 'assets/images/runners/run_1.png',
            ),
          ),

          // --------- CHALLENGES ---------
          const SliverToBoxAdapter(
            child: _SectionHeader(
              title: 'Challenges',
              actionText: 'Vergangene',
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: _ChallengeCard(
                image: 'assets/images/runners/run_2.png',
              ),
            ),
          ),

          // --------- EVENTS ---------
          const SliverToBoxAdapter(
            child: _SectionHeader(
              title: 'Events',
              actionText: 'Vergangene',
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 220,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: const [
                  _EventCard(
                    image: 'assets/images/runners/run_3.png',
                    title: 'Virtuelles Rennen',
                    subtitle: 'Startet in 38 Tagen',
                    dateLabel: 'JULI 10K',
                  ),
                  SizedBox(width: 12),
                  _EventCard(
                    image: 'assets/images/runners/run_4.png',
                    title: 'Sunset Run',
                    subtitle: 'Beendet in 3 Tagen',
                    dateLabel: 'AUG 5K',
                  ),
                ],
              ),
            ),
          ),

          // --------- COMMUNITIES ---------
          const SliverToBoxAdapter(
            child: _SectionHeader(
              title: 'Communities',
              actionText: 'Mehr',
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            sliver: SliverToBoxAdapter(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  _CommunityChip(label: 'Running Beginners'),
                  _CommunityChip(label: '10K Fans'),
                  _CommunityChip(label: 'Trail Running'),
                  _CommunityChip(label: 'After-Work Runs'),
                  _CommunityChip(label: 'Marathon Training'),
                  _CommunityChip(label: 'Family Joggers'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =======================================================
// Header Banner
// =======================================================

class _HeaderBanner extends StatelessWidget {
  final Color primaryGreen;
  final String image;

  const _HeaderBanner({
    required this.primaryGreen,
    required this.image,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: primaryGreen,
        image: DecorationImage(
          // Cap decode size to avoid huge full-res image-cache allocations.
          image: ResizeImage(AssetImage(image), width: 1080),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            Colors.black.withValues(alpha: 0.45),
            BlendMode.darken,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.white,
              child: Image.asset(
                'assets/images/icons/community/icon_community.png',
                width: 34,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Community – Coming Soon',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =======================================================
// Section Header
// =======================================================

class _SectionHeader extends StatelessWidget {
  final String title;
  final String actionText;

  const _SectionHeader({
    required this.title,
    required this.actionText,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              fontSize: 16,
            ),
          ),
          Row(
            children: [
              Text(
                actionText.toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.1,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 16),
            ],
          ),
        ],
      ),
    );
  }
}

// =======================================================
// Challenge Card
// =======================================================

class _ChallengeCard extends StatelessWidget {
  final String image;

  const _ChallengeCard({required this.image});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(image, fit: BoxFit.cover, cacheWidth: 1080),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.1),
                    Colors.black.withValues(alpha: 0.75),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Challenge Title
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    color: Colors.white,
                    child: const Text(
                      'YOUR MONTHLY 50 KM',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Time Left
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    color: Colors.redAccent,
                    child: const Text(
                      'ENDET IN 11 TAGEN',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Participants
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    color: Colors.black87,
                    child: const Text(
                      '155.317 TEILNEHMER*INNEN',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

// =======================================================
// Event Card
// =======================================================

class _EventCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String dateLabel;
  final String image;

  const _EventCard({
    required this.title,
    required this.subtitle,
    required this.dateLabel,
    required this.image,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: () {},
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              SizedBox(
                height: 120,
                width: double.infinity,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.asset(image, fit: BoxFit.cover, cacheWidth: 1080),
                    ),
                    Container(
                      color: Colors.black38,
                    ),
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        color: Colors.black87,
                        child: Text(
                          title.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Text section
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subtitle.toUpperCase(),
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// =======================================================
// Community Chip
// =======================================================

class _CommunityChip extends StatelessWidget {
  final String label;

  const _CommunityChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      backgroundColor: Colors.white,
      shape: StadiumBorder(
        side: BorderSide(color: Colors.grey[300]!),
      ),
    );
  }
}
