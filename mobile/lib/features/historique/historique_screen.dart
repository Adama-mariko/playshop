import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/models/order.dart';

final _historiqueProvider = FutureProvider.autoDispose<List<Order>>((ref) async {
  final res = await ApiClient.instance.get('/orders');
  final list = res.data as List<dynamic>;
  return list
      .map((e) => Order.fromJson(e))
      .where((o) => o.paymentStatus == 'success')
      .toList();
});

const _kPrimary = Color(0xFFe94560);
const _kDark    = Color(0xFF1a1a2e);

const _payOptions = [
  {'value': 'wave',   'label': 'Wave',         'icon': '🌊'},
  {'value': 'orange', 'label': 'Orange Money', 'icon': '🟠'},
  {'value': 'mtn',    'label': 'MTN MoMo',     'icon': '🟡'},
  {'value': 'moov',   'label': 'Moov Money',   'icon': '🔵'},
  {'value': 'djamo',  'label': 'Djamo',        'icon': '💳'},
];

String _payLabel(String? m) => (_payOptions.firstWhere((o) => o['value'] == m, orElse: () => {'label': m ?? '—'})['label'] as String);
String _payIcon(String? m)  => (_payOptions.firstWhere((o) => o['value'] == m, orElse: () => {'icon': '💰'})['icon'] as String);

String _fmtTime(String d) {
  try {
    final dt = DateTime.parse(d).toLocal();
    final h = dt.hour.toString().padLeft(2, '0');
    final mn = dt.minute.toString().padLeft(2, '0');
    return '${h}H$mn';
  } catch (_) { return ''; }
}

String _fmtDay(String d) {
  try {
    final dt = DateTime.parse(d).toLocal();
    const days = ['lun.','mar.','mer.','jeu.','ven.','sam.','dim.'];
    const months = ['jan.','fév.','mar.','avr.','mai','juin','juil.','août','sep.','oct.','nov.','déc.'];
    return '${days[dt.weekday - 1]} ${dt.day} ${months[dt.month - 1]}. ${dt.year}';
  } catch (_) { return d; }
}

// ══════════════════════════════════════════════
// Écran Historique
// ══════════════════════════════════════════════
class HistoriqueScreen extends ConsumerStatefulWidget {
  const HistoriqueScreen({super.key});

  @override
  ConsumerState<HistoriqueScreen> createState() => _HistoriqueScreenState();
}

