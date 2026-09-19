import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../../routes/app_routes.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();

  int _currentPage = 0;
  bool _showRoleSelection = false;

  late AnimationController _fadeController;
  late AnimationController _slideController;

  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  final List<_OnboardSlide> _slides = [
    _OnboardSlide(
      imageUrl:
          'https://images.pexels.com/photos/1571460/pexels-photo-1571460.jpeg',
      semanticLabel:
          'Modern luxury apartment interior with floor-to-ceiling windows and contemporary furniture in Lagos',
      headline: 'Find Your\nPerfect Home',
      subtitle:
          'Discover thousands of verified properties across Lagos — from cozy studios to luxury penthouses.',
      accentWord: 'Perfect',
    ),
    _OnboardSlide(
      imageUrl:
          'https://images.pexels.com/photos/2029694/pexels-photo-2029694.jpeg',
      semanticLabel:
          'Elegant modern house with trust verification shield overlay concept',
      headline: 'Trust Before\nYou Rent',
      subtitle:
          'Every property has a Trust Score. Know exactly who you\'re dealing with before signing anything.',
      accentWord: 'Trust',
    ),
    _OnboardSlide(
      imageUrl:
          'https://images.pexels.com/photos/3288103/pexels-photo-3288103.jpeg',
      semanticLabel:
          'Luxury penthouse with city views representing premium property listing',
      headline: 'List & Earn\nMore',
      subtitle:
          'Landlords and agents — get verified, list your properties, and connect with serious tenants.',
      accentWord: 'Earn',
    ),
  ];

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeAnim = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _slideController,
        curve: Curves.easeOutCubic,
      ),
    );

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      setState(() {
        _showRoleSelection = true;
      });
    }
  }

  void _selectRole(String role) {
    context.go(AppRoutes.homeScreen);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        child: _showRoleSelection
            ? _RoleSelectionView(
                onRoleSelected: _selectRole,
              )
            : _OnboardingView(
                slides: _slides,
                currentPage: _currentPage,
                pageController: _pageController,
                fadeAnim: _fadeAnim,
                slideAnim: _slideAnim,
                onPageChanged: (i) {
                  setState(() {
                    _currentPage = i;
                  });

                  _fadeController.reset();
                  _slideController.reset();

                  _fadeController.forward();
                  _slideController.forward();
                },
                onNext: _nextPage,
                onSkip: () {
                  setState(() {
                    _showRoleSelection = true;
                  });
                },
              ),
      ),
    );
  }
}

class _OnboardingView extends StatelessWidget {
  final List<_OnboardSlide> slides;
  final int currentPage;
  final PageController pageController;
  final Animation<double> fadeAnim;
  final Animation<Offset> slideAnim;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _OnboardingView({
    required this.slides,
    required this.currentPage,
    required this.pageController,
    required this.fadeAnim,
    required this.slideAnim,
    required this.onPageChanged,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final isLast = currentPage == slides.length - 1;

    return Stack(
      children: [
        // Full-screen image
        PageView.builder(
          controller: pageController,
          onPageChanged: onPageChanged,
          itemCount: slides.length,
          itemBuilder: (context, index) {
            return CachedNetworkImage(
              imageUrl: slides[index].imageUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              placeholder: (_, __) => Container(
                color: AppTheme.bgCard,
              ),
              errorWidget: (_, __, ___) => Container(
                color: AppTheme.bgCard,
                child: const Icon(
                  Icons.home,
                  color: AppTheme.textMuted,
                  size: 48,
                ),
              ),
            );
          },
        ),

        // Gradient overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [
                0.0,
                0.35,
                0.65,
                1.0,
              ],
              colors: [
                Colors.black.withAlpha(102),
                Colors.transparent,
                AppTheme.bg.withAlpha(204),
                AppTheme.bg,
              ],
            ),
          ),
        ),

