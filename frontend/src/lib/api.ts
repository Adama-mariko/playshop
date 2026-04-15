import axios from 'axios'
import { browser } from '$app/environment'

export const API_URL = 'https://playshop.onrender.com/api'

const api = axios.create({
  baseURL: API_URL,
  headers: { 'Content-Type': 'application/json' },
})

api.interceptors.request.use((config) => {
  if (browser) {
    const token = localStorage.getItem('token')
    if (token) config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

const PAYMENT_PATHS = ['/payments/', '/orders']

api.interceptors.response.use(
  (res) => res,
  (error) => {
    if (error.response?.status === 401 && browser) {
      const url = error.config?.url ?? ''
      const isPaymentRoute = PAYMENT_PATHS.some((p) => url.includes(p))
      // Ne pas déconnecter si on est sur une route de paiement (retour Jèko, polling, etc.)
      if (!isPaymentRoute) {
        localStorage.removeItem('token')
        window.location.href = '/login'
      }
    }
    return Promise.reject(error)
  }
)

export default api
