import 'package:sqflite/sqflite.dart';

class Galleryimagescontroller {
  // Méthode pour insérer une image dans la base de données
  Future<int> insertImage(String imagePath, String name, dbClient) async {
    return await dbClient.insert(
      'gallery_images',
      {'image_path': imagePath, 'name': name},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> searchImagesByName(
      String name, dbClient) async {
    return await dbClient.query(
      'gallery_images',
      where: 'name LIKE ?',
      whereArgs: ['%$name%'],
    );
  }

// Méthode pour récupérer toutes les images de la galerie
  Future<List<Map<String, dynamic>>> getGalleryImages(dbClient) async {
    return await dbClient.query('gallery_images');
  }

// Méthode pour supprimer une image de la galerie
  Future<int> deleteImage(int id, dbClient) async {
    return await dbClient.delete(
      'gallery_images',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateImageName(int id, String name, dbClient) async {
    return await dbClient.update(
      'gallery_images',
      {'name': name}, // Mettre à jour le nom de l'image
      where: 'id = ?', // Condition : l'ID de l'image
      whereArgs: [id], // Passer l'ID de l'image
    );
  }
}
