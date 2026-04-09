import { HttpContextContract } from '@ioc:Adonis/Core/HttpContext'
import { schema, rules } from '@ioc:Adonis/Core/Validator'
import Order from 'App/Models/Order'
import Product from 'App/Models/Product'
import Database from '@ioc:Adonis/Lucid/Database'

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
    const user = auth.use('api').user!

    const payload = await request.validate({
      schema: schema.create({
        items: schema.array([rules.minLength(1)]).members(
          schema.object().members({
            productId: schema.number(),
            quantity: schema.number([rules.unsigned(), rules.range(1, 999)]),
          })
        ),
        paymentMethod: schema.enum(['orange_money', 'wave'] as const),
      }),
    })

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
