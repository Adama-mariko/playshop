<script lang="ts">
  import { goto } from '$app/navigation'
  import { cart, cartTotal } from '$lib/stores/cart'
  import api from '$lib/api'

  let paymentMethod = $state('orange_money')
  let loading = $state(false), error = $state(''), success = $state(false)
  let orderRef = $state(''), orderId = $state(0)
  let totalSnapshot = $state(0)

  async function placeOrder() {
    if ($cart.length === 0) return
    loading = true; error = ''
    totalSnapshot = $cartTotal
    try {
      const { data: orderData } = await api.post('/orders', {
        items: $cart.map(i => ({ productId: i.productId, quantity: i.quantity })),
        paymentMethod,
      })
      orderId = orderData.order.id
      const { data: payData } = await api.post('/payments/initiate', { orderId })
      orderRef = payData.paymentReference
      cart.clear()
      success = true
    } catch (e: any) {
      error = e.response?.data?.message ?? 'Erreur lors de la commande'
    } finally { loading = false }
  }
</script>

<svelte:head><title>Commande — PlayShop</title></svelte:head>

<div class="container" style="max-width:800px;padding-top:2rem;padding-bottom:3rem">
  {#if success}
    <div class="success-card card">
      <div class="success-icon">✓</div>
      <h2>Commande créée !</h2>
      <p>Commande <strong>#{orderId}</strong></p>
      <div class="ref-box">
        <span>Référence de paiement</span>
        <strong>{orderRef}</strong>
      </div>
      <div class="payment-info">
        📱 Envoyez <strong>{totalSnapshot.toLocaleString('fr-FR')} FCFA</strong> via
        <strong>{paymentMethod === 'orange_money' ? 'Orange Money' : 'Wave'}</strong>
        en indiquant la référence ci-dessus.
      </div>
      <div class="success-actions">
        <a href="/orders" class="btn btn-primary">Voir mes commandes</a>
        <a href="/" class="btn btn-dark">Retour à l'accueil</a>
      </div>
    </div>
  {:else}
    <h1 class="page-title">Finaliser la commande</h1>
    <div class="checkout-grid">
      <div class="checkout-summary card">
        <h2>Votre commande</h2>
        {#each $cart as item}
          <div class="order-item">
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

      <div class="payment-section card">
        <h2>Mode de paiement</h2>
        <label class="payment-option" class:selected={paymentMethod === 'orange_money'}>
          <input type="radio" bind:group={paymentMethod} value="orange_money" />
          <div class="payment-icon">📱</div>
          <div><strong>Orange Money</strong><span>Paiement mobile Orange</span></div>
        </label>
        <label class="payment-option" class:selected={paymentMethod === 'wave'}>
          <input type="radio" bind:group={paymentMethod} value="wave" />
          <div class="payment-icon">🌊</div>
          <div><strong>Wave</strong><span>Paiement mobile Wave</span></div>
        </label>
        {#if error}<div class="alert-error">{error}</div>{/if}
        <button class="btn btn-primary" style="width:100%;justify-content:center;padding:0.9rem;margin-top:1rem"
          onclick={placeOrder} disabled={loading || $cart.length === 0}>
          {loading ? 'Traitement...' : `🔒 Confirmer et payer ${$cartTotal.toLocaleString('fr-FR')} FCFA`}
        </button>
      </div>
    </div>
  {/if}
</div>

<style>
  .checkout-grid{display:grid;grid-template-columns:1fr 1fr;gap:1.5rem;align-items:start}
  .checkout-summary,.payment-section{padding:1.5rem}
  h2{font-size:1.1rem;font-weight:700;margin-bottom:1.25rem}
  .order-item{display:flex;justify-content:space-between;padding:0.5rem 0;font-size:0.95rem;border-bottom:1px solid #f3f4f6}
  hr{border:none;border-top:1px solid #e5e7eb;margin:0.75rem 0}
  .order-total{display:flex;justify-content:space-between;font-size:1.1rem}
  .order-total strong{color:var(--primary)}
  .payment-option{display:flex;align-items:center;gap:1rem;padding:1rem;border-radius:var(--radius);border:2px solid #e5e7eb;cursor:pointer;margin-bottom:0.75rem;transition:all var(--transition)}
  .payment-option input{display:none}
  .payment-option.selected{border-color:var(--primary);background:rgba(233,69,96,0.04)}
  .payment-option div:last-child{display:flex;flex-direction:column}
  .payment-option strong{font-size:0.95rem}
  .payment-option span{font-size:0.8rem;color:var(--gray)}
  .payment-icon{font-size:1.5rem}
  .alert-error{background:#fee2e2;color:#991b1b;padding:0.75rem;border-radius:8px;font-size:0.9rem;margin-top:0.5rem}
  .success-card{max-width:500px;margin:0 auto;padding:3rem 2rem;text-align:center}
  .success-icon{width:70px;height:70px;border-radius:50%;background:#d1fae5;color:#059669;font-size:2rem;font-weight:800;display:flex;align-items:center;justify-content:center;margin:0 auto 1.5rem}
  .success-card h2{font-size:1.6rem;margin-bottom:0.5rem}
  .ref-box{background:var(--gray-light);border-radius:8px;padding:1rem;margin:1.5rem 0;display:flex;flex-direction:column;gap:0.3rem}
  .ref-box span{font-size:0.8rem;color:var(--gray)}
  .ref-box strong{font-size:1rem;word-break:break-all}
  .payment-info{background:#fef3c7;border-radius:8px;padding:1rem;font-size:0.9rem;margin-bottom:1.5rem}
  .success-actions{display:flex;gap:1rem;justify-content:center;flex-wrap:wrap}
  @media(max-width:768px){.checkout-grid{grid-template-columns:1fr}}
</style>
