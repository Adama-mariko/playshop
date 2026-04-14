import { HttpContextContract } from '@ioc:Adonis/Core/HttpContext'
import { schema, rules } from '@ioc:Adonis/Core/Validator'
import Order from 'App/Models/Order'
import Product from 'App/Models/Product'
import Database from '@ioc:Adonis/Lucid/Database'
import JekoService from 'App/Services/JekoService'

/** Normalise un numéro ivoirien en +225XXXXXXXXXX */
function normalizePhone(phone: string): string {
  const digits = phone.replace(/[\s\-\.\(\)]/g, '')
  if (digits.startsWith('+225')) return digits
  if (digits.startsWith('00225')) return '+225' + digits.slice(5)
  if (digits.length === 10) return '+225' + digits
  return digits
}

/** Valide un numéro ivoirien selon le mode de paiement
 *
 * Côte d'Ivoire — préfixes valides (10 chiffres) :
 *   01 → Moov
 *   05, 06 → MTN / Wave
 *   07, 08, 09 → Orange
 *
 * Orange Money : 07, 08, 09 uniquement
 * Wave         : tous les réseaux (01, 05, 06, 07, 08, 09)
 */
function validatePhone(phone: string, method: string): string | null {
  const digits = phone.replace(/[\s\-\.\(\)\+]/g, '').replace(/^225/, '')
  if (digits.length !== 10) {
    return 'Le numéro doit contenir exactement 10 chiffres (ex: 0701234567)'
  }
  const prefix = digits.substring(0, 2)
  const validAll = ['01', '05', '06', '07', '08', '09']
  const validOrange = ['07', '08', '09']

  if (!validAll.includes(prefix)) {
    return `Préfixe "${prefix}" non reconnu. Préfixes valides en Côte d'Ivoire : 01, 05, 06, 07, 08, 09`
  }

  if (method === 'orange_money' && !validOrange.includes(prefix)) {
    return `Orange Money accepte uniquement les numéros Orange (07, 08, 09). Votre numéro commence par ${prefix}.`
  }
  if (method === 'orange' && !validOrange.includes(prefix)) {
    return `Orange Money accepte uniquement les numéros Orange (07, 08, 09). Votre numéro commence par ${prefix}.`
  }
  if ((method === 'mtn') && !['05', '06'].includes(prefix)) {
    return `MTN MoMo accepte uniquement les numéros MTN (05, 06). Votre numéro commence par ${prefix}.`
  }
  if (method === 'moov' && prefix !== '01') {
    return `Moov Money accepte uniquement les numéros Moov (01). Votre numéro commence par ${prefix}.`
  }

  return null // valide
}

export default class OrdersController {
  /**
   * GET /api/orders
   */
  public async index({ auth, response }: HttpContextContract) {
    const user = auth.use('api').user!

    const orders = await Order.query()
      .where('user_id', user.id)
      .preload('items', (q) => q.preload('product'))
      .orderBy('created_at', 'desc')

    // Sync automatique des commandes en attente avec Jèko
    for (const order of orders) {
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
    }

    return response.ok(orders)
  }

  /**
   * GET /api/orders/:id
   */
  public async show({ params, auth, response }: HttpContextContract) {
    const user = auth.use('api').user!

    const order = await Order.query()
      .where('id', params.id)
      .where('user_id', user.id)
      .preload('items', (q) => q.preload('product'))
      .first()

    if (!order) {
      return response.notFound({ message: 'Commande introuvable' })
    }

    return response.ok(order)
  }

  /**
   * POST /api/orders
   */
  public async store({ request, auth, response }: HttpContextContract) {
    try {
      await auth.use('api').authenticate()
    } catch {
      return response.unauthorized({ message: 'Authentification requise. Veuillez vous connecter.' })
    }
    const user = auth.use('api').user!

    const payload = await request.validate({
      schema: schema.create({
        items: schema.array([rules.minLength(1)]).members(
          schema.object().members({
            productId: schema.number(),
            quantity: schema.number([rules.unsigned(), rules.range(1, 999)]),
          })
        ),
        paymentMethod: schema.enum(['wave', 'orange_money', 'orange', 'mtn', 'moov', 'djamo'] as const),
        phoneNumber: schema.string({ trim: true }, [
          rules.maxLength(20),
          rules.regex(/^(\+225|00225)?[0-9]{10}$/),
        ]),
      }),
      messages: {
        'phoneNumber.regex': 'Numéro invalide. Format attendu : 10 chiffres (ex: 0701234567) ou +225 suivi de 10 chiffres',
        'phoneNumber.required': 'Le numéro de téléphone est obligatoire',
      },
    })

    // Validation du numéro ivoirien selon le mode de paiement
    const phoneError = validatePhone(payload.phoneNumber, payload.paymentMethod)
    if (phoneError) {
      return response.badRequest({ message: phoneError })
    }

    // Vérification du stock et calcul du total
    let totalAmount = 0
    const itemsData: Array<{ productId: number; quantity: number; unitPrice: number }> = []

    for (const item of payload.items) {
      const product = await Product.find(item.productId)

      if (!product) {
        return response.badRequest({ message: `Produit #${item.productId} introuvable` })
      }

      if (product.stock < item.quantity) {
        return response.badRequest({
          message: `Stock insuffisant pour "${product.name}" (disponible: ${product.stock})`,
        })
      }

      totalAmount += product.price * item.quantity
      itemsData.push({
        productId: item.productId,
        quantity: item.quantity,
        unitPrice: product.price,
      })
    }

    // Transaction atomique
    const order = await Database.transaction(async (trx) => {
      const newOrder = new Order()
      newOrder.userId = user.id
      newOrder.status = 'pending'
      newOrder.totalAmount = totalAmount
      newOrder.paymentMethod = payload.paymentMethod
      // Normalisation : toujours +225XXXXXXXXXX
      newOrder.phoneNumber = normalizePhone(payload.phoneNumber)
      newOrder.paymentStatus = 'pending'
      newOrder.useTransaction(trx)
      await newOrder.save()

      for (const item of itemsData) {
        await newOrder.related('items').create({
          productId: item.productId,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
        })

        await Product.query({ client: trx })
          .where('id', item.productId)
          .decrement('stock', item.quantity)
      }

      return newOrder
    })

    await order.load('items', (q) => q.preload('product'))

    return response.created({
      message: 'Commande créée avec succès',
      order,
    })
  }

  /**
   * DELETE /api/orders/:id
   * Suppression définitive d'une commande annulée ou en attente
   */
  public async destroy({ params, auth, response }: HttpContextContract) {
    const user = auth.use('api').user!

    const order = await Order.query()
      .where('id', params.id)
      .where('user_id', user.id)
      .first()

    if (!order) {
      return response.notFound({ message: 'Commande introuvable' })
    }

    if (order.status === 'paid' || order.status === 'shipped') {
      return response.badRequest({ message: 'Impossible de supprimer une commande payée ou expédiée' })
    }

    await order.delete()
    return response.ok({ message: 'Commande supprimée' })
  }

  /**
   * PATCH /api/orders/:id/cancel
   */
  public async cancel({ params, auth, response }: HttpContextContract) {
    const user = auth.use('api').user!

    const order = await Order.query()
      .where('id', params.id)
      .where('user_id', user.id)
      .first()

    if (!order) {
      return response.notFound({ message: 'Commande introuvable' })
    }

    if (order.status !== 'pending') {
      return response.badRequest({
        message: 'Seules les commandes en attente peuvent être annulées',
      })
    }

    order.status = 'cancelled'
    await order.save()

    return response.ok({ message: 'Commande annulée', order })
  }
}
