<script lang="ts">
  import { onMount, onDestroy } from 'svelte'
  import { goto } from '$app/navigation'
  import { page } from '$app/stores'
  import { cart, cartTotal } from '$lib/stores/cart'
  import api from '$lib/api'
  import QRCode from 'qrcode'

  // ── Étape 1 : formulaire de commande
  // ── Étape 2 : paiement (QR code Wave ou redirection Orange)
  // ── Étape 3 : confirmation (paiement validé)
  type Step = 'form' | 'payment' | 'confirmed' | 'failed'

  let step = $state<Step>('form')
  let paymentMethod = $state<'orange_money' | 'wave'>('wave')
  let phoneNumber = $state('')
  let loading = $state(false)
  let error = $state('')

  // Données de paiement
  let orderId = $state(0)
  let reference = $state('')
  let paymentUrl = $state('')
  let qrCodeDataUrl = $state('')
  let totalSnapshot = $state(0)

  // Polling
  let pollInterval: ReturnType<typeof setInterval>
  let pollCount = $state(0)
  const MAX_POLL = 60

  onDestroy(() => clearInterval(pollInterval))

  // Temps restant pour le polling
  let timeLeft = $derived(Math.max(0, MAX_POLL - pollCount) * 3)

  // Si on arrive avec ?orderId= (reprise d'un paiement en attente)
  onMount(async () => {
    const existingOrderId = $page.url.searchParams.get('orderId')
    const existingMethod = $page.url.searchParams.get('method') as 'wave' | 'orange_money' | null
    if (existingOrderId) {
      orderId = parseInt(existingOrderId)
      if (existingMethod) paymentMethod = existingMethod
      // Récupérer les infos de la commande
      try {
        const { data } = await api.get(`/payments/status/${orderId}`)
        totalSnapshot = parseFloat(data.totalAmount)
        phoneNumber = data.phoneNumber ?? ''
        // Réinitier le paiement
        await initiatePayment()
      } catch {
        error = 'Impossible de reprendre cette commande'
      }
    }
  })

  // ── Initier le paiement (utilisé aussi pour reprendre un paiement)
  async function initiatePayment() {
    const { data: payData } = await api.post('/payments/initiate', { orderId })
    reference = payData.reference
    paymentUrl = payData.paymentUrl

    // QR code généré pour Wave ET Orange Money
    qrCodeDataUrl = await QRCode.toDataURL(paymentUrl, {
      width: 280, margin: 2,
      color: {
        dark: paymentMethod === 'wave' ? '#0066ff' : '#ff6600',
        light: '#ffffff',
      },
    })

    step = 'payment'
    startPolling()
  }

  // ── Étape 1 : créer la commande et initier le paiement
  async function placeOrder() {
    if ($cart.length === 0) return
    if (!phoneNumber.trim()) { error = 'Veuillez entrer votre numéro de téléphone'; return }
    loading = true; error = ''
    totalSnapshot = $cartTotal
    try {
      const { data: orderData } = await api.post('/orders', {
        items: $cart.map(i => ({ productId: i.productId, quantity: i.quantity })),
        paymentMethod,
        phoneNumber: phoneNumber.trim(),
      })
      orderId = orderData.order.id
      cart.clear()
      await initiatePayment()
    } catch (e: any) {
      error = e.response?.data?.message ?? 'Erreur lors de la commande'
    } finally {
      loading = false
    }
  }

  // ── Polling : vérifie le statut toutes les 3 secondes
  function startPolling() {
    pollInterval = setInterval(async () => {
      pollCount++
      if (pollCount > MAX_POLL) {
        clearInterval(pollInterval)
        return
      }
      try {
        const { data } = await api.get(`/payments/status/${orderId}`)
        if (data.paymentStatus === 'success') {
          clearInterval(pollInterval)
          step = 'confirmed'
        } else if (data.paymentStatus === 'failed') {
          clearInterval(pollInterval)
          step = 'failed'
        }
      } catch {}
    }, 3000)
  }

  // ── Confirmation manuelle (dev/test)
  async function confirmManual() {
    await api.patch(`/payments/confirm-manual/${orderId}`)
    clearInterval(pollInterval)
    step = 'confirmed'
  }

  // Validation numéro ivoirien
  const ORANGE_PREFIXES = ['07', '08', '09']
  const ALL_PREFIXES = ['01', '05', '06', '07', '08', '09']
  const NETWORK_LABELS: Record<string, string> = {
    '01': 'Moov', '05': 'MTN', '06': 'MTN',
    '07': 'Orange', '08': 'Orange', '09': 'Orange',
  }

  function getPhonePrefix(p: string) { return p.replace(/\D/g, '').substring(0, 2) }

  function phoneValidation(p: string, method: string) {
    const digits = p.replace(/\D/g, '')
    if (!digits) return { valid: false, error: '', network: '' }
    if (digits.length < 10) return { valid: false, error: `${digits.length}/10 chiffres`, network: '' }
    if (digits.length > 10) return { valid: false, error: 'Trop de chiffres (max 10)', network: '' }
    const prefix = digits.substring(0, 2)
    if (!ALL_PREFIXES.includes(prefix)) return { valid: false, error: `Préfixe "${prefix}" non reconnu en Côte d'Ivoire`, network: '' }
    if (method === 'orange_money' && !ORANGE_PREFIXES.includes(prefix)) {
      return { valid: false, error: `Orange Money : numéros 07, 08, 09 uniquement (votre réseau : ${NETWORK_LABELS[prefix]})`, network: NETWORK_LABELS[prefix] }
    }
    return { valid: true, error: '', network: NETWORK_LABELS[prefix] ?? '' }
  }

  let phoneState = $derived(phoneValidation(phoneNumber, paymentMethod))
