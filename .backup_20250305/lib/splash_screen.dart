import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'features/trials/trial_list_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _shimmerController;

  late Animation<double> _logoFade;
  late Animation<double> _logoScale;
  late Animation<double> _titleFade;
  late Animation<double> _titleSlide;
  late Animation<double> _subtitleFade;
  late Animation<double> _dividerWidth;
  late Animation<double> _authorFade;
  late Animation<double> _taglineFade;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    // Logo appears first
    _logoFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );
    _logoScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOutBack),
      ),
    );

    // Title slides up
    _titleFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.25, 0.55, curve: Curves.easeOut),
      ),
    );
    _titleSlide = Tween<double>(begin: 20, end: 0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.25, 0.55, curve: Curves.easeOutCubic),
      ),
    );

    // Subtitle
    _subtitleFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.4, 0.65, curve: Curves.easeOut),
      ),
    );

    // Divider expands
    _dividerWidth = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.55, 0.75, curve: Curves.easeOut),
      ),
    );

    // Author fades
    _authorFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.7, 0.88, curve: Curves.easeOut),
      ),
    );

    // Tagline last
    _taglineFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.85, 1.0, curve: Curves.easeOut),
      ),
    );

    _mainController.forward();

    Future.delayed(const Duration(milliseconds: 3800), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const TrialListScreen(),
            transitionsBuilder: (_, animation, __, child) =>
                FadeTransition(opacity: animation, child: child),
            transitionDuration: const Duration(milliseconds: 700),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F2318),
              Color(0xFF1A3C2E),
              Color(0xFF1F4A36),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Radial glow — centre
            Positioned(
              top: size.height * 0.25,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 320,
                  height: 320,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF3D7A55).withOpacity(0.35),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Gold accent glow bottom
            Positioned(
              bottom: -40,
              left: size.width * 0.1,
              right: size.width * 0.1,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFCDA82A).withOpacity(0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Fine grid pattern
            Positioned.fill(
              child: CustomPaint(painter: _GridPainter()),
            ),

            // Main content — centred
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo mark
                  AnimatedBuilder(
                    animation: _mainController,
                    builder: (_, __) => Opacity(
                      opacity: _logoFade.value,
                      child: Transform.scale(
                        scale: _logoScale.value,
                        child: Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: const Color(0xFFCDA82A).withOpacity(0.6),
                              width: 1.5,
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withOpacity(0.12),
                                Colors.white.withOpacity(0.04),
                              ],
                            ),
                          ),
                          child: const Icon(
                            Icons.energy_savings_leaf,
                            size: 50,
                            color: Color(0xFFCDA82A),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 36),

                  // Ag-Quest title
                  AnimatedBuilder(
                    animation: _mainController,
                    builder: (_, __) => Opacity(
                      opacity: _titleFade.value,
                      child: Transform.translate(
                        offset: Offset(0, _titleSlide.value),
                        child: Text(
                          'Ag-Quest',
                          style: GoogleFonts.playfairDisplay(
                            color: Colors.white,
                            fontSize: 52,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Field Companion subtitle
                  AnimatedBuilder(
                    animation: _mainController,
                    builder: (_, __) => Opacity(
                      opacity: _subtitleFade.value,
                      child: Text(
                        'F I E L D   C O M P A N I O N',
                        style: TextStyle(
                          color: const Color(0xFFCDA82A).withOpacity(0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 4.0,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Expanding divider
                  AnimatedBuilder(
                    animation: _dividerWidth,
                    builder: (_, __) => SizedBox(
                      width: 200,
                      child: FractionallySizedBox(
                        widthFactor: _dividerWidth.value,
                        child: Container(
                          height: 1,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Color(0xFFCDA82A),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // By Parminder Singh
                  AnimatedBuilder(
                    animation: _authorFade,
                    builder: (_, __) => Opacity(
                      opacity: _authorFade.value,
                      child: Text(
                        'By Parminder Singh',
                        style: GoogleFonts.playfairDisplay(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 15,
                          fontStyle: FontStyle.italic,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom tagline
            Positioned(
              bottom: 48,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _taglineFade,
                builder: (_, __) => Opacity(
                  opacity: _taglineFade.value * 0.45,
                  child: const Text(
                    'Agricultural Research  ·  Field Data Collection',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      letterSpacing: 2.0,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.025)
      ..strokeWidth = 0.5;

    const spacing = 36.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
