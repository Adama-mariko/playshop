import BaseSeeder from '@ioc:Adonis/Lucid/Seeder'
import Product from 'App/Models/Product'

export default class ProductSeeder extends BaseSeeder {
  public async run() {
    await Product.createMany([
      {
        name: 'iPhone 15 Pro',
        description: 'Smartphone Apple avec puce A17 Pro, appareil photo 48MP et écran Super Retina XDR.',
        price: 850000,
        stock: 10,
        image: 'https://images.unsplash.com/photo-1695048133142-1a20484d2569?w=400',
        category: 'Téléphones',
      },
      {
        name: 'Samsung Galaxy S24',
        description: 'Smartphone Samsung avec Galaxy AI, écran Dynamic AMOLED 2X et batterie longue durée.',
        price: 720000,
        stock: 15,
        image: 'https://images.unsplash.com/photo-1610945415295-d9bbf067e59c?w=400',
        category: 'Téléphones',
      },
      {
        name: 'MacBook Air M3',
        description: 'Ordinateur portable ultra-fin avec puce Apple M3, 8GB RAM et 256GB SSD.',
        price: 1200000,
        stock: 5,
        image: 'https://images.unsplash.com/photo-1517336714731-489689fd1ca8?w=400',
        category: 'Ordinateurs',
      },
      {
        name: 'AirPods Pro 2',
        description: 'Écouteurs sans fil avec réduction de bruit active et son spatial personnalisé.',
        price: 180000,
        stock: 20,
        image: 'https://images.unsplash.com/photo-1600294037681-c80b4cb5b434?w=400',
        category: 'Audio',
      },
      {
        name: 'iPad Air 5',
        description: 'Tablette Apple avec puce M1, écran Liquid Retina 10.9 pouces et Touch ID.',
        price: 650000,
        stock: 8,
        image: 'https://images.unsplash.com/photo-1544244015-0df4b3ffc6b0?w=400',
        category: 'Tablettes',
      },
      {
        name: 'Sony WH-1000XM5',
        description: 'Casque audio premium avec la meilleure réduction de bruit du marché.',
        price: 220000,
        stock: 12,
        image: 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=400',
        category: 'Audio',
      },
    ])
  }
}
