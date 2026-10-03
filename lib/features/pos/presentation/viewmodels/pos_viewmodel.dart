import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/sale.dart';
import '../../domain/entities/sale_item.dart';
import '../../domain/usecases/create_sale.dart';
import '../../domain/usecases/void_sale_usecase.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../inventory/domain/entities/product.dart';
import '../../../inventory/domain/usecases/get_all_products.dart';

class PosViewModel extends ChangeNotifier {
  final CreateSale createSale;
  final GetAllProducts getAllProducts;
  final VoidSaleUseCase voidSaleUseCase;

  PosViewModel({
    required this.createSale,
    required this.getAllProducts,
    required this.voidSaleUseCase,
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
  double _globalDiscount = 0.0;
  double _lastNetProfit = 0.0;
  double _lastRecoveredCapital = 0.0;

  String get paymentMethod => _paymentMethod;
  String get deliveryMethod => _deliveryMethod;
  double get deliveryFee => _deliveryFee;
  double get globalDiscount => _globalDiscount;
  double get lastNetProfit => _lastNetProfit;
  double get lastRecoveredCapital => _lastRecoveredCapital;
  String? get customerName => _customerName;
  String? get customerPhone => _customerPhone;

  void setPaymentMethod(String val) { _paymentMethod = val; notifyListeners(); }
  void setDeliveryMethod(String val) { _deliveryMethod = val; notifyListeners(); }
  void setDeliveryFee(double val) { _deliveryFee = val; notifyListeners(); }
  void setCustomerName(String val) { _customerName = val; notifyListeners(); }
  void setCustomerPhone(String val) { _customerPhone = val; notifyListeners(); }
  void setGlobalDiscount(double val) {
    _globalDiscount = val;
    notifyListeners();
  }

  final List<SaleItem> _cart = [];
  bool _isLoading = false;
  String? _error;

  List<SaleItem> get cart      => List.unmodifiable(_cart);
  bool           get isLoading => _isLoading;
  String?        get error     => _error;

  double get cartTotal {
    double total = _cart.fold(0.0, (sum, item) => sum + (item.quantity * item.unitPrice) - item.lineDiscount);
    return (total - _globalDiscount) > 0 ? (total - _globalDiscount) : 0.0;
  }
  
  double get totalCostBase {
    return _cart.fold(0.0, (sum, item) {
      final product = _filteredProducts.firstWhere(
        (p) => p.id == item.productId,
        orElse: () => _allProducts.firstWhere(
          (p) => p.id == item.productId,
          orElse: () => Product(
            id: item.productId, 
            sku: '', 
            name: item.productName, 
            brand: '',
            category: '',
            standardSellingPrice: 0.0,
            minStockThreshold: 0,
          ),
        ),
      );
      return sum + (product.latestCost ?? 0.0) * item.quantity;
    });
  }

  bool get violatesAntiLoss {
    return cartTotal < totalCostBase;
  }

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
    _error = null;
    notifyListeners();

    if (violatesAntiLoss) {
      _error = 'Violación anti-pérdida: El precio total (Bs. $cartTotal) es menor al costo (Bs. $totalCostBase).';
      _isLoading = false;
      notifyListeners();
      return false;
    }

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
      (_) {
        _lastRecoveredCapital = totalCostBase;
        _lastNetProfit = cartTotal - totalCostBase;
        clearCart();
        _globalDiscount = 0.0;
        _error = null;
        loadProducts(); // Refresh products to reflect new stock
      },
    );
    notifyListeners();
    return result.isRight();
  }

  Future<bool> voidSale(String saleId) async {
    _isLoading = true;
    notifyListeners();
    
    final result = await voidSaleUseCase(saleId);
    _isLoading = false;
    
    result.fold(
      (f) => _error = f.message,
      (_) => _error = null,
    );
    notifyListeners();
    return result.isRight();
  }
}
