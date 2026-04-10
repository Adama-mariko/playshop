import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {

  // Contrôleurs d'animation
  late AnimationController _logoCtrl;
  late AnimationController _textCtrl;
  late AnimationController _flameCtrl;

  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;
  late Animation<double> _flameScale;

  @override
  void initState() {
    super.initState();

    // Logo : apparaît avec un scale + fade
    _logoCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _logoScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: const Interval(0.0, 0.5)),
    );

    // Flamme : pulse continu
    _flameCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _flameScale = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _flameCtrl, curve: Curves.easeInOut),
    );

    // Texte : glisse depuis le bas
    _textCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(_textCtrl);
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(
      CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut),
    );

    _startSequence();
  }

  Future<void> _startSequence() async {
    // 1. Logo apparaît
    await _logoCtrl.forward();
    // 2. Texte glisse
    await _textCtrl.forward();
    // 3. Attendre + vérifier la session
    await Future.delayed(const Duration(milliseconds: 1200));
    await ref.read(authProvider.notifier).fetchMe();
    // 4. Naviguer
    if (mounted) _navigate();
  }

  void _navigate() {
    final isAuth = ref.read(authProvider).isAuthenticated;
    Navigator.of(context).pushReplacementNamed(isAuth ? '/home' : '/login');
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _textCtrl.dispose();
    _flameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f3460)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Logo avec flamme animée
              AnimatedBuilder(
                animation: Listenable.merge([_logoCtrl, _flameCtrl]),
                builder: (_, __) => Opacity(
                  opacity: _logoOpacity.value,
                  child: Transform.scale(
                    scale: _logoScale.value,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Halo lumineux
                        Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFe94560).withOpacity(0.35),
                                blurRadius: 50,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                        ),
                        // Cercle principal
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const RadialGradient(
                              colors: [Color(0xFFe94560), Color(0xFFc73652)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFe94560).withOpacity(0.5),
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.shopping_bag_rounded,
                            color: Colors.white,
                            size: 52,
                          ),
                        ),
                        // Flammes animées
                        ..._buildFlames(),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 36),

              // ── Texte animé
              AnimatedBuilder(
                animation: _textCtrl,
                builder: (_, __) => FadeTransition(
                  opacity: _textOpacity,
                  child: SlideTransition(
                    position: _textSlide,
                    child: Column(
                      children: [
                        const Text(
                          'PlayShop',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 38,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Votre boutique en ligne',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 15,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 80),

              // ── Indicateur de chargement
              AnimatedBuilder(
                animation: _textCtrl,
                builder: (_, __) => FadeTransition(
                  opacity: _textOpacity,
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white.withOpacity(0.5),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Génère les particules de flamme autour du logo
  List<Widget> _buildFlames() {
    return List.generate(6, (i) {
      final dx = (i % 2 == 0 ? 1.0 : -1.0) * (18.0 + i * 6.0);
      final dy = -(20.0 + i * 8.0);

      return AnimatedBuilder(
        animation: _flameCtrl,
        builder: (_, __) => Transform.translate(
          offset: Offset(
            dx * _flameScale.value * 0.3,
            dy * _flameScale.value * 0.3,
          ),
          child: Transform.scale(
            scale: _flameScale.value * (0.4 + i * 0.08),
            child: Icon(
              Icons.local_fire_department_rounded,
              color: [
                const Color(0xFFFF6B35),
                const Color(0xFFFFD700),
                const Color(0xFFFF4500),
                const Color(0xFFFF8C00),
                const Color(0xFFFFD700),
                const Color(0xFFFF6B35),
              ][i],
              size: 22,
            ),
          ),
        ),
      );
    });
  }
}
