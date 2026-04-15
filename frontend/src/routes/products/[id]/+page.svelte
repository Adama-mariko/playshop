<script lang="ts">
  import { onMount } from 'svelte'
  import { page } from '$app/stores'
  import { goto } from '$app/navigation'
  import api from '$lib/api'
  import { cart } from '$lib/stores/cart'
  import { isAuthenticated } from '$lib/stores/auth'

  interface Product {
    id: number; name: string; description: string
    price: string; stock: number; image: string | null; category: string | null
  }

  let product = $state<Product | null>(null)
  let loading = $state(true)
  let added = $state(false)

  onMount(async () => {
    try {
      const { data } = await api.get(`/products/${$page.params.id}`)
      product = data
    } catch { goto('/') }
    finally { loading = false }
  })

  function imageUrl(img: string | null) {
    if (!img) return null
    if (img.startsWith('http')) return img
    const parts = img.split('/')
    const encoded = parts.map(p => encodeURIComponent(p)).join('/')
    return `https://playshop.onrender.com${encoded}`
  }

  function addToCart() {
    if (!product) return
    cart.add({ productId: product.id, name: product.name, price: parseFloat(product.price), image: product.image })
    added = true
    setTimeout(() => added = false, 2000)
  }
</script>

<svelte:head><title>{product?.name ?? 'Produit'} — PlayShop</title></svelte:head>

{#if loading}
  <div class="loading-spinner"><div class="spinner"></div></div>
{:else if product}
  <div class="container" style="padding-top:2rem;padding-bottom:3rem">
    <a href="/" class="back-link">← Retour aux produits</a>

    <div class="detail-grid">
      <div class="detail-img-wrap">
        {#if imageUrl(product.image)}
          <img src={imageUrl(product.image)} alt={product.name} />
        {:else}
          <div class="img-placeholder-lg">
            <svg width="80" height="80" viewBox="0 0 24 24" fill="none" stroke="#ccc" stroke-width="1.5">
              <rect x="3" y="3" width="18" height="18" rx="2"/><circle cx="8.5" cy="8.5" r="1.5"/>
              <polyline points="21 15 16 10 5 21"/>
            </svg>
          </div>
        {/if}
      </div>

      <div class="detail-info">
        {#if product.category}
          <span class="badge badge-info">{product.category}</span>
        {/if}
        <h1>{product.name}</h1>
        <p class="detail-price">{parseInt(product.price).toLocaleString('fr-FR')} FCFA</p>

        <div class="stock-info" class:out={product.stock === 0}>
          {#if product.stock > 0}
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg>
            En stock ({product.stock} disponibles)
          {:else}
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
            Rupture de stock
          {/if}
        </div>

        {#if product.description}
          <p class="detail-desc">{product.description}</p>
        {/if}

        <div class="detail-actions">
          <button class="btn btn-primary" style="flex:1;justify-content:center;padding:0.9rem"
            disabled={product.stock === 0} onclick={addToCart}>
            {added ? '✓ Ajouté !' : 'Ajouter au panier'}
          </button>
          <a href="/cart" class="btn btn-dark" style="padding:0.9rem 1.2rem" aria-label="Voir le panier">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <circle cx="9" cy="21" r="1"/><circle cx="20" cy="21" r="1"/>
              <path d="M1 1h4l2.68 13.39a2 2 0 001.99 1.61h9.72a2 2 0 001.99-1.61L23 6H6"/>
            </svg>
          </a>
        </div>

        {#if $isAuthenticated}
          <a href="/products/{product.id}/edit" class="edit-link">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M11 4H4a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2v-7"/>
              <path d="M18.5 2.5a2.121 2.121 0 013 3L12 15l-4 1 1-4 9.5-9.5z"/>
            </svg>
            Modifier ce produit
          </a>
        {/if}
      </div>
    </div>
  </div>
{/if}

<style>
  .back-link{display:inline-flex;align-items:center;gap:0.3rem;color:var(--gray);font-size:0.9rem;margin-bottom:1.5rem;transition:color var(--transition)}
  .back-link:hover{color:var(--primary)}
  .detail-grid{display:grid;grid-template-columns:1fr 1fr;gap:3rem;align-items:start}
  .detail-img-wrap{border-radius:var(--radius);overflow:hidden;box-shadow:var(--shadow);background:var(--gray-light)}
  .detail-img-wrap img{width:100%;height:450px;object-fit:cover}
  .img-placeholder-lg{height:450px;display:flex;align-items:center;justify-content:center}
  .detail-info{display:flex;flex-direction:column;gap:1rem}
  .detail-info h1{font-size:2rem;font-weight:800;color:var(--dark)}
  .detail-price{font-size:2.2rem;font-weight:800;color:var(--primary)}
  .stock-info{display:flex;align-items:center;gap:0.4rem;font-size:0.9rem;font-weight:600;color:#059669}
  .stock-info.out{color:var(--primary)}
  .detail-desc{color:var(--gray);line-height:1.7;font-size:0.95rem}
  .detail-actions{display:flex;gap:0.75rem}
  .edit-link{display:inline-flex;align-items:center;gap:0.4rem;color:var(--gray);font-size:0.85rem;margin-top:0.5rem;transition:color var(--transition)}
  .edit-link:hover{color:var(--primary)}
  @media(max-width:768px){.detail-grid{grid-template-columns:1fr}.detail-img-wrap img{height:280px}}
</style>
