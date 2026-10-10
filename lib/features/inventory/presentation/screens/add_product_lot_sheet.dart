import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/lot.dart';
import '../viewmodels/inventory_viewmodel.dart';

import 'add_lot_sheet.dart';

class AddProductLotSheet extends StatefulWidget {
  final InventoryViewModel viewModel;

  const AddProductLotSheet({super.key, required this.viewModel});

  @override
  State<AddProductLotSheet> createState() => _AddProductLotSheetState();
}

class _AddProductLotSheetState extends State<AddProductLotSheet> {
  final _formKey = GlobalKey<FormState>();

  String _sku = '';
  String _name = '';
  String _brand = '';
  String _category = '';
  double _salePrice = 0.0;
  int _minStock = 0;

  int _quantity = 0;
  double _unitCost = 0.0;
  double? _promoterBasePrice;
  String _location = 'ALMACEN';

  bool _isSaving = false;
  Product? _existingProduct;

  void _checkSku(String sku) {
    setState(() {
      _sku = sku;
      _existingProduct = widget.viewModel.products.where((p) => p.sku == sku).firstOrNull;
    });
  }

  void _save() async {
    if (_formKey.currentState?.validate() ?? false) {
      _formKey.currentState?.save();
      setState(() {
        _isSaving = true;
      });

      final productId = const Uuid().v4();
      final lotId = const Uuid().v4();

      final newProduct = Product(
        id: productId,
        sku: _sku,
        name: _name,
        brand: _brand,
        category: _category,
        standardSellingPrice: _salePrice,
        minStockThreshold: _minStock,
      );

      final newLot = Lot(
        id: lotId,
        productId: productId,
        purchaseDate: DateTime.now().toUtc(),
        initialQuantity: _quantity,
        currentQuantity: _quantity,
        realUnitCost: _unitCost,
        promoterBasePrice: _promoterBasePrice,
        location: _location,
      );

      final success = await widget.viewModel.createProductWithLot(newProduct, newLot);
      
      setState(() {
        _isSaving = false;
      });

      if (success && mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Producto y Lote registrados con éxito.'), backgroundColor: Colors.green),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${widget.viewModel.errorMessage ?? 'Desconocido'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Padding para evitar que el teclado oculte el formulario
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Nuevo Producto y Lote Inicial',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              const Text('Datos del Producto', style: TextStyle(fontWeight: FontWeight.bold)),
              const Divider(),
              if (_existingProduct != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade400),
                  ),
                  child: Column(
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.warning, color: Colors.orange),
                          SizedBox(width: 8),
                          Expanded(child: Text('Este SKU ya está registrado.')),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => AddLotSheet(
                              viewModel: widget.viewModel,
                              product: _existingProduct!,
                            ),
                          );
                        },
                        child: const Text('Agregar lote a este SKU'),
                      ),
                    ],
                  ),
                ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'SKU / Código de Barras'),
                onChanged: _checkSku,
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Requerido';
                  if (_existingProduct != null) return 'SKU duplicado';
                  return null;
                },
                onSaved: (val) => _sku = val!,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Nombre del Producto'),
                validator: (val) => val == null || val.isEmpty ? 'Requerido' : null,
                onSaved: (val) => _name = val!,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Marca'),
                validator: (val) => val == null || val.isEmpty ? 'Requerido' : null,
                onSaved: (val) => _brand = val!,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Categoría'),
                validator: (val) => val == null || val.isEmpty ? 'Requerido' : null,
                onSaved: (val) => _category = val!,
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(labelText: 'Precio de Venta (Bs)'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Requerido';
                        if (double.tryParse(val) == null) return 'Inválido';
                        return null;
                      },
                      onSaved: (val) => _salePrice = double.parse(val!),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(labelText: 'Stock Mínimo'),
                      keyboardType: TextInputType.number,
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Requerido';
                        if (int.tryParse(val) == null) return 'Inválido';
                        return null;
                      },
                      onSaved: (val) => _minStock = int.parse(val!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              const Text('Datos del Lote de Compra Inicial', style: TextStyle(fontWeight: FontWeight.bold)),
              const Divider(),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(labelText: 'Cantidad Adquirida'),
                      keyboardType: TextInputType.number,
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Requerido';
                        if (int.tryParse(val) == null || int.parse(val) <= 0) return 'Debe ser > 0';
                        return null;
                      },
                      onSaved: (val) => _quantity = int.parse(val!),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(labelText: 'Costo Unitario (Bs)'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Requerido';
                        if (double.tryParse(val) == null || double.parse(val) < 0) return 'Inválido';
                        return null;
                      },
                      onSaved: (val) => _unitCost = double.parse(val!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _location,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Ubicación del Lote Inicial',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'ALMACEN',
                    child: Text('Almacén Central (ALMACEN)'),
                  ),
                  DropdownMenuItem(
                    value: 'TIENDA',
                    child: Text('Tienda Física / Mostrador (TIENDA)'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _location = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Precio Base Promotor (Bs - Opcional)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (val) {
                  if (val != null && val.isNotEmpty && double.tryParse(val) == null) return 'Inválido';
                  return null;
                },
                onSaved: (val) => _promoterBasePrice = (val != null && val.isNotEmpty) ? double.parse(val) : null,
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: (_isSaving || _existingProduct != null) ? null : _save,
                child: _isSaving 
                    ? const CircularProgressIndicator()
                    : const Text('Guardar Producto y Lote'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
