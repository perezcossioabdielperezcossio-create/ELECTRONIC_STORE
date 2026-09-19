import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/lot.dart';
import '../../domain/entities/product.dart';
import '../viewmodels/inventory_viewmodel.dart';

class AddLotDialog extends StatefulWidget {
  final Product product;

  const AddLotDialog({super.key, required this.product});

  @override
  State<AddLotDialog> createState() => _AddLotDialogState();
}

class _AddLotDialogState extends State<AddLotDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _costController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  @override
  void dispose() {
    _quantityController.dispose();
    _costController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final quantity = int.parse(_quantityController.text);
    final cost = double.parse(_costController.text);

    final newLot = Lot(
      id: const Uuid().v4(),
      productId: widget.product.id,
      purchaseDate: _selectedDate,
      initialQuantity: quantity,
      currentQuantity: quantity,
      realUnitCost: cost,
    );

    final success = await context.read<InventoryViewModel>().addLot(widget.product.id, newLot);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      if (success) {
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al agregar el lote')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Nuevo Lote: ${widget.product.name}'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(
                  labelText: 'Cantidad adquirida',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.add_box),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Requerido';
                  final v = int.tryParse(value);
                  if (v == null || v <= 0) return 'Debe ser un entero mayor a 0';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _costController,
                decoration: const InputDecoration(
                  labelText: 'Costo unitario real (Bs)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Requerido';
                  final v = double.tryParse(value);
                  if (v == null || v <= 0) return 'Debe ser un número mayor a 0';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Fecha de ingreso'),
                subtitle: Text('${_selectedDate.toLocal()}'.split(' ')[0]),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectDate(context),
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: widget.product.standardSellingPrice.toStringAsFixed(2),
                decoration: const InputDecoration(
                  labelText: 'Precio base sugerido (Bs) (Solo lectura)',
                  border: OutlineInputBorder(),
                ),
                readOnly: true,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading 
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
              : const Text('Confirmar'),
        ),
      ],
    );
  }
}
