abstract class CategoryRepository {
  Stream<List<Map<String, dynamic>>> categoriesStream({required String userId});
  Future<String> addCategory({required String userId, required String name, int? color, int? order});
  Future<void> updateCategory({required String userId, required String categoryId, String? name, int? color, int? order});
  /// Update multiple categories' order atomically. The map is categoryId -> order
  Future<void> updateCategoriesOrder({required String userId, required Map<String, int> orders});
  Future<void> deleteCategory({required String userId, required String categoryId});
}
