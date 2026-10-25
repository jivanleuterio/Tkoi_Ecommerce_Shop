import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/koi_backdrop.dart';

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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _scale = Tween(begin: .94, end: 1.03).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: KoiBackdrop(
        dark: true,
        child: SafeArea(
          child: Center(
            child: FadeTransition(
              opacity: Tween(begin: .72, end: 1.0).animate(_fade),
              child: ScaleTransition(
                scale: _scale,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const TkoiWordmark(height: 108, light: true),
                    const SizedBox(height: 5),
                    Text(
                      'FISH MARKETPLACE',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .78),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 34),
                    const SizedBox(
                      width: 34,
                      child: LinearProgressIndicator(
                        minHeight: 3,
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                        color: AppColors.gold,
                        backgroundColor: Color(0x44FFFFFF),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
