import { HttpContextContract } from '@ioc:Adonis/Core/HttpContext'
import { schema } from '@ioc:Adonis/Core/Validator'
import Order from 'App/Models/Order'

/*
|==========================================================================
| PaymentsController — Intégration Orange Money / Wave
|==========================================================================
|
| FONCTIONNEMENT RÉEL :
|
| 1. Le client appelle POST /api/payments/initiate
| 2. Le backend contacte l'API Orange Money ou Wave
| 3. L'API retourne une URL de paiement
| 4. Le client est redirigé vers cette URL pour payer sur son téléphone
| 5. Après paiement, Orange Money/Wave appelle notre webhook (callback)
| 6. Le backend met à jour le statut de la commande
|
| POUR ACTIVER LE VRAI PAIEMENT :
|
| Orange Money WebPay :
|   - Créer un compte sur https://developer.orange.com
|   - Obtenir client_id et client_secret
|   - Ajouter dans .env : OM_CLIENT_ID, OM_CLIENT_SECRET, OM_BASE_URL
|
| Wave :
|   - Créer un compte marchand sur https://www.wave.com/fr/business
|   - Obtenir une API key
|   - Ajouter dans .env : WAVE_API_KEY, WAVE_BASE_URL
|
| ACTUELLEMENT : Mode simulation (aucun vrai argent n'est débité)
|
*/

export default class PaymentsController {
  /**
   * POST /api/payments/initiate
   * Initie un paiement pour une commande existante
   */
  public async initiate({ request, auth, response }: HttpContextContract) {
    const user = auth.use('api').user!

    const { orderId } = await request.validate({
      schema: schema.create({
        orderId: schema.number(),
      }),
    })

    const order = await Order.query()
      .where('id', orderId)
      .where('user_id', user.id)
      .first()

    if (!order) {
      return response.notFound({ message: 'Commande introuvable' })
    }

    if (order.paymentStatus === 'success') {
      return response.badRequest({ message: 'Cette commande est déjà payée' })
    }

    // Génération d'une référence unique
    const paymentReference = `PS-${Date.now()}-${order.id}`
    order.paymentReference = paymentReference
    await order.save()

    // ----------------------------------------------------------------
    // MODE SIMULATION
    // En production, remplacer ce bloc par l'appel réel à l'API
    // ----------------------------------------------------------------
    const isSimulation = true // Passer à false quand les clés API sont configurées

    if (isSimulation) {
      return response.ok({
        simulation: true,
        message: 'SIMULATION — Aucun vrai paiement effectué',
        paymentReference,
        amount: order.totalAmount,
        method: order.paymentMethod,
        instructions: order.paymentMethod === 'orange_money'
          ? `Envoyez ${order.totalAmount} FCFA au numéro marchand Orange Money et indiquez la référence : ${paymentReference}`
          : `Envoyez ${order.totalAmount} FCFA au numéro marchand Wave et indiquez la référence : ${paymentReference}`,
      })
    }

    // ----------------------------------------------------------------
    // PRODUCTION — Orange Money WebPay (décommenter quand prêt)
    // ----------------------------------------------------------------
    // if (order.paymentMethod === 'orange_money') {
    //   const omResponse = await this._initiateOrangeMoney(order, paymentReference)
    //   return response.ok({ paymentUrl: omResponse.payment_url, paymentReference })
    // }

    // ----------------------------------------------------------------
    // PRODUCTION — Wave (décommenter quand prêt)
    // ----------------------------------------------------------------
    // if (order.paymentMethod === 'wave') {
    //   const waveResponse = await this._initiateWave(order, paymentReference)
    //   return response.ok({ paymentUrl: waveResponse.wave_launch_url, paymentReference })
    // }
  }

  /**
   * POST /api/payments/callback
   * Webhook appelé automatiquement par Orange Money ou Wave après paiement
   * NE PAS appeler manuellement — c'est Orange Money/Wave qui appelle cette route
   */
  public async callback({ request, response }: HttpContextContract) {
    const { reference, status } = request.only(['reference', 'status'])

    if (!reference || !status) {
      return response.badRequest({ message: 'Paramètres manquants' })
    }

    const order = await Order.query().where('payment_reference', reference).first()

    if (!order) {
      return response.notFound({ message: 'Commande introuvable pour cette référence' })
    }

    if (status === 'SUCCESS') {
      order.paymentStatus = 'success'
      order.status = 'paid'
    } else {
      order.paymentStatus = 'failed'
    }

    await order.save()

    return response.ok({
      message: 'Statut mis à jour',
      orderId: order.id,
      paymentStatus: order.paymentStatus,
    })
  }

  /**
   * PATCH /api/payments/confirm-manual/:orderId
   * Confirmation manuelle d'un paiement (pour la simulation ou paiement cash)
   * À utiliser uniquement en développement ou pour confirmer un paiement manuel
   */
  public async confirmManual({ params, auth, response }: HttpContextContract) {
    const user = auth.use('api').user!

    const order = await Order.query()
      .where('id', params.orderId)
      .where('user_id', user.id)
      .first()

    if (!order) {
      return response.notFound({ message: 'Commande introuvable' })
    }

    if (order.paymentStatus === 'success') {
      return response.badRequest({ message: 'Cette commande est déjà confirmée' })
    }

    order.paymentStatus = 'success'
    order.status = 'paid'
    await order.save()

    return response.ok({
      message: 'Paiement confirmé manuellement',
      orderId: order.id,
      status: order.status,
    })
  }

  /**
   * GET /api/payments/status/:orderId
   * Vérifie le statut de paiement d'une commande
   */
  public async status({ params, auth, response }: HttpContextContract) {
    const user = auth.use('api').user!

    const order = await Order.query()
      .where('id', params.orderId)
      .where('user_id', user.id)
      .first()

    if (!order) {
      return response.notFound({ message: 'Commande introuvable' })
    }

    return response.ok({
      orderId: order.id,
      paymentStatus: order.paymentStatus,
      orderStatus: order.status,
      paymentReference: order.paymentReference,
      totalAmount: order.totalAmount,
      paymentMethod: order.paymentMethod,
    })
  }
}
