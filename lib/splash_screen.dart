import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/current_user.dart';
import 'features/trials/trial_list_screen.dart';
import 'features/users/user_selection_screen.dart';

// ─── Brand and asset constants (change here to update brand or assets) ───
const String kSplashLogoAsset = 'assets/Branding/splash_logo.png';
const String kSplashBrandTitle = 'Ag-Quest';
const String kSplashBrandSubtitle = 'FIELD COMPANION';

/// Background color for native and Flutter splash (must match native splash).
/// Refined deep ag-tech green: rich, calm, modern.
const Color kSplashBackgroundColor = Color(0xFF0E3D2F);

/// Single modern splash: matches native splash visually, then title/subtitle fade in.
/// No developer credit on splash; brand text rendered in Flutter.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  /// Total time on Flutter splash before navigating (logo already visible from native).
  static const Duration _displayDuration = Duration(milliseconds: 2200);

  late AnimationController _controller;
  late Animation<double> _titleOpacity;
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
      duration: const Duration(milliseconds: 800),
    );
    _titleOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.75, curve: Curves.easeOut),
      ),
    );
    _subtitleOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.25, 1.0, curve: Curves.easeOut),
      ),
    );
    _controller.forward();

    Future.delayed(_displayDuration, () async {
      if (!mounted) return;
      final userId = await getCurrentUserId();
      if (!mounted) return;
      final next = userId == null
          ? const UserSelectionScreen()
          : const TrialListScreen();
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
    final size = MediaQuery.sizeOf(context);
    // Optical centering: logo + text block center at ~44% from top.
    const logoSize = 268.0; // dominant product mark, premium balance
    const logoToTitleGap = 32.0;
    const blockHeight = 400.0; // logoSize + gap + title ~52 + gap 12 + subtitle ~36
    final topPadding = ((size.height * 0.44) - (blockHeight / 2)).clamp(24.0, double.infinity);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: kSplashBackgroundColor,
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.only(top: topPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo (visible immediately; continuity with native splash)
                Image.asset(
                  kSplashLogoAsset,
                  width: logoSize,
                  height: logoSize,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                ),
                const SizedBox(height: logoToTitleGap),
                // Brand title — opacity animation (Lora: serif fallback; Century Schoolbook not in Google Fonts)
                AnimatedBuilder(
                  animation: _controller,
                  builder: (_, __) => Opacity(
                    opacity: _titleOpacity.value,
                    child: Text(
                      kSplashBrandTitle,
                      style: GoogleFonts.lora(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Subtitle — opacity animation (slight stagger)
                AnimatedBuilder(
                  animation: _controller,
                  builder: (_, __) => Opacity(
                    opacity: _subtitleOpacity.value,
                    child: const Text(
                      kSplashBrandSubtitle,
                      style: TextStyle(
                        color: Color(0xFFD6B43C),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 5.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
