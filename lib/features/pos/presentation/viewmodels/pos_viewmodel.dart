import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/sale.dart';
import '../../domain/entities/sale_item.dart';
import '../../domain/usecases/create_sale.dart';

class PosViewModel extends ChangeNotifier {
  final CreateSale createSale;

  PosViewModel({
    required this.createSale,
  });

  final List<SaleItem> _cart = [];
  bool _isLoading = false;
  String? _error;

  List<SaleItem> get cart      => List.unmodifiable(_cart);
  bool           get isLoading => _isLoading;
  String?        get error     => _error;
  double         get cartTotal =>
      _cart.fold(0, (s, i) => s + i.lineTotal);

  void addItem(SaleItem item) {
    final idx = _cart.indexWhere((i) => i.productId == item.productId);
    if (idx >= 0) {
      final existing = _cart[idx];
      _cart[idx] = SaleItem(
        productId:    existing.productId,
        productName:  existing.productName,
        quantity:     existing.quantity + item.quantity,
        unitPrice:    existing.unitPrice,
        lineDiscount: existing.lineDiscount,
      );
    } else {
      _cart.add(item);
    }
    notifyListeners();
  }

  void removeItem(String productId) {
    _cart.removeWhere((i) => i.productId == productId);
    notifyListeners();
  }

  void clearCart() {
    _cart.clear();
    notifyListeners();
  }

  Future<bool> checkout({String? promoterId}) async {
    _isLoading = true;
    notifyListeners();

    final sale = Sale(
      id:         const Uuid().v4(),
      items:      List.from(_cart),
      createdAt:  DateTime.now(),
      promoterId: promoterId,
    );

    final result = await createSale(CreateSaleParams(sale));
    _isLoading = false;

    result.fold(
      (f) => _error = f.message,
      (_) { clearCart(); _error = null; },
    );
    notifyListeners();
    return result.isRight();
  }
}
