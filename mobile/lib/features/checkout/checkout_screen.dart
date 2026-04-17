import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api/api_client.dart';
import '../../core/providers/cart_provider.dart';

enum PayStep { form, payment, confirmed, failed }

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> with WidgetsBindingObserver {
  PayStep _step = PayStep.form;

  // Méthodes de paiement — valeurs exactes attendues par Jèko et le backend
  static const _paymentOptions = [
    {'value': 'wave',   'label': 'Wave',         'icon': '🌊', 'desc': 'Paiement via Wave',             'prefixes': ['01','05','06','07','08','09']},
    {'value': 'orange', 'label': 'Orange Money', 'icon': '🟠', 'desc': 'Paiement via Orange Money',     'prefixes': ['07','08','09']},
    {'value': 'mtn',    'label': 'MTN MoMo',     'icon': '🟡', 'desc': 'Paiement via MTN Mobile Money', 'prefixes': ['05','06']},
    {'value': 'moov',   'label': 'Moov Money',   'icon': '🔵', 'desc': 'Paiement via Moov Money',       'prefixes': ['01']},
    {'value': 'djamo',  'label': 'Djamo',        'icon': '💳', 'desc': 'Paiement via Djamo',            'prefixes': ['01','05','06','07','08','09']},
  ];

  String _paymentMethod = 'wave';
  final _phoneCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  int    _orderId       = 0;
  String _reference     = '';
  String _paymentUrl    = '';
  double _totalSnapshot = 0;

  Timer? _pollTimer;
  int    _pollCount = 0;
  static const int _maxPoll = 80; // ~4 minutes

  // Détecte le retour de l'app externe (Jèko) pour déclencher une vérification immédiate
  bool _wasInBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _phoneCtrl.dispose();
    super.dispose();
  }

  // Quand l'utilisateur revient de l'app de paiement (Wave, Orange, MTN...)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _wasInBackground = true;
    } else if (state == AppLifecycleState.resumed && _wasInBackground && _step == PayStep.payment) {
      _wasInBackground = false;
      // Vérification immédiate au retour
      _checkStatusNow();
    }
  }

  Future<void> _checkStatusNow() async {
    if (_orderId == 0) return;
    try {
      final res = await ApiClient.instance.get('/payments/status/$_orderId');
      final status = res.data['paymentStatus'];
      if (!mounted) return;
      if (status == 'success') {
        _pollTimer?.cancel();
        setState(() => _step = PayStep.confirmed);
      } else if (status == 'failed') {
        _pollTimer?.cancel();
        setState(() => _step = PayStep.failed);
      }
    } catch (_) {}
  }

  String? _validatePhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'[\s\-\.\(\)\+]'), '').replaceAll(RegExp(r'^225'), '');
    if (digits.length != 10) return 'Le numéro doit contenir 10 chiffres';
    final prefix = digits.substring(0, 2);
    const allPrefixes = ['01', '05', '06', '07', '08', '09'];
    if (!allPrefixes.contains(prefix)) return 'Préfixe "$prefix" non reconnu';
    final opt = _paymentOptions.firstWhere((o) => o['value'] == _paymentMethod, orElse: () => _paymentOptions[0]);
    final prefixes = opt['prefixes'] as List<dynamic>;
    if (!prefixes.contains(prefix)) {
      return '${opt['label']} : préfixes ${prefixes.join(', ')} uniquement';
    }
    return null;
  }

  String _networkLabel(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 2) return '';
    const labels = {'01': 'Moov', '05': 'MTN', '06': 'MTN', '07': 'Orange', '08': 'Orange', '09': 'Orange'};
    return labels[digits.substring(0, 2)] ?? '';
  }

  Future<void> _placeOrder() async {
    final cartItems = ref.read(cartProvider);
    if (cartItems.isEmpty) return;
    if (_phoneCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Veuillez entrer votre numéro de téléphone');
      return;
    }
    final phoneErr = _validatePhone(_phoneCtrl.text.trim());
    if (phoneErr != null) {
      setState(() => _error = phoneErr);
      return;
    }

    setState(() { _loading = true; _error = null; });
    _totalSnapshot = ref.read(cartProvider.notifier).total;

    try {
      // 1. Créer la commande avec la bonne méthode de paiement
      final orderRes = await ApiClient.instance.post('/orders', data: {
        'items': cartItems.map((i) => {'productId': i.product.id, 'quantity': i.quantity}).toList(),
        'paymentMethod': _paymentMethod, // wave | orange | mtn | moov | djamo
        'phoneNumber': _phoneCtrl.text.trim(),
      });
      _orderId = orderRes.data['order']['id'];

      // 2. Initier le paiement Jèko avec le paramètre mobile=1
      final payRes = await ApiClient.instance.post('/payments/initiate', data: {
        'orderId': _orderId,
        'mobile': '1', // Indique que la requête vient du mobile
      });
      _reference  = payRes.data['reference'];
      _paymentUrl = payRes.data['paymentUrl'];

      ref.read(cartProvider.notifier).clear();

      // 3. Ouvrir l'URL Jèko (redirige vers Wave/Orange/MTN/Moov/Djamo)
      final uri = Uri.parse(_paymentUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }

      setState(() => _step = PayStep.payment);
      _startPolling();
    } catch (e) {
      String msg = 'Erreur lors de la commande. Réessayez.';
      if (e is DioException) {
        msg = e.response?.data?['message'] ?? msg;
      }
      setState(() => _error = msg);
    } finally {
      setState(() => _loading = false);
    }
  }

  void _startPolling() {
    _pollCount = 0;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      _pollCount++;
      if (_pollCount > _maxPoll) { timer.cancel(); return; }
      try {
        final res = await ApiClient.instance.get('/payments/status/$_orderId');
        final status = res.data['paymentStatus'];
        if (!mounted) { timer.cancel(); return; }
        if (status == 'success') {
          timer.cancel();
          setState(() => _step = PayStep.confirmed);
        } else if (status == 'failed') {
          timer.cancel();
          setState(() => _step = PayStep.failed);
        }
      } catch (_) {}
    });
  }

  Future<void> _confirmManual() async {
    try {
      await ApiClient.instance.patch('/payments/confirm-manual/$_orderId');
      _pollTimer?.cancel();
      if (mounted) setState(() => _step = PayStep.confirmed);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Paiement', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1a1a2e),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: switch (_step) {
        PayStep.form      => _buildForm(),
        PayStep.payment   => _buildPayment(),
        PayStep.confirmed => _buildConfirmed(),
        PayStep.failed    => _buildFailed(),
      },
    );
  }

  // ══════════════════════════════════════════════
  // ÉTAPE 1 — Formulaire
  // ══════════════════════════════════════════════
  Widget _buildForm() {
    final cartItems = ref.watch(cartProvider);
    final total = ref.read(cartProvider.notifier).total;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        // Récapitulatif commande
        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Votre commande', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...cartItems.map((item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(child: Text('${item.product.name} × ${item.quantity}', style: const TextStyle(fontSize: 14))),
              Text('${item.subtotal.toStringAsFixed(0)} FCFA', style: const TextStyle(fontWeight: FontWeight.w600)),
            ]),
          )),
          const Divider(),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('${total.toStringAsFixed(0)} FCFA',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFFe94560))),
          ]),
        ])),
        const SizedBox(height: 16),

        // Numéro de téléphone
        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Numéro de téléphone', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), bottomLeft: Radius.circular(8)),
              ),
              child: const Text('+225', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            Expanded(child: TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: '0701234567',
                counterText: '',
                enabledBorder: OutlineInputBorder(
                  borderRadius: const BorderRadius.only(topRight: Radius.circular(8), bottomRight: Radius.circular(8)),
                  borderSide: BorderSide(color: _phoneCtrl.text.isEmpty
                      ? Colors.grey[300]!
                      : _validatePhone(_phoneCtrl.text) == null ? Colors.green : Colors.red),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: const BorderRadius.only(topRight: Radius.circular(8), bottomRight: Radius.circular(8)),
                  borderSide: BorderSide(
                      color: _validatePhone(_phoneCtrl.text) == null ? Colors.green : const Color(0xFFe94560),
                      width: 2),
                ),
                filled: true, fillColor: Colors.white,
                suffixIcon: _phoneCtrl.text.isNotEmpty
                    ? Icon(_validatePhone(_phoneCtrl.text) == null ? Icons.check_circle : Icons.error_outline,
                        color: _validatePhone(_phoneCtrl.text) == null ? Colors.green : Colors.red)
                    : null,
              ),
            )),
          ]),
          const SizedBox(height: 6),
          if (_phoneCtrl.text.isNotEmpty)
            _validatePhone(_phoneCtrl.text) != null
                ? Row(children: [
                    const Icon(Icons.error_outline, size: 14, color: Colors.red),
                    const SizedBox(width: 4),
                    Expanded(child: Text(_validatePhone(_phoneCtrl.text)!, style: const TextStyle(color: Colors.red, fontSize: 12))),
                  ])
                : Row(children: [
                    const Icon(Icons.check_circle, size: 14, color: Colors.green),
                    const SizedBox(width: 4),
                    Text('Réseau ${_networkLabel(_phoneCtrl.text)} — valide', style: const TextStyle(color: Colors.green, fontSize: 12)),
                  ])
          else
            Builder(builder: (_) {
              final opt = _paymentOptions.firstWhere((o) => o['value'] == _paymentMethod, orElse: () => _paymentOptions[0]);
              final prefixes = opt['prefixes'] as List<dynamic>;
              return Text('${opt['label']} : préfixes ${prefixes.join(', ')}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12));
            }),
        ])),
        const SizedBox(height: 16),

        // Mode de paiement
        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Mode de paiement', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ..._paymentOptions.map((opt) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _payOption(opt['value'] as String, opt['icon'] as String, opt['label'] as String, opt['desc'] as String),
          )),
        ])),

        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              const Icon(Icons.error_outline, color: Color(0xFFe94560)),
              const SizedBox(width: 8),
              Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xFFe94560)))),
            ]),
          ),
        ],

        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity, height: 54,
          child: ElevatedButton(
            onPressed: _loading || _validatePhone(_phoneCtrl.text) != null ? null : _placeOrder,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFe94560), foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: _loading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text('🔒 Payer ${total.toStringAsFixed(0)} FCFA',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 20),
      ]),
    );
  }

  // ══════════════════════════════════════════════
  // ÉTAPE 2 — En attente de paiement
  // ══════════════════════════════════════════════
  Widget _buildPayment() {
    final opt = _paymentOptions.firstWhere((o) => o['value'] == _paymentMethod, orElse: () => _paymentOptions[0]);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _card(Column(mainAxisSize: MainAxisSize.min, children: [
          Text(opt['icon'] as String, style: const TextStyle(fontSize: 52)),
          const SizedBox(height: 16),
          Text('Paiement en cours via ${opt['label']}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'Complétez le paiement de ${_totalSnapshot.toStringAsFixed(0)} FCFA dans l\'application ${opt['label']}, puis revenez ici.',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          const CircularProgressIndicator(color: Color(0xFFe94560)),
          const SizedBox(height: 8),
          const Text('Vérification automatique en cours...', style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 4),
          Text('Réf : $_reference', style: const TextStyle(color: Colors.grey, fontSize: 11)),
          const SizedBox(height: 20),

          // Bouton vérifier manuellement
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _checkStatusNow,
              icon: const Icon(Icons.refresh),
              label: const Text('J\'ai payé — Vérifier'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFe94560), foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Rouvrir l'app de paiement
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final uri = Uri.parse(_paymentUrl);
                if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
              icon: const Icon(Icons.open_in_new),
              label: Text('Rouvrir ${opt['label']}'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1a1a2e),
                side: const BorderSide(color: Color(0xFF1a1a2e)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Dev only
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFFEF9C3), borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('🛠 Dev — ', style: TextStyle(fontSize: 12, color: Color(0xFF854D0E))),
              GestureDetector(
                onTap: _confirmManual,
                child: const Text('Simuler confirmation',
                    style: TextStyle(fontSize: 12, color: Color(0xFF854D0E),
                        fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
              ),
            ]),
          ),
        ])),
      ),
    );
  }

  // ══════════════════════════════════════════════
  // ÉTAPE 3 — Confirmé
  // ══════════════════════════════════════════════
  Widget _buildConfirmed() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 80, height: 80,
          decoration: const BoxDecoration(color: Color(0xFFD1FAE5), shape: BoxShape.circle),
          child: const Icon(Icons.check_circle, color: Color(0xFF059669), size: 48),
        ),
        const SizedBox(height: 20),
        const Text('Paiement confirmé !', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Commande #$_orderId payée avec succès', style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
          child: Text('Réf : $_reference', style: const TextStyle(fontSize: 13)),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context, rootNavigator: true)
                .pushNamedAndRemoveUntil('/home', (r) => false),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFe94560), foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Voir mes commandes', style: TextStyle(fontSize: 16)),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => Navigator.of(context, rootNavigator: true)
              .pushNamedAndRemoveUntil('/home', (r) => false),
          child: const Text('Retour à l\'accueil'),
        ),
      ]),
    ),
  );

  // ══════════════════════════════════════════════
  // ÉTAPE 4 — Échoué
  // ══════════════════════════════════════════════
  Widget _buildFailed() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 80, height: 80,
          decoration: const BoxDecoration(color: Color(0xFFFEE2E2), shape: BoxShape.circle),
          child: const Icon(Icons.cancel, color: Color(0xFFDC2626), size: 48),
        ),
        const SizedBox(height: 20),
        const Text('Paiement échoué', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Le paiement n\'a pas pu être effectué.', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => setState(() { _step = PayStep.form; _error = null; }),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFe94560), foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Réessayer', style: TextStyle(fontSize: 16)),
          ),
        ),
      ]),
    ),
  );

  // ══════════════════════════════════════════════
  // Widgets utilitaires
  // ══════════════════════════════════════════════
  Widget _card(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
    ),
    child: child,
  );

  Widget _payOption(String value, String icon, String label, String sub) {
    final selected = _paymentMethod == value;
    return GestureDetector(
      onTap: () => setState(() => _paymentMethod = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: selected ? const Color(0xFFe94560) : Colors.grey[300]!, width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(10),
          color: selected ? const Color(0xFFe94560).withValues(alpha: 0.04) : Colors.white,
        ),
        child: Row(children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(sub, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ])),
          if (selected) const Icon(Icons.check_circle, color: Color(0xFFe94560)),
        ]),
      ),
    );
  }
}
