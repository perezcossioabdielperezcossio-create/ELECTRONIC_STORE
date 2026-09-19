import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../features/inventory/domain/entities/product.dart';
import '../../domain/usecases/create_reservation.dart';

class NewReservationDialog extends StatefulWidget {
  final Product product;
  final String promoterId;

  const NewReservationDialog({
    super.key,
    required this.product,
    required this.promoterId,
  });

  @override
  State<NewReservationDialog> createState() => _NewReservationDialogState();
}

class _NewReservationDialogState extends State<NewReservationDialog> {
  final _quantityController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nueva Reserva'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Producto: ${widget.product.name}'),
          Text('Stock Disponible: ${widget.product.availableStock}'),
          const SizedBox(height: 16),
          TextField(
            controller: _quantityController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Cantidad'),
          ),
          const SizedBox(height: 16),
          const Text(
            'Atención: Las reservas tienen un TTL de 12 horas. '
            'Si no se concretan, el stock será liberado.',
            style: TextStyle(color: Colors.red, fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading 
            ? const CircularProgressIndicator() 
            : const Text('Reservar'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final qty = int.tryParse(_quantityController.text) ?? 0;
    if (qty <= 0 || qty > widget.product.availableStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cantidad inválida')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final createUseCase = context.read<CreateReservation>();
      await createUseCase(CreateReservationParams(
        promoterId: widget.promoterId,
        productId: widget.product.id,
        quantity: qty,
      ));
      if (mounted) {
        Navigator.pop(context, true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
