import { HttpContextContract } from '@ioc:Adonis/Core/HttpContext'
import { schema } from '@ioc:Adonis/Core/Validator'
import Order from 'App/Models/Order'
  

export default class PaymentsController {

  /**
   * POST /api/payments/initiate
   * Génère les URLs de paiement pour Wave ou Orange Money
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

    // Référence unique pour identifier ce paiement
    const reference = `PS-${Date.now()}-${order.id}`
    order.paymentReference = reference
    await order.save()

    const amount = order.totalAmount
    const phone = order.phoneNumber ?? ''

    // En production, remplacer par :
    //   POST https://api.wave.com/v1/checkout/sessions
    //   avec votre API key Wave
   
    if (order.paymentMethod === 'wave') {
      const paymentUrl = `https://pay.wave.com/m/MARCHAND_ID/c/sn/?amount=${amount}&ref=${reference}&phone=${phone}`
      const deepLink   = `wave://pay?amount=${amount}&ref=${reference}&merchant=MARCHAND_ID`

      return response.ok({
        method: 'wave',
        reference,
        amount,
        phoneNumber: phone,
        paymentUrl,   // Frontend → génère un QR code avec cette URL
        deepLink,     // Mobile   → ouvre l'app Wave directement
        instructions: `Scannez le QR code avec Wave ou ouvrez l'app Wave pour payer ${amount.toLocaleString('fr-FR')} FCFA`,
      })
    }

    // En production, remplacer par :
    //   POST https://api.orange.com/orange-money-webpay/dev/v1/webpayment
    //   avec votre client_id et client_secret Orange
    
    if (order.paymentMethod === 'orange_money') {
      const paymentUrl = `https://webpay.orange.sn/pay?amount=${amount}&ref=${reference}&phone=${phone}`
      const deepLink   = `orangemoney://pay?amount=${amount}&ref=${reference}&phone=${phone}`

      return response.ok({
        method: 'orange_money',
        reference,
        amount,
        phoneNumber: phone,
        paymentUrl,   // Frontend → redirige vers cette page Orange Money
        deepLink,     // Mobile   → ouvre l'app Orange Money directement
        instructions: `Cliquez sur le lien ou ouvrez Orange Money pour payer ${amount.toLocaleString('fr-FR')} FCFA`,
      })
    }

    return response.badRequest({ message: 'Méthode de paiement non supportée' })
  }

  /**
   * POST /api/payments/callback
   * Webhook appelé automatiquement par Wave ou Orange Money après paiement
   * NE PAS appeler manuellement — c'est Wave/Orange qui appelle cette route
   *
   * Wave envoie   : { reference, status: "succeeded" | "failed" }
   * Orange envoie : { reference, status: "SUCCESS" | "FAILED" }
   */
  public async callback({ request, response }: HttpContextContract) {
    const body = request.all()

    const reference = body.reference || body.ref
    const rawStatus  = body.status || body.payment_status || ''
    const isSuccess  = ['succeeded', 'SUCCESS', 'success', 'SUCCESSFUL'].includes(rawStatus)

    if (!reference) {
      return response.badRequest({ message: 'Référence manquante' })
    }

    const order = await Order.query().where('payment_reference', reference).first()

    if (!order) {
      return response.notFound({ message: 'Commande introuvable pour cette référence' })
    }

    if (isSuccess) {
      order.paymentStatus = 'success'
      order.status = 'paid'
    } else {
      order.paymentStatus = 'failed'
    }

    await order.save()

    return response.ok({
      received: true,
      orderId: order.id,
      paymentStatus: order.paymentStatus,
    })
  }

  /**
   * GET /api/payments/status/:orderId
   * Vérifie si le paiement a été validé
   * Appelé en polling toutes les 3 secondes depuis le frontend et le mobile
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
      paymentStatus: order.paymentStatus,  // pending | success | failed
      orderStatus: order.status,           // pending | paid | shipped | cancelled
      paymentReference: order.paymentReference,
      totalAmount: order.totalAmount,
      paymentMethod: order.paymentMethod,
      phoneNumber: order.phoneNumber,
    })
  }

  /**
   * PATCH /api/payments/confirm-manual/:orderId
   * Simule une confirmation de paiement — pour les tests Postman uniquement
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
      message: 'Paiement confirmé (simulation)',
      orderId: order.id,
      paymentStatus: order.paymentStatus,
      orderStatus: order.status,
    })
  }
}
