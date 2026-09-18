import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:unicons/unicons.dart';

import '../routes/app_routes.dart';
import '../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..forward();
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _scale = Tween<double>(begin: .94, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, .08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: const Color(0xffeef5ef),
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _CoverPainter(_controller))),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              child: FadeTransition(
                opacity: _fade,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(20),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            UniconsLine.estate,
                            color: AppTheme.accent,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Property 24',
                          style: textTheme.titleLarge?.copyWith(
                            color: const Color(0xff12324a),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Expanded(
                      child: Center(
                        child: ScaleTransition(
                          scale: _scale,
                          child: SlideTransition(
                            position: _slide,
                            child: const _PhonePreview(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: const [
                        _TrustPill(icon: UniconsLine.shield_check, text: 'Verified'),
                        _TrustPill(icon: UniconsLine.receipt, text: 'Real costs'),
                        _TrustPill(icon: UniconsLine.comparison, text: 'Compare'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Find a home you can actually trust.',
                      style: textTheme.displaySmall?.copyWith(
                        color: const Color(0xff0b2017),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                        height: 1.04,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Find -> Verify -> Understand -> Compare -> Decide. Built around fair access, secure identity checks, and the OSWAP code of ethics.',
                      style: textTheme.bodyLarge?.copyWith(
                        color: const Color(0xff536158),
                        height: 1.38,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () => context.goNamed(AppRoutes.homeName),
                      icon: const Icon(UniconsLine.arrow_right),
                      label: const Text('Explore trusted homes'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                        backgroundColor: AppTheme.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => context.goNamed(AppRoutes.profileName),
                      icon: const Icon(UniconsLine.user_circle),
                      label: const Text('Login or create account'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        foregroundColor: const Color(0xff12324a),
                        side: const BorderSide(color: Color(0xffc8d8cd)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhonePreview extends StatelessWidget {
  const _PhonePreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 268,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xff0f2118),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white, width: 5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(50),
            blurRadius: 36,
            offset: const Offset(0, 22),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 190,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [Color(0xffd8ead9), Color(0xff73bf8d)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: _HousePainter()),
                ),
                const Positioned(
                  left: 14,
                  top: 14,
                  child: _PreviewBadge(text: '92 trust'),
                ),
                const Positioned(
                  right: 14,
                  top: 14,
                  child: Icon(UniconsLine.heart, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Avondale townhouse',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              const Text(
                '\$900',
                style: TextStyle(
                  color: AppTheme.accentTeal,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: const [
              _MiniFact(icon: UniconsLine.bed_double, text: '3 bed'),
              SizedBox(width: 6),
              _MiniFact(icon: UniconsLine.water, text: 'Borehole'),
              SizedBox(width: 6),
              _MiniFact(icon: UniconsLine.bolt, text: 'Solar'),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrustPill extends StatelessWidget {
  const _TrustPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(210),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xffd5e5da)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.accent),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xff12324a),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewBadge extends StatelessWidget {
  const _PreviewBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(235),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: Color(0xff12324a),
        ),
      ),
    );
  }
}

class _MiniFact extends StatelessWidget {
  const _MiniFact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(18),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: AppTheme.accentTeal),
            const SizedBox(height: 3),
            Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverPainter extends CustomPainter {
  _CoverPainter(this.animation) : super(repaint: animation);

  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xffeef5ef), Color(0xffd4ead9), Color(0xfff7fbf8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, paint);

    final pulse = animation.value;
    canvas.drawCircle(
      Offset(size.width * .88, size.height * .16),
      96 + 20 * pulse,
      Paint()..color = AppTheme.accent.withAlpha(28),
    );
    canvas.drawCircle(
      Offset(size.width * .08, size.height * .48),
      130 + 16 * pulse,
      Paint()..color = AppTheme.accentTeal.withAlpha(22),
    );
  }

  @override
  bool shouldRepaint(covariant _CoverPainter oldDelegate) => true;
}

class _HousePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final body = Paint()..color = Colors.white.withAlpha(220);
    final roof = Paint()..color = const Color(0xff12324a);
    final window = Paint()..color = AppTheme.accent;
    final ground = Paint()..color = Colors.white.withAlpha(90);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * .22, size.height * .43, size.width * .56, 62),
        const Radius.circular(8),
      ),
      body,
    );
    final path = Path()
      ..moveTo(size.width * .16, size.height * .46)
      ..lineTo(size.width * .5, size.height * .24)
      ..lineTo(size.width * .84, size.height * .46)
      ..close();
    canvas.drawPath(path, roof);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * .43, size.height * .55, 28, 40),
        const Radius.circular(6),
      ),
      window,
    );
    canvas.drawLine(
      Offset(size.width * .12, size.height * .82),
      Offset(size.width * .9, size.height * .8),
      ground..strokeWidth = 4,
    );
  }

  @override
  bool shouldRepaint(covariant _HousePainter oldDelegate) => false;
}
