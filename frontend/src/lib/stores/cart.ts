import { writable, derived } from 'svelte/store'

export interface CartItem {
  productId: number
  name: string
  price: number
  quantity: number
  image: string | null
}

const { subscribe, update, set } = writable<CartItem[]>([])

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
