import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../viewmodels/dashboard_viewmodel.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../../inventory/presentation/viewmodels/inventory_viewmodel.dart';
import '../../../pos/presentation/viewmodels/pos_viewmodel.dart';
import '../../../pos/domain/entities/sale.dart';

class SellerDashboardView extends StatefulWidget {
  const SellerDashboardView({super.key});

  @override
  State<SellerDashboardView> createState() => _SellerDashboardViewState();
}

class _SellerDashboardViewState extends State<SellerDashboardView> {
  /// Cached reference to avoid calling context.read in dispose().
  DashboardViewModel? _dashboardVM;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthViewModel>();
    final userPhone = auth.currentUser?.celular ?? '';
    if (userPhone.isNotEmpty) {
      _dashboardVM = context.read<DashboardViewModel>();
      // Register this seller's ID so downstream sync refreshes their data.
      _dashboardVM!.setActiveSellerUsuarioId(userPhone);
      await _dashboardVM!.loadSellerDashboardData(userPhone);
    }
  }

  @override
  void dispose() {
    // Clear the active seller so admin view is not affected after leaving.
    _dashboardVM?.setActiveSellerUsuarioId(null);
    super.dispose();
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
            onRefresh: () async {
              final invVm = context.read<InventoryViewModel>();
              final posVm = context.read<PosViewModel>();
              await _loadData();
              await invVm.loadProducts();
              await posVm.refreshCatalog();
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
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

                // Encabezado / Resumen: Total Cobrado Hoy y Cantidad de transacciones concretadas hoy
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        context,
                        title: 'Total Cobrado Hoy',
                        subtitle: 'Ventas Hoy',
                        amount: currencyFormat.format(vm.sellerVentasHoy),
                        icon: Icons.point_of_sale,
                        color: Colors.teal,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        context,
                        title: 'Transacciones Concretadas',
                        subtitle: 'Total Hoy',
                        amount: '${vm.sellerSales.length}',
                        icon: Icons.receipt_long,
                        color: Colors.indigo,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildMetricCard(
                  context,
                  title: 'Ventas Esta Semana',
                  amount: currencyFormat.format(vm.sellerVentasSemana),
                  icon: Icons.date_range,
                  color: Colors.blueGrey,
                ),
                const SizedBox(height: 20),

                // Arqueo de Caja (Desglose de cobros por método de pago)
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

                // Lista cronológica de Ventas Realizadas
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Ventas Realizadas',
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
                  ...vm.sellerSales.map((sale) => _buildSaleCard(context, sale, currencyFormat)),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSaleCard(
    BuildContext context,
    Sale sale,
    NumberFormat currencyFormat,
  ) {
    final clientName = (sale.clientName != null && sale.clientName!.trim().isNotEmpty)
        ? sale.clientName!
        : 'Cliente Mostrador';
    final formattedDateTime = DateFormat('dd/MM/yyyy HH:mm').format(sale.date);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showSaleDetailDialog(context, sale),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Monto / Precio final cobrado (Bs.) & Venta #ID
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.teal.withAlpha(40),
                        child: Icon(_getPaymentIcon(sale.paymentMethod), color: Colors.teal.shade800, size: 18),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Venta #${sale.id.length > 8 ? sale.id.substring(0, 8) : sale.id}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Text(
                      currencyFormat.format(sale.totalAmount),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 18),

              // 2. Nombre del Cliente (o 'Cliente Mostrador')
              Row(
                children: [
                  const Icon(Icons.person, size: 16, color: Colors.deepPurple),
                  const SizedBox(width: 6),
                  const Text(
                    'Cliente: ',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  Expanded(
                    child: Text(
                      clientName,
                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // 3. Fecha y hora de la venta (ej. 12/10/2026 16:30)
              Row(
                children: [
                  const Icon(Icons.access_time, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  const Text(
                    'Fecha y hora: ',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  Text(
                    formattedDateTime,
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      sale.paymentMethod,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // 4. Desglose de productos vendidos: Nombre/ID del producto y cantidad vendida (ej. "Calculadora x 2")
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.shopping_bag_outlined, size: 14, color: Colors.grey),
                        SizedBox(width: 4),
                        Text(
                          'Desglose de productos vendidos:',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (sale.items.isNotEmpty)
                      ...sale.items.map((item) {
                        final displayName = item.productName.isNotEmpty ? item.productName : item.productId;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '• $displayName x ${item.quantity}',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                currencyFormat.format(item.subtotal),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                              ),
                            ],
                          ),
                        );
                      })
                    else if (sale.details.isNotEmpty)
                      ...sale.details.map((detail) {
                        final displayName = detail.productName.isNotEmpty ? detail.productName : detail.productId;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '• $displayName x ${detail.cantidad}',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                currencyFormat.format(detail.lineTotal),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                              ),
                            ],
                          ),
                        );
                      })
                    else
                      const Text(
                        'Sin desglose registrado',
                        style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    String? subtitle,
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
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 10),
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
