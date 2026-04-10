import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api/api_client.dart';
import '../../core/models/order.dart';

final ordersProvider = FutureProvider.autoDispose<List<Order>>((ref) async {
  final res = await ApiClient.instance.get('/orders');
  final list = res.data as List<dynamic>;
  return list.map((e) => Order.fromJson(e)).toList();
});

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Mes Commandes', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1a1a2e),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(ordersProvider),
          ),
        ],
      ),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFe94560))),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('Impossible de charger les commandes', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => ref.refresh(ordersProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFe94560),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        data: (orders) => orders.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text('Aucune commande pour l\'instant',
                        style: TextStyle(fontSize: 16, color: Colors.grey)),
                    const SizedBox(height: 8),
                    const Text('Vos commandes apparaîtront ici',
                        style: TextStyle(fontSize: 13, color: Colors.grey)),
                  ],
                ),
              )
            : RefreshIndicator(
                color: const Color(0xFFe94560),
                onRefresh: () => ref.refresh(ordersProvider.future),
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: orders.length,
                  itemBuilder: (context, index) => _OrderCard(
                    order: orders[index],
                    onRefresh: () => ref.refresh(ordersProvider),
                  ),
                ),
              ),
      ),
    );
  }
}

// ══════════════════════════════════════════════
// Carte commande
// ══════════════════════════════════════════════
class _OrderCard extends StatefulWidget {
  final Order order;
  final VoidCallback onRefresh;

  const _OrderCard({required this.order, required this.onRefresh});

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  bool _loading = false;

  Color get _statusColor {
    switch (widget.order.status) {
      case 'paid':      return Colors.green;
      case 'shipped':   return Colors.blue;
      case 'cancelled': return Colors.red;
      default:          return Colors.orange;
    }
  }

  String get _statusLabel {
    switch (widget.order.status) {
      case 'pending':   return 'En attente';
      case 'paid':      return 'Payée';
      case 'shipped':   return 'Expédiée';
      case 'cancelled': return 'Annulée';
      default:          return widget.order.status;
    }
  }

  String get _paymentLabel {
    switch (widget.order.paymentMethod) {
      case 'orange_money': return 'Orange Money';
      case 'wave':         return 'Wave';
      default:             return widget.order.paymentMethod ?? '—';
    }
  }

  // ── Annuler la commande
  Future<void> _cancelOrder() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Annuler la commande'),
        content: Text('Voulez-vous annuler la commande #${widget.order.id} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Non'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Oui, annuler', style: TextStyle(color: Color(0xFFe94560))),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      await ApiClient.instance.patch('/orders/${widget.order.id}/cancel');
      widget.onRefresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible d\'annuler cette commande'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Supprimer la commande (annulée uniquement)
  Future<void> _deleteOrder() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer la commande'),
        content: Text('Supprimer définitivement la commande #${widget.order.id} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Non'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      await ApiClient.instance.delete('/orders/${widget.order.id}');
      widget.onRefresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible de supprimer cette commande'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Payer la commande (initie le paiement et ouvre l'app)
  Future<void> _payOrder() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.instance.post(
        '/payments/initiate',
        data: {'orderId': widget.order.id},
      );

      final deepLink   = res.data['deepLink'] as String? ?? '';
      final paymentUrl = res.data['paymentUrl'] as String? ?? '';

      // Ouvrir l'app de paiement (deep link en priorité)
      bool launched = false;
      if (deepLink.isNotEmpty) {
        final uri = Uri.parse(deepLink);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          launched = true;
        }
      }
      if (!launched && paymentUrl.isNotEmpty) {
        final uri = Uri.parse(paymentUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          launched = true;
        }
      }

      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible d\'ouvrir l\'application de paiement'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Démarrer le polling pour détecter la confirmation
      if (mounted) {
        _showPaymentWaitingDialog(res.data['reference'] as String? ?? '');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de l\'initiation du paiement'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Dialog d'attente de confirmation de paiement
  void _showPaymentWaitingDialog(String reference) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PaymentPollingDialog(
        orderId: widget.order.id,
        reference: reference,
        paymentMethod: widget.order.paymentMethod ?? 'wave',
        amount: widget.order.totalAmount,
        onConfirmed: () {
          Navigator.of(context).pop();
          widget.onRefresh();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Paiement confirmé !'),
              backgroundColor: Colors.green,
            ),
          );
        },
        onFailed: () {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Paiement échoué ou expiré'),
              backgroundColor: Colors.red,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Commande #${order.id}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(_statusLabel,
                      style: TextStyle(
                          color: _statusColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _formatDate(order.createdAt),
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const Divider(height: 20),

            // Articles
            ...order.items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${item.product?['name'] ?? 'Produit'} × ${item.quantity}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      Text(
                        '${(item.unitPrice * item.quantity).toStringAsFixed(0)} FCFA',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                )),

            const Divider(height: 20),

            // Total + paiement
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Via $_paymentLabel',
                        style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 2),
                    _PaymentBadge(status: order.paymentStatus),
                  ],
                ),
                Text(
                  '${order.totalAmount.toStringAsFixed(0)} FCFA',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFe94560)),
                ),
              ],
            ),

            // Actions selon le statut
            if (_loading) ...[
              const SizedBox(height: 12),
              const Center(child: CircularProgressIndicator(color: Color(0xFFe94560), strokeWidth: 2)),
            ] else ...[
              // Commande en attente → Payer + Annuler
              if (order.status == 'pending') ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _payOrder,
                        icon: Text(
                          order.paymentMethod == 'wave' ? '🌊' : '🟠',
                          style: const TextStyle(fontSize: 16),
                        ),
                        label: Text(
                          'Payer via ${order.paymentMethod == 'wave' ? 'Wave' : 'Orange Money'}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: order.paymentMethod == 'wave'
                              ? const Color(0xFF0066FF)
                              : const Color(0xFFFF6600),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _cancelOrder,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFe94560),
                        side: const BorderSide(color: Color(0xFFe94560)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      ),
                      child: const Icon(Icons.cancel_outlined, size: 20),
                    ),
                  ],
                ),
              ],

              // Commande annulée → Supprimer
              if (order.status == 'cancelled') ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _deleteOrder,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Supprimer'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} à ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }
}

