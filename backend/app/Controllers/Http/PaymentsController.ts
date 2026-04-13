import { HttpContextContract } from '@ioc:Adonis/Core/HttpContext'
import { schema } from '@ioc:Adonis/Core/Validator'
import Env from '@ioc:Adonis/Core/Env'
import Order from 'App/Models/Order'
import JekoService from 'App/Services/JekoService'

export default class PaymentsController {

  /**
   * POST /api/payments/initiate
   * Crée une demande de paiement via l'API Jèko
   */
  public async initiate({ request, auth, response }: HttpContextContract) {
    const user = auth.use('api').user!

    const { orderId } = await request.validate({
      schema: schema.create({ orderId: schema.number() }),
    })

    const order = await Order.query()
      .where('id', orderId)
      .where('user_id', user.id)
      .first()

    if (!order) return response.notFound({ message: 'Commande introuvable' })
    if (order.paymentStatus === 'success') {
      return response.badRequest({ message: 'Cette commande est déjà payée' })
    }

    const reference = `PS-${Date.now()}-${order.id}`
    const appUrl = Env.get('APP_URL', 'http://localhost:3333')

    try {
      // Récupérer le storeId
      const storeId = await JekoService.getStoreId()

      // Créer la demande de paiement sur Jèko
      const jekoPayment = await JekoService.createPaymentRequest({
        storeId,
        amountCents: Math.round(order.totalAmount), // XOF : pas de conversion centimes
        currency: 'XOF',
        reference,
        paymentMethod: JekoService.mapPaymentMethod(order.paymentMethod ?? 'wave'),
        successUrl: `${appUrl}/api/payments/jeko-success?ref=${reference}`,
        errorUrl: `${appUrl}/api/payments/jeko-error?ref=${reference}`,      })

      // Sauvegarder la référence et l'ID Jèko
      order.paymentReference = reference
      order.jekoPaymentId = jekoPayment.id
      await order.save()

      return response.ok({
        method: order.paymentMethod,
        reference,
        amount: order.totalAmount,
        phoneNumber: order.phoneNumber ?? '',
        paymentUrl: jekoPayment.redirectUrl,  // URL de redirection Jèko
        jekoPaymentId: jekoPayment.id,
        instructions: `Vous allez être redirigé vers ${order.paymentMethod === 'wave' ? 'Wave' : 'Orange Money'} pour payer ${order.totalAmount.toLocaleString('fr-FR')} FCFA`,
      })
    } catch (e: any) {
      const msg = e?.response?.data?.message ?? e?.message ?? 'Erreur Jèko'
      return response.serviceUnavailable({
        message: `Paiement indisponible : ${msg}. Veuillez contacter le support.`,
      })
    }
  }

  /**
   * GET /api/payments/jeko-success
   * Callback Jèko après paiement réussi
   */
  public async jekoSuccess({ request, response }: HttpContextContract) {
    const ref = request.input('ref')
    if (ref) {
      const order = await Order.query().where('payment_reference', ref).first()
      if (order) {
        order.paymentStatus = 'success'
        order.status = 'paid'
        await order.save()
      }
    }
    // Rediriger vers le frontend
    return response.redirect(`${Env.get('FRONTEND_URL', 'http://localhost:5173')}/checkout?status=success&ref=${ref}`)
  }

  /**
   * GET /api/payments/jeko-error
   * Callback Jèko après paiement échoué
   */
  public async jekoError({ request, response }: HttpContextContract) {
    const ref = request.input('ref')
    if (ref) {
      const order = await Order.query().where('payment_reference', ref).first()
      if (order) {
        order.paymentStatus = 'failed'
        await order.save()
      }
    }
    return response.redirect(`${Env.get('FRONTEND_URL', 'http://localhost:5173')}/checkout?status=error&ref=${ref}`)
  }

  /**
   * POST /api/payments/webhook
   * Webhook Jèko — appelé automatiquement par Jèko après paiement
   */
  public async webhook({ request, response }: HttpContextContract) {
    const body = request.all()
    const reference = body.reference
    const status = body.status // 'success' | 'failed' | 'pending'

    if (!reference) return response.badRequest({ message: 'Référence manquante' })

    const order = await Order.query().where('payment_reference', reference).first()
    if (!order) return response.notFound({ message: 'Commande introuvable' })

    if (status === 'success') {
      order.paymentStatus = 'success'
      order.status = 'paid'
    } else if (status === 'failed' || status === 'expired') {
      order.paymentStatus = 'failed'
    }

    await order.save()
    return response.ok({ received: true, orderId: order.id, paymentStatus: order.paymentStatus })
  }

  /**
   * POST /api/payments/callback  (ancien — gardé pour compatibilité)
   */
  public async callback({ request, response }: HttpContextContract) {
    const body = request.all()
    const reference = body.reference || body.ref
    const rawStatus = body.status || body.payment_status || ''
    const isSuccess = ['succeeded', 'SUCCESS', 'success', 'SUCCESSFUL'].includes(rawStatus)

    if (!reference) return response.badRequest({ message: 'Référence manquante' })

    const order = await Order.query().where('payment_reference', reference).first()
    if (!order) return response.notFound({ message: 'Commande introuvable' })

    order.paymentStatus = isSuccess ? 'success' : 'failed'
    if (isSuccess) order.status = 'paid'
    await order.save()

    return response.ok({ received: true, orderId: order.id, paymentStatus: order.paymentStatus })
  }

  /**
   * GET /api/payments/status/:orderId
   * Polling du statut — vérifie aussi sur Jèko si le paiement est en attente
   */
  public async status({ params, auth, response }: HttpContextContract) {
    const user = auth.use('api').user!

    const order = await Order.query()
      .where('id', params.orderId)
      .where('user_id', user.id)
      .first()

    if (!order) return response.notFound({ message: 'Commande introuvable' })

    // Si en attente et qu'on a un ID Jèko, vérifier le statut en temps réel
    if (order.paymentStatus === 'pending' && order.jekoPaymentId) {
      try {
        const jekoStatus = await JekoService.getPaymentStatus(order.jekoPaymentId)
        if (jekoStatus.status === 'success') {
          order.paymentStatus = 'success'
          order.status = 'paid'
          await order.save()
        } else if (jekoStatus.status === 'failed' || jekoStatus.status === 'expired') {
          order.paymentStatus = 'failed'
          await order.save()
        }
      } catch (_) {}
    }

    return response.ok({
      orderId: order.id,
      paymentStatus: order.paymentStatus,
      orderStatus: order.status,
      paymentReference: order.paymentReference,
      totalAmount: order.totalAmount,
      paymentMethod: order.paymentMethod,
      phoneNumber: order.phoneNumber,
    })
  }

  /**
   * PATCH /api/payments/confirm-manual/:orderId  (dev/test uniquement)
   */
  public async confirmManual({ params, auth, response }: HttpContextContract) {
    const user = auth.use('api').user!

    const order = await Order.query()
      .where('id', params.orderId)
      .where('user_id', user.id)
      .first()

    if (!order) return response.notFound({ message: 'Commande introuvable' })
    if (order.paymentStatus === 'success') {
      return response.badRequest({ message: 'Cette commande est déjà confirmée' })
    }

    order.paymentStatus = 'success'
    order.status = 'paid'
    await order.save()

    return response.ok({
      message: 'Paiement confirmé (simulation)',
      orderId: order.id,
      paymentStatus: order.paymentStatus,
      orderStatus: order.status,
    })
  }
}
