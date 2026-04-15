<script lang="ts">
  import { onMount } from 'svelte'
  import api from '$lib/api'
  import { cart } from '$lib/stores/cart'

  interface Product {
    id: number; name: string; description: string
    price: string; stock: number; image: string | null; category: string | null
  }

  let products = $state<Product[]>([])
  let loading = $state(true)
  let search = $state('')
  let selectedCategory = $state('')
  let toast = $state('')
  let toastTimer: ReturnType<typeof setTimeout>

  let categories = $derived([...new Set(products.map(p => p.category).filter(Boolean))] as string[])
  let filtered = $derived(
    products.filter(p => {
      const matchCat = !selectedCategory || p.category === selectedCategory
      const matchSearch = !search || p.name.toLowerCase().includes(search.toLowerCase())
      return matchCat && matchSearch
    })
  )

  onMount(async () => {
    try {
      const { data } = await api.get('/products?limit=100')
      products = data.data
    } finally { loading = false }
  })

  function addToCart(p: Product) {
    cart.add({ productId: p.id, name: p.name, price: parseFloat(p.price), image: p.image })
    toast = `${p.name} ajouté au panier`
    clearTimeout(toastTimer)
    toastTimer = setTimeout(() => toast = '', 2500)
  }

  function imageUrl(img: string | null) {
    if (!img) return null
    if (img.startsWith('http')) return img
    const parts = img.split('/')
    const encoded = parts.map(p => encodeURIComponent(p)).join('/')
    return `https://playshop.onrender.com${encoded}`
  }
</script>

<svelte:head><title>Produits — PlayShop</title></svelte:head>

