import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/api/api_client.dart';
import '../../core/providers/cart_provider.dart';

// Étapes du flux de paiement
enum PayStep { form, payment, confirmed, failed }

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  PayStep _step = PayStep.form;
  String _paymentMethod = 'wave';
  final _phoneCtrl = TextEditingController();

  bool _loading = false;
  String? _error;

  // Données de paiement
  int _orderId = 0;
  String _reference = '';
  String _paymentUrl = '';
  String _deepLink = '';
  double _totalSnapshot = 0;

  // Polling
  Timer? _pollTimer;
  int _pollCount = 0;
  static const int _maxPoll = 60; // 3 min

  @override
  void dispose() {
    _pollTimer?.cancel();
    _phoneCtrl.dispose();
    super.dispose();
  }

  // Validation numéro ivoirien
  String? _validatePhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'[\s\-\.\(\)\+]'), '').replaceAll(RegExp(r'^225'), '');
    if (digits.length != 10) return 'Le numéro doit contenir 10 chiffres (ex: 0701234567)';
    final prefix = digits.substring(0, 2);
    const allPrefixes = ['01', '05', '06', '07', '08', '09'];
    const orangePrefixes = ['07', '08', '09'];
    if (!allPrefixes.contains(prefix)) return 'Préfixe "$prefix" non reconnu. Valides : 01, 05, 06, 07, 08, 09';
    if (_paymentMethod == 'orange_money' && !orangePrefixes.contains(prefix)) {
      return 'Orange Money : numéros 07, 08, 09 uniquement';
    }
    return null;
  }

  String _networkLabel(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 2) return '';
    final prefix = digits.substring(0, 2);
    const labels = {'01': 'Moov', '05': 'MTN', '06': 'MTN', '07': 'Orange', '08': 'Orange', '09': 'Orange'};
    return labels[prefix] ?? '';
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
      // 1. Créer la commande
      final orderRes = await ApiClient.instance.post('/orders', data: {
        'items': cartItems.map((i) => {'productId': i.product.id, 'quantity': i.quantity}).toList(),
        'paymentMethod': _paymentMethod,
        'phoneNumber': _phoneCtrl.text.trim(),
      });
      _orderId = orderRes.data['order']['id'];

      // 2. Initier le paiement
      final payRes = await ApiClient.instance.post('/payments/initiate', data: {'orderId': _orderId});
      _reference = payRes.data['reference'];
      _paymentUrl = payRes.data['paymentUrl'];
      _deepLink = payRes.data['deepLink'] ?? '';

      ref.read(cartProvider.notifier).clear();
      setState(() { _step = PayStep.payment; });

      // 3. Démarrer le polling
      _startPolling();

      // 4. Ouvrir l'app de paiement automatiquement
      await _openPaymentApp();

    } catch (e) {
      setState(() { _error = 'Erreur lors de la commande. Réessayez.'; });
    } finally {
      setState(() { _loading = false; });
    }
  }

  // ── Ouvrir l'application de paiement (deep link ou URL)
  Future<void> _openPaymentApp() async {
    // Essayer d'abord le deep link (ouvre l'app native)
    if (_deepLink.isNotEmpty) {
      final deepUri = Uri.parse(_deepLink);
      if (await canLaunchUrl(deepUri)) {
        await launchUrl(deepUri, mode: LaunchMode.externalApplication);
        return;
      }
    }
    // Fallback : ouvrir dans le navigateur
    final webUri = Uri.parse(_paymentUrl);
    if (await canLaunchUrl(webUri)) {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  // ── Polling : vérifie le statut toutes les 3 secondes
  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      _pollCount++;
      if (_pollCount > _maxPoll) {
        timer.cancel();
        return;
      }
      try {
        final res = await ApiClient.instance.get('/payments/status/$_orderId');
        final status = res.data['paymentStatus'];
        if (status == 'success') {
          timer.cancel();
          if (mounted) setState(() => _step = PayStep.confirmed);
        } else if (status == 'failed') {
          timer.cancel();
          if (mounted) setState(() => _step = PayStep.failed);
        }
      } catch (_) {}
    });
  }

  // ── Confirmation manuelle (dev/test)
  Future<void> _confirmManual() async {
    await ApiClient.instance.patch('/payments/confirm-manual/$_orderId');
    _pollTimer?.cancel();
    setState(() => _step = PayStep.confirmed);
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
        PayStep.form     => _buildForm(),
        PayStep.payment  => _buildPayment(),
        PayStep.confirmed => _buildConfirmed(),
        PayStep.failed   => _buildFailed(),
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
      child: Column(
        children: [
          // Récapitulatif
          _card(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Votre commande', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ...cartItems.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text('${item.product.name} × ${item.quantity}', style: const TextStyle(fontSize: 14))),
                    Text('${item.subtotal.toStringAsFixed(0)} FCFA', style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              )),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('${total.toStringAsFixed(0)} FCFA', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFFe94560))),
                ],
              ),
            ],
          )),
          const SizedBox(height: 16),

          // Numéro de téléphone
          _card(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Numéro de téléphone', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Indicatif
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), bottomLeft: Radius.circular(8)),
                    ),
                    child: const Text('+225', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                  // Champ numéro
                  Expanded(
                    child: TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: '0701234567',
                        counterText: '',
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.only(topRight: Radius.circular(8), bottomRight: Radius.circular(8)),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: const BorderRadius.only(topRight: Radius.circular(8), bottomRight: Radius.circular(8)),
                          borderSide: BorderSide(color: _phoneCtrl.text.isEmpty ? Colors.grey[300]! : _validatePhone(_phoneCtrl.text) == null ? Colors.green : Colors.red),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: const BorderRadius.only(topRight: Radius.circular(8), bottomRight: Radius.circular(8)),
                          borderSide: BorderSide(color: _validatePhone(_phoneCtrl.text) == null ? Colors.green : const Color(0xFFe94560), width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        suffixIcon: _phoneCtrl.text.isNotEmpty
                            ? Icon(
                                _validatePhone(_phoneCtrl.text) == null ? Icons.check_circle : Icons.error_outline,
                                color: _validatePhone(_phoneCtrl.text) == null ? Colors.green : Colors.red,
                              )
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Message de validation
              if (_phoneCtrl.text.isNotEmpty) ...[
                if (_validatePhone(_phoneCtrl.text) != null)
                  Row(children: [
                    const Icon(Icons.error_outline, size: 14, color: Colors.red),
                    const SizedBox(width: 4),
                    Expanded(child: Text(_validatePhone(_phoneCtrl.text)!, style: const TextStyle(color: Colors.red, fontSize: 12))),
                  ])
                else
                  Row(children: [
                    const Icon(Icons.check_circle, size: 14, color: Colors.green),
                    const SizedBox(width: 4),
                    Text('Réseau ${_networkLabel(_phoneCtrl.text)} — numéro valide', style: const TextStyle(color: Colors.green, fontSize: 12)),
                  ]),
              ] else
                Text(
                  _paymentMethod == 'orange_money'
                      ? 'Orange Money : numéros 07, 08, 09 uniquement'
                      : 'Wave : tous réseaux — Orange (07-09), MTN (05-06), Moov (01)',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
            ],
          )),
          const SizedBox(height: 16),

          // Mode de paiement
          _card(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Mode de paiement', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _payOption('wave', '🌊', 'Wave', 'Ouvre l\'application Wave'),
              const SizedBox(height: 8),
              _payOption('orange_money', '🟠', 'Orange Money', 'Redirige vers Orange Money'),
            ],
          )),

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
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _loading || _validatePhone(_phoneCtrl.text) != null ? null : _placeOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFe94560),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _loading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('🔒 Payer ${total.toStringAsFixed(0)} FCFA', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════
  // ÉTAPE 2 — Paiement en cours
  // ══════════════════════════════════════════════
  Widget _buildPayment() {
    final isWave = _paymentMethod == 'wave';
    final timeLeft = (_maxPoll - _pollCount) * 3;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _card(Column(
            children: [
              // En-tête
              Row(children: [
                Text(isWave ? '🌊' : '🟠', style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(isWave ? 'Paiement Wave' : 'Paiement Orange Money',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(isWave ? 'Scannez le QR code avec Wave' : 'Appuyez pour ouvrir Orange Money',
                      style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ]),
              ]),
              const Divider(height: 28),

              // Montant
              Text('${_totalSnapshot.toStringAsFixed(0)} FCFA',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800,
                      color: isWave ? const Color(0xFF0066FF) : const Color(0xFFFF6600))),
              const SizedBox(height: 20),

              // QR Code (Wave) ou bouton (Orange)
              if (isWave) ...[
                QrImageView(
                  data: _paymentUrl,
                  version: QrVersions.auto,
                  size: 220,
                  backgroundColor: Colors.white,
                ),
                const SizedBox(height: 12),
                const Text('Scannez avec votre app Wave', style: TextStyle(color: Colors.grey, fontSize: 13)),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _openPaymentApp,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Ouvrir Orange Money', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6600),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Instructions
              ..._steps(isWave ? [
                'Ouvrez votre application Wave',
                'Appuyez sur Scanner',
                'Scannez ce QR code',
                'Confirmez le paiement',
              ] : [
                'Appuyez sur Ouvrir Orange Money',
                'Confirmez le paiement de ${_totalSnapshot.toStringAsFixed(0)} FCFA',
                'Revenez sur PlayShop',
              ]),

              const SizedBox(height: 16),

              // Statut polling
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  _pulseDot(isWave ? const Color(0xFF22C55E) : const Color(0xFFFF6600)),
                  const SizedBox(width: 10),
                  Expanded(child: Text('En attente de confirmation... (${timeLeft}s)',
                      style: const TextStyle(color: Color(0xFF166534), fontSize: 13))),
                ]),
              ),

              const SizedBox(height: 12),
              Text('Réf : $_reference', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          )),

          // Bouton test
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFFEF9C3), borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('🛠 Dev — ', style: TextStyle(fontSize: 13, color: Color(0xFF854D0E))),
              GestureDetector(
                onTap: _confirmManual,
                child: const Text('Simuler la confirmation', style: TextStyle(fontSize: 13, color: Color(0xFF854D0E), fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════
  // ÉTAPE 3 — Confirmé
  // ══════════════════════════════════════════════
  Widget _buildConfirmed() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 80, height: 80, decoration: const BoxDecoration(color: Color(0xFFD1FAE5), shape: BoxShape.circle),
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
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () => Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil('/orders', (r) => r.isFirst),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFe94560), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Voir mes commandes', style: TextStyle(fontSize: 16)),
          )),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst),
            child: const Text('Retour à l\'accueil'),
          ),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════
  // ÉTAPE 4 — Échoué
  // ══════════════════════════════════════════════
  Widget _buildFailed() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 80, height: 80, decoration: const BoxDecoration(color: Color(0xFFFEE2E2), shape: BoxShape.circle),
            child: const Icon(Icons.cancel, color: Color(0xFFDC2626), size: 48),
          ),
          const SizedBox(height: 20),
          const Text('Paiement échoué', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Le paiement n\'a pas pu être effectué.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 28),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () => setState(() { _step = PayStep.form; _error = null; }),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFe94560), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Réessayer', style: TextStyle(fontSize: 16)),
          )),
        ]),
      ),
    );
  }

  // ── Helpers UI
  Widget _card(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    margin: const EdgeInsets.only(bottom: 0),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
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
          color: selected ? const Color(0xFFe94560).withOpacity(0.04) : Colors.white,
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

  List<Widget> _steps(List<String> steps) => steps.asMap().entries.map((e) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Container(width: 24, height: 24, decoration: const BoxDecoration(color: Color(0xFF1a1a2e), shape: BoxShape.circle),
          child: Center(child: Text('${e.key + 1}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)))),
      const SizedBox(width: 10),
      Expanded(child: Text(e.value, style: const TextStyle(fontSize: 13))),
    ]),
  )).toList();

  Widget _pulseDot(Color color) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0.5, end: 1.0),
    duration: const Duration(milliseconds: 800),
    builder: (_, v, __) => Container(width: 10, height: 10, decoration: BoxDecoration(color: color.withOpacity(v), shape: BoxShape.circle)),
    onEnd: () => setState(() {}),
  );
}
