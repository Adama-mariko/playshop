import BaseSchema from '@ioc:Adonis/Lucid/Schema'

export default class AddPhoneToOrders extends BaseSchema {
  protected tableName = 'orders'

  public async up() {
    this.schema.alterTable(this.tableName, (table) => {
      table.string('phone_number', 20).nullable().after('payment_method')
    })
  }

  public async down() {
    this.schema.alterTable(this.tableName, (table) => {
      table.dropColumn('phone_number')
    })
  }
}
