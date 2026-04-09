import 'reflect-metadata'
import sourceMapSupport from 'source-map-support'
import { Ignitor } from '@adonisjs/core/build/standalone'

sourceMapSupport.install({ handleUncaughtExceptions: false })

// Force le port et l'host depuis les variables d'environnement
process.env.PORT = process.env.PORT || '3333'
process.env.HOST = process.env.HOST || '127.0.0.1'

new Ignitor(__dirname)
  .httpServer()
  .start()