<div class="container" style="padding-top:2rem;padding-bottom:3rem">
  <div class="page-header">
    <h1 class="page-title">Tous les produits</h1>
    <a href="/products/new" class="btn btn-primary">+ Ajouter un produit</a>
  </div>

  <!-- Filtres -->
  <div class="filters">
    <div class="search-wrap">
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/>
      </svg>
      <input bind:value={search} placeholder="Rechercher un produit..." class="search-input" />
    </div>
    <div class="categories">
      <button class="cat-btn" class:active={!selectedCategory} onclick={() => selectedCategory = ''}>Tous</button>
      {#each categories as cat}
        <button class="cat-btn" class:active={selectedCategory === cat} onclick={() => selectedCategory = cat}>{cat}</button>
      {/each}
    </div>
  </div>

  {#if loading}
    <div class="loading-spinner"><div class="spinner"></div></div>
  {:else if filtered.length === 0}
    <div class="empty-state">
      <h3>Aucun produit trouvé</h3>
      <p>Essayez un autre terme de recherche</p>
    </div>
  {:else}
    <p class="results-count">{filtered.length} produit{filtered.length > 1 ? 's' : ''}</p>
    <div class="products-grid">
      {#each filtered as product (product.id)}
        <article class="product-card">
          <a href="/products/{product.id}" class="product-img-wrap">
            {#if imageUrl(product.image)}
              <img src={imageUrl(product.image)} alt={product.name} loading="lazy" />
            {:else}
              <div class="img-placeholder">
                <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="#ccc" stroke-width="1.5">
                  <rect x="3" y="3" width="18" height="18" rx="2"/><circle cx="8.5" cy="8.5" r="1.5"/>
                  <polyline points="21 15 16 10 5 21"/>
                </svg>
              </div>
            {/if}
            {#if product.stock === 0}
              <span class="out-badge">Rupture</span>
            {/if}
          </a>
          <div class="product-info">
            {#if product.category}<span class="product-cat">{product.category}</span>{/if}
            <a href="/products/{product.id}"><h3 class="product-name">{product.name}</h3></a>
            <p class="product-price">{parseInt(product.price).toLocaleString('fr-FR')} FCFA</p>
            <div class="product-actions">
              <button class="btn btn-dark" style="flex:1;justify-content:center"
                disabled={product.stock === 0} onclick={() => addToCart(product)}>
                {product.stock === 0 ? 'Rupture' : 'Ajouter'}
              </button>
              <a href="/products/{product.id}/edit" class="btn-edit" aria-label="Modifier">
                <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <path d="M11 4H4a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2v-7"/>
                  <path d="M18.5 2.5a2.121 2.121 0 013 3L12 15l-4 1 1-4 9.5-9.5z"/>
                </svg>
              </a>
            </div>
          </div>
        </article>
      {/each}
    </div>
  {/if}
</div>

{#if toast}<div class="toast">{toast}</div>{/if}

<style>
  .page-header{display:flex;justify-content:space-between;align-items:center;margin-bottom:1.5rem;flex-wrap:wrap;gap:1rem}
  .page-header .page-title{margin-bottom:0}

  .filters{display:flex;gap:1rem;margin-bottom:1.5rem;flex-wrap:wrap;align-items:center}
  .search-wrap{position:relative;flex:1;min-width:200px}
  .search-wrap svg{position:absolute;left:0.9rem;top:50%;transform:translateY(-50%);color:var(--gray)}
  .search-input{width:100%;padding:0.65rem 1rem 0.65rem 2.5rem;border:1.5px solid #e5e7eb;border-radius:var(--radius);font-size:0.95rem;transition:border-color var(--transition)}
  .search-input:focus{outline:none;border-color:var(--primary)}

  .categories{display:flex;gap:0.5rem;flex-wrap:wrap}
  .cat-btn{padding:0.4rem 1rem;border-radius:20px;border:1.5px solid #e5e7eb;background:white;font-size:0.88rem;font-weight:500;color:var(--gray);transition:all var(--transition)}
  .cat-btn:hover,.cat-btn.active{background:var(--primary);color:white;border-color:var(--primary)}

  .results-count{color:var(--gray);font-size:0.9rem;margin-bottom:1rem}

  .products-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(240px,1fr));gap:1.5rem}
  .product-card{background:white;border-radius:var(--radius);box-shadow:var(--shadow);transition:transform var(--transition),box-shadow var(--transition);overflow:hidden}
  .product-card:hover{transform:translateY(-4px);box-shadow:var(--shadow-hover)}
  .product-img-wrap{display:block;position:relative;height:200px;overflow:hidden;background:var(--gray-light)}
  .product-img-wrap img{width:100%;height:100%;object-fit:cover;transition:transform 0.4s ease}
  .product-card:hover .product-img-wrap img{transform:scale(1.05)}
  .img-placeholder{width:100%;height:100%;display:flex;align-items:center;justify-content:center}
  .out-badge{position:absolute;top:8px;left:8px;background:rgba(0,0,0,0.7);color:white;padding:0.2rem 0.6rem;border-radius:4px;font-size:0.75rem}
  .product-info{padding:1rem}
  .product-cat{font-size:0.75rem;color:var(--gray);text-transform:uppercase;letter-spacing:0.05em}
  .product-name{font-size:0.95rem;font-weight:700;margin:0.3rem 0;color:var(--dark);display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden}
  .product-name:hover{color:var(--primary)}
  .product-price{font-size:1.1rem;font-weight:800;color:var(--primary);margin:0.4rem 0 0.75rem}
  .product-actions{display:flex;gap:0.5rem;align-items:center}
  .btn-edit{display:flex;align-items:center;justify-content:center;width:36px;height:36px;border-radius:8px;border:1.5px solid #e5e7eb;color:var(--gray);transition:all var(--transition);flex-shrink:0}
  .btn-edit:hover{border-color:var(--primary);color:var(--primary)}

  .toast{position:fixed;bottom:2rem;right:2rem;background:var(--dark);color:white;padding:0.8rem 1.4rem;border-radius:var(--radius);box-shadow:0 8px 30px rgba(0,0,0,0.2);font-size:0.9rem;font-weight:500;animation:slideUp 0.3s ease;z-index:999}
  @keyframes slideUp{from{opacity:0;transform:translateY(10px)}to{opacity:1;transform:translateY(0)}}
</style>
