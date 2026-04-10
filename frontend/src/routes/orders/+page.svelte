<script lang="ts">
  import { onMount } from 'svelte'
  import { goto } from '$app/navigation'
  import api from '$lib/api'

  interface OrderItem {
    id: number
    quantity: number
    unit_price: string
    product: { name: string; image: string | null } | null
  }

  interface Order {
    id: number
    status: string
    total_amount: string
    payment_method: string
    payment_status: string
    payment_reference: string | null
    phone_number: string | null
    created_at: string
    items: OrderItem[]
  }

  let orders = $state<Order[]>([])
  let loading = $state(true)

  // Modal suppression
  let deleteModal = $state<{ open: boolean; order: Order | null }>({ open: false, order: null })
  let deleting = $state(false)

  // Modal paiement
  let payModal = $state<{ open: boolean; order: Order | null; method: string }>({
    open: false, order: null, method: 'wave'
  })

  onMount(loadOrders)

  async function loadOrders() {
    loading = true
    try {
      const { data } = await api.get('/orders')
      orders = data
    } finally { loading = false }
  }

  async function confirmDelete() {
    if (!deleteModal.order) return
    deleting = true
    try {
      await api.delete(`/orders/${deleteModal.order.id}`)
      orders = orders.filter(o => o.id !== deleteModal.order!.id)
      deleteModal = { open: false, order: null }
    } catch (e: any) {
      alert(e.response?.data?.message ?? 'Impossible de supprimer')
    } finally { deleting = false }
  }

  function openPayModal(order: Order) {
    payModal = { open: true, order, method: order.payment_method ?? 'wave' }
  }

  function goToPayment() {
    if (!payModal.order) return
    goto(`/checkout?orderId=${payModal.order.id}&method=${payModal.method}`)
    payModal = { open: false, order: null, method: 'wave' }
  }

  function imageUrl(img: string | null) {
    if (!img) return null
    return img.startsWith('http') ? img : `http://localhost:3333${img}`
  }

  function formatDate(d: string) {
    return new Date(d).toLocaleDateString('fr-FR', {
      day: '2-digit', month: 'short', year: 'numeric',
      hour: '2-digit', minute: '2-digit'
    })
  }

  const statusCfg: Record<string, { label: string; color: string; bg: string; icon: string }> = {
    pending:   { label: 'En attente',  color: '#92400e', bg: '#fef3c7', icon: 'schedule' },
    paid:      { label: 'Payée',       color: '#065f46', bg: '#d1fae5', icon: 'check_circle' },
    shipped:   { label: 'Expédiée',    color: '#1e40af', bg: '#dbeafe', icon: 'local_shipping' },
    cancelled: { label: 'Annulée',     color: '#991b1b', bg: '#fee2e2', icon: 'cancel' },
  }

  const payCfg: Record<string, { label: string; color: string; icon: string }> = {
    pending: { label: 'En attente', color: '#92400e', icon: 'hourglass_empty' },
    success: { label: 'Payé',       color: '#065f46', icon: 'verified' },
    failed:  { label: 'Échoué',     color: '#991b1b', icon: 'error_outline' },
  }
</script>

<svelte:head><title>Mes commandes — PlayShop</title></svelte:head>

<!-- ══════════════════════════════════════════
     MODAL — Confirmation suppression
