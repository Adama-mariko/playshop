import BaseSchema from '@ioc:Adonis/Lucid/Schema'

export default class AddJekoPaymentIdToOrders extends BaseSchema {
  protected tableName = 'orders'

  public async up() {
    this.schema.alterTable(this.tableName, (table) => {
      table.string('jeko_payment_id').nullable()
    })
  }

  public async down() {
    this.schema.alterTable(this.tableName, (table) => {
      table.dropColumn('jeko_payment_id')
    })
  }
}
