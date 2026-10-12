import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../viewmodels/dashboard_viewmodel.dart';
import 'package:electronic_store/core/sync/domain/services/sync_manager.dart';
import '../../data/models/financial_metrics_model.dart';
import '../../../pos/domain/entities/sale.dart';

class DashboardOverviewView extends StatefulWidget {
  const DashboardOverviewView({super.key});

  @override
  State<DashboardOverviewView> createState() => _DashboardOverviewViewState();
}

class _DashboardOverviewViewState extends State<DashboardOverviewView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = context.read<DashboardViewModel>();
      vm.loadSellers();
      vm.loadDashboardData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard & Historial'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Filtrar por fecha',
            onPressed: () async {
              final vm = context.read<DashboardViewModel>();
              final picked = await showDatePicker(
                context: context,
                initialDate: vm.selectedDate,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                vm.changeDate(picked);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: () async {
              final syncManager = context.read<SyncManager>();
              final vm = context.read<DashboardViewModel>();
              
              final count = await syncManager.forceSyncSalesFromFirestore();
              await vm.loadAuditForDate(vm.selectedDate);

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Ventas sincronizadas: $count')),
                );
              }
            },
          ),
        ],
      ),
      body: Consumer<DashboardViewModel>(
        builder: (context, vm, child) {
          if (vm.state == DashboardState.loading && vm.overview == null && vm.arqueoDiario == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (vm.state == DashboardState.error && vm.overview == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text('Error: ${vm.errorMessage}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => vm.loadDashboardData(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => vm.loadDashboardData(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Selector de Ámbito / Filtro de Auditoría (Admin)
                _buildAdminFilterSelector(context, vm),
                const SizedBox(height: 12),

                // Header con la fecha seleccionada
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                          Icon(Icons.event, color: Theme.of(context).colorScheme.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Fecha: ${dateFormat.format(vm.selectedDate)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () => vm.changeDate(DateTime.now()),
                        child: const Text('Hoy'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 3 Tarjetas Resumen Principales
                _buildMainSummaryKpiCards(vm),
                const SizedBox(height: 20),

                // Historial de Ventas del Día
                _buildDailySalesSection(vm),
                const SizedBox(height: 20),

                // Arqueo y Desglose por Método de Pago
                _buildArqueoDiario(vm.arqueoDiario),
                const SizedBox(height: 16),

                // Utilidad por Canal
                _buildMetricasCanal(vm.overview?.metricasCanal),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 3 Tarjetas resumen principales: Total Ventas del Día, Ganancia Neta Real, Capital Inmovilizado
  Widget _buildMainSummaryKpiCards(DashboardViewModel vm) {
    final totalVentas = vm.arqueoDiario?.ingresoBrutoTotal ?? 0.0;
    final gananciaNeta = vm.arqueoDiario?.gananciaNetaRealTotal ?? 0.0;
    final capitalInmovilizado = vm.overview?.balancePatrimonial.capitalInmovilizado ?? 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 600;
        final cards = [
          _buildSummaryCard(
            title: 'Total Ventas del Día',
            value: 'Bs. ${totalVentas.toStringAsFixed(2)}',
            icon: Icons.point_of_sale,
            color: Colors.deepPurple,
            subtitle: '${vm.dailySales.length} transacciones hoy',
          ),
          _buildSummaryCard(
            title: 'Ganancia Neta Real',
            value: 'Bs. ${gananciaNeta.toStringAsFixed(2)}',
            icon: Icons.trending_up,
            color: Colors.green.shade700,
            subtitle: 'Ingresos - Costo FIFO',
          ),
          _buildSummaryCard(
            title: 'Capital Inmovilizado',
            value: 'Bs. ${capitalInmovilizado.toStringAsFixed(2)}',
            icon: Icons.account_balance_wallet,
            color: Colors.blue.shade800,
            subtitle: 'Stock en almacén',
          ),
        ];

        if (isSmall) {
          return Column(
            children: cards.map((c) => Padding(padding: const EdgeInsets.only(bottom: 12), child: c)).toList(),
          );
        } else {
          return Row(
            children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: c))).toList(),
          );
        }
      },
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                CircleAvatar(
                  radius: 16,
                  backgroundColor: color.withAlpha(30),
                  child: Icon(icon, size: 18, color: color),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  /// Sección de Historial de Ventas Diarias
  Widget _buildDailySalesSection(DashboardViewModel vm) {
    final sales = vm.dailySales;
    final timeFormat = DateFormat('HH:mm');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt_long, color: Colors.deepPurple, size: 22),
                    const SizedBox(width: 8),
                    const Text(
                      'Historial de Ventas',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Chip(
                  label: Text('${sales.length} ventas'),
                  backgroundColor: Colors.deepPurple.shade50,
                  labelStyle: TextStyle(fontSize: 12, color: Colors.deepPurple.shade700, fontWeight: FontWeight.bold),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const Divider(),
            if (sales.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.inbox, size: 40, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      Text(
                        'No hay ventas registradas para esta fecha.',
                        style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sales.length,
                separatorBuilder: (_, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final sale = sales[index];
                  final isVoided = sale.status == SaleStatus.voided;
                  final totalUnits = sale.items.fold(0, (sum, i) => sum + i.quantity);

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    leading: CircleAvatar(
                      backgroundColor: isVoided ? Colors.red.shade50 : _getPaymentColor(sale.paymentMethod).withAlpha(30),
                      child: Icon(
                        _getPaymentIcon(sale.paymentMethod),
                        color: isVoided ? Colors.red : _getPaymentColor(sale.paymentMethod),
                        size: 20,
                      ),
                    ),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            sale.customerName?.isNotEmpty == true ? sale.customerName! : 'Venta #${sale.id.substring(0, sale.id.length > 6 ? 6 : sale.id.length)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              decoration: isVoided ? TextDecoration.lineThrough : null,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          'Bs. ${sale.total.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isVoided ? Colors.red : Colors.green.shade800,
                            decoration: isVoided ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Wrap(
                          spacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              timeFormat.format(sale.createdAt),
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getPaymentColor(sale.paymentMethod).withAlpha(20),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                sale.paymentMethod,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _getPaymentColor(sale.paymentMethod),
                                ),
                              ),
                            ),
                            if (sale.deliveryMethod == 'DELIVERY')
                              const Icon(Icons.delivery_dining, size: 14, color: Colors.orange),
                          ],
                        ),
                        Text(
                          isVoided ? 'ANULADA' : '$totalUnits unid.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isVoided ? FontWeight.bold : FontWeight.normal,
                            color: isVoided ? Colors.red : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  IconData _getPaymentIcon(String method) {
    switch (method.toUpperCase()) {
      case 'EFECTIVO':
        return Icons.payments;
      case 'QR':
        return Icons.qr_code;
      case 'TRANSFERENCIA':
        return Icons.account_balance;
      case 'TARJETA':
        return Icons.credit_card;
      default:
        return Icons.monetization_on;
    }
  }

  Color _getPaymentColor(String method) {
    switch (method.toUpperCase()) {
      case 'EFECTIVO':
        return Colors.green.shade700;
      case 'QR':
        return Colors.purple.shade700;
      case 'TRANSFERENCIA':
        return Colors.blue.shade700;
      case 'TARJETA':
        return Colors.orange.shade800;
      default:
        return Colors.teal;
    }
  }

  Widget _buildArqueoDiario(ArqueoDiario? arqueo) {
    if (arqueo == null) return const SizedBox.shrink();
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ExpansionTile(
        initiallyExpanded: false,
        title: const Text('Arqueo de Caja & Desglose', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        subtitle: Text('Ingreso Bruto: Bs. ${arqueo.ingresoBrutoTotal.toStringAsFixed(2)} | Ganancia: Bs. ${arqueo.gananciaNetaRealTotal.toStringAsFixed(2)}'),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildKpiRow('Ingreso Bruto Total', arqueo.ingresoBrutoTotal),
                _buildKpiRow('Capital Base Recuperado', arqueo.capitalBaseRecuperadoTotal),
                _buildKpiRow('Ganancia Neta Real', arqueo.gananciaNetaRealTotal, isBold: true, color: Colors.green.shade800),
                const SizedBox(height: 12),
                const Text('Desglose por Método de Pago:', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ...arqueo.desglose.map((d) => Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(d.metodo, style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text('Bs. ${d.ingresoBruto.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Capital Recuperado', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              Text('Bs. ${d.capitalBaseRecuperado.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Ganancia Neta', style: TextStyle(fontSize: 12, color: Colors.green)),
                              Text('Bs. ${d.gananciaNetaReal.toStringAsFixed(2)}', style: TextStyle(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricasCanal(List<MetricaCanal>? metricas) {
    if (metricas == null || metricas.isEmpty) return const SizedBox.shrink();
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ExpansionTile(
        initiallyExpanded: false,
        title: const Text('Utilidad por Canal de Venta', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        subtitle: const Text('Venta Directa vs. Red de Promotores'),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                ...metricas.map((m) => Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.canal, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const Divider(),
                          _buildKpiRow('Ingresos', m.totalIngresos),
                          _buildKpiRow('Ganancia Neta', m.gananciaNeta, color: Colors.green.shade800),
                          _buildKpiRow('Margen Neto', m.margenNetoPorcentual, isPercent: true),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminFilterSelector(BuildContext context, DashboardViewModel vm) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.filter_alt, size: 18, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 6),
                const Text(
                  'Ámbito de Auditoría & Control',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<AdminDashboardFilter>(
                segments: const [
                  ButtonSegment(
                    value: AdminDashboardFilter.almacenCentral,
                    label: Text('Almacén Central'),
                    icon: Icon(Icons.warehouse_outlined, size: 16),
                  ),
                  ButtonSegment(
                    value: AdminDashboardFilter.consolidadoGeneral,
                    label: Text('Consolidado'),
                    icon: Icon(Icons.pie_chart_outline, size: 16),
                  ),
                  ButtonSegment(
                    value: AdminDashboardFilter.porVendedor,
                    label: Text('Por Vendedor'),
                    icon: Icon(Icons.person_search_outlined, size: 16),
                  ),
                ],
                selected: {vm.adminFilter},
                onSelectionChanged: (newSelection) {
                  vm.setAdminFilter(newSelection.first);
                },
              ),
            ),
            if (vm.adminFilter == AdminDashboardFilter.porVendedor) ...[
              const SizedBox(height: 12),
              if (vm.sellers.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4.0),
                  child: Text('No hay vendedores registrados.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: vm.sellers.any((s) => s.celular == vm.selectedSellerPhone)
                      ? vm.selectedSellerPhone
                      : (vm.sellers.isNotEmpty ? vm.sellers.first.celular : null),
                  decoration: InputDecoration(
                    labelText: 'Vendedor a auditar',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: const Icon(Icons.person, size: 20),
                  ),
                  items: vm.sellers.map((seller) {
                    return DropdownMenuItem<String>(
                      value: seller.celular,
                      child: Text('${seller.nombre} (${seller.tiendaNombre})'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      vm.setSelectedSellerPhone(val);
                    }
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildKpiRow(String label, double value, {bool isBold = false, Color? color, bool isPercent = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
          Text(
            isPercent ? '${value.toStringAsFixed(2)}%' : 'Bs. ${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
