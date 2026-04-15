<script lang="ts">
  import { goto } from '$app/navigation'
  import { cart, cartTotal, cartCount } from '$lib/stores/cart'
  import { isAuthenticated } from '$lib/stores/auth'

  function checkout() {
    if (!$isAuthenticated) { goto('/login'); return }
    goto('/checkout')
  }

  function imageUrl(img: string | null) {
    if (!img) return null
    if (img.startsWith('http')) return img
    const parts = img.split('/')
    const encoded = parts.map(p => encodeURIComponent(p)).join('/')
    return `https://playshop.onrender.com${encoded}`
  }
</script>

<svelte:head><title>Panier — PlayShop</title></svelte:head>

<div class="container" style="padding-top:2rem;padding-bottom:3rem">
  <h1 class="page-title">Mon Panier</h1>

  {#if $cart.length === 0}
    <div class="empty-state">
      <svg width="80" height="80" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
        <circle cx="9" cy="21" r="1"/><circle cx="20" cy="21" r="1"/>
        <path d="M1 1h4l2.68 13.39a2 2 0 001.99 1.61h9.72a2 2 0 001.99-1.61L23 6H6"/>
      </svg>
      <h3>Votre panier est vide</h3>
      <p>Ajoutez des produits pour commencer vos achats</p>
      <a href="/" class="btn btn-primary" style="margin-top:1rem">Voir les produits</a>
    </div>
  {:else}
    <div class="cart-layout">
      <div class="cart-items">
        {#each $cart as item (item.productId)}
          <div class="cart-item card">
            <div class="item-img">
              {#if imageUrl(item.image)}
                <img src={imageUrl(item.image)} alt={item.name} />
              {:else}
                <div class="img-ph"></div>
              {/if}
            </div>
            <div class="item-info">
              <h3>{item.name}</h3>
              <p class="item-price">{item.price.toLocaleString('fr-FR')} FCFA</p>
            </div>
            <div class="item-qty">
              <button onclick={() => cart.updateQty(item.productId, item.quantity - 1)}>−</button>
              <span>{item.quantity}</span>
              <button onclick={() => cart.updateQty(item.productId, item.quantity + 1)}>+</button>
            </div>
            <p class="item-subtotal">{(item.price * item.quantity).toLocaleString('fr-FR')} FCFA</p>
            <button class="remove-btn" onclick={() => cart.remove(item.productId)} aria-label="Supprimer">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14a2 2 0 01-2 2H8a2 2 0 01-2-2L5 6"/>
                <path d="M10 11v6"/><path d="M14 11v6"/><path d="M9 6V4h6v2"/>
              </svg>
            </button>
          </div>
        {/each}
      </div>

      <div class="cart-summary card">
        <h2>Récapitulatif</h2>
        <div class="summary-row"><span>Articles ({$cartCount})</span><span>{$cartTotal.toLocaleString('fr-FR')} FCFA</span></div>
        <div class="summary-row"><span>Livraison</span><span class="free">Gratuite</span></div>
        <hr />
        <div class="summary-row total"><span>Total</span><span>{$cartTotal.toLocaleString('fr-FR')} FCFA</span></div>
        <button class="btn btn-primary" style="width:100%;justify-content:center;padding:0.9rem;margin-top:1rem" onclick={checkout}>
          Passer la commande
        </button>
        <a href="/" class="continue-link">← Continuer mes achats</a>
      </div>
    </div>
  {/if}
</div>

<style>
  .cart-layout{display:grid;grid-template-columns:1fr 340px;gap:2rem;align-items:start}
  .cart-items{display:flex;flex-direction:column;gap:1rem}
  .cart-item{display:flex;align-items:center;gap:1rem;padding:1rem}
  .item-img{width:80px;height:80px;border-radius:8px;overflow:hidden;flex-shrink:0;background:var(--gray-light)}
  .item-img img{width:100%;height:100%;object-fit:cover}
  .img-ph{width:100%;height:100%}
  .item-info{flex:1}
  .item-info h3{font-size:0.95rem;font-weight:700;margin-bottom:0.25rem}
  .item-price{color:var(--primary);font-weight:600;font-size:0.9rem}
  .item-qty{display:flex;align-items:center;gap:0.5rem}
  .item-qty button{width:30px;height:30px;border-radius:6px;border:1.5px solid #e5e7eb;background:white;font-size:1.1rem;font-weight:600;transition:all var(--transition)}
  .item-qty button:hover{border-color:var(--primary);color:var(--primary)}
  .item-qty span{min-width:24px;text-align:center;font-weight:700}
  .item-subtotal{font-weight:700;min-width:110px;text-align:right}
  .remove-btn{background:none;border:none;color:#ccc;padding:0.3rem;transition:color var(--transition)}
  .remove-btn:hover{color:var(--primary)}
  .cart-summary{padding:1.5rem}
  .cart-summary h2{font-size:1.1rem;font-weight:700;margin-bottom:1.25rem}
  .summary-row{display:flex;justify-content:space-between;margin-bottom:0.75rem;font-size:0.95rem}
  .summary-row.total{font-size:1.1rem;font-weight:800}
  .free{color:#059669;font-weight:600}
  hr{border:none;border-top:1px solid #e5e7eb;margin:0.75rem 0}
  .continue-link{display:block;text-align:center;margin-top:1rem;font-size:0.85rem;color:var(--gray)}
  .continue-link:hover{color:var(--primary)}
  @media(max-width:768px){.cart-layout{grid-template-columns:1fr}.cart-item{flex-wrap:wrap}}
</style>
