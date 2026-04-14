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

const _kPrimary = Color(0xFFe94560);
const _kDark    = Color(0xFF1a1a2e);

const _payOptions = [
  {'value': 'wave',   'label': 'Wave',         'icon': '🌊', 'color': Color(0xFF0066FF)},
  {'value': 'orange', 'label': 'Orange Money', 'icon': '🟠', 'color': Color(0xFFFF6600)},
  {'value': 'mtn',    'label': 'MTN MoMo',     'icon': '🟡', 'color': Color(0xFFFFCC00)},
  {'value': 'moov',   'label': 'Moov Money',   'icon': '🔵', 'color': Color(0xFF0099CC)},
  {'value': 'djamo',  'label': 'Djamo',        'icon': '💳', 'color': Color(0xFF6C3CE1)},
];

Map<String, dynamic> _payOpt(String? method) => _payOptions.firstWhere(
  (o) => o['value'] == method,
  orElse: () => {'label': method ?? '—', 'icon': '💰', 'color': Colors.grey},
);

String _fmtDate(String d) {
  try {
    final dt = DateTime.parse(d).toLocal();
    final months = ['jan.','fév.','mar.','avr.','mai','juin','juil.','août','sep.','oct.','nov.','déc.'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  } catch (_) { return d; }
}

// ══════════════════════════════════════════════
// Écran Commandes
// ══════════════════════════════════════════════
class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Mes Commandes', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _kDark,
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
        loading: () => const Center(child: CircularProgressIndicator(color: _kPrimary)),
        error: (e, _) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('Impossible de charger les commandes', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => ref.refresh(ordersProvider),
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
            style: ElevatedButton.styleFrom(backgroundColor: _kPrimary, foregroundColor: Colors.white),
          ),
        ])),
        data: (orders) {
          if (orders.isEmpty) {
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('Aucune commande pour l\'instant', style: TextStyle(fontSize: 16, color: Colors.grey)),
            ]));
          }
          return RefreshIndicator(
            color: _kPrimary,
            onRefresh: () => ref.refresh(ordersProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _OrderCard(
                order: orders[i],
                onRefresh: () => ref.refresh(ordersProvider),
              ),
            ),
          );
        },
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

  Order get o => widget.order;

  Future<void> _payOrder() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.instance.post('/payments/initiate', data: {'orderId': o.id});
      final url = res.data['paymentUrl'] as String? ?? '';
      if (url.isNotEmpty) {
        final uri = Uri.parse(url);
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Annuler la commande', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Annuler la commande #${o.id} ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Non')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Oui', style: TextStyle(color: _kPrimary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _loading = true);
    try {
      await ApiClient.instance.patch('/orders/${o.id}/cancel');
      widget.onRefresh();
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final opt = _payOpt(o.paymentMethod);
    final isPaid      = o.paymentStatus == 'success';
    final isCancelled = o.status == 'cancelled';
    final isFailed    = o.paymentStatus == 'failed';

    return Opacity(
      opacity: isCancelled ? 0.6 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 2))],
        ),
        child: Column(children: [
          // En-tête
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: (opt['color'] as Color).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(child: Text(opt['icon'] as String, style: const TextStyle(fontSize: 20))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Commande #${o.id}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text(_fmtDate(o.createdAt), style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ])),
              _StatusBadge(paymentStatus: o.paymentStatus, orderStatus: o.status),
            ]),
          ),

          const Divider(height: 1, indent: 16, endIndent: 16),

          // Articles
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              children: o.items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Expanded(child: Text(
                    '${item.product?['name'] ?? 'Produit'} × ${item.quantity}',
                    style: const TextStyle(fontSize: 13),
                  )),
                  Text(
                    '${(item.unitPrice * item.quantity).toStringAsFixed(0)} FCFA',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ]),
              )).toList(),
            ),
          ),

          const Divider(height: 1, indent: 16, endIndent: 16),

          // Pied
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Row(children: [
              // Méthode + téléphone
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _MetaChip(icon: Icons.payment_outlined, label: opt['label'] as String),
                if (o.phoneNumber != null) ...[
                  const SizedBox(height: 4),
                  _MetaChip(icon: Icons.phone_iphone_outlined, label: o.phoneNumber!),
                ],
              ])),
              // Total + actions
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                const Text('Total', style: TextStyle(fontSize: 11, color: Colors.grey)),
                Text(
                  '${o.totalAmount.toStringAsFixed(0)} FCFA',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _kPrimary),
                ),
                if (o.status == 'pending' && !isFailed) ...[
                  const SizedBox(height: 8),
                  if (_loading)
                    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _kPrimary))
                  else
                    Row(children: [
                      if (o.paymentStatus == 'pending')
                        _ActionBtn(label: 'Payer', icon: Icons.payment, onTap: _payOrder, primary: true),
                      const SizedBox(width: 6),
                      _ActionBtn(label: 'Annuler', icon: Icons.delete_outline, onTap: _cancelOrder, primary: false),
                    ]),
                ],
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 14, color: Colors.grey),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
  ]);
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;
  const _ActionBtn({required this.label, required this.icon, required this.onTap, required this.primary});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: primary ? _kDark : const Color(0xFFFFF5F5),
        borderRadius: BorderRadius.circular(8),
        border: primary ? null : Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: primary ? Colors.white : _kPrimary),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: primary ? Colors.white : _kPrimary)),
      ]),
    ),
  );
}

// ══════════════════════════════════════════════
// Badge statut
// ══════════════════════════════════════════════
class _StatusBadge extends StatelessWidget {
  final String paymentStatus;
  final String orderStatus;
  const _StatusBadge({required this.paymentStatus, required this.orderStatus});

  @override
  Widget build(BuildContext context) {
    String label; Color bg; Color fg; IconData ico;
    if (paymentStatus == 'success') {
      label = 'Payée'; bg = const Color(0xFFD1FAE5); fg = const Color(0xFF059669); ico = Icons.check_circle_outline;
    } else if (orderStatus == 'cancelled') {
      label = 'Annulée'; bg = const Color(0xFFFEE2E2); fg = const Color(0xFFDC2626); ico = Icons.cancel_outlined;
    } else if (paymentStatus == 'failed') {
      label = 'Échouée'; bg = const Color(0xFFFEE2E2); fg = const Color(0xFFDC2626); ico = Icons.error_outline;
    } else {
      label = 'En attente'; bg = const Color(0xFFFEF3C7); fg = const Color(0xFFD97706); ico = Icons.schedule;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(ico, size: 12, color: fg),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 11)),
      ]),
    );
  }
}
