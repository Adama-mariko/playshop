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
    const isMobile = request.input('mobile') === '1'
    const mobileSuffix = isMobile ? '&mobile=1' : ''

    try {
      // Récupérer le storeId
      const storeId = await JekoService.getStoreId()

      // Créer la demande de paiement sur Jèko
      const jekoPayment = await JekoService.createPaymentRequest({
        storeId,
        amountCents: Math.round(order.totalAmount),
        currency: 'XOF',
        reference,
        paymentMethod: JekoService.mapPaymentMethod(order.paymentMethod ?? 'wave'),
        successUrl: `${appUrl}/api/payments/jeko-success?ref=${reference}${mobileSuffix}`,
        errorUrl: `${appUrl}/api/payments/jeko-error?ref=${reference}${mobileSuffix}`,
      })

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
      if (order && order.paymentStatus !== 'success') {
        order.paymentStatus = 'success'
        order.status = 'paid'
        await order.save()
      }
    }
    
    // Détecter si la requête vient du mobile via le User-Agent ou un paramètre
    const userAgent = request.header('User-Agent', '').toLowerCase()
    const isMobile = request.input('mobile') === '1' || 
                     userAgent.includes('dart') || 
                     userAgent.includes('flutter')
    
    if (isMobile) {
      // Redirection vers l'app mobile via deep link
      return response.redirect(`playshop://payment/success?ref=${ref}`)
    } else {
      // Redirection vers le frontend web
      const frontendUrl = Env.get('FRONTEND_URL', 'http://localhost:5173')
      return response.redirect(`${frontendUrl}/payment/success?ref=${ref}`)
    }
  }

  public async jekoError({ request, response }: HttpContextContract) {
    const ref = request.input('ref')
    if (ref) {
      const order = await Order.query().where('payment_reference', ref).first()
      if (order && order.paymentStatus !== 'success') {
        order.paymentStatus = 'failed'
        await order.save()
      }
    }
    
    const userAgent = request.header('User-Agent', '').toLowerCase()
    const isMobile = request.input('mobile') === '1' || 
                     userAgent.includes('dart') || 
                     userAgent.includes('flutter')
    
    if (isMobile) {
      return response.redirect(`playshop://payment/error?ref=${ref}`)
    } else {
      const frontendUrl = Env.get('FRONTEND_URL', 'http://localhost:5173')
      return response.redirect(`${frontendUrl}/payment/success?ref=${ref}&error=1`)
    }
  }

  /**
   * POST /api/payments/webhook
   * Webhook Jèko — transaction.completed
   */
  public async webhook({ request, response }: HttpContextContract) {
    const body = request.all()
    const secret = Env.get('JEKO_WEBHOOK_SECRET', '')

    // Vérification signature HMAC-SHA256
    // Jèko signe le raw body JSON — on le reconstruit de façon déterministe
    if (secret) {
      const crypto = await import('crypto')
      const signature = request.header('jeko-signature') ?? ''

      if (signature) {
        // request.raw() fonctionne si AdonisJS l'a capturé, sinon on reconstruit
        const rawBody = request.raw() ?? JSON.stringify(body)
        const expected = crypto.createHmac('sha256', secret).update(rawBody).digest('hex')

        if (signature !== expected) {
          return response.unauthorized({ message: 'Signature invalide' })
        }
      }
    }

    // 2. Extraire la référence depuis transactionDetails (format Jèko)
    const reference = body.transactionDetails?.reference ?? body.reference ?? null
    const status = body.status // 'success' | 'error'
    const transactionType = body.transactionType ?? 'payment'

    // On ne traite que les paiements entrants
    if (transactionType !== 'payment') {
      return response.ok({ received: true, skipped: true })
    }

    if (!reference) return response.badRequest({ message: 'Référence manquante' })

    const order = await Order.query().where('payment_reference', reference).first()
    if (!order) return response.notFound({ message: 'Commande introuvable' })

    // Idempotence — ne pas retraiter si déjà à jour
    if (order.paymentStatus === 'success') {
      return response.ok({ received: true, skipped: true, orderId: order.id })
    }

    if (status === 'success') {
      order.paymentStatus = 'success' 
      order.status = 'paid'
    } else if (status === 'error' || status === 'failed' || status === 'expired') {
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
   * Polling du statut — auth optionnelle (retour depuis redirection Jèko)
   */
  public async status({ params, auth, response }: HttpContextContract) {
    // Tenter l'auth sans bloquer si token absent/expiré
    let userId: number | null = null
    try {
      await auth.use('api').authenticate()
      userId = auth.use('api').user!.id
    } catch {}

    // Chercher la commande : par user_id si connecté, sinon juste par id
    const query = Order.query().where('id', params.orderId)
    if (userId) query.where('user_id', userId)
    const order = await query.first()

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
