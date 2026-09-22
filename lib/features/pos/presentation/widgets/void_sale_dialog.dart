import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/pos_viewmodel.dart';

class VoidSaleDialog extends StatefulWidget {
  const VoidSaleDialog({super.key});

  @override
  State<VoidSaleDialog> createState() => _VoidSaleDialogState();
}

class _VoidSaleDialogState extends State<VoidSaleDialog> {
  final TextEditingController _saleIdController = TextEditingController();

  @override
  void dispose() {
    _saleIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PosViewModel>(
      builder: (context, viewModel, child) {
        return AlertDialog(
          title: const Text('Anular Venta (24h)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Ingrese el ID de la venta a anular. La anulación debe estar dentro del margen de 24 horas y devolverá el stock al lote origen.'),
              const SizedBox(height: 16),
              TextField(
                controller: _saleIdController,
                decoration: const InputDecoration(
                  labelText: 'ID de la Venta',
                  border: OutlineInputBorder(),
                ),
              ),
              if (viewModel.error != null) ...[
                const SizedBox(height: 16),
                Text(viewModel.error!, style: const TextStyle(color: Colors.red)),
              ]
            ],
          ),
          actions: [
            TextButton(
              onPressed: viewModel.isLoading ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: viewModel.isLoading
                  ? null
                  : () async {
                      if (_saleIdController.text.isEmpty) return;
                      final success = await viewModel.voidSale(_saleIdController.text.trim());
                      if (!context.mounted) return;
                      if (success) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Venta anulada con éxito'), backgroundColor: Colors.green),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: viewModel.isLoading
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Confirmar Anulación'),
            ),
          ],
        );
      },
    );
  }
}