class _HistoriqueScreenState extends ConsumerState<HistoriqueScreen> {
  String _search = '';
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_historiqueProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Historique', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _kDark,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(_historiqueProvider),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _kPrimary)),
        error: (e, _) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('Impossible de charger l\'historique', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => ref.refresh(_historiqueProvider),
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
            style: ElevatedButton.styleFrom(backgroundColor: _kPrimary, foregroundColor: Colors.white),
          ),
        ])),
        data: (all) {
          // Filtrage
          final filtered = all.where((t) {
            final matchMethod = _filter == 'all' || t.paymentMethod == _filter;
            final q = _search.toLowerCase();
            final matchSearch = q.isEmpty ||
                (t.paymentReference ?? '').toLowerCase().contains(q) ||
                (t.phoneNumber ?? '').contains(q) ||
                _payLabel(t.paymentMethod).toLowerCase().contains(q);
            return matchMethod && matchSearch;
          }).toList();

          return RefreshIndicator(
            color: _kPrimary,
            onRefresh: () => ref.refresh(_historiqueProvider.future),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Titre + résumé
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Transactions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _kDark)),
                  Text('${filtered.length} résultat${filtered.length > 1 ? 's' : ''}',
                      style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ]),
                const SizedBox(height: 12),

                // Résumé cards
                if (all.isNotEmpty) ...[
                  Row(children: [
                    Expanded(child: _SumCard(
                      icon: Icons.payments_outlined,
                      color: const Color(0xFF059669),
                      value: '${all.length}',
                      label: 'Transaction${all.length > 1 ? 's' : ''}',
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _SumCard(
                      icon: Icons.account_balance_wallet_outlined,
                      color: const Color(0xFF7C3AED),
                      value: '${all.fold(0.0, (s, t) => s + t.totalAmount).toStringAsFixed(0)} F',
                      label: 'Total encaissé',
                    )),
                  ]),
                  const SizedBox(height: 16),
                ],

                // Barre de recherche
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: TextField(
                    onChanged: (v) => setState(() => _search = v),
                    decoration: InputDecoration(
                      hintText: 'Rechercher par référence, numéro...',
                      hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      suffixIcon: _search.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, color: Colors.grey),
                              onPressed: () => setState(() => _search = ''),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Filtres méthode
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    _FilterChip(label: 'Tous', selected: _filter == 'all', onTap: () => setState(() => _filter = 'all')),
                    ..._payOptions.map((o) => _FilterChip(
                      label: '${o['icon']} ${o['label']}',
                      selected: _filter == o['value'],
                      onTap: () => setState(() => _filter = o['value'] as String),
                    )),
                  ]),
                ),
                const SizedBox(height: 16),

                // Tableau
                if (filtered.isEmpty)
                  Center(child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Column(children: [
                      const Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text(
                        _search.isNotEmpty || _filter != 'all'
                            ? 'Aucun résultat pour cette recherche'
                            : 'Aucune transaction pour l\'instant',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ]),
                  ))
                else
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 2))],
                    ),
                    child: Column(children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                        ),
                        child: const Row(children: [
                          Expanded(flex: 3, child: Text('OPÉRATEUR',   style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey, letterSpacing: 0.5))),
                          Expanded(flex: 2, child: Text('MONTANT',     style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey, letterSpacing: 0.5))),
                          Expanded(flex: 3, child: Text('RÉFÉRENCE',   style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey, letterSpacing: 0.5))),
                          Expanded(flex: 2, child: Text('TYPE',        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey, letterSpacing: 0.5))),
                          Expanded(flex: 2, child: Text('HEURE ET DATE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey, letterSpacing: 0.5))),
                          SizedBox(width: 36, child: Text('STATUT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey, letterSpacing: 0.5))),
                        ]),
                      ),
                      const Divider(height: 1),

                      // Lignes
                      ...filtered.asMap().entries.map((entry) {
                        final isLast = entry.key == filtered.length - 1;
                        final tx = entry.value;
                        return _TxRow(tx: tx, isLast: isLast);
                      }),
                    ]),
                  ),

                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════
// Ligne transaction
// ══════════════════════════════════════════════
class _TxRow extends StatelessWidget {
  final Order tx;
  final bool isLast;
  const _TxRow({required this.tx, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        // Opérateur
        Expanded(flex: 3, child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle,
                border: Border.all(color: Colors.grey[200]!)),
            child: Center(child: Text(_payIcon(tx.paymentMethod), style: const TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_payLabel(tx.paymentMethod),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                overflow: TextOverflow.ellipsis),
            Text(tx.phoneNumber ?? '—',
                style: const TextStyle(color: Colors.grey, fontSize: 11),
                overflow: TextOverflow.ellipsis),
          ])),
        ])),

        // Montant
        Expanded(flex: 2, child: Text(
          '+ ${tx.totalAmount.toStringAsFixed(0)} F CFA',
          style: const TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.w700, fontSize: 12),
        )),

        // Référence
        Expanded(flex: 3, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(4)),
          child: Text(
            tx.paymentReference ?? '#${tx.id}',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Color(0xFF374151)),
            overflow: TextOverflow.ellipsis,
          ),
        )),

        // Type
        Expanded(flex: 2, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(color: const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(20)),
          child: const Text('Encaissement',
              style: TextStyle(color: Color(0xFF6D28D9), fontSize: 10, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center),
        )),

        // Heure et date
        Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_fmtTime(tx.updatedAt),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: _kDark)),
          Text(_fmtDay(tx.updatedAt),
              style: const TextStyle(color: Colors.grey, fontSize: 10)),
        ])),

        // Statut
        const SizedBox(width: 36, child: Icon(Icons.check_circle, color: Color(0xFF059669), size: 22)),
      ]),
    );
  }
}

// ══════════════════════════════════════════════
// Widgets utilitaires
// ══════════════════════════════════════════════
class _SumCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  const _SumCard({required this.icon, required this.color, required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
    ),
    child: Row(children: [
      Icon(icon, color: color, size: 28),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _kDark),
            overflow: TextOverflow.ellipsis),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
      ])),
    ]),
  );
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? _kPrimary : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? _kPrimary : Colors.grey[300]!),
      ),
      child: Text(label,
          style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.grey[600],
          )),
    ),
  );
}
