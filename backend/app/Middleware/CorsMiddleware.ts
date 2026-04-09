import { HttpContextContract } from '@ioc:Adonis/Core/HttpContext'

export default class CorsMiddleware {
  public async handle({ request, response }: HttpContextContract, next: () => Promise<void>) {
    response.header('Access-Control-Allow-Origin', '*')
    response.header('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE, OPTIONS')
    response.header('Access-Control-Allow-Headers', 'Content-Type, Authorization, Accept, X-Requested-With')
    response.header('Access-Control-Expose-Headers', 'Content-Disposition')
    response.header('Cross-Origin-Resource-Policy', 'cross-origin')

    if (request.method() === 'OPTIONS') {
      return response.status(204).send('')
    }

    await next()
  }
}
