import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/providers/auth_provider.dart';
import 'features/home/home_screen.dart';
import 'features/cart/cart_screen.dart';
import 'features/orders/orders_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/product/add_product_screen.dart';

void main() {
  runApp(const ProviderScope(child: PlayShopApp()));
}

class PlayShopApp extends ConsumerStatefulWidget {
  const PlayShopApp({super.key});

  @override
  ConsumerState<PlayShopApp> createState() => _PlayShopAppState();
}

class _PlayShopAppState extends ConsumerState<PlayShopApp> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(authProvider.notifier).fetchMe());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PlayShop',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFe94560)),
        useMaterial3: true,
      ),
      home: const MainNavigation(),
      routes: {
        '/cart': (_) => const CartScreen(),
        '/orders': (_) => const OrdersScreen(),
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
      },
    );
  }
}

class MainNavigation extends ConsumerStatefulWidget {
  const MainNavigation({super.key});

  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<MainNavigation> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    final tabs = [
      const HomeScreen(),
      const CartScreen(),
      auth.isAuthenticated ? const OrdersScreen() : const LoginScreen(),
    ];

    return Scaffold(
      body: tabs[_currentIndex],

      // FAB visible uniquement sur l'onglet Accueil et si connecté
      floatingActionButton: (_currentIndex == 0 && auth.isAuthenticated)
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddProductScreen()),
              ),
              backgroundColor: const Color(0xFFe94560),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Produit', style: TextStyle(fontWeight: FontWeight.w600)),
            )
          : null,

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        selectedItemColor: const Color(0xFFe94560),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Accueil'),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart_outlined), activeIcon: Icon(Icons.shopping_cart), label: 'Panier'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), activeIcon: Icon(Icons.receipt_long), label: 'Commandes'),
        ],
      ),
    );
  }
}
