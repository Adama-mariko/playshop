import type { ApplicationContract } from '@ioc:Adonis/Core/Application'

export default class AppProvider {
  constructor (protected app: ApplicationContract) {}

  public register () {}

  public async boot () {}

  public async ready () {
    // Lancer les migrations automatiquement en production
    if (this.app.environment === 'web') {
      const { default: Database } = await import('@ioc:Adonis/Lucid/Database')
      await Database.connection().migrate.latest({
        directory: this.app.migrationsPath(),
      })
    }
  }

  public async shutdown () {}
}
