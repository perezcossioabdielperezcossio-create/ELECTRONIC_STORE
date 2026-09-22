import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/pos_viewmodel.dart';

class CheckoutBottomSheet extends StatefulWidget {
  const CheckoutBottomSheet({super.key});

  @override
  State<CheckoutBottomSheet> createState() => _CheckoutBottomSheetState();
}

class _CheckoutBottomSheetState extends State<CheckoutBottomSheet> {
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerPhoneController = TextEditingController();
  final TextEditingController _deliveryFeeController = TextEditingController();

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _deliveryFeeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Evitar que el teclado oculte el contenido
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 24,
      ),
      child: Consumer<PosViewModel>(
        builder: (context, viewModel, child) {
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Checkout', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                
                // Método de pago
                const Text('Método de Pago', style: TextStyle(fontWeight: FontWeight.bold)),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'EFECTIVO', label: Text('Efectivo')),
                    ButtonSegment(value: 'TRANSFERENCIA', label: Text('Transferencia')),
                  ],
                  selected: {viewModel.paymentMethod},
                  onSelectionChanged: (Set<String> newSelection) {
                    viewModel.setPaymentMethod(newSelection.first);
                  },
                ),
                const SizedBox(height: 16),

                // Método de Despacho
                const Text('Despacho', style: TextStyle(fontWeight: FontWeight.bold)),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'TIENDA', label: Text('Tienda')),
                    ButtonSegment(value: 'DELIVERY', label: Text('Delivery')),
                  ],
                  selected: {viewModel.deliveryMethod},
                  onSelectionChanged: (Set<String> newSelection) {
                    viewModel.setDeliveryMethod(newSelection.first);
                  },
                ),
                const SizedBox(height: 16),

                if (viewModel.deliveryMethod == 'DELIVERY') ...[
                  TextField(
                    controller: _deliveryFeeController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Flete (Bs)', border: OutlineInputBorder()),
                    onChanged: (val) {
                      viewModel.setDeliveryFee(double.tryParse(val) ?? 0.0);
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                // Datos de cliente (Opcional)
                const Text('Cliente (Opcional)', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: _customerNameController,
                  decoration: const InputDecoration(labelText: 'Nombre o Alias', border: OutlineInputBorder()),
                  onChanged: viewModel.setCustomerName,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _customerPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Teléfono / WhatsApp', border: OutlineInputBorder()),
                  onChanged: viewModel.setCustomerPhone,
                ),
                const SizedBox(height: 24),

                const SizedBox(height: 16),
                
                // Descuento Global
                const Text('Descuento Global (Bs)', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Monto de Descuento', border: OutlineInputBorder()),
                  onChanged: (val) {
                    viewModel.setGlobalDiscount(double.tryParse(val) ?? 0.0);
                  },
                ),
                const SizedBox(height: 16),

                // Total y Confirmar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total:', style: const TextStyle(fontSize: 20)),
                    Text('Bs. ${(viewModel.cartTotal + viewModel.deliveryFee).toStringAsFixed(2)}', 
                      style: TextStyle(
                        fontSize: 24, 
                        fontWeight: FontWeight.bold,
                        color: viewModel.violatesAntiLoss ? Colors.red : Colors.green,
                      ),
                    ),
                  ],
                ),
                if (viewModel.violatesAntiLoss)
                  const Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Text('Violación de Anti-Pérdida. Total menor al costo.', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ),
                const SizedBox(height: 16),

                if (viewModel.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(viewModel.error!, style: const TextStyle(color: Colors.red)),
                  ),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: viewModel.isLoading
                        ? null
                        : viewModel.violatesAntiLoss 
                            ? null 
                            : () async {
                            final success = await viewModel.checkout();
                            if (!context.mounted) return;
                            if (success) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Venta completada con éxito.\nCapital recuperado: Bs. ${viewModel.lastRecoveredCapital.toStringAsFixed(2)} | Ganancia: Bs. ${viewModel.lastNetProfit.toStringAsFixed(2)}'),
                                  backgroundColor: Colors.green,
                                  duration: const Duration(seconds: 4),
                                ),
                              );
                            }
                          },
                    child: viewModel.isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Confirmar Venta', style: TextStyle(fontSize: 18)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}
