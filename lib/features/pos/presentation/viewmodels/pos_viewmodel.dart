import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/sale.dart';
import '../../domain/entities/sale_item.dart';
import '../../domain/usecases/create_sale.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../inventory/domain/entities/product.dart';
import '../../../inventory/domain/usecases/get_all_products.dart';

class PosViewModel extends ChangeNotifier {
  final CreateSale createSale;
  final GetAllProducts getAllProducts;

  PosViewModel({
    required this.createSale,
    required this.getAllProducts,
  });

  // Catálogo y Búsqueda
  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  bool _isLoadingProducts = false;

  List<Product> get filteredProducts => List.unmodifiable(_filteredProducts);
  bool get isLoadingProducts => _isLoadingProducts;

  // Estado del Checkout
  String _paymentMethod = 'EFECTIVO';
  String _deliveryMethod = 'TIENDA';
  double _deliveryFee = 0.0;
  String? _customerName;
  String? _customerPhone;

  String get paymentMethod => _paymentMethod;
  String get deliveryMethod => _deliveryMethod;
  double get deliveryFee => _deliveryFee;
  String? get customerName => _customerName;
  String? get customerPhone => _customerPhone;

  void setPaymentMethod(String val) { _paymentMethod = val; notifyListeners(); }
  void setDeliveryMethod(String val) { _deliveryMethod = val; notifyListeners(); }
  void setDeliveryFee(double val) { _deliveryFee = val; notifyListeners(); }
  void setCustomerName(String val) { _customerName = val; notifyListeners(); }
  void setCustomerPhone(String val) { _customerPhone = val; notifyListeners(); }

  final List<SaleItem> _cart = [];
  bool _isLoading = false;
  String? _error;

  List<SaleItem> get cart      => List.unmodifiable(_cart);
  bool           get isLoading => _isLoading;
  String?        get error     => _error;
  double         get cartTotal =>
      _cart.fold(0, (s, i) => s + i.lineTotal);

  Future<void> loadProducts() async {
    _isLoadingProducts = true;
    notifyListeners();
    final result = await getAllProducts(const NoParams());
    result.fold(
      (f) => _error = f.message,
      (products) {
        _allProducts = products;
        _filteredProducts = products;
      },
    );
    _isLoadingProducts = false;
    notifyListeners();
  }

  void searchProducts(String query) {
    if (query.isEmpty) {
      _filteredProducts = List.from(_allProducts);
    } else {
      final q = query.toLowerCase();
      _filteredProducts = _allProducts.where((p) {
        return p.sku.toLowerCase().contains(q) || p.name.toLowerCase().contains(q);
      }).toList();
    }
    notifyListeners();
  }

  void addItem(SaleItem item, Product product) {
    // Validar anti-pérdida (RF-08)
    final finalPrice = item.unitPrice - item.lineDiscount;
    if (product.latestCost != null && finalPrice < product.latestCost!) {
      _error = 'El precio final no puede ser menor al costo de adquisición (\$${product.latestCost})';
      notifyListeners();
      return;
    }

    final idx = _cart.indexWhere((i) => i.productId == item.productId);
    int newQuantity = item.quantity;
    
    if (idx >= 0) {
      newQuantity += _cart[idx].quantity;
    }

    // Validar stock (RF-07)
    if (newQuantity > product.availableStock) {
      _error = 'Cantidad supera el stock disponible (${product.availableStock})';
      notifyListeners();
      return;
    }

    if (idx >= 0) {
      final existing = _cart[idx];
      _cart[idx] = SaleItem(
        productId:    existing.productId,
        productName:  existing.productName,
        quantity:     newQuantity,
        unitPrice:    item.unitPrice,
        lineDiscount: item.lineDiscount,
      );
    } else {
      _cart.add(item);
    }
    _error = null;
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
      id:             const Uuid().v4(),
      items:          List.from(_cart),
      createdAt:      DateTime.now(),
      promoterId:     promoterId,
      paymentMethod:  _paymentMethod,
      deliveryMethod: _deliveryMethod,
      deliveryFee:    _deliveryFee,
      customerName:   _customerName,
      customerPhone:  _customerPhone,
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
