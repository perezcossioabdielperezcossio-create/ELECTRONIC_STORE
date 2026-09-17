import 'package:flutter/foundation.dart';
import '../../domain/entities/inventory_batch.dart';
import '../../domain/entities/product.dart';
import '../../domain/usecases/get_all_products.dart';
import '../../domain/usecases/add_inventory_batch.dart';
import '../../domain/usecases/consume_stock_fifo.dart';
import '../../../../core/usecases/usecase.dart';

enum ViewState { idle, loading, error }

class InventoryViewModel extends ChangeNotifier {
  final GetAllProducts    getAllProductsUseCase;
  final AddInventoryBatch addBatchUseCase;
  final ConsumeStockFifo  consumeStockUseCase;

  InventoryViewModel({
    required this.getAllProductsUseCase,
    required this.addBatchUseCase,
    required this.consumeStockUseCase,
  });

  ViewState           _state    = ViewState.idle;
  List<Product>       _products = [];
  String?             _errorMessage;
  
  String _searchQuery = '';
  bool _showOnlyReplenishment = false;

  ViewState     get state        => _state;
  List<Product> get products     => List.unmodifiable(_products);
  String?       get errorMessage => _errorMessage;
  
  String get searchQuery => _searchQuery;
  bool get showOnlyReplenishment => _showOnlyReplenishment;

  List<Product> get filteredProducts {
    return _products.where((product) {
      final matchesSearch = _searchQuery.isEmpty || 
          product.name.toLowerCase().contains(_searchQuery.toLowerCase()) || 
          product.sku.toLowerCase().contains(_searchQuery.toLowerCase());
          
      final requiresReplenishment = product.status == StockStatus.lowStock || product.status == StockStatus.outOfStock;
      final matchesFilter = !_showOnlyReplenishment || requiresReplenishment;
      
      return matchesSearch && matchesFilter;
    }).toList();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void toggleReplenishmentFilter() {
    _showOnlyReplenishment = !_showOnlyReplenishment;
    notifyListeners();
  }

  Future<void> loadProducts() async {
    _state = ViewState.loading;
    notifyListeners();

    final result = await getAllProductsUseCase(const NoParams());
    result.fold(
      (failure) {
        _state        = ViewState.error;
        _errorMessage = failure.message;
      },
      (products) {
        _state    = ViewState.idle;
        _products = products;
      },
    );
    notifyListeners();
  }

  Future<bool> addBatch(InventoryBatch batch) async {
    final result = await addBatchUseCase(AddBatchParams(batch));
    return result.isRight();
  }

  Future<bool> consumeStock(String productId, int quantity) async {
    final result = await consumeStockUseCase(
        ConsumeStockParams(productId: productId, quantity: quantity));
    return result.isRight();
  }
}
