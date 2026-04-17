<script lang="ts">
  import { onMount } from 'svelte'
  import { page } from '$app/stores'
  import api from '$lib/api'
  import { cart } from '$lib/stores/cart'

  let status = $state<'loading' | 'success' | 'failed'>('loading')
  let reference = $state('')
  let orderId = $state(0)
  let amount = $state(0)
  let paymentMethod = $state('')

  const PAY_LABELS: Record<string, string> = {
    wave: 'Wave', orange: 'Orange Money', mtn: 'MTN MoMo', moov: 'Moov Money', djamo: 'Djamo'
  }

  onMount(async () => {
    reference = $page.url.searchParams.get('ref') ?? ''
    const hasError = $page.url.searchParams.get('error') === '1'

    if (!reference) { status = 'failed'; return }
    if (hasError) { status = 'failed'; return }

    try {
      const { data: orders } = await api.get('/orders')
      const order = orders.find((o: any) => o.payment_reference === reference)

      if (order) {
        orderId = order.id
        amount = parseFloat(order.total_amount)
        paymentMethod = order.payment_method ?? ''

        if (order.payment_status !== 'success') {
          const { data: st } = await api.get(`/payments/status/${order.id}`)
          status = st.paymentStatus === 'success' ? 'success' : 'failed'
        } else {
          status = 'success'
        }

        // Vider le panier uniquement si paiement confirmé
        if (status === 'success') cart.clear()
      } else {
        status = 'failed'
      }
    } catch {
      status = 'failed'
    }
  })

  function fmtAmount(n: number) {
    return n.toLocaleString('fr-FR')
  }
</script>

<svelte:head>
  <title>{status === 'success' ? 'Paiement confirmé' : 'Paiement'} — PlayShop</title>
</svelte:head>

<div class="page">
  <div class="container">
    <div class="card">

      {#if status === 'loading'}
        <div class="loading">
          <div class="spinner"></div>
          <p>Vérification du paiement...</p>
        </div>

      {:else if status === 'success'}
        <!-- Succès -->
        <div class="icon-wrap success">
          <span class="material-icons-round">check_circle</span>
        </div>
        <h1>Paiement confirmé !</h1>
        <p class="sub">Votre paiement a été effectué avec succès.</p>

        <div class="details">
          {#if orderId}
            <div class="detail-row">
              <span>Commande</span>
              <strong>#{orderId}</strong>
            </div>
          {/if}
          {#if amount > 0}
            <div class="detail-row">
              <span>Montant payé</span>
              <strong class="green">+ {fmtAmount(amount)} FCFA</strong>
            </div>
          {/if}
          {#if paymentMethod}
            <div class="detail-row">
              <span>Via</span>
              <strong>{PAY_LABELS[paymentMethod] ?? paymentMethod}</strong>
            </div>
          {/if}
          {#if reference}
            <div class="detail-row">
              <span>Référence</span>
              <code>{reference}</code>
            </div>
          {/if}
        </div>

        <div class="actions">
          <a href="/orders" class="btn btn-primary">
            <span class="material-icons-round">receipt_long</span>
            Voir mes commandes
          </a>
          <a href="/" class="btn btn-dark">
            <span class="material-icons-round">home</span>
            Accueil
          </a>
        </div>

      {:else}
        <!-- Échec -->
        <div class="icon-wrap failed">
          <span class="material-icons-round">cancel</span>
        </div>
        <h1>Paiement non confirmé</h1>
        <p class="sub">Nous n'avons pas pu confirmer votre paiement. Si vous avez été débité, contactez le support.</p>

        {#if reference}
          <div class="details">
            <div class="detail-row">
              <span>Référence</span>
              <code>{reference}</code>
            </div>
          </div>
        {/if}

        <div class="actions">
          <a href="/checkout" class="btn btn-primary">Réessayer</a>
          <a href="/" class="btn btn-dark">Accueil</a>
        </div>
      {/if}

    </div>
  </div>
</div>

<style>
  .page {
    min-height: 80vh;
    display: flex; align-items: center;
    padding: 2rem 0;
  }

  .card {
    max-width: 480px; margin: 0 auto;
    background: white; border-radius: 20px;
    padding: 3rem 2rem; text-align: center;
    box-shadow: 0 8px 40px rgba(0,0,0,0.1);
  }

  .loading {
    display: flex; flex-direction: column; align-items: center; gap: 1rem;
    padding: 2rem 0;
  }
  .spinner {
    width: 44px; height: 44px; border-radius: 50%;
    border: 3px solid #f3f4f6; border-top-color: var(--primary);
    animation: spin 0.7s linear infinite;
  }
  @keyframes spin { to { transform: rotate(360deg); } }
  .loading p { color: var(--gray); }

  .icon-wrap {
    width: 80px; height: 80px; border-radius: 50%;
    display: flex; align-items: center; justify-content: center;
    margin: 0 auto 1.5rem;
  }
  .icon-wrap .material-icons-round { font-size: 2.5rem !important; }
  .icon-wrap.success { background: #d1fae5; color: #059669; }
  .icon-wrap.failed  { background: #fee2e2; color: #dc2626; }

  h1 { font-size: 1.7rem; font-weight: 800; margin-bottom: 0.5rem; }
  .sub { color: var(--gray); font-size: 0.95rem; margin-bottom: 1.75rem; line-height: 1.5; }

  .details {
    background: #f9fafb; border-radius: 12px;
    padding: 1rem 1.25rem; margin-bottom: 2rem;
    text-align: left;
  }
  .detail-row {
    display: flex; justify-content: space-between; align-items: center;
    padding: 0.55rem 0; border-bottom: 1px solid #f3f4f6;
    font-size: 0.9rem;
  }
  .detail-row:last-child { border-bottom: none; }
  .detail-row span { color: var(--gray); }
  .detail-row strong { font-weight: 700; }
  .detail-row code {
    font-family: monospace; font-size: 0.8rem;
    background: #e5e7eb; padding: 0.2rem 0.5rem; border-radius: 4px;
  }
  .green { color: #059669; }

  .actions {
    display: flex; gap: 0.75rem; justify-content: center; flex-wrap: wrap;
  }
  .actions .btn { padding: 0.7rem 1.4rem; font-size: 0.9rem; }
</style>
