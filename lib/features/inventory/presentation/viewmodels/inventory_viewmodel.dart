import 'package:flutter/foundation.dart';
import '../../domain/entities/inventory_batch.dart';
import '../../domain/entities/product.dart';
import '../../domain/usecases/get_all_products.dart';
import '../../domain/usecases/add_inventory_batch.dart';
import '../../domain/usecases/consume_stock_fifo.dart';
import '../../../../core/usecases/usecase.dart';

enum ViewState { idle, loading, error }

class InventoryViewModel extends ChangeNotifier {
  final GetAllProducts    _getAllProducts;
  final AddInventoryBatch _addBatch;
  final ConsumeStockFifo  _consumeStock;

  InventoryViewModel({
    required GetAllProducts getAllProducts,
    required AddInventoryBatch addBatch,
    required ConsumeStockFifo consumeStock,
  })  : _getAllProducts = getAllProducts,
        _addBatch      = addBatch,
        _consumeStock  = consumeStock;

  ViewState           _state    = ViewState.idle;
  List<Product>       _products = [];
  String?             _errorMessage;

  ViewState     get state        => _state;
  List<Product> get products     => List.unmodifiable(_products);
  String?       get errorMessage => _errorMessage;

  Future<void> loadProducts() async {
    _state = ViewState.loading;
    notifyListeners();

    final result = await _getAllProducts(const NoParams());
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
    final result = await _addBatch(AddBatchParams(batch));
    return result.isRight();
  }

  Future<bool> consumeStock(String productId, int quantity) async {
    final result = await _consumeStock(
        ConsumeStockParams(productId: productId, quantity: quantity));
    return result.isRight();
  }
}
