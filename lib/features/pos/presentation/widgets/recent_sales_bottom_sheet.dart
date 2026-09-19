import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/sale.dart';
import '../viewmodels/pos_viewmodel.dart';

class RecentSalesBottomSheet extends StatefulWidget {
  const RecentSalesBottomSheet({super.key});

  @override
  State<RecentSalesBottomSheet> createState() => _RecentSalesBottomSheetState();
}

class _RecentSalesBottomSheetState extends State<RecentSalesBottomSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PosViewModel>().loadRecentSales();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PosViewModel>(
      builder: (context, vm, _) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, controller) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Ventas de Hoy', style: Theme.of(context).textTheme.titleLarge),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                if (vm.isLoadingRecentSales)
                  const Expanded(child: Center(child: CircularProgressIndicator()))
                else if (vm.recentSales.isEmpty)
                  const Expanded(child: Center(child: Text('No hay ventas registradas hoy.')))
                else
                  Expanded(
                    child: ListView.builder(
                      controller: controller,
                      itemCount: vm.recentSales.length,
                      itemBuilder: (context, i) {
                        final sale = vm.recentSales[i];
                        final formatter = NumberFormat.currency(symbol: 'Bs ', decimalDigits: 2);
                        final isRefunded = sale.status == SaleStatus.refunded || sale.status == SaleStatus.voided;
                        final timeFormat = DateFormat('HH:mm');
                        
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: ExpansionTile(
                            title: Text('Venta #${sale.id.substring(0, 8).toUpperCase()}'),
                            subtitle: Text('${timeFormat.format(sale.createdAt)} - ${formatter.format(sale.total)}'),
                            trailing: isRefunded 
                              ? const Chip(label: Text('ANULADA', style: TextStyle(fontSize: 10)), backgroundColor: Colors.redAccent)
                              : const Chip(label: Text('OK', style: TextStyle(fontSize: 10)), backgroundColor: Colors.greenAccent),
                            children: [
                              ...sale.items.map((item) => ListTile(
                                dense: true,
                                title: Text('${item.quantity}x ${item.productName}'),
                                trailing: Text(formatter.format(item.lineTotal)),
                              )),
                              if (!isRefunded)
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.undo, color: Colors.red),
                                    label: const Text('Anular y Devolver a Inventario', style: TextStyle(color: Colors.red)),
                                    onPressed: () => _confirmRefund(context, vm, sale.id),
                                  ),
                                )
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmRefund(BuildContext context, PosViewModel vm, String saleId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Anulación'),
        content: const Text(
          '¿Estás seguro de anular esta venta? '
          'Las cantidades vendidas serán reintegradas al lote más reciente de cada producto de forma irreversible.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await vm.refundSale(saleId);
              if (ctx.mounted) {
                if (success) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Venta anulada correctamente')),
                  );
                } else if (vm.error != null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(vm.error!), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Sí, Anular Venta'),
          ),
        ],
      ),
    );
  }
}
