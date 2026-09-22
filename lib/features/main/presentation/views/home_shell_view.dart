import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/sync/domain/services/sync_manager.dart';
import '../../../pos/presentation/views/pos_sales_view.dart';
import '../../../pos/presentation/widgets/void_sale_dialog.dart';
import '../../../inventory/presentation/screens/inventory_catalog_screen.dart';
import '../../../inventory/presentation/viewmodels/inventory_viewmodel.dart';
import '../../../promoters/presentation/views/promoters_view.dart';
import '../../../dashboard/presentation/views/dashboard_overview_view.dart';

class HomeShellView extends StatefulWidget {
  const HomeShellView({super.key});

  @override
  State<HomeShellView> createState() => _HomeShellViewState();
}

class _HomeShellViewState extends State<HomeShellView> {
  int _currentIndex = 1; // Default to POS

  List<Widget> _buildPages(BuildContext context) {
    return [
      InventoryCatalogScreen(viewModel: context.read<InventoryViewModel>()),
      const PosSalesView(),
      const PromotersView(),
      const DashboardOverviewView(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ElectronicStore POS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.assignment_return),
            tooltip: 'Anular Venta (24h)',
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const VoidSaleDialog(),
              );
            },
          ),
          Consumer<SyncManager>(
            builder: (context, syncManager, child) {
              final isOnline = syncManager.isOnline;
              final pendingCount = syncManager.pendingCount;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Icon(
                      isOnline ? Icons.cloud_done : Icons.cloud_off,
                      color: isOnline ? Colors.green : Colors.orange,
                    ),
                    if (pendingCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$pendingCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _buildPages(context),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory),
            label: 'Inventario',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.point_of_sale),
            label: 'POS',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Promotores',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
        ],
      ),
    );
  }
}
