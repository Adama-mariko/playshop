import Env from '@ioc:Adonis/Core/Env'

export default Env.rules({
  HOST: Env.schema.string({ format: 'host' }),
  PORT: Env.schema.number(),
  APP_KEY: Env.schema.string(),
  APP_NAME: Env.schema.string(),
  DRIVE_DISK: Env.schema.enum(['local'] as const),
  NODE_ENV: Env.schema.enum(['development', 'production', 'test'] as const),

  DB_CONNECTION: Env.schema.string(),
  MYSQL_HOST: Env.schema.string({ format: 'host' }),
  MYSQL_PORT: Env.schema.number(),
  MYSQL_USER: Env.schema.string(),
  MYSQL_PASSWORD: Env.schema.string.optional(),
  MYSQL_DB_NAME: Env.schema.string(),

  JEKO_API_KEY: Env.schema.string(),
  JEKO_API_KEY_ID: Env.schema.string(),
  JEKO_API_URL: Env.schema.string(),
  JEKO_STORE_ID: Env.schema.string.optional(),
  JEKO_WEBHOOK_SECRET: Env.schema.string.optional(),
  APP_URL: Env.schema.string(),
  FRONTEND_URL: Env.schema.string(),
})
