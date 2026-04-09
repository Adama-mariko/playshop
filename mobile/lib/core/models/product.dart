import '../api/api_client.dart';

class Product {
  final int id;
  final String name;
  final String description;
  final double price;
  final int stock;
  final String? image;
  final String? category;

  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.stock,
    this.image,
    this.category,
  });

  // Construit l'URL complète de l'image
  String? get imageUrl {
    if (image == null || image!.isEmpty) return null;
    if (image!.startsWith('http')) return image; // URL externe (Unsplash etc.)
    return '${ApiClient.baseUrl.replaceAll('/api', '')}$image'; // /uploads/...
  }

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'],
        name: json['name'],
        description: json['description'] ?? '',
        price: double.parse(json['price'].toString()),
        stock: json['stock'] ?? 0,
        image: json['image'],
        category: json['category'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'price': price,
        'stock': stock,
        'image': image,
        'category': category,
      };

  bool get inStock => stock > 0;
}
