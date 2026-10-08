import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/pos_viewmodel.dart';
import '../../../clients/domain/entities/client.dart';
import '../../../deliveries/domain/entities/delivery.dart';
import '../../../deliveries/presentation/widgets/delivery_management_dialog.dart';

class CheckoutBottomSheet extends StatefulWidget {
  const CheckoutBottomSheet({super.key});

  @override
  State<CheckoutBottomSheet> createState() => _CheckoutBottomSheetState();
}

class _CheckoutBottomSheetState extends State<CheckoutBottomSheet> {
  final TextEditingController _deliveryFeeController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();

  @override
  void dispose() {
    _deliveryFeeController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  void _showNewClientDialog(BuildContext context, PosViewModel viewModel) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.person_add, color: Colors.deepPurple),
            SizedBox(width: 8),
            Text('Nuevo Cliente CRM'),
          ],
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre / Alias *',
                    hintText: 'Ej. Juan Pérez / Tech Store',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa el nombre o alias' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono / WhatsApp',
                    hintText: 'Ej. +591 70000000',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: addressCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Dirección Predeterminada',
                    hintText: 'Ej. Av. Principal #123',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Guardar Cliente'),
            onPressed: () async {
              if (formKey.currentState?.validate() == true) {
                final newClient = await viewModel.createNewClient(
                  nombreAlias: nameCtrl.text,
                  telefonoWhatsapp: phoneCtrl.text,
                  direccionPredet: addressCtrl.text,
                );
                if (context.mounted) {
                  Navigator.pop(dialogCtx);
                  if (newClient != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Cliente "${newClient.nombreAlias}" guardado y sincronizado.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              }
            },
          ),
        ],
      ),
    );
  }

  void _showEditItemPriceDialog(BuildContext context, PosViewModel vm, String productId, double currentPrice) {
    final priceCtrl = TextEditingController(text: currentPrice.toStringAsFixed(2));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar Precio Cobrado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ajusta el precio unitario pactado para este ítem:',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Precio Unitario Cobrado (Bs.)',
                border: OutlineInputBorder(),
                prefixText: 'Bs. ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final newPrice = double.tryParse(priceCtrl.text);
              if (newPrice != null && newPrice >= 0) {
                vm.updateItemPrice(productId, newPrice);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Actualizar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 20,
      ),
      child: Consumer<PosViewModel>(
        builder: (context, viewModel, child) {
          final totalConFlete = viewModel.cartTotal + viewModel.deliveryFee;

          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Resumen & Cobro', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(),

                // 1. CRM - Selección de Cliente
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Cliente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    TextButton.icon(
                      icon: const Icon(Icons.person_add, size: 18),
                      label: const Text('+ Nuevo Cliente'),
                      onPressed: () => _showNewClientDialog(context, viewModel),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: viewModel.selectedClient?.id ?? 'mostrador',
                      items: viewModel.clients.map((Client c) {
                        return DropdownMenuItem<String>(
                          value: c.id,
                          child: Row(
                            children: [
                              Icon(
                                c.id == 'mostrador' ? Icons.storefront : Icons.person,
                                size: 18,
                                color: Colors.deepPurple,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  c.nombreAlias,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: c.id == 'mostrador' ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                              if (c.telefonoWhatsapp != null && c.telefonoWhatsapp!.isNotEmpty)
                                Text(
                                  ' (${c.telefonoWhatsapp})',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newId) {
                        if (newId != null) {
                          final selected = viewModel.clients.firstWhere((c) => c.id == newId, orElse: () => PosViewModel.defaultClient);
                          viewModel.selectClient(selected);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Desglose de Ítems en Carrito con Edición de Precio
                const Text('Productos en Carrito', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: viewModel.cart.length,
                    separatorBuilder: (_, index) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final item = viewModel.cart[i];
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        title: Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Row(
                          children: [
                            Text('${item.quantity} x Bs. ${item.unitPrice.toStringAsFixed(2)}'),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => _showEditItemPriceDialog(context, viewModel, item.productId, item.unitPrice),
                              child: const Row(
                                children: [
                                  Icon(Icons.edit, size: 14, color: Colors.deepPurple),
                                  SizedBox(width: 2),
                                  Text('Editar Precio', style: TextStyle(fontSize: 12, color: Colors.deepPurple, decoration: TextDecoration.underline)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        trailing: Text(
                          'Bs. ${item.lineTotal.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Método de Pago
                const Text('Método de Pago', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    ChoiceChip(
                      label: const Text('Efectivo'),
                      avatar: const Icon(Icons.payments, size: 16),
                      selected: viewModel.paymentMethod == 'EFECTIVO',
                      onSelected: (_) => viewModel.setPaymentMethod('EFECTIVO'),
                    ),
                    ChoiceChip(
                      label: const Text('Transferencia'),
                      avatar: const Icon(Icons.account_balance, size: 16),
                      selected: viewModel.paymentMethod == 'TRANSFERENCIA',
                      onSelected: (_) => viewModel.setPaymentMethod('TRANSFERENCIA'),
                    ),
                    ChoiceChip(
                      label: const Text('QR'),
                      avatar: const Icon(Icons.qr_code, size: 16),
                      selected: viewModel.paymentMethod == 'QR',
                      onSelected: (_) => viewModel.setPaymentMethod('QR'),
                    ),
                    ChoiceChip(
                      label: const Text('Tarjeta'),
                      avatar: const Icon(Icons.credit_card, size: 16),
                      selected: viewModel.paymentMethod == 'TARJETA',
                      onSelected: (_) => viewModel.setPaymentMethod('TARJETA'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 4. Modalidad de Entrega
                const Text('Modalidad de Entrega', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'TIENDA', label: Text('Retiro en Tienda'), icon: Icon(Icons.store)),
                    ButtonSegment(value: 'DELIVERY', label: Text('Delivery / Encomienda'), icon: Icon(Icons.delivery_dining)),
                  ],
                  selected: {viewModel.deliveryMethod},
                  onSelectionChanged: (Set<String> newSelection) {
                    viewModel.setDeliveryMethod(newSelection.first);
                    if (newSelection.first == 'TIENDA') {
                      viewModel.setDeliveryFee(0.0);
                      _deliveryFeeController.clear();
                    }
                  },
                ),
                const SizedBox(height: 12),

                if (viewModel.deliveryMethod == 'DELIVERY') ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Repartidor Asignado', style: TextStyle(fontWeight: FontWeight.w600)),
                      TextButton.icon(
                        icon: const Icon(Icons.two_wheeler, size: 16),
                        label: const Text('Gestionar Repartidores'),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => const DeliveryManagementDialog(),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        isExpanded: true,
                        value: viewModel.selectedDelivery?.id,
                        hint: const Text('Selecciona o asigna un repartidor'),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Sin repartidor específico (Por asignar)'),
                          ),
                          ...viewModel.deliveries.where((d) => d.activo).map((Delivery d) {
                            return DropdownMenuItem<String?>(
                              value: d.id,
                              child: Row(
                                children: [
                                  const Icon(Icons.two_wheeler, size: 18, color: Colors.deepPurple),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${d.nombre} (${d.telefono})',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (d.vehiculo != null)
                                    Text(
                                      ' [${d.vehiculo}]',
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                ],
                              ),
                            );
                          }),
                        ],
                        onChanged: (String? deliveryId) {
                          if (deliveryId == null) {
                            viewModel.selectDelivery(null);
                          } else {
                            final found = viewModel.deliveries.firstWhere((d) => d.id == deliveryId);
                            viewModel.selectDelivery(found);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _deliveryFeeController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Costo de Flete (Bs.)',
                      prefixText: 'Bs. ',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      viewModel.setDeliveryFee(double.tryParse(val) ?? 0.0);
                    },
                  ),
                  const SizedBox(height: 12),
                ],

                // 5. Descuento Global
                TextField(
                  controller: _discountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Descuento Global Adicional (Bs.)',
                    prefixText: 'Bs. ',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) {
                    viewModel.setGlobalDiscount(double.tryParse(val) ?? 0.0);
                  },
                ),
                const SizedBox(height: 16),

                // 6. Resumen de Totales en Tiempo Real
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withAlpha(40),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).colorScheme.primary.withAlpha(50)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Subtotal:'),
                          Text('Bs. ${viewModel.cartSubtotal.toStringAsFixed(2)}'),
                        ],
                      ),
                      if (viewModel.globalDiscount > 0)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Descuento:'),
                            Text('- Bs. ${viewModel.globalDiscount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.red)),
                          ],
                        ),
                      if (viewModel.deliveryFee > 0)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Flete Delivery:'),
                            Text('+ Bs. ${viewModel.deliveryFee.toStringAsFixed(2)}'),
                          ],
                        ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('TOTAL A COBRAR:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(
                            'Bs. ${totalConFlete.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: viewModel.violatesAntiLoss ? Colors.red : Colors.green.shade800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                if (viewModel.violatesAntiLoss)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'Violación de Anti-Pérdida: El precio total (Bs. ${viewModel.cartTotal.toStringAsFixed(2)}) es menor al costo real (Bs. ${viewModel.totalCostBase.toStringAsFixed(2)}).',
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),

                if (viewModel.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(viewModel.error!, style: const TextStyle(color: Colors.red)),
                  ),

                const SizedBox(height: 20),

                // Botón Confirmar Cobro
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.check_circle_outline),
                    onPressed: viewModel.isLoading || viewModel.violatesAntiLoss
                        ? null
                        : () async {
                            final success = await viewModel.checkout();
                            if (!context.mounted) return;
                            if (success) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Venta registrada con éxito.\nCapital recuperado: Bs. ${viewModel.lastRecoveredCapital.toStringAsFixed(2)} | Ganancia Neta: Bs. ${viewModel.lastNetProfit.toStringAsFixed(2)}',
                                  ),
                                  backgroundColor: Colors.green.shade800,
                                  duration: const Duration(seconds: 4),
                                ),
                              );
                            }
                          },
                    label: viewModel.isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            'Confirmar Cobro (Bs. ${totalConFlete.toStringAsFixed(2)})',
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                          ),
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
