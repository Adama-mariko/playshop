import { HttpContextContract } from '@ioc:Adonis/Core/HttpContext'

export default class AuthMiddleware {
  public async handle({ auth, response }: HttpContextContract, next: () => Promise<void>) {
    try {
      await auth.use('api').authenticate()
      await next()
    } catch (e: any) {
      const code = e?.code ?? ''
      // E_INVALID_API_TOKEN = token présent mais invalide/expiré
      // E_UNAUTHORIZED_ACCESS = pas de token du tout
      if (code === 'E_INVALID_API_TOKEN') {
        return response.unauthorized({ message: 'Token expiré. Veuillez vous reconnecter.' })
      }
      return response.unauthorized({ message: 'Authentification requise. Veuillez vous connecter.' })
    }
  }
}
