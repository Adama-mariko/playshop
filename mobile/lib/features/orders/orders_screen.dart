import 'dart:async';
import 'package:dio/dio.dart';
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
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Impossible de charger les commandes', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => ref.refresh(ordersProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFe94560), foregroundColor: Colors.white),
            ),
          ]),
        ),
        data: (orders) => orders.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('Aucune commande pour l\'instant', style: TextStyle(fontSize: 16, color: Colors.grey)),
              ]))
            : RefreshIndicator(
                color: const Color(0xFFe94560),
                onRefresh: () => ref.refresh(ordersProvider.future),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // En-tête style Jèko
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Historique', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1a1a2e))),
                        Text('${orders.length} commande${orders.length > 1 ? 's' : ''}',
                            style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Tableau transactions
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 2))],
                      ),
                      child: Column(
                        children: [
                          // Header tableau
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF8F9FA),
                              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                            ),
                            child: const Row(children: [
                              Expanded(flex: 3, child: Text('Opérateur', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey))),
                              Expanded(flex: 2, child: Text('Montant', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey))),
                              Expanded(flex: 2, child: Text('Référence', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey))),
                              Expanded(flex: 2, child: Text('Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey))),
                              SizedBox(width: 40, child: Text('Statut', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey))),
                            ]),
                          ),
                          const Divider(height: 1),

                          // Lignes
                          ...orders.asMap().entries.map((entry) {
                            final i = entry.key;
                            final order = entry.value;
                            return _OrderRow(
                              order: order,
                              isLast: i == orders.length - 1,
                              onRefresh: () => ref.refresh(ordersProvider),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

// ══════════════════════════════════════════════
// Ligne de transaction
// ══════════════════════════════════════════════
class _OrderRow extends StatefulWidget {
  final Order order;
  final bool isLast;
  final VoidCallback onRefresh;

  const _OrderRow({required this.order, required this.isLast, required this.onRefresh});

  @override
  State<_OrderRow> createState() => _OrderRowState();
}

class _OrderRowState extends State<_OrderRow> {
  bool _loading = false;

  static const _paymentOptions = [
    {'value': 'wave',   'label': 'Wave',         'icon': '🌊', 'color': Color(0xFF0066FF)},
    {'value': 'orange', 'label': 'Orange Money', 'icon': '🟠', 'color': Color(0xFFFF6600)},
    {'value': 'mtn',    'label': 'MTN MoMo',     'icon': '🟡', 'color': Color(0xFFFFCC00)},
    {'value': 'moov',   'label': 'Moov Money',   'icon': '🔵', 'color': Color(0xFF0099CC)},
    {'value': 'djamo',  'label': 'Djamo',        'icon': '💳', 'color': Color(0xFF6C3CE1)},
  ];

  Map<String, dynamic> get _payOpt => _paymentOptions.firstWhere(
    (o) => o['value'] == widget.order.paymentMethod,
    orElse: () => {'label': widget.order.paymentMethod ?? '—', 'icon': '💰', 'color': Colors.grey},
  );

  String _formatDate(String d) {
    try {
      final dt = DateTime.parse(d).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      final day = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'][dt.weekday - 1];
      final months = ['jan.', 'fév.', 'mar.', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sep.', 'oct.', 'nov.', 'déc.'];
      return '$h:$m\n$day ${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) { return d; }
  }

  Future<void> _payOrder() async {
    final selectedMethod = await showDialog<String>(
      context: context,
      builder: (ctx) => _PaymentMethodDialog(currentMethod: widget.order.paymentMethod ?? 'wave'),
    );
    if (selectedMethod == null) return;

    setState(() => _loading = true);
    try {
      final res = await ApiClient.instance.post('/payments/initiate', data: {'orderId': widget.order.id});
      final paymentUrl = res.data['paymentUrl'] as String? ?? '';
      if (paymentUrl.isNotEmpty) {
        final uri = Uri.parse(paymentUrl);
        if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        String msg = 'Erreur lors du paiement';
        if (e is DioException) msg = e.response?.data?['message'] ?? msg;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancelOrder() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Annuler la commande'),
        content: Text('Annuler la commande #${widget.order.id} ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Non')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Oui', style: TextStyle(color: Color(0xFFe94560)))),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _loading = true);
    try {
      await ApiClient.instance.patch('/orders/${widget.order.id}/cancel');
      widget.onRefresh();
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final opt = _payOpt;

    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: widget.isLast ? null : const Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
        ),
        child: Row(children: [
          // Opérateur
          Expanded(flex: 3, child: Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: (opt['color'] as Color).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Center(child: Text(opt['icon'] as String, style: const TextStyle(fontSize: 18))),
            ),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(opt['label'] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              if (order.items.isNotEmpty)
                Text('${order.items.length} article${order.items.length > 1 ? 's' : ''}',
                    style: const TextStyle(color: Colors.grey, fontSize: 11)),
            ])),
          ])),

          // Montant
          Expanded(flex: 2, child: Text(
            '+ ${order.totalAmount.toStringAsFixed(0)} F',
            style: const TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold, fontSize: 13),
          )),

          // Référence (ID commande)
          Expanded(flex: 2, child: Text(
            '#${order.id}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF1a1a2e), fontWeight: FontWeight.w500),
          )),

          // Date
          Expanded(flex: 2, child: Text(
            _formatDate(order.createdAt),
            style: const TextStyle(fontSize: 11, color: Colors.grey, height: 1.4),
          )),

          // Statut
          SizedBox(width: 40, child: _loading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFe94560)))
              : _StatusIcon(paymentStatus: order.paymentStatus, orderStatus: order.status)),
        ]),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    final order = widget.order;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Commande #${order.id}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            _StatusBadge(paymentStatus: order.paymentStatus, orderStatus: order.status),
          ]),
          const SizedBox(height: 16),
          // Articles
          ...order.items.map((item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(child: Text('${item.product?['name'] ?? 'Produit'} × ${item.quantity}', style: const TextStyle(fontSize: 14))),
              Text('${(item.unitPrice * item.quantity).toStringAsFixed(0)} FCFA', style: const TextStyle(fontWeight: FontWeight.w600)),
            ]),
          )),
          const Divider(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('${order.totalAmount.toStringAsFixed(0)} FCFA',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFFe94560))),
          ]),
          const SizedBox(height: 20),
          // Actions
          if (order.status == 'pending' && order.paymentStatus == 'pending') ...[
            SizedBox(width: double.infinity, child: ElevatedButton.icon(
              onPressed: () { Navigator.pop(context); _payOrder(); },
              icon: const Icon(Icons.payment),
              label: const Text('Payer maintenant'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFe94560), foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            )),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: OutlinedButton(
              onPressed: () { Navigator.pop(context); _cancelOrder(); },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFe94560),
                side: const BorderSide(color: Color(0xFFe94560)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Annuler la commande'),
            )),
          ],
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════
// Icône statut (style Jèko — cercle vert/rouge/orange)
// ══════════════════════════════════════════════
class _StatusIcon extends StatelessWidget {
  final String paymentStatus;
  final String orderStatus;
  const _StatusIcon({required this.paymentStatus, required this.orderStatus});

