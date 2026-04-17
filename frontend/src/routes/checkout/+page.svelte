<script lang="ts">
  import { onMount, onDestroy } from 'svelte'
  import { page } from '$app/stores'
  import { cart, cartTotal } from '$lib/stores/cart'
  import api from '$lib/api'

  type Step = 'form' | 'payment' | 'confirmed' | 'failed'
  type PayMethod = 'wave' | 'orange' | 'mtn' | 'moov' | 'djamo'

  const PAYMENT_OPTIONS: { value: PayMethod; label: string; icon: string; desc: string; prefixes: string[] }[] = [
    { value: 'wave',   label: 'Wave',         icon: 'fa-solid fa-water',         desc: 'Paiement via Wave',             prefixes: ['01','05','06','07','08','09'] },
    { value: 'orange', label: 'Orange Money', icon: 'fa-solid fa-circle',        desc: 'Paiement via Orange Money',     prefixes: ['07','08','09'] },
    { value: 'mtn',    label: 'MTN MoMo',     icon: 'fa-solid fa-mobile-screen', desc: 'Paiement via MTN Mobile Money', prefixes: ['05','06'] },
    { value: 'moov',   label: 'Moov Money',   icon: 'fa-solid fa-bolt',          desc: 'Paiement via Moov Money',       prefixes: ['01'] },
    { value: 'djamo',  label: 'Djamo',        icon: 'fa-solid fa-credit-card',   desc: 'Paiement via Djamo',            prefixes: ['01','05','06','07','08','09'] },
  ]

  const NETWORK_LABELS: Record<string, string> = {
    '01': 'Moov', '05': 'MTN', '06': 'MTN',
    '07': 'Orange', '08': 'Orange', '09': 'Orange',
  }

  let step = $state<Step>('form')
  let paymentMethod = $state<PayMethod>('wave')
  let phoneNumber = $state('')
  let loading = $state(false)
  let error = $state('')

  let orderId = $state(0)
  let reference = $state('')
  let paymentUrl = $state('')
  let totalSnapshot = $state(0)

  let pollInterval: ReturnType<typeof setInterval>
  let pollCount = $state(0)
  const MAX_POLL = 60
  let timeLeft = $derived(Math.max(0, MAX_POLL - pollCount) * 3)

  onDestroy(() => clearInterval(pollInterval))

  // Retour depuis Jèko ou reprise commande
  onMount(async () => {
    const status = $page.url.searchParams.get('status')
    const ref = $page.url.searchParams.get('ref')
    if (status === 'success') { reference = ref ?? ''; cart.clear(); step = 'confirmed'; return }
    if (status === 'error')   { reference = ref ?? ''; step = 'failed';    return }

    const existingOrderId = $page.url.searchParams.get('orderId')
    if (existingOrderId) {
      orderId = parseInt(existingOrderId)
      try {
        const { data } = await api.get(`/payments/status/${orderId}`)
        totalSnapshot = parseFloat(data.totalAmount)
        phoneNumber = data.phoneNumber ?? ''
        paymentMethod = (data.paymentMethod as PayMethod) ?? 'wave'
        await initiatePayment()
      } catch { error = 'Impossible de reprendre cette commande' }
    }
  })

  // Validation numéro
  function phoneValidation(p: string, method: PayMethod) {
    const digits = p.replace(/\D/g, '')
    if (!digits) return { valid: false, error: '', network: '' }
    if (digits.length < 10) return { valid: false, error: `${digits.length}/10 chiffres`, network: '' }
    if (digits.length > 10) return { valid: false, error: 'Trop de chiffres (max 10)', network: '' }
    const prefix = digits.substring(0, 2)
    const opt = PAYMENT_OPTIONS.find(o => o.value === method)
    if (opt && !opt.prefixes.includes(prefix)) {
      return { valid: false, error: `${opt.label} : préfixes ${opt.prefixes.join(', ')} uniquement`, network: NETWORK_LABELS[prefix] ?? '' }
    }
    if (!Object.keys(NETWORK_LABELS).includes(prefix)) {
      return { valid: false, error: `Préfixe "${prefix}" non reconnu`, network: '' }
    }
    return { valid: true, error: '', network: NETWORK_LABELS[prefix] ?? '' }
  }

  let phoneState = $derived(phoneValidation(phoneNumber, paymentMethod))

  async function initiatePayment() {
    const { data: payData } = await api.post('/payments/initiate', { orderId })
    reference = payData.reference
    paymentUrl = payData.paymentUrl
    // Redirection directe vers Jèko pour tous les modes
    window.location.href = paymentUrl
  }

  async function placeOrder() {
    if ($cart.length === 0) return
    if (!phoneNumber.trim()) { error = 'Veuillez entrer votre numéro de téléphone'; return }
    if (!phoneState.valid) { error = phoneState.error; return }
    loading = true; error = ''
    totalSnapshot = $cartTotal
    try {
      const { data: orderData } = await api.post('/orders', {
        items: $cart.map(i => ({ productId: i.productId, quantity: i.quantity })),
        paymentMethod,
        phoneNumber: phoneNumber.trim(),
      })
      orderId = orderData.order.id
      // Ne pas vider le panier ici — on le vide seulement si le paiement réussit
      await initiatePayment()
    } catch (e: any) {
      error = e.response?.data?.message ?? 'Erreur lors de la commande'
    } finally {
      loading = false
    }
  }

  function startPolling() {
    pollInterval = setInterval(async () => {
      pollCount++
      if (pollCount > MAX_POLL) { clearInterval(pollInterval); return }
      try {
        const { data } = await api.get(`/payments/status/${orderId}`)
        if (data.paymentStatus === 'success') { clearInterval(pollInterval); cart.clear(); step = 'confirmed' }
        else if (data.paymentStatus === 'failed') { clearInterval(pollInterval); step = 'failed' }
      } catch {}
    }, 3000)
  }

  async function confirmManual() {
    await api.patch(`/payments/confirm-manual/${orderId}`)
    clearInterval(pollInterval)
    step = 'confirmed'
  }
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
              {PAYMENT_OPTIONS.find(o => o.value === paymentMethod)?.label} : préfixes {PAYMENT_OPTIONS.find(o => o.value === paymentMethod)?.prefixes.join(', ')}
            </small>
          {/if}
        </div>

        <!-- Choix du mode -->
        <div class="payment-options">
          {#each PAYMENT_OPTIONS as opt}
            <label class="pay-option" class:selected={paymentMethod === opt.value}>
              <input type="radio" bind:group={paymentMethod} value={opt.value} />
              <div class="pay-icon"><i class="{opt.icon}"></i></div>
              <div class="pay-info">
                <strong>{opt.label}</strong>
                <span>{opt.desc}</span>
              </div>
              {#if paymentMethod === opt.value}
                <span class="check">✓</span>
              {/if}
            </label>
          {/each}
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
            <i class="fa-solid fa-lock"></i> Payer {$cartTotal.toLocaleString('fr-FR')} FCFA
          {/if}
        </button>
      </div>
    </div>

  <!-- ═══════════════════════════════════════════════
       ÉTAPE 2 — Redirection en cours (loading)
  ═══════════════════════════════════════════════ -->
  {:else if step === 'payment'}
    <div class="result-card card">
      <div class="result-icon" style="background:#f0f9ff">
        <span class="material-icons-round" style="color:#0066ff;font-size:2rem">open_in_new</span>
      </div>
      <h2>Redirection en cours...</h2>
      <p class="result-sub">Vous allez être redirigé vers Jèko pour finaliser votre paiement.</p>
      <div class="dev-note" style="margin-top:1rem">
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
  .pay-icon { font-size:1.6rem; color: var(--primary); width: 2rem; text-align: center; }
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
  .payment-header.wave { border-left:4px solid #0066ff; padding-left:1rem; }
  .payment-header.orange { border-left:4px solid #ff6600; padding-left:1rem; }
  .pay-logo-icon { font-size:2.2rem !important; }

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
