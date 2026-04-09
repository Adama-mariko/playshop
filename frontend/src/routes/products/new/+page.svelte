<script lang="ts">
  import { goto } from '$app/navigation'
  import api from '$lib/api'

  let name = $state(''), description = $state(''), price = $state(''), category = $state('')
  let imageFile = $state<File | null>(null)
  let imagePreview = $state('')
  let loading = $state(false), error = $state('')

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
      await api.post('/products', fd, { headers: { 'Content-Type': 'multipart/form-data' } })
      goto('/')
    } catch (e: any) {
      error = e.response?.data?.message ?? 'Erreur lors de la création'
    } finally { loading = false }
  }
</script>

<svelte:head><title>Ajouter un produit — PlayShop</title></svelte:head>

<div class="container" style="max-width:680px;padding-top:2rem;padding-bottom:3rem">
  <a href="/" class="back-link">← Retour</a>
  <h1 class="page-title">Ajouter un produit</h1>

  <form onsubmit={(e) => { e.preventDefault(); submit() }} class="product-form">
    <div class="upload-zone" onclick={() => document.getElementById('img-input')?.click()}>
      {#if imagePreview}
        <img src={imagePreview} alt="Aperçu" class="preview-img" />
        <div class="upload-overlay">Changer l'image</div>
      {:else}
        <svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="#ccc" stroke-width="1.5">
          <rect x="3" y="3" width="18" height="18" rx="2"/><circle cx="8.5" cy="8.5" r="1.5"/>
          <polyline points="21 15 16 10 5 21"/>
        </svg>
        <p>Cliquez pour choisir une image</p>
        <span>JPG, PNG, WEBP — max 5MB</span>
      {/if}
    </div>
    <input id="img-input" type="file" accept="image/*" onchange={onFileChange} style="display:none" />

    <div class="form-row">
      <div class="form-group">
        <label for="name">Nom du produit *</label>
        <input id="name" bind:value={name} placeholder="Ex: iPhone 15 Pro" required />
      </div>
      <div class="form-group">
        <label for="category">Catégorie</label>
        <input id="category" bind:value={category} placeholder="Ex: Téléphones" />
      </div>
    </div>

    <div class="form-group">
      <label for="desc">Description</label>
      <textarea id="desc" bind:value={description} rows="3" placeholder="Décrivez votre produit..."></textarea>
    </div>

    <div class="form-group">
      <label for="price">Prix (FCFA) *</label>
      <div class="price-input">
        <input id="price" type="number" bind:value={price} placeholder="0" min="0" required />
        <span class="price-suffix">FCFA</span>
      </div>
    </div>

    {#if error}<p class="error-msg">⚠ {error}</p>{/if}

    <button type="submit" class="btn btn-primary" style="width:100%;justify-content:center;padding:0.9rem" disabled={loading}>
      {loading ? 'Création en cours...' : 'Créer le produit'}
    </button>
  </form>
</div>

<style>
  .back-link{display:inline-flex;align-items:center;gap:0.3rem;color:var(--gray);font-size:0.9rem;margin-bottom:1.5rem;transition:color var(--transition)}
  .back-link:hover{color:var(--primary)}
  .product-form{display:flex;flex-direction:column;gap:1.25rem}
  .upload-zone{position:relative;height:220px;border:2px dashed #e5e7eb;border-radius:var(--radius);display:flex;flex-direction:column;align-items:center;justify-content:center;gap:0.5rem;cursor:pointer;overflow:hidden;background:var(--gray-light);transition:border-color var(--transition)}
  .upload-zone:hover{border-color:var(--primary)}
  .upload-zone p{font-weight:600;color:var(--dark)}
  .upload-zone span{font-size:0.8rem;color:var(--gray)}
  .preview-img{width:100%;height:100%;object-fit:cover}
  .upload-overlay{position:absolute;inset:0;background:rgba(0,0,0,0.4);color:white;display:flex;align-items:center;justify-content:center;font-weight:600;opacity:0;transition:opacity var(--transition)}
  .upload-zone:hover .upload-overlay{opacity:1}
  .form-row{display:grid;grid-template-columns:1fr 1fr;gap:1rem}
  .price-input{position:relative}
  .price-input input{width:100%;padding-right:4rem}
  .price-suffix{position:absolute;right:1rem;top:50%;transform:translateY(-50%);color:var(--gray);font-weight:600;font-size:0.9rem}
  @media(max-width:600px){.form-row{grid-template-columns:1fr}}
</style>
