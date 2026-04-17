<script lang="ts">
  import '../app.css'
  import { onMount } from 'svelte'
  import { page } from '$app/stores'
  import { goto } from '$app/navigation'
  import { auth, isAuthenticated } from '$lib/stores/auth'
  import { cart, cartCount } from '$lib/stores/cart'
  let { children } = $props()

  onMount(() => auth.fetchMe())

  let menuOpen = $state(false)

  async function handleLogout() {
    await auth.logout()
    goto('/')
  }
</script>

<div class="layout">
  <!-- NAVBAR -->
  <header class="navbar">
    <div class="container nav-inner">
      <!-- Logo -->
      <a href="/" class="logo">
        <svg width="28" height="28" viewBox="0 0 24 24" fill="none">
          <path d="M6 2L3 6v14a2 2 0 002 2h14a2 2 0 002-2V6l-3-4z" stroke="currentColor" stroke-width="2" stroke-linejoin="round"/>
          <line x1="3" y1="6" x2="21" y2="6" stroke="currentColor" stroke-width="2"/>
          <path d="M16 10a4 4 0 01-8 0" stroke="currentColor" stroke-width="2"/>
        </svg>
        PlayShop
      </a>

      <!-- Nav links desktop -->
      <nav class="nav-links">
        <a href="/" class:active={$page.url.pathname === '/'}>Accueil</a>
        <a href="/products" class:active={$page.url.pathname.startsWith('/products')}>Produits</a>
        {#if $isAuthenticated}
          <a href="/orders" class:active={$page.url.pathname === '/orders'}>Commandes</a>
          <a href="/historique" class:active={$page.url.pathname === '/historique'}>Historique</a>
        {/if}
      </nav>

      <!-- Actions -->
      <div class="nav-actions">
        <!-- Panier -->
        <a href="/cart" class="cart-btn" aria-label="Panier">
          <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <circle cx="9" cy="21" r="1"/><circle cx="20" cy="21" r="1"/>
            <path d="M1 1h4l2.68 13.39a2 2 0 001.99 1.61h9.72a2 2 0 001.99-1.61L23 6H6"/>
          </svg>
          {#if $cartCount > 0}
            <span class="cart-badge">{$cartCount}</span>
          {/if}
        </a>

        {#if $isAuthenticated}
          <div class="user-menu">
            <button class="user-btn" onclick={() => menuOpen = !menuOpen}>
              <span class="avatar">{$auth?.user?.name?.[0]?.toUpperCase() ?? 'U'}</span>
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
                <polyline points="6 9 12 15 18 9"/>
              </svg>
            </button>
            {#if menuOpen}
              <div class="dropdown" onmouseleave={() => menuOpen = false} role="menu">
                <div class="dropdown-header">
                  <strong>{$auth?.user?.name}</strong>
                  <span>{$auth?.user?.email}</span>
                </div>
                <a href="/orders" onclick={() => menuOpen = false}>Mes commandes</a>
                <a href="/historique" onclick={() => menuOpen = false}>Historique</a>
                <a href="/products/new" onclick={() => menuOpen = false}>Ajouter un produit</a>
                <hr />
                <button onclick={handleLogout}>Déconnexion</button>
              </div>
            {/if}
          </div>
        {:else}
          <a href="/login" class="btn btn-outline" style="padding: 0.5rem 1.1rem; font-size:0.9rem">Connexion</a>
          <a href="/register" class="btn btn-primary" style="padding: 0.5rem 1.1rem; font-size:0.9rem">Inscription</a>
        {/if}
      </div>
    </div>
  </header>

  <!-- PAGE CONTENT -->
  <main class="main-content">
    {@render children?.()}
  </main>

  <!-- FOOTER -->
  <footer class="footer">
    <div class="container footer-inner">
      <div class="footer-brand">
        <span class="logo" style="color:white">PlayShop</span>
        <p>Votre boutique en ligne de confiance.</p>
      </div>
      <div class="footer-links">
        <h4>Navigation</h4>
        <a href="/">Accueil</a>
        <a href="/products">Produits</a>
        <a href="/cart">Panier</a>
      </div>
      <div class="footer-links">
        <h4>Compte</h4>
        <a href="/login">Connexion</a>
        <a href="/register">Inscription</a>
        <a href="/orders">Commandes</a>
      </div>
    </div>
    <div class="footer-bottom">
      <p>© {new Date().getFullYear()} PlayShop. Tous droits réservés.</p>
    </div>
  </footer>
</div>

<style>
  .layout { display: flex; flex-direction: column; min-height: 100vh; }

  /* NAVBAR */
  .navbar {
    position: sticky; top: 0; z-index: 100;
    background: var(--dark);
    box-shadow: 0 2px 20px rgba(0,0,0,0.3);
  }

  .nav-inner {
    display: flex; align-items: center; gap: 2rem;
    height: 64px;
  }

  .logo {
    display: flex; align-items: center; gap: 0.5rem;
    font-size: 1.3rem; font-weight: 800;
    color: var(--primary);
    flex-shrink: 0;
  }

  .nav-links {
    display: flex; gap: 0.25rem; flex: 1;
  }

  .nav-links a {
    padding: 0.4rem 0.9rem;
    border-radius: 6px;
    color: rgba(255,255,255,0.75);
    font-weight: 500;
    font-size: 0.95rem;
    transition: all var(--transition);
  }

  .nav-links a:hover, .nav-links a.active {
    color: white;
    background: rgba(255,255,255,0.1);
  }

  .nav-actions { display: flex; align-items: center; gap: 0.75rem; margin-left: auto; }

  .cart-btn {
    position: relative;
    display: flex; align-items: center; justify-content: center;
    width: 40px; height: 40px;
    border-radius: 8px;
    color: rgba(255,255,255,0.8);
    transition: all var(--transition);
  }
  .cart-btn:hover { background: rgba(255,255,255,0.1); color: white; }

  .cart-badge {
    position: absolute; top: 2px; right: 2px;
    background: var(--primary);
    color: white; font-size: 0.65rem; font-weight: 700;
    width: 18px; height: 18px;
    border-radius: 50%;
    display: flex; align-items: center; justify-content: center;
  }

  /* User menu */
  .user-menu { position: relative; }

  .user-btn {
    display: flex; align-items: center; gap: 0.4rem;
    background: rgba(255,255,255,0.1);
    border: none; border-radius: 8px;
    padding: 0.4rem 0.8rem;
    color: white; cursor: pointer;
    transition: background var(--transition);
  }
  .user-btn:hover { background: rgba(255,255,255,0.18); }

  .avatar {
    width: 28px; height: 28px;
    background: var(--primary);
    border-radius: 50%;
    display: flex; align-items: center; justify-content: center;
    font-weight: 700; font-size: 0.85rem;
  }

  .dropdown {
    position: absolute; right: 0; top: calc(100% + 8px);
    background: white; border-radius: var(--radius);
    box-shadow: 0 10px 40px rgba(0,0,0,0.15);
    min-width: 200px; overflow: hidden;
    animation: fadeIn 0.15s ease;
  }

  @keyframes fadeIn { from { opacity:0; transform:translateY(-6px) } to { opacity:1; transform:translateY(0) } }

  .dropdown-header {
    padding: 0.9rem 1rem;
    background: var(--gray-light);
    display: flex; flex-direction: column; gap: 0.1rem;
  }
  .dropdown-header strong { font-size: 0.95rem; color: var(--dark); }
  .dropdown-header span { font-size: 0.8rem; color: var(--gray); }

  .dropdown a, .dropdown button {
    display: block; width: 100%;
    padding: 0.7rem 1rem;
    text-align: left;
    font-size: 0.9rem; color: var(--dark);
    background: none; border: none;
    transition: background var(--transition);
  }
  .dropdown a:hover, .dropdown button:hover { background: var(--gray-light); }
  .dropdown hr { border: none; border-top: 1px solid #e5e7eb; margin: 0.25rem 0; }
  .dropdown button { color: var(--primary); font-weight: 600; }

  /* MAIN */
  .main-content { flex: 1; }

  /* FOOTER */
  .footer { background: var(--dark); color: rgba(255,255,255,0.7); margin-top: 4rem; }

  .footer-inner {
    display: grid; grid-template-columns: 2fr 1fr 1fr;
    gap: 3rem; padding: 3rem 0;
  }

  .footer-brand p { margin-top: 0.5rem; font-size: 0.9rem; }

  .footer-links { display: flex; flex-direction: column; gap: 0.5rem; }
  .footer-links h4 { color: white; font-size: 0.95rem; margin-bottom: 0.25rem; }
  .footer-links a { font-size: 0.9rem; transition: color var(--transition); }
  .footer-links a:hover { color: var(--primary); }

  .footer-bottom {
    border-top: 1px solid rgba(255,255,255,0.1);
    padding: 1rem 0; text-align: center;
    font-size: 0.85rem;
  }

  @media (max-width: 768px) {
    .nav-links { display: none; }
    .footer-inner { grid-template-columns: 1fr; gap: 1.5rem; }
  }
</style>
