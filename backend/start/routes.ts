import Route from '@ioc:Adonis/Core/Route'
import Application from '@ioc:Adonis/Core/Application'
import { HttpContextContract } from '@ioc:Adonis/Core/HttpContext'

// Santé de l'API
Route.get('/', async () => {
  return { status: 'ok', app: 'PlayShop API', version: '1.0.0' }
})

// Servir les images uploadées avec headers CORS
Route.get('/uploads/*', async ({ request, response }: HttpContextContract) => {
  const fs = await import('fs')
  const path = await import('path')
  const filename = request.url().replace('/uploads/', '')
  const decodedFilename = decodeURIComponent(filename)
  const filePath = Application.publicPath(`uploads/${decodedFilename}`)

  if (!fs.existsSync(filePath)) {
    return response.notFound({ message: 'Image introuvable' })
  }

  const ext = path.extname(decodedFilename).toLowerCase()
  const mimeTypes: Record<string, string> = {
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.png': 'image/png',
    '.webp': 'image/webp',
    '.gif': 'image/gif',
  }
  const contentType = mimeTypes[ext] ?? 'application/octet-stream'

  response.header('Content-Type', contentType)
  response.header('Cross-Origin-Resource-Policy', 'cross-origin')
  response.header('Access-Control-Allow-Origin', '*')
  response.header('Cache-Control', 'public, max-age=31536000')

  return response.stream(fs.createReadStream(filePath))
})

/*
|--------------------------------------------------------------------------
| Authentification
|--------------------------------------------------------------------------
*/
Route.group(() => {
  Route.post('/register', 'AuthController.register')
  Route.post('/login', 'AuthController.login')
  Route.post('/logout', 'AuthController.logout').middleware('auth')
  Route.get('/me', 'AuthController.me').middleware('auth')
}).prefix('/api/auth').namespace('App/Controllers/Http')

/*
|--------------------------------------------------------------------------
| Produits — tous les utilisateurs connectés peuvent gérer les produits
|--------------------------------------------------------------------------
*/
Route.group(() => {
  Route.get('/', 'ProductsController.index')
  Route.get('/:id', 'ProductsController.show')
  Route.post('/', 'ProductsController.store').middleware('auth')
  Route.put('/:id', 'ProductsController.update').middleware('auth')
  Route.delete('/:id', 'ProductsController.destroy').middleware('auth')
}).prefix('/api/products').namespace('App/Controllers/Http')

/*
|--------------------------------------------------------------------------
| Commandes
|--------------------------------------------------------------------------
*/
Route.group(() => {
  Route.get('/', 'OrdersController.index').middleware('auth')
  Route.get('/:id', 'OrdersController.show').middleware('auth')
  Route.post('/', 'OrdersController.store').middleware('auth')
  Route.delete('/:id', 'OrdersController.destroy').middleware('auth')
  Route.patch('/:id/cancel', 'OrdersController.cancel').middleware('auth')
}).prefix('/api/orders').namespace('App/Controllers/Http')

/*
|--------------------------------------------------------------------------
| Paiements
|--------------------------------------------------------------------------
*/
Route.group(() => {
  Route.post('/initiate', 'PaymentsController.initiate').middleware('auth')
  Route.post('/callback', 'PaymentsController.callback')
  Route.post('/webhook', 'PaymentsController.webhook')
  Route.get('/jeko-success', 'PaymentsController.jekoSuccess')
  Route.get('/jeko-error', 'PaymentsController.jekoError')
  Route.patch('/confirm-manual/:orderId', 'PaymentsController.confirmManual').middleware('auth')
  Route.get('/status/:orderId', 'PaymentsController.status') // auth optionnelle gérée dans le controller
}).prefix('/api/payments').namespace('App/Controllers/Http')