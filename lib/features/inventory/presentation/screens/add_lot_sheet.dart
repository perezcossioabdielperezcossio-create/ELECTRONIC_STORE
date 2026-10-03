import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/lot.dart';
import '../../domain/entities/product.dart';
import '../viewmodels/inventory_viewmodel.dart';

class AddLotSheet extends StatefulWidget {
  final InventoryViewModel viewModel;
  final Product product;

  const AddLotSheet({
    super.key,
    required this.viewModel,
    required this.product,
  });

  @override
  State<AddLotSheet> createState() => _AddLotSheetState();
}

class _AddLotSheetState extends State<AddLotSheet> {
  final _formKey = GlobalKey<FormState>();

  int _quantity = 0;
  double _unitCost = 0.0;
  double? _promoterBasePrice;

  bool _isSaving = false;

  void _save() async {
    if (_formKey.currentState?.validate() ?? false) {
      _formKey.currentState?.save();
      setState(() {
        _isSaving = true;
      });

      final lotId = const Uuid().v4();

      final newLot = Lot(
        id: lotId,
        productId: widget.product.id,
        purchaseDate: DateTime.now().toUtc(),
        initialQuantity: _quantity,
        currentQuantity: _quantity,
        realUnitCost: _unitCost,
        promoterBasePrice: _promoterBasePrice,
      );

      final success = await widget.viewModel.addLot(widget.product.id, newLot);
      
      setState(() {
        _isSaving = false;
      });

      if (success && mounted) {
        // Refrescar inventario
        widget.viewModel.loadProducts();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lote registrado con éxito.'), backgroundColor: Colors.green),
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
                'Nuevo Lote de Compra',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Producto: ${widget.product.name}\nSKU: ${widget.product.sku}',
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
              ),
              const Divider(),
              const SizedBox(height: 8),
              
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
                onPressed: _isSaving ? null : _save,
                child: _isSaving 
                    ? const CircularProgressIndicator()
                    : const Text('Guardar Lote'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
