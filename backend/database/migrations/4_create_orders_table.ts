import BaseSchema from '@ioc:Adonis/Lucid/Schema'

export default class OrdersSchema extends BaseSchema {
  protected tableName = 'orders'

  public async up() {
    this.schema.createTable(this.tableName, (table) => {
      table.increments('id').primary()
      table.integer('user_id').unsigned().references('id').inTable('users').onDelete('CASCADE')
      table.enum('status', ['pending', 'paid', 'shipped', 'cancelled']).defaultTo('pending')
      table.decimal('total_amount', 10, 2).notNullable()
      table.enum('payment_method', ['orange_money', 'wave']).nullable()
      table.enum('payment_status', ['pending', 'success', 'failed']).defaultTo('pending')
      table.string('payment_reference', 255).nullable()
      table.datetime('created_at').notNullable()
      table.datetime('updated_at').notNullable()
    })
  }

  public async down() {
    this.schema.dropTable(this.tableName)
  }
}
