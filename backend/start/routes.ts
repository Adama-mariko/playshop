import Route from '@ioc:Adonis/Core/Route'
import Application from '@ioc:Adonis/Core/Application'
import { HttpContextContract } from '@ioc:Adonis/Core/HttpContext'

// Santé de l'API
Route.get('/', async () => {
  return { status: 'ok', app: 'PlayShop API', version: '1.0.0' }
})

// Servir les images uploadées avec headers CORS
Route.get('/uploads/:filename', async ({ params, response }: HttpContextContract) => {
  const filePath = Application.publicPath(`uploads/${params.filename}`)
  response.header('Cross-Origin-Resource-Policy', 'cross-origin')
  response.header('Access-Control-Allow-Origin', '*')
  return response.download(filePath)
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
  Route.get('/', 'OrdersController.index')
  Route.get('/:id', 'OrdersController.show')
  Route.post('/', 'OrdersController.store')
  Route.delete('/:id', 'OrdersController.destroy')
  Route.patch('/:id/cancel', 'OrdersController.cancel')
}).prefix('/api/orders').namespace('App/Controllers/Http').middleware('auth')

/*
|--------------------------------------------------------------------------
| Paiements
|--------------------------------------------------------------------------
*/
Route.group(() => {
  Route.post('/initiate', 'PaymentsController.initiate').middleware('auth')
  Route.post('/callback', 'PaymentsController.callback')
  Route.patch('/confirm-manual/:orderId', 'PaymentsController.confirmManual').middleware('auth')
  Route.get('/status/:orderId', 'PaymentsController.status').middleware('auth')
}).prefix('/api/payments').namespace('App/Controllers/Http')