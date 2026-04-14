import { HttpContextContract } from '@ioc:Adonis/Core/HttpContext'
import { schema, rules } from '@ioc:Adonis/Core/Validator'
import User from 'App/Models/User'

export default class AuthController {
  /**
   * POST /api/auth/register
   */
  public async register({ request, response }: HttpContextContract) {
    const payload = await request.validate({
      schema: schema.create({
        name: schema.string({ trim: true }, [rules.maxLength(100)]),
        email: schema.string({ trim: true }, [
          rules.email(),
          rules.unique({ table: 'users', column: 'email' }),
        ]),
        password: schema.string({}, [rules.minLength(8)]),
      }),
      messages: {
        'email.unique': 'Cet email est déjà utilisé',
        'password.minLength': 'Le mot de passe doit contenir au moins 8 caractères',
      },
    })

    const user = await User.create({
      name: payload.name,
      email: payload.email,
      password: payload.password,
    })

    return response.created({
      message: 'Compte créé avec succès',
      user: { id: user.id, name: user.name, email: user.email },
    })
  }

  /**
   * POST /api/auth/login
   */
  public async login({ request, response, auth }: HttpContextContract) {
    const { email, password } = await request.validate({
      schema: schema.create({
        email: schema.string({ trim: true }, [rules.email()]),
        password: schema.string(),
      }),
    })

    try {
      const token = await auth.use('api').attempt(email, password, {
        expiresIn: '30days',
      })

      const user = auth.use('api').user!

      return response.ok({
        message: 'Connexion réussie',
        token: token.token,
        user: { id: user.id, name: user.name, email: user.email },
      })
    } catch {
      return response.unauthorized({ message: 'Email ou mot de passe incorrect' })
    }
  }

  /**
   * POST /api/auth/logout
   */
  public async logout({ auth, response }: HttpContextContract) {
    await auth.use('api').revoke()
    return response.ok({ message: 'Déconnexion réussie' })
  }

  /**
   * GET /api/auth/me
   */
  public async me({ auth, response }: HttpContextContract) {
    const user = auth.use('api').user!
    return response.ok({
      id: user.id,
      name: user.name,
      email: user.email,
    })
  }
}
