import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/sale.dart';
import '../../domain/entities/sale_item.dart';
import '../../domain/usecases/create_sale.dart';
import '../../domain/usecases/void_sale_usecase.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../inventory/domain/entities/product.dart';
import '../../../inventory/domain/usecases/get_all_products.dart';
import '../../../clients/domain/entities/client.dart';
import '../../../clients/domain/usecases/get_clients_usecase.dart';
import '../../../clients/domain/usecases/save_client_usecase.dart';
import '../../../deliveries/domain/entities/delivery.dart';
import '../../../deliveries/domain/usecases/get_deliveries_usecase.dart';
import '../../../deliveries/domain/usecases/save_delivery_usecase.dart';
import '../../../deliveries/domain/usecases/delete_delivery_usecase.dart';
import '../../../../core/sync/domain/services/sync_manager.dart';

class PosViewModel extends ChangeNotifier {
  final CreateSale createSale;
  final GetAllProducts getAllProducts;
  final VoidSaleUseCase voidSaleUseCase;
  final GetClientsUseCase? getClientsUseCase;
  final SaveClientUseCase? saveClientUseCase;
  final GetDeliveriesUseCase? getDeliveriesUseCase;
  final SaveDeliveryUseCase? saveDeliveryUseCase;
  final DeleteDeliveryUseCase? deleteDeliveryUseCase;
  final SyncManager? syncManager;

  StreamSubscription? _syncSubscription;

  // Default quick client
  static final Client defaultClient = Client(
    id: 'mostrador',
    nombreAlias: 'Cliente Mostrador / Ocasional',
    creadoEn: DateTime(2020, 1, 1),
  );

  PosViewModel({
    required this.createSale,
    required this.getAllProducts,
    required this.voidSaleUseCase,
    this.getClientsUseCase,
    this.saveClientUseCase,
    this.getDeliveriesUseCase,
    this.saveDeliveryUseCase,
    this.deleteDeliveryUseCase,
    this.syncManager,
  }) {
    _selectedClient = defaultClient;
    _customerName = defaultClient.nombreAlias;
    _initSyncListener();
  }

