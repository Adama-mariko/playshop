import BaseSchema from '@ioc:Adonis/Lucid/Schema'

export default class UpdatePaymentMethodEnum extends BaseSchema {
  protected tableName = 'orders'

  public async up() {
    this.schema.alterTable(this.tableName, (table) => {
      table
        .enum('payment_method', ['wave', 'orange', 'mtn', 'moov', 'djamo'])
        .nullable()
        .alter()
    })
  }

  public async down() {
    this.schema.alterTable(this.tableName, (table) => {
      table.enum('payment_method', ['orange_money', 'wave']).nullable().alter()
    })
  }
}
