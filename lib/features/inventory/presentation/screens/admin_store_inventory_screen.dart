import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../auth/domain/entities/user.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:electronic_store/core/database/database_helper.dart';
import '../../../dashboard/data/datasources/dashboard_local_datasource.dart';
import '../../domain/entities/product.dart';
import '../viewmodels/inventory_viewmodel.dart';

class AdminStoreInventoryScreen extends StatefulWidget {
  final InventoryViewModel viewModel;
  final List<User>? sellers;

  const AdminStoreInventoryScreen({
    super.key,
    required this.viewModel,
    this.sellers,
  });

  @override
  State<AdminStoreInventoryScreen> createState() => _AdminStoreInventoryScreenState();
}

class _AdminStoreInventoryScreenState extends State<AdminStoreInventoryScreen> {
  List<User> _sellers = [];
  User? _selectedSeller;
  bool _isLoadingSellers = true;

  @override
  void initState() {
    super.initState();
    if (widget.sellers != null) {
      _sellers = widget.sellers!;
      _selectedSeller = _sellers.isNotEmpty ? _sellers.first : null;
      _isLoadingSellers = false;
    } else {
      _loadSellers();
    }
  }

  Future<void> _loadSellers() async {
    try {
      final dbHelper = DatabaseHelper.instance;
      final ds = DashboardLocalDatasourceImpl(dbHelper);
      final sellers = await ds.getSellers().timeout(const Duration(seconds: 2), onTimeout: () => []);
      if (mounted) {
        setState(() {
          _sellers = sellers;
          if (_sellers.isNotEmpty) {
            _selectedSeller = _sellers.first;
          } else {
            _selectedSeller = const User(
              celular: 'general',
              nombre: 'Vendedor Tienda',
              pin: '0000',
              role: UserRole.seller,
              tiendaNombre: 'Sucursal Central',
            );
          }
          _isLoadingSellers = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _selectedSeller = const User(
            celular: 'general',
            nombre: 'Vendedor Tienda',
            pin: '0000',
            role: UserRole.seller,
            tiendaNombre: 'Sucursal Central',
          );
          _isLoadingSellers = false;
        });
      }
    }
  }

