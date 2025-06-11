import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        // Updated gradient to match your camera screen theme
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF121212), // Main dark background
              Color(0xFF1E1E1E), // Secondary background
              Color(0xFF00FF88), // Accent green
            ],
            stops: [0.1, 0.6, 1.0],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Glow effect behind logo using accent color
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00FF88).withOpacity(0.18),
                      blurRadius: 60,
                      spreadRadius: 24,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: Image.asset(
                    'assets/tevelgo-visia-high-resolution-logo.png', // <-- Use your logo asset path
                    width: 170,
                    height: 170,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 36),
              // Animated App Name with matching accent shadow
              TweenAnimationBuilder<double>(
                duration: const Duration(seconds: 1),
                tween: Tween(begin: 0, end: 1),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: const Text(
                  'Tevelgo Visia',
                  style: TextStyle(
                    fontFamily: 'Serif',
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 36,
                    letterSpacing: 1.5,
                    shadows: [
                      Shadow(
                        color: Color(0xFF00FF88),
                        blurRadius: 16,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Tagline with accent color
              const Text(
                "Vision. Intelligence. Security.",
                style: TextStyle(
                  color: Color(0xFF00FF88),
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
