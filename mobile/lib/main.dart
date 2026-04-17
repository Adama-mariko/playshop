import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_links/app_links.dart';
import 'core/providers/auth_provider.dart';
import 'features/splash/splash_screen.dart';
import 'features/home/home_screen.dart';
import 'features/cart/cart_screen.dart';
import 'features/orders/orders_screen.dart';
import 'features/historique/historique_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/product/add_product_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Barre de statut transparente
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const ProviderScope(child: PlayShopApp()));
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class PlayShopApp extends StatefulWidget {
  const PlayShopApp({super.key});

  @override
  State<PlayShopApp> createState() => _PlayShopAppState();
}

class _PlayShopAppState extends State<PlayShopApp> {
  late AppLinks _appLinks;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();
    
    // Gérer les deep links quand l'app est déjà ouverte
    _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) {
    // playshop://payment/success?ref=PS-123
    // playshop://payment/error?ref=PS-123
    if (uri.scheme == 'playshop') {
      if (uri.host == 'payment') {
        final ref = uri.queryParameters['ref'];
        if (uri.path.contains('success')) {
          // Rediriger vers l'écran des commandes avec un message de succès
          navigatorKey.currentState?.pushNamedAndRemoveUntil('/orders', (r) => false);
          // Afficher un snackbar de confirmation
          Future.delayed(const Duration(milliseconds: 500), () {
            final context = navigatorKey.currentContext;
            if (context != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Paiement confirmé ! Réf: $ref')),
                  ]),
                  backgroundColor: const Color(0xFF059669),
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          });
        } else if (uri.path.contains('error')) {
          navigatorKey.currentState?.pushNamedAndRemoveUntil('/orders', (r) => false);
          Future.delayed(const Duration(milliseconds: 500), () {
            final context = navigatorKey.currentContext;
            if (context != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Row(children: [
                    Icon(Icons.error_outline, color: Colors.white),
                    SizedBox(width: 8),
                    Expanded(child: Text('Paiement échoué. Veuillez réessayer.')),
                  ]),
                  backgroundColor: Color(0xFFDC2626),
                  duration: Duration(seconds: 4),
                ),
              );
            }
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'PlayShop',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFe94560)),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      // Splash screen comme page initiale
      initialRoute: '/',
      routes: {
        '/':       (_) => const SplashScreen(),
        '/home':   (_) => const MainNavigation(),
        '/login':  (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/cart':   (_) => const CartScreen(),
        '/orders': (_) => const OrdersScreen(),
      },
    );
  }
}

// ══════════════════════════════════════════════
// Navigation principale (après connexion)
// ══════════════════════════════════════════════
class MainNavigation extends ConsumerStatefulWidget {
  const MainNavigation({super.key});

  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<MainNavigation> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const HomeScreen(),
      const CartScreen(),
      const OrdersScreen(),
      const HistoriqueScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: tabs,
      ),

      // FAB visible uniquement sur l'onglet Accueil
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(builder: (_) => const AddProductScreen()),
              ),
              backgroundColor: const Color(0xFFe94560),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Produit', style: TextStyle(fontWeight: FontWeight.w600)),
            )
          : null,

      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFe94560).withOpacity(0.12),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: Color(0xFFe94560)),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            selectedIcon: Icon(Icons.shopping_cart, color: Color(0xFFe94560)),
            label: 'Panier',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long, color: Color(0xFFe94560)),
            label: 'Commandes',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history, color: Color(0xFFe94560)),
            label: 'Historique',
          ),
        ],
      ),
    );
  }
}
