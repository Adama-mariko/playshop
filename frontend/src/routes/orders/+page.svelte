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
    updated_at: string
    items: OrderItem[]
  }

  let orders = $state<Order[]>([])
  let loading = $state(true)

  let deleteModal = $state<{ open: boolean; order: Order | null }>({ open: false, order: null })
  let deleting = $state(false)

  const PAY_OPTIONS = [
    { value: 'wave',   label: 'Wave',         icon: 'fa-solid fa-water' },
    { value: 'orange', label: 'Orange Money', icon: 'fa-solid fa-circle' },
    { value: 'mtn',    label: 'MTN MoMo',     icon: 'fa-solid fa-mobile-screen' },
    { value: 'moov',   label: 'Moov Money',   icon: 'fa-solid fa-bolt' },
    { value: 'djamo',  label: 'Djamo',        icon: 'fa-solid fa-credit-card' },
  ]

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

  function goToPayment() {
    if (!payModal.order) return
    goto(`/checkout?orderId=${payModal.order.id}&method=${payModal.method}`)
    payModal = { open: false, order: null, method: 'wave' }
  }

  function imageUrl(img: string | null) {
    if (!img) return null
    if (img.startsWith('http')) return img
    return `https://playshop.onrender.com${img.split('/').map(p => encodeURIComponent(p)).join('/')}`
  }

  function fmtDate(d: string) {
    return new Date(d).toLocaleDateString('fr-FR', { day: '2-digit', month: 'short', year: 'numeric' })
  }
  function fmtTime(d: string) {
    return new Date(d).toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' }).replace(':', 'H')
  }
  function fmtDateShort(d: string) {
    return new Date(d).toLocaleDateString('fr-FR', { weekday: 'short', day: '2-digit', month: 'short', year: 'numeric' })
  }
  function fmtAmount(a: string) {
    return parseInt(a).toLocaleString('fr-FR')
  }

  function payLabel(m: string) { return PAY_OPTIONS.find(o => o.value === m)?.label ?? m }
  function payIcon(m: string)  { return PAY_OPTIONS.find(o => o.value === m)?.icon ?? 'fa-solid fa-money-bill' }

  const statusCfg: Record<string, { label: string; color: string; bg: string; icon: string }> = {
    pending:   { label: 'En attente', color: '#92400e', bg: '#fef3c7', icon: 'schedule' },
    paid:      { label: 'Payée',      color: '#065f46', bg: '#d1fae5', icon: 'check_circle' },
    shipped:   { label: 'Expédiée',   color: '#1e40af', bg: '#dbeafe', icon: 'local_shipping' },
    cancelled: { label: 'Annulée',    color: '#991b1b', bg: '#fee2e2', icon: 'cancel' },
  }
  const payCfg: Record<string, { label: string; color: string; icon: string }> = {
    pending: { label: 'En attente', color: '#92400e', icon: 'hourglass_empty' },
    success: { label: 'Payé',       color: '#065f46', icon: 'verified' },
    failed:  { label: 'Échoué',     color: '#991b1b', icon: 'error_outline' },
  }
</script>

<svelte:head><title>Mes commandes — PlayShop</title></svelte:head>

