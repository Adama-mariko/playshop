<script lang="ts">
  import { onMount } from 'svelte'
  import api from '$lib/api'
  import { cart } from '$lib/stores/cart'
  import { isAuthenticated } from '$lib/stores/auth'

  interface Product {
    id: number; name: string; description: string
    price: string; stock: number; image: string | null; category: string | null
  }

  let products = $state<Product[]>([])
  let loading = $state(true)
  let error = $state('')
  let selectedCategory = $state('')
  let toast = $state('')
  let toastTimer: ReturnType<typeof setTimeout>

  let categories = $derived([...new Set(products.map(p => p.category).filter(Boolean))] as string[])
  let filtered = $derived(selectedCategory ? products.filter(p => p.category === selectedCategory) : products)

  onMount(async () => {
    try {
      const { data } = await api.get('/products')
      products = data.data
    } catch {
      error = 'Impossible de charger les produits'
    } finally {
      loading = false
    }
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

<svelte:head><title>PlayShop — Accueil</title></svelte:head>

<!-- HERO -->
<section class="hero">
  <div class="container hero-inner">
    <div class="hero-text">
      <span class="hero-tag">Nouvelle collection</span>
      <h1>Découvrez les <span class="highlight">meilleurs produits</span> au meilleur prix</h1>
      <p>Des milliers de produits livrés rapidement. Paiement sécurisé via Orange Money et Wave.</p>
      <div class="hero-actions">
        <a href="/products" class="btn btn-primary">Voir les produits</a>
        {#if !$isAuthenticated}
          <a href="/register" class="btn btn-outline" style="color:white;border-color:rgba(255,255,255,0.5)">Créer un compte</a>
        {/if}
      </div>
    </div>
    <div class="hero-visual">
      <div class="hero-card">
        <svg width="80" height="80" viewBox="0 0 24 24" fill="none" stroke="rgba(255,255,255,0.6)" stroke-width="1.5">
          <path d="M6 2L3 6v14a2 2 0 002 2h14a2 2 0 002-2V6l-3-4z"/>
          <line x1="3" y1="6" x2="21" y2="6"/>
          <path d="M16 10a4 4 0 01-8 0"/>
        </svg>
        <p>PlayShop</p>
      </div>
    </div>
  </div>
</section>

<!-- FEATURES -->
<section class="features">
  <div class="container features-grid">
    {#each [
      { icon: 'fa-solid fa-rocket',          title: 'Livraison rapide',  desc: 'Recevez vos commandes en un temps record' },
      { icon: 'fa-solid fa-lock',            title: 'Paiement sécurisé', desc: 'Orange Money et Wave acceptés' },
      { icon: 'fa-solid fa-rotate-left',     title: 'Retours faciles',   desc: 'Retour gratuit sous 30 jours' },
      { icon: 'fa-solid fa-headset',         title: 'Support 24/7',      desc: 'Une équipe disponible pour vous aider' },
    ] as f}
      <div class="feature-item">
        <i class="feature-icon {f.icon}"></i>
        <h3>{f.title}</h3>
        <p>{f.desc}</p>
      </div>
    {/each}
  </div>
</section>

<!-- PRODUITS -->
<section class="products-section">
  <div class="container">
    <div class="section-header">
      <h2 class="page-title">Nos produits</h2>
      {#if categories.length > 0}
        <div class="categories">
          <button class="cat-btn" class:active={!selectedCategory} onclick={() => selectedCategory = ''}>Tous</button>
          {#each categories as cat}
            <button class="cat-btn" class:active={selectedCategory === cat} onclick={() => selectedCategory = cat}>{cat}</button>
          {/each}
        </div>
      {/if}
    </div>

    {#if loading}
      <div class="loading-spinner"><div class="spinner"></div></div>
    {:else if error}
      <div class="empty-state"><p>{error}</p></div>
    {:else if filtered.length === 0}
      <div class="empty-state"><h3>Aucun produit disponible</h3></div>
    {:else}
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
                <span class="out-of-stock-badge">Rupture</span>
              {/if}
            </a>
            <div class="product-info">
              {#if product.category}<span class="product-cat">{product.category}</span>{/if}
              <a href="/products/{product.id}"><h3 class="product-name">{product.name}</h3></a>
              <p class="product-price">{parseInt(product.price).toLocaleString('fr-FR')} FCFA</p>
              <button class="btn btn-dark product-btn" disabled={product.stock === 0} onclick={() => addToCart(product)}>
                {product.stock === 0 ? 'Rupture de stock' : 'Ajouter au panier'}
              </button>
            </div>
          </article>
        {/each}
      </div>
    {/if}
  </div>
</section>

{#if toast}<div class="toast">{toast}</div>{/if}

<style>
  .hero { background:linear-gradient(135deg,var(--dark) 0%,#16213e 60%,#0f3460 100%); color:white; padding:5rem 0; }
  .hero-inner { display:grid; grid-template-columns:1fr 1fr; gap:3rem; align-items:center; }
  .hero-tag { display:inline-block; background:rgba(233,69,96,0.2); color:var(--primary); padding:0.3rem 0.9rem; border-radius:20px; font-size:0.85rem; font-weight:600; margin-bottom:1rem; }
  .hero-text h1 { font-size:2.8rem; font-weight:800; line-height:1.2; margin-bottom:1rem; }
  .highlight { color:var(--primary); }
  .hero-text p { color:rgba(255,255,255,0.7); font-size:1.05rem; margin-bottom:2rem; }
  .hero-actions { display:flex; gap:1rem; flex-wrap:wrap; }
  .hero-visual { display:flex; justify-content:center; }
  .hero-card { width:220px; height:220px; background:rgba(255,255,255,0.05); border:1px solid rgba(255,255,255,0.1); border-radius:24px; display:flex; flex-direction:column; align-items:center; justify-content:center; gap:1rem; color:rgba(255,255,255,0.5); font-size:1.2rem; font-weight:700; }
  .features { padding:3rem 0; background:white; }
  .features-grid { display:grid; grid-template-columns:repeat(4,1fr); gap:1.5rem; }
  .feature-item { text-align:center; padding:1.5rem 1rem; }
  .feature-icon { font-size:2rem; display:block; margin-bottom:0.75rem; color:var(--primary); }
  .feature-item h3 { font-size:1rem; font-weight:700; margin-bottom:0.4rem; }
  .feature-item p { font-size:0.88rem; color:var(--gray); }
  .products-section { padding:3rem 0; }
  .section-header { display:flex; align-items:center; justify-content:space-between; flex-wrap:wrap; gap:1rem; margin-bottom:2rem; }
  .section-header .page-title { margin-bottom:0; }
  .categories { display:flex; gap:0.5rem; flex-wrap:wrap; }
  .cat-btn { padding:0.4rem 1rem; border-radius:20px; border:1.5px solid #e5e7eb; background:white; font-size:0.88rem; font-weight:500; color:var(--gray); transition:all var(--transition); }
  .cat-btn:hover,.cat-btn.active { background:var(--primary); color:white; border-color:var(--primary); }
  .products-grid { display:grid; grid-template-columns:repeat(auto-fill,minmax(240px,1fr)); gap:1.5rem; }
  .product-card { background:white; border-radius:var(--radius); box-shadow:var(--shadow); transition:transform var(--transition),box-shadow var(--transition); overflow:hidden; }
  .product-card:hover { transform:translateY(-4px); box-shadow:var(--shadow-hover); }
  .product-img-wrap { display:block; position:relative; height:220px; overflow:hidden; background:var(--gray-light); }
  .product-img-wrap img { width:100%; height:100%; object-fit:cover; transition:transform 0.4s ease; }
  .product-card:hover .product-img-wrap img { transform:scale(1.05); }
  .img-placeholder { width:100%; height:100%; display:flex; align-items:center; justify-content:center; }
  .out-of-stock-badge { position:absolute; top:10px; left:10px; background:rgba(0,0,0,0.7); color:white; padding:0.2rem 0.6rem; border-radius:4px; font-size:0.78rem; }
  .product-info { padding:1rem; }
  .product-cat { font-size:0.75rem; color:var(--gray); text-transform:uppercase; letter-spacing:0.05em; }
  .product-name { font-size:1rem; font-weight:700; margin:0.3rem 0; color:var(--dark); display:-webkit-box; -webkit-line-clamp:2; -webkit-box-orient:vertical; overflow:hidden; }
  .product-name:hover { color:var(--primary); }
  .product-price { font-size:1.15rem; font-weight:800; color:var(--primary); margin:0.5rem 0 0.75rem; }
  .product-btn { width:100%; justify-content:center; }
  .toast { position:fixed; bottom:2rem; right:2rem; background:var(--dark); color:white; padding:0.8rem 1.4rem; border-radius:var(--radius); box-shadow:0 8px 30px rgba(0,0,0,0.2); font-size:0.9rem; font-weight:500; animation:slideUp 0.3s ease; z-index:999; }
  @keyframes slideUp { from{opacity:0;transform:translateY(10px)} to{opacity:1;transform:translateY(0)} }
  @media(max-width:768px) { .hero-inner{grid-template-columns:1fr} .hero-visual{display:none} .hero-text h1{font-size:2rem} .features-grid{grid-template-columns:repeat(2,1fr)} .section-header{flex-direction:column;align-items:flex-start} }
</style>