  @override
  Widget build(BuildContext context) {
    if (paymentStatus == 'success') {
      return Container(
        width: 28, height: 28,
        decoration: const BoxDecoration(color: Color(0xFFD1FAE5), shape: BoxShape.circle),
        child: const Icon(Icons.check, color: Color(0xFF059669), size: 16),
      );
    }
    if (paymentStatus == 'failed' || orderStatus == 'cancelled') {
      return Container(
        width: 28, height: 28,
        decoration: const BoxDecoration(color: Color(0xFFFEE2E2), shape: BoxShape.circle),
        child: const Icon(Icons.close, color: Color(0xFFDC2626), size: 16),
      );
    }
    return Container(
      width: 28, height: 28,
      decoration: const BoxDecoration(color: Color(0xFFFEF3C7), shape: BoxShape.circle),
      child: const Icon(Icons.schedule, color: Color(0xFFD97706), size: 16),
    );
  }
}

// ══════════════════════════════════════════════
// Badge statut (pour le bottom sheet)
// ══════════════════════════════════════════════
class _StatusBadge extends StatelessWidget {
  final String paymentStatus;
  final String orderStatus;
  const _StatusBadge({required this.paymentStatus, required this.orderStatus});

  @override
  Widget build(BuildContext context) {
    String label; Color bg; Color fg;
    if (paymentStatus == 'success') {
      label = 'Payée'; bg = const Color(0xFFD1FAE5); fg = const Color(0xFF059669);
    } else if (paymentStatus == 'failed' || orderStatus == 'cancelled') {
      label = orderStatus == 'cancelled' ? 'Annulée' : 'Échouée';
      bg = const Color(0xFFFEE2E2); fg = const Color(0xFFDC2626);
    } else {
      label = 'En attente'; bg = const Color(0xFFFEF3C7); fg = const Color(0xFFD97706);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}

// ══════════════════════════════════════════════
// Dialog sélection méthode de paiement
// ══════════════════════════════════════════════
class _PaymentMethodDialog extends StatefulWidget {
  final String currentMethod;
  const _PaymentMethodDialog({required this.currentMethod});

  @override
  State<_PaymentMethodDialog> createState() => _PaymentMethodDialogState();
}

class _PaymentMethodDialogState extends State<_PaymentMethodDialog> {
  static const _options = [
    {'value': 'wave',   'label': 'Wave',         'icon': '🌊', 'desc': 'Paiement via Wave'},
    {'value': 'orange', 'label': 'Orange Money', 'icon': '🟠', 'desc': 'Paiement via Orange Money'},
    {'value': 'mtn',    'label': 'MTN MoMo',     'icon': '🟡', 'desc': 'Paiement via MTN Mobile Money'},
    {'value': 'moov',   'label': 'Moov Money',   'icon': '🔵', 'desc': 'Paiement via Moov Money'},
    {'value': 'djamo',  'label': 'Djamo',        'icon': '💳', 'desc': 'Paiement via Djamo'},
  ];

  late String _selected;

  @override
  void initState() { super.initState(); _selected = widget.currentMethod; }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Mode de paiement', style: TextStyle(fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: _options.map((opt) {
          final selected = _selected == opt['value'];
          return GestureDetector(
            onTap: () => setState(() => _selected = opt['value'] as String),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: selected ? const Color(0xFFe94560) : Colors.grey[300]!, width: selected ? 2 : 1),
                borderRadius: BorderRadius.circular(10),
                color: selected ? const Color(0xFFe94560).withValues(alpha: 0.04) : Colors.white,
              ),
              child: Row(children: [
                Text(opt['icon'] as String, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(opt['label'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(opt['desc'] as String, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ])),
                if (selected) const Icon(Icons.check_circle, color: Color(0xFFe94560), size: 20),
              ]),
            ),
          );
        }).toList(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler', style: TextStyle(color: Colors.grey))),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _selected),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFe94560), foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          child: const Text('Continuer'),
        ),
      ],
    );
  }
}
