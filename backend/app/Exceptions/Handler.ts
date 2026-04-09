import Logger from '@ioc:Adonis/Core/Logger'
import HttpExceptionHandler from '@ioc:Adonis/Core/HttpExceptionHandler'
import { HttpContextContract } from '@ioc:Adonis/Core/HttpContext'

export default class ExceptionHandler extends HttpExceptionHandler {
  constructor() {
    super(Logger)
  }

  public async handle(error: any, ctx: HttpContextContract) {
    // Erreurs de validation
    if (error.code === 'E_VALIDATION_FAILURE') {
      return ctx.response.status(422).json({
        message: 'Données invalides',
        errors: error.messages,
      })
    }

    // Erreur d'authentification
    if (error.code === 'E_UNAUTHORIZED_ACCESS') {
      return ctx.response.status(401).json({
        message: 'Authentification requise',
      })
    }

    // Ressource introuvable
    if (error.code === 'E_ROW_NOT_FOUND') {
      return ctx.response.status(404).json({
        message: 'Ressource introuvable',
      })
    }

    return super.handle(error, ctx)
  }
}
