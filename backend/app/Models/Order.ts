import { DateTime } from 'luxon'
import { column, BaseModel, belongsTo, BelongsTo, hasMany, HasMany } from '@ioc:Adonis/Lucid/Orm'
import User from 'App/Models/User'
import OrderItem from 'App/Models/OrderItem'

export default class Order extends BaseModel {
  @column({ isPrimary: true })
  public id: number

  @column()
  public userId: number

  @column()
  public status: 'pending' | 'paid' | 'shipped' | 'cancelled'

  @column()
  public totalAmount: number

  @column()
  public paymentMethod: 'orange_money' | 'wave' | null

  @column()
  public phoneNumber: string | null

  @column()
  public paymentStatus: 'pending' | 'success' | 'failed'

  @column()
  public paymentReference: string | null

  @column.dateTime({ autoCreate: true })
  public createdAt: DateTime

  @column.dateTime({ autoCreate: true, autoUpdate: true })
  public updatedAt: DateTime

  @belongsTo(() => User)
  public user: BelongsTo<typeof User>

  @hasMany(() => OrderItem)
  public items: HasMany<typeof OrderItem>
}
