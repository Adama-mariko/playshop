import Env from '@ioc:Adonis/Core/Env'

const appConfig = {
  /*
  |--------------------------------------------------------------------------
  | Application secret key — utilisée par le chiffrement et les sessions
  |--------------------------------------------------------------------------
  */
  appKey: Env.get('APP_KEY'),

  http: {
    trustProxy: () => true,
    etag: false,
    jsonpCallbackName: 'callback',
    cookie: {
      domain: '',
      path: '/',
      maxAge: '2h',
      httpOnly: true,
      secure: false,
      sameSite: false,
    },
  },
}

export default appConfig
