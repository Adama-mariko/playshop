import 'reflect-metadata'
import sourceMapSupport from 'source-map-support'
import { Ignitor } from '@adonisjs/core/build/standalone'

sourceMapSupport.install({ handleUncaughtExceptions: false })

// Render injecte PORT automatiquement — on écoute sur 0.0.0.0 pour être accessible
process.env.PORT = process.env.PORT || '3333'
process.env.HOST = '0.0.0.0'

new Ignitor(__dirname)
  .httpServer()
  .start()