        // Skip button
        Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          right: 20,
          child: GestureDetector(
            onTap: onSkip,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(77),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withAlpha(51),
                ),
              ),
              child: Text(
                'Skip',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),

        // Bottom content
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              28,
              0,
              28,
              MediaQuery.of(context).padding.bottom + 32,
            ),
            child: FadeTransition(
              opacity: fadeAnim,
              child: SlideTransition(
                position: slideAnim,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Headline
                    _buildHeadline(slides[currentPage]),

                    const SizedBox(height: 14),

                    // Subtitle
                    Text(
                      slides[currentPage].subtitle,
                      style: GoogleFonts.poppins(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                        height: 1.6,
                        fontWeight: FontWeight.w400,
                      ),
                    ),

                    const SizedBox(height: 36),

                    // Dots + Button row
                    Row(
                      children: [
                        // Page dots
                        Row(
                          children: List.generate(
                            slides.length,
                            (i) {
                              final isActive = i == currentPage;

                              return AnimatedContainer(
                                duration: const Duration(
                                  milliseconds: 300,
                                ),
                                margin: const EdgeInsets.only(right: 6),
                                width: isActive ? 24 : 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? AppTheme.accent
                                      : AppTheme.textMuted,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              );
                            },
                          ),
                        ),

                        const Spacer(),

                        // Next / Get Started button
                        GestureDetector(
                          onTap: onNext,
                          child: AnimatedContainer(
                            duration: const Duration(
                              milliseconds: 300,
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: isLast ? 28 : 20,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  AppTheme.accent,
                                  AppTheme.accentTeal,
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.accent.withAlpha(77),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  isLast ? 'Get Started' : 'Next',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeadline(_OnboardSlide slide) {
    final parts = slide.headline.split(slide.accentWord);

    return RichText(
      text: TextSpan(
        style: GoogleFonts.poppins(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          color: AppTheme.textPrimary,
          height: 1.15,
          letterSpacing: 0,
        ),
        children: [
          if (parts.isNotEmpty)
            TextSpan(
              text: parts[0],
            ),
          TextSpan(
            text: slide.accentWord,
            style: TextStyle(
              foreground: Paint()
                ..shader = LinearGradient(
                  colors: [
                    AppTheme.accent,
                    AppTheme.accentTeal,
                  ],
                ).createShader(
                  const Rect.fromLTWH(
                    0,
                    0,
                    200,
                    50,
                  ),
                ),
            ),
          ),
          if (parts.length > 1)
            TextSpan(
              text: parts[1],
            ),
        ],
      ),
    );
  }
}

class _RoleSelectionView extends StatefulWidget {
  final ValueChanged<String> onRoleSelected;

  const _RoleSelectionView({
    required this.onRoleSelected,
  });

  @override
  State<_RoleSelectionView> createState() => _RoleSelectionViewState();
}

class _RoleSelectionViewState extends State<_RoleSelectionView>
    with SingleTickerProviderStateMixin {
  String? _selectedRole;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 48),

                  // Header
                  Text(
                    'How will you\nuse PropNest?',
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      height: 1.2,
                      letterSpacing: 0,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    'Choose your role to get a personalized experience.',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: AppTheme.textSecondary,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Tenant card
                  _RoleCard(
                    role: 'tenant',
                    title: "I'm Looking to Rent",
                    subtitle:
                        'Browse verified properties, compare listings, and find your perfect home.',
                    icon: Icons.search_rounded,
                    isSelected: _selectedRole == 'tenant',
                    onTap: () {
                      setState(() {
                        _selectedRole = 'tenant';
                      });
                    },
                    gradientColors: [
                      AppTheme.accent,
                      AppTheme.accentTeal,
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Landlord card
                  _RoleCard(
                    role: 'landlord',
                    title: "I'm a Landlord / Agent",
                    subtitle:
                        'List your properties, get verified, and connect with quality tenants.',
                    icon: Icons.apartment_rounded,
                    isSelected: _selectedRole == 'landlord',
                    onTap: () {
                      setState(() {
                        _selectedRole = 'landlord';
                      });
                    },
                    gradientColors: [
                      AppTheme.accentTeal,
                      AppTheme.accentTeal,
                    ],
                  ),

                  const Spacer(),

                  // Continue button
                  AnimatedOpacity(
                    opacity: _selectedRole != null ? 1.0 : 0.4,
                    duration: const Duration(milliseconds: 300),
                    child: GestureDetector(
                      onTap: _selectedRole != null
                          ? () => widget.onRoleSelected(
                                _selectedRole!,
                              )
                          : null,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 18,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              AppTheme.accent,
                              AppTheme.accentTeal,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: _selectedRole != null
                              ? [
                                  BoxShadow(
                                    color: AppTheme.accent.withAlpha(77),
                                    blurRadius: 24,
                                    offset: const Offset(0, 8),
                                  ),
                                ]
                              : [],
                        ),
                        child: Center(
                          child: Text(
                            'Continue',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String role;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final List<Color> gradientColors;

  const _RoleCard({
    required this.role,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(
          milliseconds: 250,
        ),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isSelected ? gradientColors[0].withAlpha(26) : AppTheme.bgCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? gradientColors[0] : AppTheme.border,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: gradientColors[0].withAlpha(51),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            // Icon container
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 26,
              ),
            ),

            const SizedBox(width: 18),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            AnimatedContainer(
              duration: const Duration(
                milliseconds: 250,
              ),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? gradientColors[0] : Colors.transparent,
                border: Border.all(
                  color: isSelected ? gradientColors[0] : AppTheme.textMuted,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 13,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardSlide {
  final String imageUrl;
  final String semanticLabel;
  final String headline;
  final String subtitle;
  final String accentWord;

  const _OnboardSlide({
    required this.imageUrl,
    required this.semanticLabel,
    required this.headline,
    required this.subtitle,
    required this.accentWord,
  });
}