</script>

<svelte:head><title>Paiement — PlayShop</title></svelte:head>

<div class="container" style="max-width:700px;padding-top:2rem;padding-bottom:3rem">

  <!-- ═══════════════════════════════════════════════
       ÉTAPE 1 — Formulaire de commande
  ═══════════════════════════════════════════════ -->
  {#if step === 'form'}
    <h1 class="page-title">Finaliser la commande</h1>

    <div class="checkout-grid">
      <!-- Récapitulatif -->
      <div class="card section">
        <h2>Votre commande</h2>
        {#each $cart as item}
          <div class="order-row">
            <span>{item.name} × {item.quantity}</span>
            <span>{(item.price * item.quantity).toLocaleString('fr-FR')} FCFA</span>
          </div>
        {/each}
        <hr />
        <div class="order-total">
          <span>Total</span>
          <strong>{$cartTotal.toLocaleString('fr-FR')} FCFA</strong>
        </div>
      </div>

      <!-- Paiement -->
      <div class="card section">
        <h2>Mode de paiement</h2>

        <!-- Numéro de téléphone -->
        <div class="form-group" style="margin-bottom:1.25rem">
          <label for="phone">Numéro de téléphone *</label>
          <div class="phone-input-wrap" class:phone-valid={phoneState.valid} class:phone-invalid={phoneNumber && !phoneState.valid}>
            <span class="phone-prefix">+225</span>
            <input
              id="phone"
              type="tel"
              bind:value={phoneNumber}
              placeholder="0701234567"
              maxlength="10"
              oninput={(e) => { const t = e.target as HTMLInputElement; t.value = t.value.replace(/\D/g,''); phoneNumber = t.value }}
            />
            {#if phoneState.valid}
              <span class="material-icons-round phone-icon valid">check_circle</span>
            {:else if phoneNumber}
              <span class="material-icons-round phone-icon invalid">error_outline</span>
            {/if}
          </div>

          {#if phoneState.valid}
            <small class="phone-ok">
              <span class="material-icons-round" style="font-size:13px;vertical-align:-2px">check_circle</span>
              Réseau {phoneState.network} — numéro valide
            </small>
          {:else if phoneNumber && phoneState.error}
            <small class="phone-error">
              <span class="material-icons-round" style="font-size:13px;vertical-align:-2px">error_outline</span>
              {phoneState.error}
            </small>
          {:else}
            <small class="phone-hint">
              {#if paymentMethod === 'orange_money'}
                Orange Money : numéros 07, 08, 09 (réseau Orange)
              {:else}
                Wave : tous réseaux — Orange (07-09), MTN (05-06), Moov (01)
              {/if}
            </small>
          {/if}
        </div>

        <!-- Choix du mode -->
        <div class="payment-options">
          <label class="pay-option" class:selected={paymentMethod === 'wave'}>
            <input type="radio" bind:group={paymentMethod} value="wave" />
            <div class="pay-icon wave-icon">🌊</div>
            <div class="pay-info">
              <strong>Wave</strong>
              <span>Scannez le QR code avec Wave</span>
            </div>
            {#if paymentMethod === 'wave'}
              <span class="check">✓</span>
            {/if}
          </label>

          <label class="pay-option" class:selected={paymentMethod === 'orange_money'}>
            <input type="radio" bind:group={paymentMethod} value="orange_money" />
            <div class="pay-icon om-icon">🟠</div>
            <div class="pay-info">
              <strong>Orange Money</strong>
              <span>Redirection vers Orange Money</span>
            </div>
            {#if paymentMethod === 'orange_money'}
              <span class="check">✓</span>
            {/if}
          </label>
        </div>

        {#if error}
          <div class="alert-error">{error}</div>
        {/if}

        <button
          class="btn btn-primary pay-btn"
          onclick={placeOrder}
          disabled={loading || $cart.length === 0 || !phoneState.valid}
        >
          {#if loading}
            <span class="btn-spinner"></span> Traitement...
          {:else}
            🔒 Payer {$cartTotal.toLocaleString('fr-FR')} FCFA
          {/if}
        </button>
      </div>
    </div>

  <!-- ═══════════════════════════════════════════════
       ÉTAPE 2 — Paiement en cours
  ═══════════════════════════════════════════════ -->
  {:else if step === 'payment'}
    <div class="payment-screen">
      <div class="card payment-card">

        <!-- En-tête selon la méthode -->
        <div class="payment-header" class:wave={paymentMethod === 'wave'} class:orange={paymentMethod === 'orange_money'}>
          <span class="material-icons-round pay-logo-icon">
            {paymentMethod === 'wave' ? 'waves' : 'circle'}
          </span>
          <div>
            <h2>{paymentMethod === 'wave' ? 'Paiement Wave' : 'Paiement Orange Money'}</h2>
            <p>Scannez le QR code avec votre application {paymentMethod === 'wave' ? 'Wave' : 'Orange Money'}</p>
          </div>
        </div>

        <!-- QR Code — identique pour Wave et Orange Money -->
        <div class="qr-container">
          {#if qrCodeDataUrl}
            <div class="qr-wrapper" class:qr-wave={paymentMethod === 'wave'} class:qr-orange={paymentMethod === 'orange_money'}>
              <img src={qrCodeDataUrl} alt="QR Code paiement" class="qr-img" />
            </div>
          {/if}
          <div class="qr-amount" class:orange-amount={paymentMethod === 'orange_money'}>
            {totalSnapshot.toLocaleString('fr-FR')} FCFA
          </div>
        </div>

        <!-- Instructions -->
        <div class="payment-steps">
          <div class="step-item">
            <span class="step-num">1</span>
            <span>Ouvrez votre application <strong>{paymentMethod === 'wave' ? 'Wave' : 'Orange Money'}</strong></span>
          </div>
          <div class="step-item">
            <span class="step-num">2</span>
            <span>Appuyez sur <strong>Scanner un QR code</strong></span>
          </div>
          <div class="step-item">
            <span class="step-num">3</span>
            <span>Scannez ce QR code et confirmez le paiement de <strong>{totalSnapshot.toLocaleString('fr-FR')} FCFA</strong></span>
          </div>
          <div class="step-item">
            <span class="step-num">4</span>
            <span>Revenez ici — la page se met à jour automatiquement</span>
          </div>
        </div>

        <!-- Statut polling -->
        <div class="polling-status">
          <div class="pulse-dot" class:orange-dot={paymentMethod === 'orange_money'}></div>
          <span>En attente de confirmation... ({timeLeft}s restantes)</span>
        </div>

        <div class="ref-line">Réf : <code>{reference}</code></div>
      </div>

      <!-- Bouton test dev -->
      <div class="dev-note">
        <span class="material-icons-round" style="font-size:16px;vertical-align:-3px">build</span>
        Mode développement —
        <button class="link-btn" onclick={confirmManual}>Simuler la confirmation</button>
      </div>
    </div>

  <!-- ═══════════════════════════════════════════════
       ÉTAPE 3 — Paiement confirmé ✓
  ═══════════════════════════════════════════════ -->
  {:else if step === 'confirmed'}
    <div class="result-card card">
      <div class="result-icon success">✓</div>
      <h2>Paiement confirmé !</h2>
      <p class="result-sub">Votre commande <strong>#{orderId}</strong> a été payée avec succès.</p>
      <div class="result-ref">Référence : <code>{reference}</code></div>
      <div class="result-actions">
        <a href="/orders" class="btn btn-primary">Voir mes commandes</a>
        <a href="/" class="btn btn-dark">Retour à l'accueil</a>
      </div>
    </div>

  <!-- ═══════════════════════════════════════════════
       ÉTAPE 4 — Paiement échoué ✗
  ═══════════════════════════════════════════════ -->
  {:else if step === 'failed'}
    <div class="result-card card">
      <div class="result-icon failed">✗</div>
      <h2>Paiement échoué</h2>
      <p class="result-sub">Le paiement n'a pas pu être effectué. Veuillez réessayer.</p>
      <div class="result-actions">
        <button class="btn btn-primary" onclick={() => { step = 'form'; error = '' }}>Réessayer</button>
        <a href="/" class="btn btn-dark">Retour à l'accueil</a>
      </div>
    </div>
  {/if}
</div>

<style>
  .checkout-grid { display:grid; grid-template-columns:1fr 1fr; gap:1.5rem; align-items:start; }
  .section { padding:1.5rem; }
  h2 { font-size:1.1rem; font-weight:700; margin-bottom:1.25rem; }

  .order-row { display:flex; justify-content:space-between; padding:0.5rem 0; font-size:0.9rem; border-bottom:1px solid #f3f4f6; }
  hr { border:none; border-top:1px solid #e5e7eb; margin:0.75rem 0; }
  .order-total { display:flex; justify-content:space-between; font-size:1.05rem; }
  .order-total strong { color:var(--primary); }

  small { color:var(--gray); font-size:0.8rem; margin-top:0.3rem; display:block; }

  .payment-options { display:flex; flex-direction:column; gap:0.75rem; margin-bottom:1.25rem; }
  .pay-option {
    display:flex; align-items:center; gap:0.9rem;
    padding:0.9rem 1rem; border-radius:var(--radius);
    border:2px solid #e5e7eb; cursor:pointer;
    transition:all var(--transition); position:relative;
  }
  .pay-option input { display:none; }
  .pay-option.selected { border-color:var(--primary); background:rgba(233,69,96,0.04); }
  .pay-icon { font-size:1.6rem; }
  .pay-info { flex:1; display:flex; flex-direction:column; }
  .pay-info strong { font-size:0.95rem; }
  .pay-info span { font-size:0.8rem; color:var(--gray); }
  .check { color:var(--primary); font-weight:700; }

  .alert-error { background:#fee2e2; color:#991b1b; padding:0.75rem; border-radius:8px; font-size:0.9rem; margin-bottom:1rem; }

  .pay-btn { width:100%; justify-content:center; padding:0.9rem; font-size:1rem; }
  .btn-spinner { width:16px; height:16px; border:2px solid rgba(255,255,255,0.4); border-top-color:white; border-radius:50%; animation:spin 0.7s linear infinite; display:inline-block; }
  @keyframes spin { to { transform:rotate(360deg); } }

  /* Champ téléphone */
  .phone-input-wrap {
    display:flex; align-items:center;
    border:1.5px solid #e5e7eb; border-radius:var(--radius);
    overflow:hidden; transition:border-color 0.2s;
    background:white;
  }
  .phone-input-wrap:focus-within { border-color:var(--primary); box-shadow:0 0 0 3px rgba(233,69,96,0.1); }
  .phone-input-wrap.phone-valid { border-color:#059669; }
  .phone-input-wrap.phone-invalid { border-color:#dc2626; }
  .phone-prefix {
    padding:0.7rem 0.75rem; background:#f3f4f6;
    font-weight:700; font-size:0.9rem; color:var(--dark);
    border-right:1.5px solid #e5e7eb; white-space:nowrap;
  }
  .phone-input-wrap input {
    flex:1; padding:0.7rem 0.75rem; border:none; outline:none;
    font-size:0.95rem; letter-spacing:0.05em;
  }
  .phone-icon { padding:0 0.75rem; font-size:1.1rem !important; }
  .phone-icon.valid { color:#059669; }
  .phone-icon.invalid { color:#dc2626; }
  .phone-ok { color:#059669; display:flex; align-items:center; gap:0.3rem; margin-top:0.35rem; }
  .phone-error { color:#dc2626; display:flex; align-items:center; gap:0.3rem; margin-top:0.35rem; }
  .phone-hint { color:var(--gray); display:block; margin-top:0.35rem; }

  /* Payment screen */
  .payment-screen { display:flex; flex-direction:column; gap:1rem; }
  .payment-card { padding:2rem; }

  .payment-header { display:flex; align-items:center; gap:1rem; margin-bottom:1.5rem; padding-bottom:1.5rem; border-bottom:1px solid #f3f4f6; }
  .payment-header h2 { font-size:1.3rem; margin-bottom:0.2rem; }
  .payment-header p { color:var(--gray); font-size:0.9rem; }
  .payment-header.wave { border-left:4px solid #0066ff; padding-left:1rem; }
  .payment-header.orange { border-left:4px solid #ff6600; padding-left:1rem; }
  .pay-logo-icon { font-size:2.2rem !important; }
  .payment-header.wave .pay-logo-icon { color:#0066ff; }
  .payment-header.orange .pay-logo-icon { color:#ff6600; }

  /* QR Code */
  .qr-container { display:flex; flex-direction:column; align-items:center; gap:1rem; margin:1.5rem 0; }
  .qr-wrapper { padding:12px; border-radius:16px; }
  .qr-wave { border:3px solid #0066ff; box-shadow:0 4px 20px rgba(0,102,255,0.15); }
  .qr-orange { border:3px solid #ff6600; box-shadow:0 4px 20px rgba(255,102,0,0.15); }
  .qr-img { border-radius:8px; display:block; }
  .qr-amount { font-size:1.8rem; font-weight:800; color:var(--primary); }
  .orange-amount { color:#ff6600; }

  /* Steps */
  .payment-steps { display:flex; flex-direction:column; gap:0.75rem; margin:1.5rem 0; }
  .step-item { display:flex; align-items:center; gap:0.75rem; font-size:0.9rem; }
  .step-num { width:26px; height:26px; border-radius:50%; background:var(--dark); color:white; display:flex; align-items:center; justify-content:center; font-size:0.8rem; font-weight:700; flex-shrink:0; }

  /* Polling */
  .polling-status { display:flex; align-items:center; gap:0.75rem; padding:0.9rem 1rem; background:#f0fdf4; border-radius:8px; font-size:0.9rem; color:#166534; margin-top:1rem; }
  .pulse-dot { width:10px; height:10px; border-radius:50%; background:#22c55e; animation:pulse 1.5s ease-in-out infinite; flex-shrink:0; }
  .orange-dot { background:#ff6600; }
  @keyframes pulse { 0%,100%{opacity:1;transform:scale(1)} 50%{opacity:0.5;transform:scale(1.3)} }

  .ref-line { text-align:center; margin-top:1rem; font-size:0.85rem; color:var(--gray); }
  .ref-line code { background:#f3f4f6; padding:0.2rem 0.5rem; border-radius:4px; font-size:0.85rem; }

  /* Dev note */
  .dev-note { text-align:center; padding:0.75rem; background:#fef9c3; border-radius:8px; font-size:0.85rem; color:#854d0e; }
  .link-btn { background:none; border:none; color:#854d0e; font-weight:700; cursor:pointer; text-decoration:underline; }

  /* Result */
  .result-card { max-width:480px; margin:0 auto; padding:3rem 2rem; text-align:center; }
  .result-icon { width:72px; height:72px; border-radius:50%; font-size:2rem; font-weight:800; display:flex; align-items:center; justify-content:center; margin:0 auto 1.5rem; }
  .result-icon.success { background:#d1fae5; color:#059669; }
  .result-icon.failed { background:#fee2e2; color:#dc2626; }
  .result-card h2 { font-size:1.6rem; margin-bottom:0.5rem; }
  .result-sub { color:var(--gray); margin-bottom:1rem; }
  .result-ref { background:#f3f4f6; padding:0.75rem; border-radius:8px; font-size:0.85rem; margin-bottom:1.5rem; }
  .result-ref code { font-weight:600; }
  .result-actions { display:flex; gap:1rem; justify-content:center; flex-wrap:wrap; }

  @media (max-width:768px) { .checkout-grid { grid-template-columns:1fr; } }
</style>
