import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/providers/cart_provider.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  String _paymentMethod = 'orange_money';
  bool _loading = false;
  String? _error;

  Future<void> _placeOrder() async {
    final cartItems = ref.read(cartProvider);
    if (cartItems.isEmpty) return;

    setState(() { _loading = true; _error = null; });

    try {
      // 1. Créer la commande
      final orderRes = await ApiClient.instance.post('/orders', data: {
        'items': cartItems.map((i) => {
          'productId': i.product.id,
          'quantity': i.quantity,
        }).toList(),
        'paymentMethod': _paymentMethod,
      });

      final orderId = orderRes.data['order']['id'];
      final total = orderRes.data['order']['total_amount'] ?? orderRes.data['order']['totalAmount'];

      // 2. Initier le paiement
      final paymentRes = await ApiClient.instance.post('/payments/initiate', data: {
        'orderId': orderId,
      });

      final reference = paymentRes.data['paymentReference'];
      final isSimulation = paymentRes.data['simulation'] == true;
      final instructions = paymentRes.data['instructions'] ?? '';

      // 3. Vider le panier
      ref.read(cartProvider.notifier).clear();

      // 4. Afficher la confirmation
      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => _ConfirmationDialog(
            orderId: orderId,
            total: double.parse(total.toString()),
            reference: reference,
            paymentMethod: _paymentMethod,
            isSimulation: isSimulation,
            instructions: instructions,
          ),
        );
        if (mounted) Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
      }
    } catch (e) {
      String msg = 'Une erreur est survenue. Réessayez.';
      if (e.toString().contains('Stock insuffisant')) {
        msg = 'Stock insuffisant pour un ou plusieurs produits.';
      } else if (e.toString().contains('401')) {
        msg = 'Session expirée. Reconnectez-vous.';
      }
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartItems = ref.watch(cartProvider);
    final cartNotifier = ref.read(cartProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Finaliser la commande', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1a1a2e),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Récapitulatif articles
            _section(
              title: 'Récapitulatif',
              icon: Icons.receipt_outlined,
              child: Column(
                children: [
                  ...cartItems.map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: item.product.imageUrl != null
                                  ? Image.network(item.product.imageUrl!, width: 48, height: 48, fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => _imgPlaceholder())
                                  : _imgPlaceholder(),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  Text('× ${item.quantity}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                ],
                              ),
                            ),
                            Text(
                              '${item.subtotal.toStringAsFixed(0)} FCFA',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      )),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total à payer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(
                        '${cartNotifier.total.toStringAsFixed(0)} FCFA',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFFe94560)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Mode de paiement
            _section(
              title: 'Mode de paiement',
              icon: Icons.payment,
              child: Column(
                children: [
                  _PaymentOption(
                    value: 'orange_money',
                    label: 'Orange Money',
                    subtitle: 'Paiement mobile Orange',
                    icon: Icons.phone_android,
                    color: Colors.orange,
                    groupValue: _paymentMethod,
                    onChanged: (v) => setState(() => _paymentMethod = v!),
                  ),
                  const SizedBox(height: 8),
                  _PaymentOption(
                    value: 'wave',
                    label: 'Wave',
                    subtitle: 'Paiement mobile Wave',
                    icon: Icons.waves,
                    color: Colors.blue,
                    groupValue: _paymentMethod,
                    onChanged: (v) => setState(() => _paymentMethod = v!),
                  ),
                ],
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Color(0xFFe94560)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xFFe94560)))),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _loading ? null : _placeOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFe94560),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _loading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.lock_outline, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Confirmer et payer ${cartNotifier.total.toStringAsFixed(0)} FCFA',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _section({required String title, required IconData icon, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 18, color: const Color(0xFF1a1a2e)),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1a1a2e))),
          ]),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _imgPlaceholder() => Container(
        width: 48, height: 48,
        color: Colors.grey[100],
        child: const Icon(Icons.image_outlined, color: Colors.grey, size: 24),
      );
}

// Option de paiement
class _PaymentOption extends StatelessWidget {
  final String value, label, subtitle, groupValue;
  final IconData icon;
  final Color color;
  final ValueChanged<String?> onChanged;

  const _PaymentOption({
    required this.value, required this.label, required this.subtitle,
    required this.icon, required this.color, required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: selected ? const Color(0xFFe94560) : Colors.grey[300]!, width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(10),
          color: selected ? const Color(0xFFe94560).withOpacity(0.05) : Colors.white,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            Radio<String>(
              value: value,
              groupValue: groupValue,
              onChanged: onChanged,
              activeColor: const Color(0xFFe94560),
            ),
          ],
        ),
      ),
    );
  }
}

// Dialog de confirmation
class _ConfirmationDialog extends StatelessWidget {
  final int orderId;
  final double total;
  final String reference;
  final String paymentMethod;
  final bool isSimulation;
  final String instructions;

  const _ConfirmationDialog({
    required this.orderId,
    required this.total,
    required this.reference,
    required this.paymentMethod,
    required this.isSimulation,
    required this.instructions,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(color: Color(0xFFE8F5E9), shape: BoxShape.circle),
              child: const Icon(Icons.check_circle, color: Colors.green, size: 48),
            ),
            const SizedBox(height: 16),
            const Text('Commande créée !', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Commande #$orderId', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            _infoRow('Montant', '${total.toStringAsFixed(0)} FCFA'),
            _infoRow('Paiement', paymentMethod == 'orange_money' ? 'Orange Money' : 'Wave'),
            _infoRow('Référence', reference),
            const SizedBox(height: 12),

            // Bandeau simulation ou instructions réelles
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSimulation ? Colors.orange.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isSimulation ? Colors.orange : Colors.green),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isSimulation ? Icons.info_outline : Icons.phone_android,
                        color: isSimulation ? Colors.orange : Colors.green,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isSimulation ? 'Mode simulation' : 'Instructions de paiement',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isSimulation ? Colors.orange : Colors.green,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isSimulation
                        ? instructions.isNotEmpty
                            ? instructions
                            : 'Aucun vrai argent n\'est débité. Pour activer le vrai paiement, configurez les clés API Orange Money ou Wave dans le backend.'
                        : instructions,
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFe94560),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Voir mes commandes'),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
            Flexible(
              child: Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      );
}