// ══════════════════════════════════════════════
// Dialog de polling après ouverture de l'app
// ══════════════════════════════════════════════
class _PaymentPollingDialog extends StatefulWidget {
  final int orderId;
  final String reference;
  final String paymentMethod;
  final double amount;
  final VoidCallback onConfirmed;
  final VoidCallback onFailed;

  const _PaymentPollingDialog({
    required this.orderId,
    required this.reference,
    required this.paymentMethod,
    required this.amount,
    required this.onConfirmed,
    required this.onFailed,
  });

  @override
  State<_PaymentPollingDialog> createState() => _PaymentPollingDialogState();
}

class _PaymentPollingDialogState extends State<_PaymentPollingDialog> {
  Timer? _timer;
  int _seconds = 0;
  static const int _maxSeconds = 180; // 3 min

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      _seconds += 3;
      if (_seconds >= _maxSeconds) {
        timer.cancel();
        if (mounted) widget.onFailed();
        return;
      }
      try {
        final res = await ApiClient.instance.get('/payments/status/${widget.orderId}');
        final status = res.data['paymentStatus'];
        if (status == 'success') {
          timer.cancel();
          if (mounted) widget.onConfirmed();
        } else if (status == 'failed') {
          timer.cancel();
          if (mounted) widget.onFailed();
        } else {
          if (mounted) setState(() {});
        }
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWave = widget.paymentMethod == 'wave';
    final remaining = _maxSeconds - _seconds;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(isWave ? '🌊' : '🟠', style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text(
            isWave ? 'En attente de Wave' : 'En attente d\'Orange Money',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Confirmez le paiement de\n${widget.amount.toStringAsFixed(0)} FCFA dans l\'application',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const CircularProgressIndicator(color: Color(0xFFe94560)),
          const SizedBox(height: 12),
          Text(
            'Expiration dans ${remaining}s',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            'Réf : ${widget.reference}',
            style: const TextStyle(color: Colors.grey, fontSize: 11),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            _timer?.cancel();
            Navigator.of(context).pop();
          },
          child: const Text('Fermer', style: TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════
// Badge statut paiement
// ══════════════════════════════════════════════
class _PaymentBadge extends StatelessWidget {
  final String status;
  const _PaymentBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case 'success':
        color = Colors.green;
        label = 'Paiement reçu';
        break;
      case 'failed':
        color = Colors.red;
        label = 'Paiement échoué';
        break;
      default:
        color = Colors.orange;
        label = 'Paiement en attente';
    }
    return Row(
      children: [
        Icon(Icons.circle, size: 8, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
