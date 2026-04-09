import { HttpContextContract } from '@ioc:Adonis/Core/HttpContext'
import { schema, rules } from '@ioc:Adonis/Core/Validator'
import Application from '@ioc:Adonis/Core/Application'
import Product from 'App/Models/Product'

export default class ProductsController {
  /**
   * GET /api/products
   */
  public async index({ request, response }: HttpContextContract) {
    const page = request.input('page', 1)
    const limit = request.input('limit', 12)
    const category = request.input('category')

    const query = Product.query().orderBy('created_at', 'desc')
    if (category) query.where('category', category)

    const products = await query.paginate(page, limit)
    return response.ok(products)
  }

  /**
   * GET /api/products/:id
   */
  public async show({ params, response }: HttpContextContract) {
    const product = await Product.find(params.id)
    if (!product) return response.notFound({ message: 'Produit introuvable' })
    return response.ok(product)
  }

  /**
   * POST /api/products  (multipart/form-data)
   */
  public async store({ request, response }: HttpContextContract) {
    const name = request.input('name')
    const description = request.input('description', '')
    const price = request.input('price')
    const category = request.input('category', null)

    if (!name || !price) {
      return response.badRequest({ message: 'Le nom et le prix sont obligatoires' })
    }

    // Gestion de l'image uploadée
    let imagePath: string | null = null
    const image = request.file('image', {
      size: '5mb',
      extnames: ['jpg', 'jpeg', 'png', 'webp'],
    })

    if (image) {
      if (!image.isValid) {
        return response.badRequest({ message: `Image invalide : ${image.errors[0]?.message}` })
      }
      await image.move(Application.publicPath('uploads'), {
        name: `${Date.now()}_${image.clientName}`,
        overwrite: true,
      })
      imagePath = `/uploads/${image.fileName}`
    }

    const product = await Product.create({
      name,
      description,
      price: parseFloat(price),
      stock: 99, // stock par défaut
      image: imagePath,
      category,
    })

    return response.created({ message: 'Produit créé avec succès', product })
  }

  /**
   * PUT /api/products/:id  (multipart/form-data)
   */
  public async update({ params, request, response }: HttpContextContract) {
    const product = await Product.find(params.id)
    if (!product) return response.notFound({ message: 'Produit introuvable' })

    const name = request.input('name')
    const description = request.input('description')
    const price = request.input('price')
    const category = request.input('category')

    // Nouvelle image si fournie
    const image = request.file('image', {
      size: '5mb',
      extnames: ['jpg', 'jpeg', 'png', 'webp'],
    })

    if (image) {
      if (!image.isValid) {
        return response.badRequest({ message: `Image invalide : ${image.errors[0]?.message}` })
      }
      await image.move(Application.publicPath('uploads'), {
        name: `${Date.now()}_${image.clientName}`,
        overwrite: true,
      })
      product.image = `/uploads/${image.fileName}`
    }

    if (name) product.name = name
    if (description !== undefined) product.description = description
    if (price) product.price = parseFloat(price)
    if (category !== undefined) product.category = category

    await product.save()
    return response.ok({ message: 'Produit mis à jour', product })
  }

  /**
   * DELETE /api/products/:id
   */
  public async destroy({ params, response }: HttpContextContract) {
    const product = await Product.find(params.id)
    if (!product) return response.notFound({ message: 'Produit introuvable' })
    await product.delete()
    return response.ok({ message: 'Produit supprimé' })
  }
}
