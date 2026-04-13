import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/config/app_info.dart';
import 'core/current_user.dart';
import 'features/shell/main_shell_screen.dart';
import 'features/users/user_selection_screen.dart';

const String kSplashLogoAsset = 'assets/Branding/splash_logo.png';

// Must match android colors.xml splash_background for seamless handoff.
const Color _nativeSplashColor = Color(0xFF163B28);

// Gradient destination colors.
const Color _splashDark = Color(0xFF0F2A1C);
const Color _splashMid = Color(0xFF163B28);
const Color _splashAccent = Color(0xFF1E4D34);

// Subtle gold accent for the divider.
const Color _accentGold = Color(0x66C8A951);

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _displayDuration = Duration(milliseconds: 3400);

  late AnimationController _controller;
  late Animation<double> _bgFade;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _titleOpacity;
  late Animation<double> _dividerWidth;
  late Animation<double> _subtitleOpacity;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    // Background gradient fades in immediately (0–25%).
    _bgFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.25, curve: Curves.easeOut),
      ),
    );

    // Logo: scale from 0.9→1.0 + fade in (0–35%).
    _logoScale = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOutCubic),
      ),
    );
    _logoOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );

    // Title: fade in (15–45%).
    _titleOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.15, 0.45, curve: Curves.easeOut),
      ),
    );

    // Divider: expand width (30–55%).
    _dividerWidth = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.55, curve: Curves.easeOut),
      ),
    );

    // Subtitle: fade in (40–70%).
    _subtitleOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 0.7, curve: Curves.easeOut),
      ),
    );

    _controller.forward();

    Future.delayed(_displayDuration, () async {
      if (!mounted) return;
      final userId = await getCurrentUserId();
      if (!mounted) return;
      final next = userId == null
          ? const UserSelectionScreen()
          : const MainShellScreen();
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => next,
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) => Stack(
          children: [
            // Base: solid color matching the native splash exactly.
            Container(
              width: double.infinity,
              height: double.infinity,
              color: _nativeSplashColor,
            ),

            // Gradient fades in on top for a seamless transition.
            Opacity(
              opacity: _bgFade.value,
              child: Container(
                width: double.infinity,
                height: double.infinity,
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -0.3),
                    radius: 1.2,
                    colors: [_splashAccent, _splashMid, _splashDark],
                    stops: [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),

            // Content.
            Positioned.fill(
              child: SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // --- Logo ---
                        Transform.scale(
                          scale: _logoScale.value,
                          child: Opacity(
                            opacity: _logoOpacity.value,
                            child: Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF2D7A4A)
                                        .withValues(alpha: 0.35),
                                    blurRadius: 48,
                                    spreadRadius: 4,
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: Image.asset(
                                  kSplashLogoAsset,
                                  width: 110,
                                  height: 110,
                                  fit: BoxFit.cover,
                                  filterQuality: FilterQuality.medium,
                                  semanticLabel: 'App logo',
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        // --- Title ---
                        Opacity(
                          opacity: _titleOpacity.value,
                          child: Text(
                            AppInfo.appName.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 32,
                              fontWeight: FontWeight.w300,
                              color: Colors.white,
                              letterSpacing: 10,
                              height: 1.1,
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // --- Gold divider ---
                        SizedBox(
                          height: 1,
                          child: FractionallySizedBox(
                            widthFactor: _dividerWidth.value * 0.35,
                            child: Container(color: _accentGold),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // --- Subtitle ---
                        Opacity(
                          opacity: _subtitleOpacity.value,
                          child: Text(
                            'Professional field trial data collection\nand execution platform',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w300,
                              color: Colors.white.withValues(alpha: 0.5),
                              letterSpacing: 0.8,
                              height: 1.7,
                            ),
                          ),
                        ),
                      ],
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
