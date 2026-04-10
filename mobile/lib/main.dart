import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/providers/auth_provider.dart';
import 'features/splash/splash_screen.dart';
import 'features/home/home_screen.dart';
import 'features/cart/cart_screen.dart';
import 'features/orders/orders_screen.dart';
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

class PlayShopApp extends StatelessWidget {
  const PlayShopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
        ],
      ),
    );
  }
}