  void _showDispatchDialog() {
    final warehouseProducts = widget.viewModel.products.where((p) => p.stockInAlmacen > 0).toList();

    if (warehouseProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay productos con existencias disponibles en Almacén Central.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Product selectedProduct = warehouseProducts.first;
    final qtyController = TextEditingController(text: '1');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.move_to_inbox, color: Colors.deepPurple),
                  SizedBox(width: 8),
                  Text('Despachar a Tienda', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Selecciona un producto de Almacén Central:',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        key: const Key('dispatch_product_dropdown'),
                        isExpanded: true,
                        initialValue: selectedProduct.id,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        items: warehouseProducts.map((p) {
                          return DropdownMenuItem<String>(
                            value: p.id,
                            child: Text(
                              '${p.name} (Disp: ${p.stockInAlmacen})',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedProduct = warehouseProducts.firstWhere((p) => p.id == val);
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Stock en Almacén:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            Text(
                              '${selectedProduct.stockInAlmacen} uds.',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.deepPurple.shade700),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('dispatch_quantity_field'),
                        controller: qtyController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          labelText: 'Cantidad a transferir',
                          hintText: 'Ej. 5',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          prefixIcon: const Icon(Icons.numbers),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Ingresa una cantidad';
                          }
                          final parsed = int.tryParse(value.trim());
                          if (parsed == null || parsed <= 0) {
                            return 'Debe ser mayor a 0';
                          }
                          if (parsed > selectedProduct.stockInAlmacen) {
                            return 'No puede superar el stock en Almacén (${selectedProduct.stockInAlmacen})';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  key: const Key('dispatch_confirm_button'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    if (!(formKey.currentState?.validate() ?? false)) return;
                    final qty = int.parse(qtyController.text.trim());
                    Navigator.of(ctx).pop();

                    final success = await widget.viewModel.transferStockToStore(
                      productId: selectedProduct.id,
                      quantity: qty,
                      sellerId: _selectedSeller?.celular,
                      storeLocation: 'TIENDA',
                    );

                    if (mounted) {
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Se transfirieron $qty uds. de "${selectedProduct.name}" a la Tienda.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(widget.viewModel.errorMessage ?? 'Error al transferir mercancía.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Transferir'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAdjustQuantityDialog(Product product) {
    final currentQty = product.stockInTienda;
    final availableWarehouse = product.stockInAlmacen;
    final controller = TextEditingController(text: currentQty.toString());
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final parsedNewQty = int.tryParse(controller.text.trim()) ?? currentQty;
            final diff = parsedNewQty - currentQty;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.edit, color: Colors.blueAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Corregir Stock: ${product.name}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('En Tienda actual:', style: TextStyle(fontSize: 13, color: Colors.grey)),
                        Text('$currentQty uds.', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Disponible en Almacén:', style: TextStyle(fontSize: 13, color: Colors.grey)),
                        Text('$availableWarehouse uds.', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.indigo)),
                      ],
                    ),
                    const Divider(height: 20),
                    TextFormField(
                      key: const Key('adjust_quantity_input'),
                      controller: controller,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Nueva cantidad en Tienda',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        prefixIcon: const Icon(Icons.store),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Ingresa una cantidad';
                        }
                        final parsed = int.tryParse(value.trim());
                        if (parsed == null || parsed < 0) {
                          return 'No puede ser negativo';
                        }
                        final increase = parsed - currentQty;
                        if (increase > availableWarehouse) {
                          return 'Supera el stock de Almacén (Máx: ${currentQty + availableWarehouse})';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    if (diff < 0)
                      Text(
                        'ℹ Se reintegrarán ${-diff} uds. a Almacén Central.',
                        style: const TextStyle(fontSize: 12, color: Colors.teal, fontWeight: FontWeight.w600),
                      )
                    else if (diff > 0)
                      Text(
                        'ℹ Se transferirán $diff uds. adicionales desde Almacén.',
                        style: const TextStyle(fontSize: 12, color: Colors.indigo, fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  key: const Key('adjust_confirm_button'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    if (!(formKey.currentState?.validate() ?? false)) return;
                    final newQty = int.parse(controller.text.trim());
                    Navigator.of(ctx).pop();

                    final success = await widget.viewModel.revertOrAdjustStoreStock(
                      productId: product.id,
                      newQuantity: newQty,
                    );

                    if (mounted) {
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Stock de "${product.name}" corregido a $newQty uds.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(widget.viewModel.errorMessage ?? 'Error al ajustar existencias.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Guardar Corrección'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showRevertDialog(Product product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Reintegrar Producto', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          '¿Deseas reintegrar todo el stock de "${product.name}" (${product.stockInTienda} uds.) de vuelta a Almacén Central?\n\n'
          'Esta acción eliminará el producto asignado por error a la tienda sin afectar ventas completadas.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            key: const Key('revert_confirm_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final success = await widget.viewModel.revertOrAdjustStoreStock(
                productId: product.id,
                newQuantity: 0,
              );

              if (mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Se reintegró el stock de "${product.name}" a Almacén Central.'),
                      backgroundColor: Colors.teal,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(widget.viewModel.errorMessage ?? 'Error al reintegrar mercancía.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Reintegrar a Almacén'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel?>();
    final isAuthorized = auth?.isAdmin ?? false;

    if (!isAuthorized) {
      return Scaffold(
        appBar: AppBar(title: const Text('Gestión de Tienda')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.gpp_bad_outlined, size: 64, color: Colors.red),
                SizedBox(height: 16),
                Text(
                  'Acceso Restringido',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Esta sección es exclusiva para el perfil Administrador.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventario en Tienda'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: () => widget.viewModel.loadProducts(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => widget.viewModel.loadProducts(),
        child: ListenableBuilder(
          listenable: widget.viewModel,
          builder: (context, _) {
            final storeProducts = widget.viewModel.products.where((p) => p.stockInTienda > 0).toList();
            final totalUnitsInStore = storeProducts.fold<int>(0, (sum, p) => sum + p.stockInTienda);

            return ListView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                // 1. Selector de Tienda / Vendedor
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.storefront, size: 18, color: Colors.deepPurple),
                            SizedBox(width: 6),
                            Text(
                              'Tienda / Vendedor Inspeccionado:',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_isLoadingSellers)
                          const SizedBox(height: 24, child: Center(child: Text('Cargando vendedores...', style: TextStyle(fontSize: 12, color: Colors.grey))))
                        else if (_sellers.isEmpty)
                          Text(
                            _selectedSeller?.tiendaNombre ?? 'Sucursal Central',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          )
                        else
                          DropdownButtonFormField<String>(
                            key: const Key('seller_selector_dropdown'),
                            isExpanded: true,
                            initialValue: _selectedSeller?.celular,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            items: _sellers.map((s) {
                              return DropdownMenuItem<String>(
                                value: s.celular,
                                child: Text(
                                  '${s.nombre} • ${s.tiendaNombre} (${s.celular})',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              );
                            }).toList(),
                            onChanged: (phone) {
                              if (phone != null) {
                                setState(() {
                                  _selectedSeller = _sellers.firstWhere((s) => s.celular == phone);
                                });
                              }
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Resumen rápido
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.teal.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Productos en Tienda', style: TextStyle(fontSize: 12, color: Colors.teal)),
                            const SizedBox(height: 4),
                            Text(
                              '${storeProducts.length} ítems',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.deepPurple.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Unidades Totales', style: TextStyle(fontSize: 12, color: Colors.deepPurple)),
                            const SizedBox(height: 4),
                            Text(
                              '$totalUnitsInStore uds.',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepPurple.shade900),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 2. Encabezado de Lista
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Mercancía Asignada en Tienda',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${storeProducts.length} productos',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // 3. Vista de lista con todos los productos que actualmente tiene el vendedor en TIENDA
                if (storeProducts.isEmpty)
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36.0, horizontal: 16.0),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text(
                              'No hay mercancía asignada a esta tienda',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Usa el botón "Despachar a Tienda" para transferir stock desde Almacén Central.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  ...storeProducts.map((product) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'SKU: ${product.sku} • ${product.brand}',
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.teal.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.teal.shade300),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text('En Tienda', style: TextStyle(fontSize: 10, color: Colors.teal)),
                                      Text(
                                        '${product.stockInTienda} uds.',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.teal.shade900),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 18),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Almacén Central: ${product.stockInAlmacen} uds.',
                                  style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.w500),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      key: Key('edit_stock_${product.id}'),
                                      icon: const Icon(Icons.edit, size: 20, color: Colors.blueAccent),
                                      tooltip: 'Corregir cantidad asignada',
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => _showAdjustQuantityDialog(product),
                                    ),
                                    IconButton(
                                      key: Key('delete_stock_${product.id}'),
                                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                      tooltip: 'Reintegrar a Almacén Central',
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => _showRevertDialog(product),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 60),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('dispatch_fab'),
        onPressed: _showDispatchDialog,
        icon: const Icon(Icons.move_to_inbox),
        label: const Text('Despachar a Tienda'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
    );
  }
}
