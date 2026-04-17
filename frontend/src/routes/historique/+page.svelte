<script lang="ts">
  import { onMount } from 'svelte'
  import api from '$lib/api'

  interface Order {
    id: number
    total_amount: string
    payment_method: string
    payment_status: string
    payment_reference: string | null
    phone_number: string | null
    updated_at: string
  }

  const PAY = [
    { value: 'wave',   label: 'Wave',         icon: 'fa-solid fa-water',         fallback: 'fa-solid fa-water' },
    { value: 'orange', label: 'Orange Money', icon: 'fa-solid fa-circle',        fallback: 'fa-solid fa-circle' },
    { value: 'mtn',    label: 'MTN MoMo',     icon: 'fa-solid fa-mobile-screen', fallback: 'fa-solid fa-mobile-screen' },
    { value: 'moov',   label: 'Moov Money',   icon: 'fa-solid fa-bolt',          fallback: 'fa-solid fa-bolt' },
    { value: 'djamo',  label: 'Djamo',        icon: 'fa-solid fa-credit-card',   fallback: 'fa-solid fa-credit-card' },
  ]

  let transactions = $state<Order[]>([])
  let loading = $state(true)
  let search = $state('')
  let filterMethod = $state('all')

  onMount(async () => {
    try {
      const { data } = await api.get('/orders')
      transactions = (data as Order[]).filter(o => o.payment_status === 'success')
    } finally { loading = false }
  })

  function payLabel(m: string) { return PAY.find(p => p.value === m)?.label ?? m }
  function payFallback(m: string) { return PAY.find(p => p.value === m)?.fallback ?? 'fa-solid fa-money-bill' }

  function fmtTime(d: string) {
    return new Date(d).toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' }).replace(':', 'H')
  }
  function fmtDay(d: string) {
    return new Date(d).toLocaleDateString('fr-FR', { weekday: 'short', day: '2-digit', month: 'short', year: 'numeric' })
  }
  function fmtAmt(a: string) { return parseInt(a).toLocaleString('fr-FR') }

  let filtered = $derived(
    transactions.filter(t => {
      const matchMethod = filterMethod === 'all' || t.payment_method === filterMethod
      const q = search.toLowerCase()
      const matchSearch = !q ||
        (t.payment_reference ?? '').toLowerCase().includes(q) ||
        (t.phone_number ?? '').includes(q) ||
        payLabel(t.payment_method).toLowerCase().includes(q)
      return matchMethod && matchSearch
    })
  )

  const methods = ['all', 'wave', 'orange', 'mtn', 'moov', 'djamo']
  const methodLabels: Record<string, string> = {
    all: 'Tous', wave: 'Wave', orange: 'Orange Money',
    mtn: 'MTN MoMo', moov: 'Moov Money', djamo: 'Djamo'
  }
</script>

<svelte:head><title>Historique — PlayShop</title></svelte:head>

