import type { ApplicationContract } from '@ioc:Adonis/Core/Application'

export default class AppProvider {
  constructor (protected app: ApplicationContract) {}

  public register () {}

  public async boot () {}

  public async ready () {
    // Lancer les migrations automatiquement en production
    if (this.app.environment === 'web') {
      const { Migrator } = await import('@adonisjs/lucid/build/src/Migrator')
      const { default: Database } = await import('@ioc:Adonis/Lucid/Database')
      const migrator = new Migrator(Database, this.app, {
        direction: 'up',
        dryRun: false,
      })
      await migrator.run()
    }
  }

  public async shutdown () {}
}
