<script lang="ts">
  import { onMount } from 'svelte'
  import { page } from '$app/stores'
  import { goto } from '$app/navigation'
  import api from '$lib/api'

  let name = $state(''), description = $state(''), price = $state(''), category = $state('')
  let currentImage = $state<string | null>(null)
  let imageFile = $state<File | null>(null)
  let imagePreview = $state('')
  let loading = $state(false), fetching = $state(true), error = $state('')

  onMount(async () => {
    try {
      const { data } = await api.get(`/products/${$page.params.id}`)
      name = data.name
      description = data.description ?? ''
      price = parseFloat(data.price).toString()
      category = data.category ?? ''
      currentImage = data.image
    } catch { goto('/') }
    finally { fetching = false }
  })

  function onFileChange(e: Event) {
    const input = e.target as HTMLInputElement
    imageFile = input.files?.[0] ?? null
    if (imageFile) imagePreview = URL.createObjectURL(imageFile)
  }

  async function submit() {
    if (!name || !price) { error = 'Le nom et le prix sont obligatoires'; return }
    loading = true; error = ''
    try {
      const fd = new FormData()
      fd.append('name', name)
      fd.append('description', description)
      fd.append('price', price)
      fd.append('category', category)
      if (imageFile) fd.append('image', imageFile)
      await api.put(`/products/${$page.params.id}`, fd, { headers: { 'Content-Type': 'multipart/form-data' } })
      goto(`/products/${$page.params.id}`)
    } catch (e: any) {
      error = e.response?.data?.message ?? 'Erreur lors de la modification'
    } finally { loading = false }
  }

  async function deleteProduct() {
    if (!confirm('Supprimer définitivement ce produit ?')) return
    await api.delete(`/products/${$page.params.id}`)
    goto('/')
  }

  function imageUrl(img: string | null) {
    if (!img) return null
    return img.startsWith('http') ? img : `http://localhost:3333${img}`
  }
</script>

<svelte:head><title>Modifier le produit — PlayShop</title></svelte:head>

{#if fetching}
  <div class="loading-spinner"><div class="spinner"></div></div>
{:else}
  <div class="container" style="max-width:680px;padding-top:2rem;padding-bottom:3rem">
    <a href="/products/{$page.params.id}" class="back-link">← Retour au produit</a>
    <div class="form-header">
      <h1 class="page-title">Modifier le produit</h1>
      <button class="btn-delete" onclick={deleteProduct}>
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14a2 2 0 01-2 2H8a2 2 0 01-2-2L5 6"/>
          <path d="M10 11v6"/><path d="M14 11v6"/>
        </svg>
        Supprimer
      </button>
    </div>

    <form onsubmit={(e) => { e.preventDefault(); submit() }} class="product-form">
      <!-- Zone image -->
      <button type="button" class="upload-zone" onclick={() => document.getElementById('img-input')?.click()}>
        {#if imagePreview}
          <img src={imagePreview} alt="Aperçu" class="preview-img" />
          <div class="upload-overlay">Changer l'image</div>
        {:else if imageUrl(currentImage)}
          <img src={imageUrl(currentImage)} alt="Image actuelle" class="preview-img" />
          <div class="upload-overlay">Changer l'image</div>
        {:else}
          <svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="#ccc" stroke-width="1.5">
            <rect x="3" y="3" width="18" height="18" rx="2"/><circle cx="8.5" cy="8.5" r="1.5"/>
            <polyline points="21 15 16 10 5 21"/>
          </svg>
          <p>Cliquez pour choisir une image</p>
        {/if}
      </button>
      <input id="img-input" type="file" accept="image/*" onchange={onFileChange} style="display:none" />

      <div class="form-row">
        <div class="form-group">
          <label for="name">Nom du produit *</label>
          <input id="name" bind:value={name} required />
        </div>
        <div class="form-group">
          <label for="category">Catégorie</label>
          <input id="category" bind:value={category} />
        </div>
      </div>

      <div class="form-group">
        <label for="desc">Description</label>
        <textarea id="desc" bind:value={description} rows="3"></textarea>
      </div>

      <div class="form-group">
        <label for="price">Prix (FCFA) *</label>
        <div class="price-input">
          <input id="price" type="number" bind:value={price} min="0" required />
          <span class="price-suffix">FCFA</span>
        </div>
      </div>

      {#if error}<p class="error-msg">⚠ {error}</p>{/if}

      <button type="submit" class="btn btn-primary" style="width:100%;justify-content:center;padding:0.9rem" disabled={loading}>
        {loading ? 'Enregistrement...' : 'Enregistrer les modifications'}
      </button>
    </form>
  </div>
{/if}

<style>
  .back-link{display:inline-flex;align-items:center;gap:0.3rem;color:var(--gray);font-size:0.9rem;margin-bottom:1.5rem;transition:color var(--transition)}
  .back-link:hover{color:var(--primary)}
  .form-header{display:flex;justify-content:space-between;align-items:center;margin-bottom:0}
  .form-header .page-title{margin-bottom:0}
  .btn-delete{display:flex;align-items:center;gap:0.4rem;padding:0.5rem 1rem;border-radius:8px;border:1.5px solid #fee2e2;color:#991b1b;background:#fff5f5;font-size:0.88rem;font-weight:600;transition:all var(--transition)}
  .btn-delete:hover{background:#fee2e2}
  .product-form{display:flex;flex-direction:column;gap:1.25rem;margin-top:1.5rem}
  .upload-zone{position:relative;height:220px;border:2px dashed #e5e7eb;border-radius:var(--radius);display:flex;flex-direction:column;align-items:center;justify-content:center;gap:0.5rem;cursor:pointer;overflow:hidden;background:var(--gray-light);transition:border-color var(--transition);width:100%}
  .upload-zone:hover{border-color:var(--primary)}
  .upload-zone p{font-weight:600;color:var(--dark)}
  .preview-img{width:100%;height:100%;object-fit:cover}
  .upload-overlay{position:absolute;inset:0;background:rgba(0,0,0,0.4);color:white;display:flex;align-items:center;justify-content:center;font-weight:600;opacity:0;transition:opacity var(--transition)}
  .upload-zone:hover .upload-overlay{opacity:1}
  .form-row{display:grid;grid-template-columns:1fr 1fr;gap:1rem}
  .price-input{position:relative}
  .price-input input{width:100%;padding-right:4rem}
  .price-suffix{position:absolute;right:1rem;top:50%;transform:translateY(-50%);color:var(--gray);font-weight:600;font-size:0.9rem}
  @media(max-width:600px){.form-row{grid-template-columns:1fr}}
</style>
