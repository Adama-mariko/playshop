import BaseSchema from '@ioc:Adonis/Lucid/Schema'

export default class RemoveRoleFromUsers extends BaseSchema {
  protected tableName = 'users'

  public async up() {
    this.schema.alterTable(this.tableName, (table) => {
      table.dropColumn('role')
    })
  }

  public async down() {
    this.schema.alterTable(this.tableName, (table) => {
      table.enum('role', ['client', 'admin']).defaultTo('client')
    })
  }
}
