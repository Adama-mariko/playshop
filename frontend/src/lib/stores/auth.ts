import { writable, derived } from 'svelte/store'
import { browser } from '$app/environment'
import api from '$lib/api'

interface User {
  id: number
  name: string
  email: string
}

interface AuthStore {
  user: User | null
  token: string | null
  loading: boolean
}

const initial: AuthStore = {
  user: null,
  token: browser ? localStorage.getItem('token') : null,
  loading: false,
}

const { subscribe, set, update } = writable<AuthStore>(initial)

export const auth = {
  subscribe,

  async login(email: string, password: string) {
    update((s) => ({ ...s, loading: true }))
    const { data } = await api.post('/auth/login', { email, password })
    if (browser) localStorage.setItem('token', data.token)
    set({ user: data.user, token: data.token, loading: false })
  },

  async register(name: string, email: string, password: string) {
    await api.post('/auth/register', { name, email, password })
    await auth.login(email, password)
  },

  async logout() {
    try { await api.post('/auth/logout') } catch {}
    if (browser) localStorage.removeItem('token')
    set({ user: null, token: null, loading: false })
  },

  async fetchMe() {
    const token = browser ? localStorage.getItem('token') : null
    if (!token) return
    try {
      const { data } = await api.get('/auth/me')
      update((s) => ({ ...s, user: data }))
    } catch (e: any) {
      // Ne déconnecter que sur 401 explicite, pas sur erreur réseau/timeout
      if (e?.response?.status === 401) {
        if (browser) localStorage.removeItem('token')
        update((s) => ({ ...s, user: null, token: null }))
      }
    }
  },
}

export const isAuthenticated = derived(
  { subscribe },
  ($auth) => !!$auth.token
)