══════════════════════════════════════════ -->
{#if deleteModal.open}
  <div class="modal-overlay" onclick={() => deleteModal = { open: false, order: null }}>
    <div class="modal" onclick={(e) => e.stopPropagation()}>
      <div class="modal-icon danger">
        <span class="material-icons-round">delete_forever</span>
      </div>
      <h3>Supprimer la commande ?</h3>
      <p>La commande <strong>#{deleteModal.order?.id}</strong> sera définitivement supprimée. Cette action est irréversible.</p>
      <div class="modal-actions">
        <button class="btn-modal-cancel" onclick={() => deleteModal = { open: false, order: null }}>
          Annuler
        </button>
        <button class="btn-modal-confirm danger" onclick={confirmDelete} disabled={deleting}>
          {#if deleting}
            <span class="material-icons-round spin">refresh</span>
          {:else}
            <span class="material-icons-round">delete</span>
          {/if}
          {deleting ? 'Suppression...' : 'Supprimer'}
        </button>
      </div>
    </div>
  </div>
{/if}

<!-- ══════════════════════════════════════════
     MODAL — Choix du mode de paiement
══════════════════════════════════════════ -->
{#if payModal.open}
  <div class="modal-overlay" onclick={() => payModal = { open: false, order: null, method: 'wave' }}>
    <div class="modal" onclick={(e) => e.stopPropagation()}>
      <div class="modal-icon primary">
        <span class="material-icons-round">payment</span>
      </div>
      <h3>Choisir le mode de paiement</h3>
      <p>Commande <strong>#{payModal.order?.id}</strong> — <strong>{parseInt(payModal.order?.total_amount ?? '0').toLocaleString('fr-FR')} FCFA</strong></p>

      <div class="pay-choices">
        <label class="pay-choice" class:selected={payModal.method === 'wave'}>
          <input type="radio" bind:group={payModal.method} value="wave" />
          <div class="pay-choice-inner">
            <span class="material-icons-round pay-icon">waves</span>
            <div>
              <strong>Wave</strong>
              <span>QR code à scanner</span>
            </div>
          </div>
          {#if payModal.method === 'wave'}
            <span class="material-icons-round check-icon">check_circle</span>
          {/if}
        </label>

        <label class="pay-choice" class:selected={payModal.method === 'orange_money'}>
          <input type="radio" bind:group={payModal.method} value="orange_money" />
          <div class="pay-choice-inner">
            <span class="material-icons-round pay-icon" style="color:#ff6600">circle</span>
            <div>
              <strong>Orange Money</strong>
              <span>Redirection Orange</span>
            </div>
          </div>
          {#if payModal.method === 'orange_money'}
            <span class="material-icons-round check-icon">check_circle</span>
          {/if}
        </label>
      </div>

      <div class="modal-actions">
        <button class="btn-modal-cancel" onclick={() => payModal = { open: false, order: null, method: 'wave' }}>
          Annuler
        </button>
        <button class="btn-modal-confirm primary" onclick={goToPayment}>
          <span class="material-icons-round">arrow_forward</span>
          Continuer
        </button>
      </div>
    </div>
  </div>
{/if}

<!-- ══════════════════════════════════════════
     PAGE
══════════════════════════════════════════ -->
<div class="page">
  <div class="container">

    <div class="page-header">
      <div>
        <h1>Mes commandes</h1>
        <p class="subtitle">Suivez et gérez toutes vos commandes</p>
      </div>
      <a href="/" class="btn btn-primary">
        <span class="material-icons-round">add_shopping_cart</span>
        Nouvelle commande
      </a>
    </div>

    {#if loading}
      <div class="loading-spinner"><div class="spinner"></div></div>

    {:else if orders.length === 0}
      <div class="empty-state">
        <span class="material-icons-round empty-icon">receipt_long</span>
        <h3>Aucune commande</h3>
        <p>Vous n'avez pas encore passé de commande.</p>
        <a href="/" class="btn btn-primary" style="margin-top:1.5rem">
          <span class="material-icons-round">storefront</span>
          Commencer mes achats
        </a>
      </div>

    {:else}
      <div class="orders-list">
        {#each orders as order (order.id)}
          <div class="order-card" class:is-cancelled={order.status === 'cancelled'}>

            <!-- En-tête -->
            <div class="order-head">
              <div class="order-id-wrap">
                <span class="material-icons-round order-icon">receipt</span>
                <div>
                  <span class="order-num">Commande #{order.id}</span>
                  <span class="order-date">
                    <span class="material-icons-round" style="font-size:13px;vertical-align:-2px">calendar_today</span>
                    {formatDate(order.created_at)}
                  </span>
                </div>
              </div>

              <div class="badges-wrap">
                <span class="status-badge" style="color:{statusCfg[order.status]?.color};background:{statusCfg[order.status]?.bg}">
                  <span class="material-icons-round" style="font-size:14px">{statusCfg[order.status]?.icon}</span>
                  {statusCfg[order.status]?.label}
                </span>
                <span class="pay-status-badge" style="color:{payCfg[order.payment_status]?.color}">
                  <span class="material-icons-round" style="font-size:14px">{payCfg[order.payment_status]?.icon}</span>
                  {payCfg[order.payment_status]?.label}
                </span>
              </div>
            </div>

            <!-- Articles -->
            <div class="items-list">
              {#each order.items as item}
                <div class="item-row">
                  <div class="item-thumb">
                    {#if imageUrl(item.product?.image ?? null)}
                      <img src={imageUrl(item.product?.image ?? null)} alt={item.product?.name} />
                    {:else}
                      <span class="material-icons-round" style="color:#ccc;font-size:22px">inventory_2</span>
                    {/if}
                  </div>
                  <span class="item-name">{item.product?.name ?? 'Produit'}</span>
                  <span class="item-qty">× {item.quantity}</span>
                  <span class="item-subtotal">{(parseFloat(item.unit_price) * item.quantity).toLocaleString('fr-FR')} FCFA</span>
                </div>
              {/each}
            </div>

            <!-- Pied -->
            <div class="order-foot">
              <div class="foot-meta">
                <span class="meta-tag">
                  <span class="material-icons-round" style="font-size:15px">
                    {order.payment_method === 'wave' ? 'waves' : 'circle'}
                  </span>
                  {order.payment_method === 'wave' ? 'Wave' : 'Orange Money'}
                </span>
                {#if order.phone_number}
                  <span class="meta-tag">
                    <span class="material-icons-round" style="font-size:15px">phone_iphone</span>
                    {order.phone_number}
                  </span>
                {/if}
              </div>

              <div class="foot-right">
                <div class="total-wrap">
                  <span class="total-label">Total</span>
                  <span class="total-val">{parseInt(order.total_amount).toLocaleString('fr-FR')} FCFA</span>
                </div>

                {#if order.status === 'pending'}
                  <div class="action-btns">
                    {#if order.payment_status === 'pending'}
                      <button class="btn-pay" onclick={() => openPayModal(order)}>
                        <span class="material-icons-round">payment</span>
                        Payer
                      </button>
                    {/if}
                    <button class="btn-del" onclick={() => deleteModal = { open: true, order }}>
                      <span class="material-icons-round">delete_outline</span>
                      Supprimer
                    </button>
                  </div>
                {/if}
              </div>
            </div>

          </div>
        {/each}
      </div>
    {/if}

  </div>
</div>

<style>
  .page { padding: 2.5rem 0 4rem; }

  .page-header {
    display: flex; justify-content: space-between; align-items: flex-start;
    margin-bottom: 2.5rem; flex-wrap: wrap; gap: 1rem;
  }
  .page-header h1 { font-size: 1.9rem; font-weight: 800; }
  .subtitle { color: var(--gray); font-size: 0.9rem; margin-top: 0.25rem; }

  /* Empty */
  .empty-state { text-align: center; padding: 5rem 2rem; }
  .empty-icon { font-size: 5rem !important; color: #d1d5db; display: block; margin-bottom: 1rem; }
  .empty-state h3 { font-size: 1.3rem; font-weight: 700; margin-bottom: 0.5rem; }
  .empty-state p { color: var(--gray); }

  /* Liste */
  .orders-list { display: flex; flex-direction: column; gap: 1.25rem; }

  .order-card {
    background: white; border-radius: 14px;
    box-shadow: 0 2px 12px rgba(0,0,0,0.07);
    overflow: hidden; transition: box-shadow 0.2s;
  }
  .order-card:hover { box-shadow: 0 6px 24px rgba(0,0,0,0.11); }
  .order-card.is-cancelled { opacity: 0.55; }

  /* En-tête */
  .order-head {
    display: flex; justify-content: space-between; align-items: center;
    padding: 1.1rem 1.5rem; border-bottom: 1px solid #f3f4f6;
    flex-wrap: wrap; gap: 0.75rem;
  }
  .order-id-wrap { display: flex; align-items: center; gap: 0.75rem; }
  .order-icon { color: var(--primary); font-size: 1.4rem !important; }
  .order-num { font-weight: 700; font-size: 1rem; display: block; }
  .order-date { font-size: 0.78rem; color: var(--gray); margin-top: 0.1rem; display: block; }

  .badges-wrap { display: flex; gap: 0.5rem; flex-wrap: wrap; }
  .status-badge, .pay-status-badge {
    display: inline-flex; align-items: center; gap: 0.3rem;
    padding: 0.3rem 0.75rem; border-radius: 20px;
    font-size: 0.78rem; font-weight: 600;
  }
  .pay-status-badge { background: #f3f4f6; }

  /* Articles */
  .items-list { padding: 0.75rem 1.5rem; display: flex; flex-direction: column; gap: 0.6rem; }
  .item-row { display: flex; align-items: center; gap: 0.9rem; }
  .item-thumb {
    width: 42px; height: 42px; border-radius: 8px;
    overflow: hidden; flex-shrink: 0; background: #f3f4f6;
    display: flex; align-items: center; justify-content: center;
  }
  .item-thumb img { width: 100%; height: 100%; object-fit: cover; }
  .item-name { flex: 1; font-size: 0.88rem; font-weight: 600; color: var(--dark); }
  .item-qty { font-size: 0.82rem; color: var(--gray); white-space: nowrap; }
  .item-subtotal { font-size: 0.88rem; font-weight: 700; white-space: nowrap; }

  /* Pied */
  .order-foot {
    display: flex; justify-content: space-between; align-items: center;
    padding: 0.9rem 1.5rem; background: #fafafa;
    border-top: 1px solid #f3f4f6; flex-wrap: wrap; gap: 0.75rem;
  }
  .foot-meta { display: flex; gap: 0.5rem; flex-wrap: wrap; }
  .meta-tag {
    display: inline-flex; align-items: center; gap: 0.3rem;
    background: white; border: 1px solid #e5e7eb;
    padding: 0.25rem 0.7rem; border-radius: 20px;
    font-size: 0.8rem; color: var(--gray);
  }
  .foot-right { display: flex; align-items: center; gap: 1.25rem; flex-wrap: wrap; }
  .total-wrap { display: flex; flex-direction: column; align-items: flex-end; }
  .total-label { font-size: 0.72rem; color: var(--gray); text-transform: uppercase; letter-spacing: 0.05em; }
  .total-val { font-size: 1.2rem; font-weight: 800; color: var(--primary); }

  .action-btns { display: flex; gap: 0.5rem; }
  .btn-pay {
    display: inline-flex; align-items: center; gap: 0.35rem;
    padding: 0.5rem 1rem; border-radius: 8px;
    background: var(--dark); color: white; border: none;
    font-size: 0.85rem; font-weight: 600; cursor: pointer;
    transition: background 0.2s;
  }
  .btn-pay:hover { background: var(--primary); }
  .btn-del {
    display: inline-flex; align-items: center; gap: 0.35rem;
    padding: 0.5rem 1rem; border-radius: 8px;
    background: #fff5f5; color: #dc2626;
    border: 1.5px solid #fca5a5;
    font-size: 0.85rem; font-weight: 600; cursor: pointer;
    transition: all 0.2s;
  }
  .btn-del:hover { background: #fee2e2; border-color: #dc2626; }

  /* ══ MODALS ══ */
  .modal-overlay {
    position: fixed; inset: 0; z-index: 200;
    background: rgba(0,0,0,0.45);
    display: flex; align-items: center; justify-content: center;
    padding: 1rem;
    animation: fadeIn 0.15s ease;
  }
  @keyframes fadeIn { from { opacity: 0 } to { opacity: 1 } }

  .modal {
    background: white; border-radius: 16px;
    padding: 2rem; width: 100%; max-width: 420px;
    text-align: center;
    box-shadow: 0 20px 60px rgba(0,0,0,0.2);
    animation: slideUp 0.2s ease;
  }
  @keyframes slideUp { from { transform: translateY(16px); opacity: 0 } to { transform: translateY(0); opacity: 1 } }

  .modal-icon {
    width: 64px; height: 64px; border-radius: 50%;
    display: flex; align-items: center; justify-content: center;
    margin: 0 auto 1.25rem;
  }
  .modal-icon.danger { background: #fee2e2; color: #dc2626; }
  .modal-icon.primary { background: #ede9fe; color: #7c3aed; }
  .modal-icon .material-icons-round { font-size: 2rem !important; }

  .modal h3 { font-size: 1.2rem; font-weight: 700; margin-bottom: 0.6rem; }
  .modal p { color: var(--gray); font-size: 0.9rem; line-height: 1.5; margin-bottom: 1.5rem; }

  .modal-actions { display: flex; gap: 0.75rem; justify-content: center; }
  .btn-modal-cancel {
    flex: 1; padding: 0.75rem; border-radius: 10px;
    background: #f3f4f6; color: var(--dark); border: none;
    font-weight: 600; font-size: 0.9rem; cursor: pointer;
    transition: background 0.2s;
  }
  .btn-modal-cancel:hover { background: #e5e7eb; }
  .btn-modal-confirm {
    flex: 1; padding: 0.75rem; border-radius: 10px;
    border: none; font-weight: 600; font-size: 0.9rem; cursor: pointer;
    display: flex; align-items: center; justify-content: center; gap: 0.4rem;
    transition: opacity 0.2s;
  }
  .btn-modal-confirm:disabled { opacity: 0.6; cursor: not-allowed; }
  .btn-modal-confirm.danger { background: #dc2626; color: white; }
  .btn-modal-confirm.danger:hover:not(:disabled) { background: #b91c1c; }
  .btn-modal-confirm.primary { background: var(--primary); color: white; }
  .btn-modal-confirm.primary:hover { background: var(--primary-dark); }

  /* Choix paiement dans modal */
  .pay-choices { display: flex; flex-direction: column; gap: 0.75rem; margin-bottom: 1.5rem; text-align: left; }
  .pay-choice {
    display: flex; align-items: center; gap: 0.75rem;
    padding: 0.9rem 1rem; border-radius: 10px;
    border: 2px solid #e5e7eb; cursor: pointer;
    transition: all 0.2s; position: relative;
  }
  .pay-choice input { display: none; }
  .pay-choice.selected { border-color: var(--primary); background: rgba(233,69,96,0.04); }
  .pay-choice-inner { display: flex; align-items: center; gap: 0.75rem; flex: 1; }
  .pay-icon { font-size: 1.5rem !important; color: #0066ff; }
  .pay-choice-inner div { display: flex; flex-direction: column; }
  .pay-choice-inner strong { font-size: 0.9rem; }
  .pay-choice-inner span { font-size: 0.78rem; color: var(--gray); }
  .check-icon { color: var(--primary); font-size: 1.2rem !important; }

  .spin { animation: spin 0.8s linear infinite; display: inline-block; }
  @keyframes spin { to { transform: rotate(360deg); } }

  @media (max-width: 768px) {
    .order-head { flex-direction: column; align-items: flex-start; }
    .order-foot { flex-direction: column; align-items: flex-start; }
    .foot-right { width: 100%; justify-content: space-between; }
  }
</style>