<div class="page">
  <div class="container">

    <div class="page-head">
      <div>
        <h1>Historique</h1>
        <p class="sub">Toutes vos transactions de paiement</p>
      </div>
      <a href="/orders" class="btn btn-outline">
        <span class="material-icons-round">receipt_long</span>
        Mes commandes
      </a>
    </div>

    <!-- Filtres -->
    <div class="filters">
      <div class="search-wrap">
        <span class="material-icons-round search-ico">search</span>
        <input
          type="text"
          bind:value={search}
          placeholder="Rechercher par référence, numéro..."
          class="search-input"
        />
        {#if search}
          <button class="clear-btn" onclick={() => search = ''}>
            <span class="material-icons-round">close</span>
          </button>
        {/if}
      </div>
      <div class="method-tabs">
        {#each methods as m}
          <button
            class="tab"
            class:active={filterMethod === m}
            onclick={() => filterMethod = m}
          >
            {#if m !== 'all'}<i class="{PAY.find(p => p.value === m)?.fallback}"></i>{/if}
            {methodLabels[m]}
          </button>
        {/each}
      </div>
    </div>

    <!-- Tableau -->
    {#if loading}
      <div class="loader"><div class="spin-ring"></div></div>

    {:else if filtered.length === 0}
      <div class="empty">
        <span class="material-icons-round empty-ico">receipt_long</span>
        <h3>Aucune transaction</h3>
        <p>{search || filterMethod !== 'all' ? 'Aucun résultat pour cette recherche.' : 'Vous n\'avez pas encore effectué de paiement.'}</p>
      </div>

    {:else}
      <!-- Résumé -->
      <div class="summary">
        <div class="sum-card">
          <span class="material-icons-round sum-ico" style="color:#059669">payments</span>
          <div>
            <span class="sum-val">{filtered.length}</span>
            <span class="sum-lbl">Transaction{filtered.length > 1 ? 's' : ''}</span>
          </div>
        </div>
        <div class="sum-card">
          <span class="material-icons-round sum-ico" style="color:#7c3aed">account_balance_wallet</span>
          <div>
            <span class="sum-val">
              {filtered.reduce((acc, t) => acc + parseInt(t.total_amount), 0).toLocaleString('fr-FR')} FCFA
            </span>
            <span class="sum-lbl">Total encaissé</span>
          </div>
        </div>
      </div>

      <div class="tx-card">
        <div class="tx-scroll">
          <table class="tx-tbl">
            <thead>
              <tr>
                <th>Opérateur</th>
                <th>Montant</th>
                <th>Référence</th>
                <th>Type</th>
                <th>Heure et date</th>
                <th>Statut</th>
              </tr>
            </thead>
            <tbody>
              {#each filtered as tx (tx.id)}
                <tr>
                  <td>
                    <div class="op-cell">
                      <div class="op-avatar"><i class="{payFallback(tx.payment_method)}"></i></div>
                      <div class="op-info">
                        <span class="op-name">{payLabel(tx.payment_method)}</span>
                        <span class="op-phone">{tx.phone_number ?? '—'}</span>
                      </div>
                    </div>
                  </td>
                  <td>
                    <span class="tx-amt">+ {fmtAmt(tx.total_amount)} F CFA</span>
                  </td>
                  <td>
                    <span class="tx-ref">{tx.payment_reference ?? `#${tx.id}`}</span>
                  </td>
                  <td>
                    <span class="tx-type">Encaissement</span>
                  </td>
                  <td>
                    <div class="tx-dt">
                      <span class="tx-time">{fmtTime(tx.updated_at)}</span>
                      <span class="tx-day">{fmtDay(tx.updated_at)}</span>
                    </div>
                  </td>
                  <td>
                    <span class="tx-ok">
                      <span class="material-icons-round">check_circle</span>
                    </span>
                  </td>
                </tr>
              {/each}
            </tbody>
          </table>
        </div>
      </div>
    {/if}

  </div>
</div>

<style>
  .page { padding: 2.5rem 0 4rem; }

  .page-head {
    display: flex; justify-content: space-between; align-items: flex-start;
    margin-bottom: 2rem; flex-wrap: wrap; gap: 1rem;
  }
  .page-head h1 { font-size: 1.9rem; font-weight: 800; }
  .sub { color: var(--gray); font-size: 0.9rem; margin-top: 0.2rem; }

  /* Filtres */
  .filters {
    display: flex; flex-direction: column; gap: 1rem;
    margin-bottom: 1.5rem;
  }

  .search-wrap {
    position: relative; display: flex; align-items: center;
    background: white; border: 1.5px solid #e5e7eb;
    border-radius: 10px; overflow: hidden;
    transition: border-color 0.2s;
  }
  .search-wrap:focus-within { border-color: var(--primary); }
  .search-ico {
    padding: 0 0.75rem; color: #9ca3af; font-size: 1.2rem !important;
    pointer-events: none;
  }
  .search-input {
    flex: 1; padding: 0.7rem 0; border: none; outline: none;
    font-size: 0.9rem; background: transparent;
  }
  .clear-btn {
    background: none; border: none; cursor: pointer;
    padding: 0 0.75rem; color: #9ca3af;
    display: flex; align-items: center;
  }
  .clear-btn:hover { color: var(--dark); }

  .method-tabs {
    display: flex; gap: 0.5rem; flex-wrap: wrap;
  }
  .tab {
    display: inline-flex; align-items: center; gap: 0.35rem;
    padding: 0.4rem 0.9rem; border-radius: 20px;
    border: 1.5px solid #e5e7eb; background: white;
    font-size: 0.82rem; font-weight: 600; cursor: pointer;
    color: var(--gray); transition: all 0.2s;
  }
  .tab:hover { border-color: var(--primary); color: var(--primary); }
  .tab.active { background: var(--primary); border-color: var(--primary); color: white; }

  /* Résumé */
  .summary {
    display: flex; gap: 1rem; margin-bottom: 1.5rem; flex-wrap: wrap;
  }
  .sum-card {
    display: flex; align-items: center; gap: 0.75rem;
    background: white; border-radius: 12px;
    padding: 1rem 1.5rem;
    box-shadow: 0 2px 8px rgba(0,0,0,0.06);
    flex: 1; min-width: 200px;
  }
  .sum-ico { font-size: 1.8rem !important; }
  .sum-val { display: block; font-size: 1.2rem; font-weight: 800; color: var(--dark); }
  .sum-lbl { display: block; font-size: 0.78rem; color: var(--gray); margin-top: 0.1rem; }

  /* Tableau */
  .tx-card {
    background: white; border-radius: 14px;
    box-shadow: 0 2px 12px rgba(0,0,0,0.07); overflow: hidden;
  }
  .tx-scroll { overflow-x: auto; }

  .tx-tbl { width: 100%; border-collapse: collapse; font-size: 0.875rem; }
  .tx-tbl thead tr { border-bottom: 1.5px solid #f3f4f6; }
  .tx-tbl th {
    padding: 0.9rem 1.5rem; text-align: left;
    font-size: 0.75rem; font-weight: 700;
    color: #6b7280; text-transform: uppercase; letter-spacing: 0.05em;
    white-space: nowrap; background: #fafafa;
  }
  .tx-tbl tbody tr { border-bottom: 1px solid #f3f4f6; transition: background 0.15s; }
  .tx-tbl tbody tr:last-child { border-bottom: none; }
  .tx-tbl tbody tr:hover { background: #f9fafb; }
  .tx-tbl td { padding: 1.1rem 1.5rem; vertical-align: middle; }

  .op-cell { display: flex; align-items: center; gap: 0.85rem; }
  .op-avatar {
    width: 42px; height: 42px; border-radius: 50%;
    background: #f3f4f6; display: flex; align-items: center;
    justify-content: center; font-size: 1.1rem; flex-shrink: 0;
    border: 1.5px solid #e5e7eb; color: var(--primary);
  }
  .op-info { display: flex; flex-direction: column; }
  .op-name { font-weight: 700; color: var(--dark); font-size: 0.9rem; }
  .op-phone { font-size: 0.76rem; color: #6b7280; margin-top: 0.15rem; }

  .tx-amt { color: #059669; font-weight: 700; font-size: 0.95rem; white-space: nowrap; }

  .tx-ref {
    font-family: monospace; font-size: 0.82rem; color: #374151;
    background: #f3f4f6; padding: 0.25rem 0.6rem; border-radius: 6px;
    white-space: nowrap; display: inline-block;
  }

  .tx-type {
    display: inline-flex; align-items: center;
    background: #ede9fe; color: #6d28d9;
    padding: 0.25rem 0.75rem; border-radius: 20px;
    font-size: 0.78rem; font-weight: 600; white-space: nowrap;
  }

  .tx-dt { display: flex; flex-direction: column; }
  .tx-time { font-weight: 800; color: var(--dark); font-size: 0.95rem; }
  .tx-day { font-size: 0.76rem; color: #6b7280; margin-top: 0.15rem; }

  .tx-ok { color: #059669; display: flex; align-items: center; }
  .tx-ok .material-icons-round { font-size: 1.6rem !important; }

  /* Misc */
  .loader { display: flex; justify-content: center; padding: 4rem; }
  .spin-ring {
    width: 38px; height: 38px; border-radius: 50%;
    border: 3px solid #f3f4f6; border-top-color: var(--primary);
    animation: spin 0.7s linear infinite;
  }
  @keyframes spin { to { transform: rotate(360deg); } }

  .empty { text-align: center; padding: 5rem 2rem; }
  .empty-ico { font-size: 5rem !important; color: #d1d5db; display: block; margin-bottom: 1rem; }
  .empty h3 { font-size: 1.3rem; font-weight: 700; margin-bottom: 0.5rem; }
  .empty p { color: var(--gray); }

  @media (max-width: 768px) {
    .tx-tbl th, .tx-tbl td { padding: 0.85rem 1rem; }
    .summary { flex-direction: column; }
  }
</style>
