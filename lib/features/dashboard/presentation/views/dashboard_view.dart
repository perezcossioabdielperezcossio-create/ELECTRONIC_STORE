import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/dashboard_viewmodel.dart';
import '../widgets/summary_card.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});
  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<DashboardViewModel>().load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: Consumer<DashboardViewModel>(
        builder: (context, vm, _) {
          if (vm.isLoading) return const Center(child: CircularProgressIndicator());
          if (vm.error != null) return Center(child: Text(vm.error!));
          final s = vm.summary;
          if (s == null) return const SizedBox();
          return GridView.count(
            crossAxisCount: 2,
            padding: const EdgeInsets.all(16),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              SummaryCard(title: 'Ventas Hoy',       value: 'RD\$ ${s.todaySales}', icon: Icons.point_of_sale),
              SummaryCard(title: 'Transacciones',     value: '${s.transactionCount}', icon: Icons.receipt_long),
              SummaryCard(title: 'Stock Bajo',        value: '${s.lowStockCount} productos', icon: Icons.warning_amber, isAlert: s.lowStockCount > 0),
              SummaryCard(title: 'Comisiones Pend.',  value: 'RD\$ ${s.pendingCommissions}', icon: Icons.people),
            ],
          );
        },
      ),
    );
  }
}
