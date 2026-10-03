import 'package:flutter/material.dart';
import '../../domain/entities/product.dart';
import '../viewmodels/inventory_viewmodel.dart';

class EditProductSheet extends StatefulWidget {
  final InventoryViewModel viewModel;
  final Product product;

  const EditProductSheet({
    super.key,
    required this.viewModel,
    required this.product,
  });

  @override
  State<EditProductSheet> createState() => _EditProductSheetState();
}

class _EditProductSheetState extends State<EditProductSheet> {
  final _formKey = GlobalKey<FormState>();

  late String _name;
  late double _salePrice;
  late int _minStock;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _name = widget.product.name;
    _salePrice = widget.product.standardSellingPrice;
    _minStock = widget.product.minStockThreshold;
  }

  void _save() async {
    if (_formKey.currentState?.validate() ?? false) {
      _formKey.currentState?.save();
      setState(() {
        _isSaving = true;
      });

      final updatedProduct = Product(
        id: widget.product.id,
        sku: widget.product.sku,
        name: _name,
        brand: widget.product.brand,
        category: widget.product.category,
        standardSellingPrice: _salePrice,
        minStockThreshold: _minStock,
        lots: widget.product.lots, // maintain existing lots
      );

      final success = await widget.viewModel.updateProduct(updatedProduct);
      
      setState(() {
        _isSaving = false;
      });

      if (success && mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Producto actualizado con éxito.'), backgroundColor: Colors.green),
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
                'Editar Producto',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                initialValue: _name,
                decoration: const InputDecoration(labelText: 'Nombre del Producto'),
                validator: (val) => val == null || val.isEmpty ? 'Requerido' : null,
                onSaved: (val) => _name = val!,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _salePrice.toStringAsFixed(2),
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
                      initialValue: _minStock.toString(),
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

              ElevatedButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving 
                    ? const CircularProgressIndicator()
                    : const Text('Actualizar Producto'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
