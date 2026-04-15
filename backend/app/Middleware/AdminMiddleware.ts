import { HttpContextContract } from '@ioc:Adonis/Core/HttpContext'

export default class AdminMiddleware {
  public async handle({ auth, response }: HttpContextContract, next: () => Promise<void>) {
    const user = auth.use('api').user as any

    if (!user || user.role !== 'admin') {
      return response.forbidden({ message: 'Accès réservé aux administrateurs' })
    }

    await next()
  }
}
