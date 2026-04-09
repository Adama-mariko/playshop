<script lang="ts">
  import { onMount } from 'svelte'
  import api from '$lib/api'

  interface Order {
    id: number; status: string; total_amount: string
    payment_method: string; payment_status: string
    created_at: string; items: any[]
  }

  let orders = $state<Order[]>([])
  let loading = $state(true)

  onMount(async () => {
    try {
      const { data } = await api.get('/orders')
      orders = data
    } finally { loading = false }
  })

  async function cancelOrder(id: number) {
    if (!confirm('Annuler cette commande ?')) return
    await api.patch(`/orders/${id}/cancel`)
    orders = orders.map(o => o.id === id ? { ...o, status: 'cancelled' } : o)
  }

  const statusMap: Record<string, { label: string; cls: string }> = {
    pending:   { label: 'En attente',  cls: 'badge-warning' },
    paid:      { label: 'Payée',       cls: 'badge-success' },
    shipped:   { label: 'Expédiée',    cls: 'badge-info' },
    cancelled: { label: 'Annulée',     cls: 'badge-danger' },
  }

  const payMap: Record<string, string> = { pending: 'En attente', success: 'Reçu', failed: 'Échoué' }

  function formatDate(d: string) {
    return new Date(d).toLocaleDateString('fr-FR', { day:'2-digit', month:'short', year:'numeric', hour:'2-digit', minute:'2-digit' })
  }
</script>

<svelte:head><title>Mes commandes — PlayShop</title></svelte:head>

<div class="container" style="padding-top:2rem;padding-bottom:3rem">
  <h1 class="page-title">Mes commandes</h1>

  {#if loading}
    <div class="loading-spinner"><div class="spinner"></div></div>
  {:else if orders.length === 0}
    <div class="empty-state">
      <svg width="80" height="80" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
        <path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z"/>
        <polyline points="14 2 14 8 20 8"/>
      </svg>
      <h3>Aucune commande</h3>
      <p>Vous n'avez pas encore passé de commande.</p>
      <a href="/" class="btn btn-primary" style="margin-top:1rem">Commencer mes achats</a>
    </div>
  {:else}
    <div class="orders-list">
      {#each orders as order (order.id)}
        <div class="order-card card">
          <div class="order-header">
            <div>
              <h3>Commande #{order.id}</h3>
              <span class="order-date">{formatDate(order.created_at)}</span>
            </div>
            <span class="badge {statusMap[order.status]?.cls ?? 'badge-info'}">
              {statusMap[order.status]?.label ?? order.status}
            </span>
          </div>
          <div class="order-items">
            {#each order.items as item}
              <div class="order-item-row">
                <span>{item.product?.name ?? 'Produit'} × {item.quantity}</span>
                <span>{(parseFloat(item.unit_price) * item.quantity).toLocaleString('fr-FR')} FCFA</span>
              </div>
            {/each}
          </div>
          <div class="order-footer">
            <div class="order-meta">
              <span class="meta-item">💳 {order.payment_method === 'orange_money' ? 'Orange Money' : 'Wave'}</span>
              <span class="meta-item" class:paid={order.payment_status === 'success'} class:failed={order.payment_status === 'failed'}>
                {payMap[order.payment_status] ?? order.payment_status}
              </span>
            </div>
            <div class="order-right">
              <strong class="order-total">{parseInt(order.total_amount).toLocaleString('fr-FR')} FCFA</strong>
              {#if order.status === 'pending'}
                <button class="btn-cancel" onclick={() => cancelOrder(order.id)}>Annuler</button>
              {/if}
            </div>
          </div>
        </div>
      {/each}
    </div>
  {/if}
</div>

<style>
  .orders-list{display:flex;flex-direction:column;gap:1.25rem}
  .order-card{padding:1.5rem}
  .order-header{display:flex;justify-content:space-between;align-items:flex-start;margin-bottom:1rem}
  .order-header h3{font-size:1rem;font-weight:700}
  .order-date{font-size:0.82rem;color:var(--gray);margin-top:0.2rem;display:block}
  .order-items{border-top:1px solid #f3f4f6;padding-top:0.75rem;margin-bottom:0.75rem}
  .order-item-row{display:flex;justify-content:space-between;padding:0.35rem 0;font-size:0.9rem;color:var(--gray)}
  .order-footer{display:flex;justify-content:space-between;align-items:center;border-top:1px solid #f3f4f6;padding-top:0.75rem}
  .order-meta{display:flex;gap:1rem}
  .meta-item{font-size:0.85rem;color:var(--gray)}
  .meta-item.paid{color:#059669;font-weight:600}
  .meta-item.failed{color:var(--primary);font-weight:600}
  .order-right{display:flex;align-items:center;gap:1rem}
  .order-total{font-size:1.1rem;color:var(--primary)}
  .btn-cancel{padding:0.35rem 0.9rem;border-radius:6px;border:1.5px solid var(--primary);color:var(--primary);background:none;font-size:0.85rem;font-weight:600;transition:all var(--transition)}
  .btn-cancel:hover{background:var(--primary);color:white}
</style>
