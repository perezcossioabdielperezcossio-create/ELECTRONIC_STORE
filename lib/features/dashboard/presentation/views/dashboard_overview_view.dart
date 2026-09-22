import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../viewmodels/dashboard_viewmodel.dart';
import '../../data/models/financial_metrics_model.dart';

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
      context.read<DashboardViewModel>().loadDashboardData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Financiero'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
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
        ],
      ),
      body: Consumer<DashboardViewModel>(
        builder: (context, vm, child) {
          if (vm.state == DashboardState.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (vm.state == DashboardState.error) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: ${vm.errorMessage}', style: const TextStyle(color: Colors.red)),
                  ElevatedButton(
                    onPressed: () => vm.loadDashboardData(),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }
          if (vm.state == DashboardState.loaded) {
            return RefreshIndicator(
              onRefresh: () => vm.loadDashboardData(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildBalancePatrimonial(vm.overview?.balancePatrimonial),
                  const SizedBox(height: 16),
                  _buildArqueoDiario(vm.arqueoDiario),
                  const SizedBox(height: 16),
                  _buildMetricasCanal(vm.overview?.metricasCanal),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildBalancePatrimonial(BalancePatrimonial? balance) {
    if (balance == null) return const SizedBox.shrink();
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Balance Patrimonial', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            Row(
              children: [
                Expanded(child: _buildKpi('Capital Inmovilizado', balance.capitalInmovilizado, Colors.blue)),
                Container(width: 1, height: 50, color: Colors.grey[300]),
                Expanded(child: _buildKpi('Ganancia Potencial', balance.gananciaPotencial, Colors.green)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArqueoDiario(ArqueoDiario? arqueo) {
    if (arqueo == null) return const SizedBox.shrink();
    final dateFormat = DateFormat('dd/MM/yyyy');
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Arqueo de Caja - ${dateFormat.format(arqueo.fecha)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            _buildKpiRow('Ingreso Bruto Total', arqueo.ingresoBrutoTotal),
            _buildKpiRow('Capital Base Recuperado', arqueo.capitalBaseRecuperadoTotal),
            _buildKpiRow('Ganancia Neta Real', arqueo.gananciaNetaRealTotal, isBold: true),
            const SizedBox(height: 16),
            const Text('Desglose por Método de Pago', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...arqueo.desglose.map((d) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(d.metodo, style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text('Bs ${d.ingresoBruto.toStringAsFixed(2)}'),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Capital Recuperado', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            Text('Bs ${d.capitalBaseRecuperado.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Ganancia Neta', style: TextStyle(fontSize: 12, color: Colors.green)),
                            Text('Bs ${d.gananciaNetaReal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricasCanal(List<MetricaCanal>? metricas) {
    if (metricas == null || metricas.isEmpty) return const SizedBox.shrink();
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Utilidad por Canal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            ...metricas.map((m) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.canal, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      _buildKpiRow('Ingresos', m.totalIngresos),
                      _buildKpiRow('Ganancia Neta', m.gananciaNeta, color: Colors.green),
                      _buildKpiRow('Margen Neto', m.margenNetoPorcentual, isPercent: true),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildKpi(String label, double value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text('Bs ${value.toStringAsFixed(2)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildKpiRow(String label, double value, {bool isBold = false, Color? color, bool isPercent = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(
            isPercent ? '${value.toStringAsFixed(2)}%' : 'Bs ${value.toStringAsFixed(2)}',
            style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color),
          ),
        ],
      ),
    );
  }
}
