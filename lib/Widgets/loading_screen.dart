import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:sticampuscentralguide/Screens/home_screen.dart';

/// Custom clipper that reveals content from bottom to top based on progress (0.0 to 1.0)
class _ProgressClipPath extends CustomClipper<Rect> {
  final double progress;
  const _ProgressClipPath(this.progress);

  @override
  Rect getClip(Size size) {
    final visibleHeight = size.height * progress;
    return Rect.fromLTWH(
      0,
      size.height - visibleHeight,
      size.width,
      visibleHeight,
    );
  }

  @override
  bool shouldReclip(covariant _ProgressClipPath oldClipper) {
    return oldClipper.progress != progress;
  }
}

/// Startup loading screen
/// - Navy background
/// - icon_zero (greyscale) bounces in
/// - icon_complete fills from bottom to top as progress
/// - Screen fades out and navigates to Home
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> 
    with SingleTickerProviderStateMixin {
  
  // Animation states
  int _animationState = 0;
  double _progress = 0.0;

  // Controllers
  late final AnimationController _bounceController;
  late final Animation<double> _bounceScale;

  Timer? _progressTimer;
  Timer? _failsafeTimer;

  // Assets
  static const String _iconComplete = 'assets/images/icon_complete.webp';
  static const String _iconZero = 'assets/images/icon_zero.webp';
  String _zeroAssetInUse = _iconComplete; // fallback

  @override
  void initState() {
    super.initState();
    
    // Bounce animation with overshoot
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _bounceScale = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut),
    );

    // Failsafe: automatically timeout after 5 seconds
    _failsafeTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _animationState = 3);
      }
    });

    _prepareAndStart();
  }

  Future<void> _prepareAndStart() async {
    // Check if icon_zero exists
    try {
      await rootBundle.load(_iconZero);
      _zeroAssetInUse = _iconZero;
    } catch (_) {
      _zeroAssetInUse = _iconComplete;
    }

    // Precache both icons
    if (mounted) {
      await Future.wait([
        precacheImage(AssetImage(_zeroAssetInUse), context),
        precacheImage(const AssetImage(_iconComplete), context),
      ]);
    }

    if (!mounted) return;

    // Start animation sequence
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    // State 1: Bounce in
    setState(() => _animationState = 1);
    _bounceController.forward();

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    // State 2: Fill animation
    setState(() => _animationState = 2);
    _startFillAnimation();
  }

  void _startFillAnimation() {
    const steps = [0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0];
    int currentStep = 0;

    _progressTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (!mounted || currentStep >= steps.length) {
        timer.cancel();
        if (mounted && currentStep >= steps.length) {
          // Fill complete, wait a bit then fade
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              setState(() => _animationState = 3);
            }
          });
        }
        return;
      }
      setState(() {
        _progress = steps[currentStep];
      });
      currentStep++;
    });
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _progressTimer?.cancel();
    _failsafeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color navy = Color(0xFF123CBE);
    final media = MediaQuery.of(context);
    final double size = (media.size.width * 0.51).clamp(180.0, 280.0);

    // Fade alpha
    final fadeAlpha = _animationState >= 3 ? 0.0 : 1.0;

    // Navigate when fade completes
    if (_animationState >= 3 && fadeAlpha == 0.0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      });
    }

    return AnimatedOpacity(
      opacity: fadeAlpha,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      child: Container(
        color: navy,
        child: Center(
          child: AnimatedBuilder(
            animation: _bounceScale,
            builder: (context, child) {
              return Transform.scale(
                scale: _bounceScale.value,
                child: SizedBox(
                  width: size,
                  height: size,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Base greyscale icon (icon_zero)
                      Image.asset(
                        _zeroAssetInUse,
                        width: size,
                        height: size,
                        fit: BoxFit.contain,
                      ),
                      // Filled portion (icon_complete) clipped from bottom to top
                      if (_animationState >= 2)
                        ClipRect(
                          clipper: _ProgressClipPath(_progress),
                          child: Image.asset(
                            _iconComplete,
                            width: size,
                            height: size,
                            fit: BoxFit.contain,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

