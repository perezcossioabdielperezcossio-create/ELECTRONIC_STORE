import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/entities/lot.dart';
import '../../domain/entities/product.dart';
import '../../domain/usecases/get_all_products.dart';
import '../../domain/usecases/add_inventory_batch.dart';
import '../../domain/usecases/consume_stock_fifo.dart';
import '../../domain/usecases/create_product_with_lot_usecase.dart';
import '../../domain/usecases/update_product_usecase.dart';
import '../../domain/usecases/delete_product_usecase.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/sync/domain/services/sync_manager.dart';

enum ViewState { idle, loading, error }
enum InventoryFilter { all, lowStock, outOfStock }

class InventoryViewModel extends ChangeNotifier {
  final GetAllProducts getAllProductsUseCase;
  final AddLotUseCase addLotUseCase;
  final ConsumeStockFifo consumeStockUseCase;
  final CreateProductWithLotUseCase createProductWithLotUseCase;
  final UpdateProductUseCase updateProductUseCase;
  final DeleteProductUseCase deleteProductUseCase;
  final SyncManager? syncManager;

  StreamSubscription? _syncSubscription;

  InventoryViewModel({
    required this.getAllProductsUseCase,
    required this.addLotUseCase,
    required this.consumeStockUseCase,
    required this.createProductWithLotUseCase,
    required this.updateProductUseCase,
    required this.deleteProductUseCase,
    this.syncManager,
  }) {
    _initSyncListener();
  }

  void _initSyncListener() {
    _syncSubscription = syncManager?.onRemoteDataChanged.listen((_) {
      loadProducts();
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }

  ViewState _state = ViewState.idle;
  List<Product> _products = [];
  String? _errorMessage;
  
  String _searchQuery = '';
  InventoryFilter _filter = InventoryFilter.all;

  ViewState get state => _state;
  List<Product> get products => List.unmodifiable(_products);
  String? get errorMessage => _errorMessage;
  
  String get searchQuery => _searchQuery;
  InventoryFilter get filter => _filter;

  double get totalCapitalInmovilizado {
    return _products.fold(0.0, (sum, product) => sum + product.totalInvestedCapital);
  }

  double get gananciaPotencialEstimada {
    double totalGanancia = 0.0;
    for (var product in _products) {
      for (var lot in product.lots.where((l) => l.isActive)) {
        final gain = (product.standardSellingPrice - lot.realUnitCost) * lot.currentQuantity;
        totalGanancia += gain;
      }
    }
    return totalGanancia;
  }

  List<Product> get filteredProducts {
    return _products.where((product) {
      final matchesSearch = _searchQuery.isEmpty || 
          product.name.toLowerCase().contains(_searchQuery.toLowerCase()) || 
          product.sku.toLowerCase().contains(_searchQuery.toLowerCase());
          
      bool matchesFilter = true;
      if (_filter == InventoryFilter.lowStock) {
        matchesFilter = product.status == StockStatus.lowStock || product.status == StockStatus.outOfStock;
      } else if (_filter == InventoryFilter.outOfStock) {
        matchesFilter = product.status == StockStatus.outOfStock;
      }
      
      return matchesSearch && matchesFilter;
    }).toList();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setFilter(InventoryFilter newFilter) {
    _filter = newFilter;
    notifyListeners();
  }

  Future<void> loadProducts() async {
    _state = ViewState.loading;
    notifyListeners();

    final result = await getAllProductsUseCase(const NoParams());
    result.fold(
      (failure) {
        _state = ViewState.error;
        _errorMessage = failure.message;
      },
      (products) {
        _state = ViewState.idle;
        _products = products;
      },
    );
    notifyListeners();
  }

  Future<bool> addLot(String productId, Lot lot) async {
    final result = await addLotUseCase(AddLotParams(productId: productId, lot: lot));
    if (result.isRight()) {
      await loadProducts();
      syncManager?.syncPendingOperations();
      return true;
    }
    return false;
  }

  Future<bool> consumeStock(String productId, int quantity) async {
    final result = await consumeStockUseCase(
        ConsumeStockParams(productId: productId, quantity: quantity));
    return result.isRight();
  }

  Future<bool> createProductWithLot(Product product, Lot lot) async {
    try {
      await createProductWithLotUseCase(product: product, initialLot: lot);
      await loadProducts();
      syncManager?.syncPendingOperations();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProduct(Product product) async {
    final result = await updateProductUseCase(UpdateProductParams(product: product));
    return result.fold(
      (failure) {
        _errorMessage = failure.message;
        notifyListeners();
        return false;
      },
      (_) async {
        await loadProducts();
        syncManager?.syncPendingOperations();
        return true;
      },
    );
  }

  Future<bool> deleteProduct(String productId) async {
    final result = await deleteProductUseCase(DeleteProductParams(productId: productId));
    return result.fold(
      (failure) {
        _errorMessage = failure.message;
        notifyListeners();
        return false;
      },
      (_) async {
        await loadProducts();
        syncManager?.syncPendingOperations();
        return true;
      },
    );
  }
}