  void _initSyncListener() {
    _syncSubscription = syncManager?.onRemoteDataChanged.listen((_) {
      loadProducts();
      loadClients();
      loadDeliveries();
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }

  // Catálogo y Búsqueda
  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  bool _isLoadingProducts = false;
  String _currentSearchQuery = '';

  List<Product> get filteredProducts => List.unmodifiable(_filteredProducts);
  bool get isLoadingProducts => _isLoadingProducts;

  // Clientes CRM
  List<Client> _clients = [];
  Client? _selectedClient;
  bool _isLoadingClients = false;

  List<Client> get clients => List.unmodifiable(_clients);
  Client? get selectedClient => _selectedClient;
  bool get isLoadingClients => _isLoadingClients;

  // Repartidores / Deliveries
  List<Delivery> _deliveries = [];
  Delivery? _selectedDelivery;
  bool _isLoadingDeliveries = false;

  List<Delivery> get deliveries => List.unmodifiable(_deliveries);
  Delivery? get selectedDelivery => _selectedDelivery;
  bool get isLoadingDeliveries => _isLoadingDeliveries;

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
  void setCustomerName(String? val) { _customerName = val; notifyListeners(); }
  void setCustomerPhone(String? val) { _customerPhone = val; notifyListeners(); }
  void setGlobalDiscount(double val) {
    _globalDiscount = val;
    notifyListeners();
  }

  void selectClient(Client? client) {
    _selectedClient = client ?? defaultClient;
    if (_selectedClient != null) {
      _customerName = _selectedClient!.nombreAlias;
      _customerPhone = _selectedClient!.telefonoWhatsapp;
    }
    notifyListeners();
  }

  void selectDelivery(Delivery? delivery) {
    _selectedDelivery = delivery;
    notifyListeners();
  }

  final List<SaleItem> _cart = [];
  bool _isLoading = false;
  String? _error;
  String _stockLocation = 'ALMACEN'; // Default for admin, sellers switch to 'TIENDA'

  List<SaleItem> get cart          => List.unmodifiable(_cart);
  bool           get isLoading     => _isLoading;
  String?        get error         => _error;
  String         get stockLocation => _stockLocation;

  void setStockLocation(String location) {
    _stockLocation = location.toUpperCase().trim().contains('ALMACEN') ? 'ALMACEN' : 'TIENDA';
    notifyListeners();
  }

  int getAvailableStock(Product product) {
    if (_stockLocation == 'TIENDA') {
      return product.stockInTienda;
    } else if (_stockLocation == 'ALMACEN') {
      return product.stockInAlmacen;
    }
    return product.availableStock;
  }

  double get cartSubtotal => _cart.fold(0.0, (sum, item) => sum + item.lineTotal);

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
        searchProducts(_currentSearchQuery);
      },
    );
    _isLoadingProducts = false;
    notifyListeners();
  }

  Future<void> loadClients() async {
    if (getClientsUseCase == null) return;
    _isLoadingClients = true;
    notifyListeners();
    final result = await getClientsUseCase!(const NoParams());
    result.fold(
      (_) => _clients = [defaultClient],
      (loadedClients) {
        final list = <Client>[defaultClient];
        for (final c in loadedClients) {
          if (c.id != defaultClient.id && !list.any((item) => item.id == c.id)) {
            list.add(c);
          }
        }
        _clients = list;
        if (_selectedClient != null) {
          final found = _clients.firstWhere((c) => c.id == _selectedClient!.id, orElse: () => _selectedClient!);
          _selectedClient = found;
        }
      },
    );
    _isLoadingClients = false;
    notifyListeners();
  }

  Future<void> loadDeliveries() async {
    if (getDeliveriesUseCase == null) return;
    _isLoadingDeliveries = true;
    notifyListeners();
    final result = await getDeliveriesUseCase!(const GetDeliveriesParams());
    result.fold(
      (_) => _deliveries = [],
      (list) {
        _deliveries = list;
        if (_selectedDelivery != null) {
          final found = _deliveries.where((d) => d.id == _selectedDelivery!.id);
          _selectedDelivery = found.isNotEmpty ? found.first : null;
        }
      },
    );
    _isLoadingDeliveries = false;
    notifyListeners();
  }

  Future<Client?> createNewClient({
    required String nombreAlias,
    String? telefonoWhatsapp,
    String? direccionPredet,
  }) async {
    if (saveClientUseCase == null) return null;
    _isLoading = true;
    _error = null;
    notifyListeners();

    final newClient = Client(
      id: const Uuid().v4(),
      nombreAlias: nombreAlias.trim(),
      telefonoWhatsapp: telefonoWhatsapp?.trim().isEmpty == true ? null : telefonoWhatsapp?.trim(),
      direccionPredet: direccionPredet?.trim().isEmpty == true ? null : direccionPredet?.trim(),
      creadoEn: DateTime.now(),
    );

    final result = await saveClientUseCase!(newClient);
    _isLoading = false;

    Client? created;
    result.fold(
      (f) {
        _error = f.message;
      },
      (saved) {
        created = saved;
        if (!_clients.any((c) => c.id == saved.id)) {
          if (_clients.length >= 2) {
            _clients.insert(1, saved);
          } else {
            _clients.add(saved);
          }
        }
        selectClient(saved);
        syncManager?.syncPendingOperations();
      },
    );

    notifyListeners();
    return created;
  }

  Future<Delivery?> saveDelivery({
    String? id,
    required String nombre,
    required String telefono,
    String? vehiculo,
    bool activo = true,
  }) async {
    if (saveDeliveryUseCase == null) return null;
    _isLoading = true;
    _error = null;
    notifyListeners();

    final delivery = Delivery(
      id: id ?? const Uuid().v4(),
      nombre: nombre.trim(),
      telefono: telefono.trim(),
      vehiculo: vehiculo?.trim().isEmpty == true ? null : vehiculo?.trim(),
      activo: activo,
      creadoEn: DateTime.now(),
    );

    final result = await saveDeliveryUseCase!(delivery);
    _isLoading = false;

    Delivery? savedResult;
    result.fold(
      (f) {
        _error = f.message;
      },
      (saved) {
        savedResult = saved;
        final idx = _deliveries.indexWhere((d) => d.id == saved.id);
        if (idx >= 0) {
          _deliveries[idx] = saved;
        } else {
          _deliveries.add(saved);
        }
        _selectedDelivery = saved;
        syncManager?.syncPendingOperations();
      },
    );

    notifyListeners();
    return savedResult;
  }

  Future<void> deleteDelivery(String id) async {
    if (deleteDeliveryUseCase == null) return;
    _isLoading = true;
    notifyListeners();

    final result = await deleteDeliveryUseCase!(id);
    _isLoading = false;

    result.fold(
      (f) => _error = f.message,
      (_) {
        _deliveries.removeWhere((d) => d.id == id);
        if (_selectedDelivery?.id == id) {
          _selectedDelivery = null;
        }
        syncManager?.syncPendingOperations();
      },
    );

    notifyListeners();
  }

  void searchProducts(String query) {
    _currentSearchQuery = query;
    if (query.isEmpty) {
      _filteredProducts = List.from(_allProducts);
    } else {
      final q = query.toLowerCase();
      _filteredProducts = _allProducts.where((p) {
        return p.sku.toLowerCase().contains(q) || 
               p.name.toLowerCase().contains(q) || 
               p.brand.toLowerCase().contains(q);
      }).toList();
    }
    notifyListeners();
  }

  void addItem(SaleItem item, Product product) {
    // Validar anti-pérdida (RF-08)
    final finalPrice = item.unitPrice - (item.quantity > 0 ? (item.lineDiscount / item.quantity) : 0);
    if (product.latestCost != null && finalPrice < product.latestCost!) {
      _error = 'El precio unitario (Bs. ${item.unitPrice.toStringAsFixed(2)}) no puede ser menor al costo de adquisición (Bs. ${product.latestCost?.toStringAsFixed(2)})';
      notifyListeners();
      return;
    }

    final idx = _cart.indexWhere((i) => i.productId == item.productId);
    int newQuantity = item.quantity;
    
    if (idx >= 0) {
      newQuantity += _cart[idx].quantity;
    }

    // Validar stock (RF-07)
    final available = getAvailableStock(product);
    if (newQuantity > available) {
      _error = 'Cantidad supera el stock disponible en $_stockLocation ($available)';
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
        unitCost:     product.latestCost ?? existing.unitCost,
        lineDiscount: item.lineDiscount,
      );
    } else {
      _cart.add(SaleItem(
        productId: item.productId,
        productName: item.productName,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        unitCost: product.latestCost ?? 0.0,
        lineDiscount: item.lineDiscount,
      ));
    }
    _error = null;
    notifyListeners();
  }

  void updateItemPrice(String productId, double newUnitPrice) {
    final idx = _cart.indexWhere((i) => i.productId == productId);
    if (idx >= 0) {
      final item = _cart[idx];
      final product = _allProducts.firstWhere((p) => p.id == productId, orElse: () => Product(
        id: productId,
        sku: '',
        name: item.productName,
        brand: '',
        category: '',
        standardSellingPrice: newUnitPrice,
        minStockThreshold: 0,
      ));

      if (product.latestCost != null && newUnitPrice < product.latestCost!) {
        _error = 'El precio unitario (Bs. ${newUnitPrice.toStringAsFixed(2)}) no puede ser menor al costo real (Bs. ${product.latestCost?.toStringAsFixed(2)})';
        notifyListeners();
        return;
      }

      _cart[idx] = SaleItem(
        productId: item.productId,
        productName: item.productName,
        quantity: item.quantity,
        unitPrice: newUnitPrice,
        unitCost: item.unitCost,
        lineDiscount: item.lineDiscount,
      );
      _error = null;
      notifyListeners();
    }
  }

  void updateItemQuantity(String productId, int newQuantity, Product product) {
    if (newQuantity <= 0) {
      removeItem(productId);
      return;
    }
    final available = getAvailableStock(product);
    if (newQuantity > available) {
      _error = 'Cantidad supera el stock disponible en $_stockLocation ($available)';
      notifyListeners();
      return;
    }
    final idx = _cart.indexWhere((i) => i.productId == productId);
    if (idx >= 0) {
      final item = _cart[idx];
      _cart[idx] = SaleItem(
        productId: item.productId,
        productName: item.productName,
        quantity: newQuantity,
        unitPrice: item.unitPrice,
        unitCost: item.unitCost,
        lineDiscount: item.lineDiscount,
      );
      _error = null;
      notifyListeners();
    }
  }

  void removeItem(String productId) {
    _cart.removeWhere((i) => i.productId == productId);
    notifyListeners();
  }

  void clearCart() {
    _cart.clear();
    notifyListeners();
  }

  Future<bool> checkout({String? promoterId, String? storeLocation}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    if (violatesAntiLoss) {
      _error = 'Violación anti-pérdida: El precio total (Bs. $cartTotal) es menor al costo (Bs. $totalCostBase).';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    final targetLocation = storeLocation ?? _stockLocation;

    final sale = Sale(
      id:             const Uuid().v4(),
      clienteId:      _selectedClient?.id,
      deliveryId:     _deliveryMethod == 'DELIVERY' ? _selectedDelivery?.id : null,
      deliveryName:   _deliveryMethod == 'DELIVERY' ? _selectedDelivery?.nombre : null,
      items:          List.from(_cart),
      createdAt:      DateTime.now(),
      promoterId:     promoterId,
      paymentMethod:  _paymentMethod,
      deliveryMethod: _deliveryMethod,
      deliveryFee:    _deliveryFee,
      customerName:   _selectedClient?.nombreAlias ?? _customerName,
      customerPhone:  _selectedClient?.telefonoWhatsapp ?? _customerPhone,
      discount:       _globalDiscount,
      storeLocation:  targetLocation,
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
        syncManager?.syncPendingOperations();
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
      (_) {
        _error = null;
        loadProducts();
        syncManager?.syncPendingOperations();
      },
    );
    notifyListeners();
    return result.isRight();
  }
}
