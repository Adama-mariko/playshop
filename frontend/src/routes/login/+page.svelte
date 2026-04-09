<script lang="ts">
  import { goto } from '$app/navigation'
  import { auth } from '$lib/stores/auth'

  let email = $state(''), password = $state(''), error = $state(''), loading = $state(false)

  async function submit() {
    loading = true; error = ''
    try {
      await auth.login(email, password)
      goto('/')
    } catch (e: any) {
      error = e.response?.data?.message ?? 'Identifiants incorrects'
    } finally { loading = false }
  }
</script>

<svelte:head><title>Connexion — PlayShop</title></svelte:head>

<div class="auth-page">
  <div class="auth-card card">
    <div class="auth-logo">
      <svg width="36" height="36" viewBox="0 0 24 24" fill="none" stroke="var(--primary)" stroke-width="2">
        <path d="M6 2L3 6v14a2 2 0 002 2h14a2 2 0 002-2V6l-3-4z"/>
        <line x1="3" y1="6" x2="21" y2="6"/>
        <path d="M16 10a4 4 0 01-8 0"/>
      </svg>
      <span>PlayShop</span>
    </div>
    <h1>Connexion</h1>
    <p class="auth-sub">Bienvenue ! Connectez-vous à votre compte.</p>

    <form onsubmit={(e) => { e.preventDefault(); submit() }}>
      <div class="form-group">
        <label for="email">Email</label>
        <input id="email" type="email" bind:value={email} placeholder="votre@email.com" required />
      </div>
      <div class="form-group">
        <label for="password">Mot de passe</label>
        <input id="password" type="password" bind:value={password} placeholder="••••••••" required />
      </div>
      {#if error}<div class="alert-error">{error}</div>{/if}
      <button type="submit" class="btn btn-primary" style="width:100%;justify-content:center;padding:0.85rem;margin-top:0.5rem" disabled={loading}>
        {loading ? 'Connexion...' : 'Se connecter'}
      </button>
    </form>
    <p class="auth-switch">Pas encore de compte ? <a href="/register">S'inscrire</a></p>
  </div>
</div>

<style>
  .auth-page{min-height:80vh;display:flex;align-items:center;justify-content:center;padding:2rem}
  .auth-card{width:100%;max-width:420px;padding:2.5rem}
  .auth-logo{display:flex;align-items:center;gap:0.5rem;font-size:1.4rem;font-weight:800;color:var(--primary);margin-bottom:1.5rem}
  h1{font-size:1.6rem;font-weight:800;margin-bottom:0.3rem}
  .auth-sub{color:var(--gray);font-size:0.9rem;margin-bottom:1.5rem}
  form{display:flex;flex-direction:column;gap:1rem}
  .alert-error{background:#fee2e2;color:#991b1b;padding:0.75rem 1rem;border-radius:8px;font-size:0.9rem}
  .auth-switch{text-align:center;margin-top:1.5rem;font-size:0.9rem;color:var(--gray)}
  .auth-switch a{color:var(--primary);font-weight:600}
</style>
