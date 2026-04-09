import Server from '@ioc:Adonis/Core/Server'

Server.middleware.register([
  () => import('App/Middleware/CorsMiddleware'),
  () => import('@ioc:Adonis/Core/BodyParser'),
])

Server.middleware.registerNamed({
  auth: () => import('App/Middleware/AuthMiddleware'),
})