<!-- ══ MODAL suppression ══ -->
{#if deleteModal.open}
  <div class="overlay" onclick={() => deleteModal = { open: false, order: null }}>
    <div class="modal" onclick={e => e.stopPropagation()}>
      <div class="modal-ico danger"><span class="material-icons-round">delete_forever</span></div>
      <h3>Supprimer la commande ?</h3>
      <p>La commande <strong>#{deleteModal.order?.id}</strong> sera définitivement supprimée.</p>
      <div class="modal-row">
        <button class="m-cancel" onclick={() => deleteModal = { open: false, order: null }}>Annuler</button>
        <button class="m-confirm danger" onclick={confirmDelete} disabled={deleting}>
          {#if deleting}<span class="material-icons-round spin">refresh</span>{:else}<span class="material-icons-round">delete</span>{/if}
          {deleting ? 'Suppression...' : 'Supprimer'}
        </button>
      </div>
    </div>
  </div>
{/if}

<!-- ══ MODAL paiement ══ -->
{#if payModal.open}
  <div class="overlay" onclick={() => payModal = { open: false, order: null, method: 'wave' }}>
    <div class="modal" onclick={e => e.stopPropagation()}>
      <div class="modal-ico primary"><span class="material-icons-round">payment</span></div>
      <h3>Mode de paiement</h3>
      <p>Commande <strong>#{payModal.order?.id}</strong> — <strong>{fmtAmount(payModal.order?.total_amount ?? '0')} FCFA</strong></p>
      <div class="pay-list">
        {#each PAY_OPTIONS as opt}
          <label class="pay-opt" class:sel={payModal.method === opt.value}>
            <input type="radio" bind:group={payModal.method} value={opt.value} />
            <span class="pay-ico"><i class="{opt.icon}"></i></span>
            <strong>{opt.label}</strong>
            {#if payModal.method === opt.value}
              <span class="material-icons-round chk">check_circle</span>
            {/if}
          </label>
        {/each}
      </div>
      <div class="modal-row">
        <button class="m-cancel" onclick={() => payModal = { open: false, order: null, method: 'wave' }}>Annuler</button>
        <button class="m-confirm primary" onclick={goToPayment}>
          <span class="material-icons-round">arrow_forward</span> Continuer
        </button>
      </div>
    </div>
  </div>
{/if}

<!-- ══ PAGE ══ -->
<div class="page">
  <div class="container">

    <div class="page-head">
      <div>
        <h1>Mes commandes</h1>
        <p class="sub">Suivez et gérez toutes vos commandes</p>
      </div>
      <a href="/" class="btn btn-primary">
        <span class="material-icons-round">add_shopping_cart</span>
        Nouvelle commande
      </a>
    </div>

    {#if loading}
      <div class="loader"><div class="spin-ring"></div></div>

    {:else if orders.length === 0}
      <div class="empty">
        <span class="material-icons-round empty-ico">receipt_long</span>
        <h3>Aucune commande</h3>
        <p>Vous n'avez pas encore passé de commande.</p>
        <a href="/" class="btn btn-primary" style="margin-top:1.5rem">
          <span class="material-icons-round">storefront</span> Commencer mes achats
        </a>
      </div>

    {:else}

      <!-- ══════════════ COMMANDES ══════════════ -->
      <div class="orders">
        {#each orders as order (order.id)}
          <div class="o-card" class:cancelled={order.status === 'cancelled'}>

            <div class="o-head">
              <div class="o-id">
                <span class="material-icons-round o-ico">receipt</span>
                <div>
                  <span class="o-num">Commande #{order.id}</span>
                  <span class="o-date">
                    <span class="material-icons-round" style="font-size:12px;vertical-align:-2px">calendar_today</span>
                    {fmtDate(order.created_at)}
                  </span>
                </div>
              </div>
              <div class="badges">
                <span class="badge" style="color:{statusCfg[order.status]?.color};background:{statusCfg[order.status]?.bg}">
                  <span class="material-icons-round" style="font-size:13px">{statusCfg[order.status]?.icon}</span>
                  {statusCfg[order.status]?.label}
                </span>
                <span class="badge pay-badge" style="color:{payCfg[order.payment_status]?.color}">
                  <span class="material-icons-round" style="font-size:13px">{payCfg[order.payment_status]?.icon}</span>
                  {payCfg[order.payment_status]?.label}
                </span>
              </div>
            </div>

            <div class="o-items">
              {#each order.items as item}
                <div class="o-item">
                  <div class="o-thumb">
                    {#if imageUrl(item.product?.image ?? null)}
                      <img src={imageUrl(item.product?.image ?? null)} alt={item.product?.name} />
                    {:else}
                      <span class="material-icons-round" style="color:#ccc;font-size:20px">inventory_2</span>
                    {/if}
                  </div>
                  <span class="o-name">{item.product?.name ?? 'Produit'}</span>
                  <span class="o-qty">× {item.quantity}</span>
                  <span class="o-sub">{(parseFloat(item.unit_price) * item.quantity).toLocaleString('fr-FR')} FCFA</span>
                </div>
              {/each}
            </div>

            <div class="o-foot">
              <div class="o-meta">
                <span class="meta-tag">
                  <span class="material-icons-round" style="font-size:14px">payment</span>
                  {payLabel(order.payment_method)}
                </span>
                {#if order.phone_number}
                  <span class="meta-tag">
                    <span class="material-icons-round" style="font-size:14px">phone_iphone</span>
                    {order.phone_number}
                  </span>
                {/if}
              </div>
              <div class="o-right">
                <div class="o-total">
                  <span class="total-lbl">Total</span>
                  <span class="total-val">{fmtAmount(order.total_amount)} FCFA</span>
                </div>
                {#if order.status === 'pending'}
                  <div class="o-actions">
                    {#if order.payment_status === 'pending'}
                      <button class="btn-pay" onclick={() => payModal = { open: true, order, method: order.payment_method ?? 'wave' }}>
                        <span class="material-icons-round">payment</span> Payer
                      </button>
                    {/if}
                    <button class="btn-del" onclick={() => deleteModal = { open: true, order }}>
                      <span class="material-icons-round">delete_outline</span> Supprimer
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

  .page-head {
    display: flex; justify-content: space-between; align-items: flex-start;
    margin-bottom: 2.5rem; flex-wrap: wrap; gap: 1rem;
  }
  .page-head h1 { font-size: 1.9rem; font-weight: 800; }
  .sub { color: var(--gray); font-size: 0.9rem; margin-top: 0.2rem; }

  /* ══ COMMANDES ══ */
  .orders { display: flex; flex-direction: column; gap: 1.25rem; }

  .o-card {
    background: white; border-radius: 14px;
    box-shadow: 0 2px 12px rgba(0,0,0,0.07);
    overflow: hidden; transition: box-shadow 0.2s;
  }
  .o-card:hover { box-shadow: 0 6px 24px rgba(0,0,0,0.11); }
  .o-card.cancelled { opacity: 0.55; }

  .o-head {
    display: flex; justify-content: space-between; align-items: center;
    padding: 1rem 1.5rem; border-bottom: 1px solid #f3f4f6;
    flex-wrap: wrap; gap: 0.75rem;
  }
  .o-id { display: flex; align-items: center; gap: 0.75rem; }
  .o-ico { color: var(--primary); font-size: 1.3rem !important; }
  .o-num { font-weight: 700; font-size: 0.95rem; display: block; }
  .o-date { font-size: 0.76rem; color: var(--gray); display: block; margin-top: 0.1rem; }

  .badges { display: flex; gap: 0.5rem; flex-wrap: wrap; }
  .badge {
    display: inline-flex; align-items: center; gap: 0.3rem;
    padding: 0.28rem 0.7rem; border-radius: 20px;
    font-size: 0.76rem; font-weight: 600;
  }
  .pay-badge { background: #f3f4f6; }

  .o-items { padding: 0.75rem 1.5rem; display: flex; flex-direction: column; gap: 0.55rem; }
  .o-item { display: flex; align-items: center; gap: 0.85rem; }
  .o-thumb {
    width: 40px; height: 40px; border-radius: 8px;
    overflow: hidden; flex-shrink: 0; background: #f3f4f6;
    display: flex; align-items: center; justify-content: center;
  }
  .o-thumb img { width: 100%; height: 100%; object-fit: cover; }
  .o-name { flex: 1; font-size: 0.86rem; font-weight: 600; }
  .o-qty { font-size: 0.8rem; color: var(--gray); white-space: nowrap; }
  .o-sub { font-size: 0.86rem; font-weight: 700; white-space: nowrap; }

  .o-foot {
    display: flex; justify-content: space-between; align-items: center;
    padding: 0.85rem 1.5rem; background: #fafafa;
    border-top: 1px solid #f3f4f6; flex-wrap: wrap; gap: 0.75rem;
  }
  .o-meta { display: flex; gap: 0.5rem; flex-wrap: wrap; }
  .meta-tag {
    display: inline-flex; align-items: center; gap: 0.3rem;
    background: white; border: 1px solid #e5e7eb;
    padding: 0.22rem 0.65rem; border-radius: 20px;
    font-size: 0.78rem; color: var(--gray);
  }
  .o-right { display: flex; align-items: center; gap: 1.25rem; flex-wrap: wrap; }
  .o-total { display: flex; flex-direction: column; align-items: flex-end; }
  .total-lbl { font-size: 0.7rem; color: var(--gray); text-transform: uppercase; letter-spacing: 0.05em; }
  .total-val { font-size: 1.15rem; font-weight: 800; color: var(--primary); }

  .o-actions { display: flex; gap: 0.5rem; }
  .btn-pay {
    display: inline-flex; align-items: center; gap: 0.3rem;
    padding: 0.45rem 0.9rem; border-radius: 8px;
    background: var(--dark); color: white; border: none;
    font-size: 0.82rem; font-weight: 600; cursor: pointer; transition: background 0.2s;
  }
  .btn-pay:hover { background: var(--primary); }
  .btn-del {
    display: inline-flex; align-items: center; gap: 0.3rem;
    padding: 0.45rem 0.9rem; border-radius: 8px;
    background: #fff5f5; color: #dc2626;
    border: 1.5px solid #fca5a5;
    font-size: 0.82rem; font-weight: 600; cursor: pointer; transition: all 0.2s;
  }
  .btn-del:hover { background: #fee2e2; border-color: #dc2626; }

  /* ══ MODALS ══ */
  .overlay {
    position: fixed; inset: 0; z-index: 200;
    background: rgba(0,0,0,0.45);
    display: flex; align-items: center; justify-content: center;
    padding: 1rem; animation: fi 0.15s ease;
  }
  @keyframes fi { from { opacity: 0 } to { opacity: 1 } }

  .modal {
    background: white; border-radius: 16px;
    padding: 2rem; width: 100%; max-width: 420px;
    text-align: center; box-shadow: 0 20px 60px rgba(0,0,0,0.2);
    animation: su 0.2s ease;
  }
  @keyframes su { from { transform: translateY(14px); opacity: 0 } to { transform: translateY(0); opacity: 1 } }

  .modal-ico {
    width: 60px; height: 60px; border-radius: 50%;
    display: flex; align-items: center; justify-content: center;
    margin: 0 auto 1.1rem;
  }
  .modal-ico.danger { background: #fee2e2; color: #dc2626; }
  .modal-ico.primary { background: #ede9fe; color: #7c3aed; }
  .modal-ico .material-icons-round { font-size: 1.8rem !important; }

  .modal h3 { font-size: 1.15rem; font-weight: 700; margin-bottom: 0.5rem; }
  .modal p { color: var(--gray); font-size: 0.88rem; line-height: 1.5; margin-bottom: 1.4rem; }

  .modal-row { display: flex; gap: 0.75rem; }
  .m-cancel {
    flex: 1; padding: 0.7rem; border-radius: 10px;
    background: #f3f4f6; color: var(--dark); border: none;
    font-weight: 600; font-size: 0.88rem; cursor: pointer;
  }
  .m-cancel:hover { background: #e5e7eb; }
  .m-confirm {
    flex: 1; padding: 0.7rem; border-radius: 10px; border: none;
    font-weight: 600; font-size: 0.88rem; cursor: pointer;
    display: flex; align-items: center; justify-content: center; gap: 0.35rem;
  }
  .m-confirm:disabled { opacity: 0.6; cursor: not-allowed; }
  .m-confirm.danger { background: #dc2626; color: white; }
  .m-confirm.danger:hover:not(:disabled) { background: #b91c1c; }
  .m-confirm.primary { background: var(--primary); color: white; }

  .pay-list { display: flex; flex-direction: column; gap: 0.55rem; margin-bottom: 1.4rem; text-align: left; }
  .pay-opt {
    display: flex; align-items: center; gap: 0.7rem;
    padding: 0.7rem 0.9rem; border-radius: 10px;
    border: 2px solid #e5e7eb; cursor: pointer; transition: all 0.2s;
  }
  .pay-opt input { display: none; }
  .pay-opt.sel { border-color: var(--primary); background: rgba(233,69,96,0.04); }
  .pay-ico { font-size: 1.3rem; color: var(--primary); width: 1.5rem; text-align: center; }
  .pay-opt strong { flex: 1; font-size: 0.88rem; }
  .chk { color: var(--primary); font-size: 1.1rem !important; }

  /* misc */
  .loader { display: flex; justify-content: center; padding: 4rem; }
  .spin-ring {
    width: 38px; height: 38px; border-radius: 50%;
    border: 3px solid #f3f4f6; border-top-color: var(--primary);
    animation: spin 0.7s linear infinite;
  }
  .spin { animation: spin 0.8s linear infinite; display: inline-block; }
  @keyframes spin { to { transform: rotate(360deg); } }

  .empty { text-align: center; padding: 5rem 2rem; }
  .empty-ico { font-size: 5rem !important; color: #d1d5db; display: block; margin-bottom: 1rem; }
  .empty h3 { font-size: 1.3rem; font-weight: 700; margin-bottom: 0.5rem; }
  .empty p { color: var(--gray); }

  @media (max-width: 768px) {
    .o-head, .o-foot { flex-direction: column; align-items: flex-start; }
    .o-right { width: 100%; justify-content: space-between; }
  }
</style>
