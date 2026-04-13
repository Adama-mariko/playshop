import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/models/product.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/cart_provider.dart';
import '../product/product_detail_screen.dart';
import '../product/add_product_screen.dart';
import '../auth/login_screen.dart';

final productsProvider = FutureProvider.autoDispose<List<Product>>((ref) async {
  try {
    final res = await ApiClient.instance.get('/products');
    final data = res.data['data'] as List<dynamic>;
    return data.map((e) => Product.fromJson(e)).toList();
  } catch (e) {
    throw Exception('Impossible de charger les produits : $e');
  }
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider);
    final cart = ref.read(cartProvider.notifier);
    final auth = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('PlayShop', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1a1a2e),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Icône panier avec badge
          Consumer(builder: (context, ref, _) {
            final count = ref.watch(cartProvider.notifier).count;
            return Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart_outlined),
                  onPressed: () => Navigator.pushNamed(context, '/cart'),
                ),
                if (count > 0)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: CircleAvatar(
                      radius: 9,
                      backgroundColor: const Color(0xFFe94560),
                      child: Text('$count', style: const TextStyle(fontSize: 11, color: Colors.white)),
                    ),
                  ),
              ],
            );
          }),
          // Icône profil / connexion
          IconButton(
            icon: Icon(auth.isAuthenticated ? Icons.person : Icons.person_outline),
            onPressed: () {
              if (!auth.isAuthenticated) {
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              } else {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: const Color(0xFFe94560),
                          child: Text(
                            auth.user!.name[0].toUpperCase(),
                            style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(auth.user!.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text(auth.user!.email, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                        const SizedBox(height: 20),
                        ListTile(
                          leading: const Icon(Icons.receipt_long, color: Color(0xFF1a1a2e)),
                          title: const Text('Mes commandes'),
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.of(context, rootNavigator: true).pushNamed('/orders');
                          },
                        ),
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.logout, color: Color(0xFFe94560)),
                          title: const Text('Déconnexion', style: TextStyle(color: Color(0xFFe94560), fontWeight: FontWeight.bold)),
                          onTap: () async {
                            Navigator.pop(ctx);
                            await ref.read(authProvider.notifier).logout();
                            if (context.mounted) {
                              Navigator.of(context, rootNavigator: true)
                                  .pushNamedAndRemoveUntil('/login', (r) => false);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }
            },
          ),        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFFe94560),
        onRefresh: () => ref.refresh(productsProvider.future),
        child: productsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFe94560))),
          error: (e, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wifi_off, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('Impossible de charger les produits', style: TextStyle(fontSize: 16, color: Colors.grey)),
                const SizedBox(height: 8),
                const Text('Vérifiez que le serveur est démarré', style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => ref.refresh(productsProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Réessayer'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFe94560), foregroundColor: Colors.white),
                ),
              ],
            ),
          ),
          data: (products) => products.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('Aucun produit disponible', style: TextStyle(fontSize: 18, color: Colors.grey)),
                      const SizedBox(height: 8),
                      const Text('Ajoutez des produits depuis l\'interface admin', style: TextStyle(fontSize: 13, color: Colors.grey)),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () => ref.refresh(productsProvider),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Actualiser'),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFe94560), foregroundColor: Colors.white),
                      ),
                    ],
                  ),
                )
              : CustomScrollView(
                  slivers: [
                    // Bannière de bienvenue
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1a1a2e), Color(0xFFe94560)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              auth.isAuthenticated ? 'Bonjour, ${auth.user!.name} 👋' : 'Bienvenue sur PlayShop 👋',
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            const Text('Découvrez nos meilleurs produits', style: TextStyle(color: Colors.white70, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),

                    // Titre section
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text('Tous les produits', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1a1a2e))),
                      ),
                    ),

                    // Grille produits
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.70,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final product = products[index];
                            return _ProductCard(
                              product: product,
                              onTap: () => Navigator.of(context, rootNavigator: true).push(
                                MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
                              ),
                              onAddToCart: () {
                                cart.addItem(product);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('${product.name} ajouté au panier'),
                                    backgroundColor: const Color(0xFF1a1a2e),
                                    duration: const Duration(seconds: 1),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                            );
                          },
                          childCount: products.length,
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 20)),
                  ],
                ),
        ),
      ),
    );
  }
}

// Fiche produit
class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  final VoidCallback onAddToCart;

  const _ProductCard({required this.product, required this.onTap, required this.onAddToCart});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: product.image != null && product.image!.isNotEmpty
                    ? Image.network(
                        product.imageUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (_, __, ___) => _placeholder(),
                      )
                    : _placeholder(),
              ),
            ),
            // Infos
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (product.category != null)
                    Text(product.category!, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  Text(
                    product.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${product.price.toStringAsFixed(0)} FCFA',
                    style: const TextStyle(color: Color(0xFFe94560), fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 32,
                    child: ElevatedButton(
                      onPressed: product.inStock ? onAddToCart : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1a1a2e),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        elevation: 0,
                      ),
                      child: Text(
                        product.inStock ? 'Ajouter' : 'Rupture',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        color: Colors.grey[100],
        child: const Center(child: Icon(Icons.image_outlined, size: 48, color: Colors.grey)),
      );
}

// Bottom sheet profil
class _ProfileSheet extends ConsumerWidget {
  final AuthState auth;
  const _ProfileSheet({required this.auth});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: const Color(0xFFe94560),
            child: Text(
              auth.user!.name[0].toUpperCase(),
              style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),
          Text(auth.user!.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(auth.user!.email, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.receipt_long, color: Color(0xFF1a1a2e)),
            title: const Text('Mes commandes'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context, rootNavigator: true).pushNamed('/orders');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Color(0xFFe94560)),
            title: const Text('Déconnexion', style: TextStyle(color: Color(0xFFe94560))),
            onTap: () async {
              final nav = Navigator.of(context, rootNavigator: true);
              Navigator.pop(context);
              await ref.read(authProvider.notifier).logout();
              nav.pushNamedAndRemoveUntil('/login', (r) => false);
            },
          ),
        ],
      ),
    );
  }
}
