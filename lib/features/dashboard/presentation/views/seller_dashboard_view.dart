import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../viewmodels/dashboard_viewmodel.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../../pos/domain/entities/sale.dart';

class SellerDashboardView extends StatefulWidget {
  const SellerDashboardView({super.key});

  @override
  State<SellerDashboardView> createState() => _SellerDashboardViewState();
}

class _SellerDashboardViewState extends State<SellerDashboardView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    final auth = context.read<AuthViewModel>();
    final userPhone = auth.currentUser?.celular ?? '';
    if (userPhone.isNotEmpty) {
      context.read<DashboardViewModel>().loadSellerDashboardData(userPhone);
    }
  }

  void _showSaleDetailDialog(BuildContext context, Sale sale) {
    final currencyFormat = NumberFormat.currency(symbol: 'Bs. ', decimalDigits: 2);
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.receipt_long, color: Colors.blueAccent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Venta #${sale.id.length > 8 ? sale.id.substring(0, 8) : sale.id}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Fecha: ${dateFormat.format(sale.date)}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
              Text('Método: ${sale.paymentMethod}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              if (sale.clientName != null && sale.clientName!.isNotEmpty)
                Text('Cliente: ${sale.clientName}', style: const TextStyle(fontSize: 13)),
              const Divider(height: 20),
              const Text('Productos Vendidos:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: sale.items.length,
                  separatorBuilder: (_, index) => const Divider(height: 1),
                  itemBuilder: (ctx, idx) {
                    final item = sale.items[idx];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.productName,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                                Text(
                                  '${item.quantity} x ${currencyFormat.format(item.soldUnitPrice)}',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            currencyFormat.format(item.subtotal),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(
                    currencyFormat.format(sale.totalAmount),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: 'Bs. ', decimalDigits: 2);
    final dateFormat = DateFormat('dd/MM/yyyy');
    final auth = context.watch<AuthViewModel>();
    final user = auth.currentUser;
    final userPhone = user?.celular ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Filtrar fecha',
            onPressed: () async {
              final vm = context.read<DashboardViewModel>();
              final picked = await showDatePicker(
                context: context,
                initialDate: vm.selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                await vm.changeDate(picked, sellerUsuarioId: userPhone);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: _loadData,
          ),
        ],
      ),
      body: Consumer<DashboardViewModel>(
        builder: (context, vm, child) {
          if (vm.isSellerLoading && vm.sellerArqueo == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (vm.sellerErrorMessage != null && vm.sellerArqueo == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text(
                      'Error: ${vm.sellerErrorMessage}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _loadData,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }

          final arqueo = vm.sellerArqueo;

          return RefreshIndicator(
            onRefresh: () async => _loadData(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Header Info
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withAlpha(50),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).colorScheme.primary.withAlpha(40)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.storefront, color: Theme.of(context).colorScheme.primary, size: 22),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.nombre ?? 'Vendedor',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              Text(
                                'Fecha: ${dateFormat.format(vm.selectedDate)}',
                                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Chip(
                        label: const Text('Tienda', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        backgroundColor: Colors.blue.withAlpha(40),
                        side: BorderSide.none,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Tarjetas de Ventas Hoy y Semana
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        context,
                        title: 'Ventas Hoy',
                        amount: currencyFormat.format(vm.sellerVentasHoy),
                        icon: Icons.today,
                        color: Colors.teal,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        context,
                        title: 'Ventas Esta Semana',
                        amount: currencyFormat.format(vm.sellerVentasSemana),
                        icon: Icons.date_range,
                        color: Colors.indigo,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Arqueo de Caja (Desglose por método de pago)
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.point_of_sale, color: Colors.blueAccent),
                            const SizedBox(width: 8),
                            const Text(
                              'Arqueo de Mi Caja (Hoy)',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            Text(
                              currencyFormat.format(arqueo?.totalIngresos ?? 0.0),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        _buildPaymentRow(
                          context,
                          label: 'Efectivo',
                          amount: arqueo?.ingresosEfectivo ?? 0.0,
                          icon: Icons.payments_outlined,
                          color: Colors.green,
                          currencyFormat: currencyFormat,
                        ),
                        const SizedBox(height: 10),
                        _buildPaymentRow(
                          context,
                          label: 'QR',
                          amount: arqueo?.ingresosQr ?? 0.0,
                          icon: Icons.qr_code,
                          color: Colors.purple,
                          currencyFormat: currencyFormat,
                        ),
                        const SizedBox(height: 10),
                        _buildPaymentRow(
                          context,
                          label: 'Transferencia',
                          amount: arqueo?.ingresosTransferencia ?? 0.0,
                          icon: Icons.account_balance,
                          color: Colors.blue,
                          currencyFormat: currencyFormat,
                        ),
                        const SizedBox(height: 10),
                        _buildPaymentRow(
                          context,
                          label: 'Tarjeta',
                          amount: arqueo?.ingresosTarjeta ?? 0.0,
                          icon: Icons.credit_card,
                          color: Colors.orange,
                          currencyFormat: currencyFormat,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Lista de Ventas Recientes
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Mis Ventas del Día',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${vm.sellerSales.length} transacciones',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (vm.sellerSales.isEmpty)
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32.0, horizontal: 16.0),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.receipt_outlined, size: 40, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('No registraste ventas en esta fecha.', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: vm.sellerSales.length,
                    itemBuilder: (ctx, index) {
                      final sale = vm.sellerSales[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.withAlpha(40),
                            child: Icon(_getPaymentIcon(sale.paymentMethod), color: Colors.blue, size: 20),
                          ),
                          title: Text(
                            'Venta #${sale.id.length > 8 ? sale.id.substring(0, 8) : sale.id}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          subtitle: Text(
                            '${DateFormat('HH:mm').format(sale.date)} • ${sale.paymentMethod} • ${sale.items.length} productos',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                currencyFormat.format(sale.totalAmount),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
                            ],
                          ),
                          onTap: () => _showSaleDetailDialog(context, sale),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String amount,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              amount,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentRow(
    BuildContext context, {
    required String label,
    required double amount,
    required IconData icon,
    required Color color,
    required NumberFormat currencyFormat,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 14)),
        const Spacer(),
        Text(
          currencyFormat.format(amount),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ],
    );
  }

  IconData _getPaymentIcon(String method) {
    switch (method.toUpperCase()) {
      case 'EFECTIVO':
        return Icons.payments_outlined;
      case 'QR':
        return Icons.qr_code;
      case 'TRANSFERENCIA':
        return Icons.account_balance;
      case 'TARJETA':
        return Icons.credit_card;
      default:
        return Icons.receipt;
    }
  }
}
