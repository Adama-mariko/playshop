import Env from '@ioc:Adonis/Core/Env'
import axios from 'axios'

const JEKO_API_URL = Env.get('JEKO_API_URL', 'https://api.jeko.africa')
const JEKO_API_KEY = Env.get('JEKO_API_KEY')
const JEKO_API_KEY_ID = Env.get('JEKO_API_KEY_ID')

const jekoClient = axios.create({
  baseURL: JEKO_API_URL,
  headers: {
    'X-API-KEY': JEKO_API_KEY,
    'X-API-KEY-ID': JEKO_API_KEY_ID,
    'Content-Type': 'application/json',
  },
  timeout: 15000,
})

export type JekoPaymentMethod = 'wave' | 'orange' | 'mtn' | 'moov' | 'djamo'

export interface JekoPaymentRequest {
  storeId: string
  amountCents: number
  currency: string
  reference: string
  paymentMethod: JekoPaymentMethod
  successUrl: string
  errorUrl: string
}

export interface JekoPaymentResponse {
  id: string
  storeId: string
  reference: string
  type: string
  paymentMethod: string
  status: 'pending' | 'success' | 'failed' | 'expired'
  redirectUrl: string
}

export default class JekoService {
  /**
   * Récupère le storeId depuis l'API Jèko
   */
  static async getStoreId(): Promise<string> {
    const storeId = Env.get('JEKO_STORE_ID', '')
    if (storeId) return storeId

    const { data } = await jekoClient.get('/partner_api/stores')
    const stores = Array.isArray(data) ? data : data.data ?? []
    if (!stores.length) throw new Error('Aucun magasin trouvé sur Jèko')
    return stores[0].id
  }

  /**
   * Crée une demande de paiement Jèko (type redirect)
   */
  static async createPaymentRequest(params: JekoPaymentRequest): Promise<JekoPaymentResponse> {
    const { data } = await jekoClient.post('/partner_api/payment_requests', {
      storeId: params.storeId,
      amountCents: params.amountCents,
      currency: params.currency,
      reference: params.reference,
      paymentDetails: {
        type: 'redirect',
        data: {
          paymentMethod: params.paymentMethod,
          successUrl: params.successUrl,
          errorUrl: params.errorUrl,
        },
      },
    })
    return data
  }

  /**
   * Vérifie le statut d'une demande de paiement
   */
  static async getPaymentStatus(paymentRequestId: string): Promise<JekoPaymentResponse> {
    const { data } = await jekoClient.get(`/partner_api/payment_requests/${paymentRequestId}`)
    return data
  }

  /**
   * Convertit la méthode de paiement PlayShop → Jèko
   */
  static mapPaymentMethod(method: string): JekoPaymentMethod {
    const map: Record<string, JekoPaymentMethod> = {
      wave: 'wave',
      orange_money: 'orange',
      mtn: 'mtn',
      moov: 'moov',
      djamo: 'djamo',
    }
    return map[method] ?? 'wave'
  }
}
