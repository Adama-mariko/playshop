import { writable, derived } from 'svelte/store'
import { browser } from '$app/environment'

export interface CartItem {
  productId: number
  name: string
  price: number
  quantity: number
  image: string | null
}

const STORAGE_KEY = 'playshop_cart'

function loadFromStorage(): CartItem[] {
  if (!browser) return []
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    return raw ? JSON.parse(raw) : []
  } catch {
    return []
  }
}

function saveToStorage(items: CartItem[]) {
  if (!browser) return
  localStorage.setItem(STORAGE_KEY, JSON.stringify(items))
}

const { subscribe, update, set } = writable<CartItem[]>(loadFromStorage())

// Persiste automatiquement à chaque changement
subscribe((items) => saveToStorage(items))

export const cart = {
  subscribe,

  add(product: Omit<CartItem, 'quantity'>) {
    update((items) => {
      const existing = items.find((i) => i.productId === product.productId)
      if (existing) {
        return items.map((i) =>
          i.productId === product.productId ? { ...i, quantity: i.quantity + 1 } : i
        )
      }
      return [...items, { ...product, quantity: 1 }]
    })
  },

  remove(productId: number) {
    update((items) => items.filter((i) => i.productId !== productId))
  },

  updateQty(productId: number, quantity: number) {
    if (quantity <= 0) {
      cart.remove(productId)
      return
    }
    update((items) =>
      items.map((i) => (i.productId === productId ? { ...i, quantity } : i))
    )
  },

  // Appelé uniquement après paiement confirmé
  clear() {
    set([])
  },
}

export const cartTotal = derived({ subscribe }, ($items) =>
  $items.reduce((sum, i) => sum + i.price * i.quantity, 0)
)

export const cartCount = derived({ subscribe }, ($items) =>
  $items.reduce((sum, i) => sum + i.quantity, 0)
)
