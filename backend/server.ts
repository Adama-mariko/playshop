import 'reflect-metadata'
import sourceMapSupport from 'source-map-support'
import { Ignitor } from '@adonisjs/core/build/standalone'

sourceMapSupport.install({ handleUncaughtExceptions: false })

process.env.PORT = process.env.PORT || '3333'
process.env.HOST = '0.0.0.0'

new Ignitor(__dirname)
  .httpServer()
  .start()
