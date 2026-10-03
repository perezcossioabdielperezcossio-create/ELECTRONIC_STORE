import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/sync/domain/services/sync_manager.dart';
import '../../../pos/presentation/views/pos_sales_view.dart';
import '../../../pos/presentation/widgets/void_sale_dialog.dart';
import '../../../pos/presentation/viewmodels/pos_viewmodel.dart';
import '../../../inventory/presentation/screens/inventory_catalog_screen.dart';
import '../../../inventory/presentation/viewmodels/inventory_viewmodel.dart';

import '../../../dashboard/presentation/views/dashboard_overview_view.dart';
import '../../../dashboard/presentation/viewmodels/dashboard_viewmodel.dart';
import '../../../promoters/presentation/views/promoters_view.dart';
import '../../../promoters/presentation/viewmodels/promoters_viewmodel.dart';

import 'dart:async';

class HomeShellView extends StatefulWidget {
  const HomeShellView({super.key});

  @override
  State<HomeShellView> createState() => _HomeShellViewState();
}

class _HomeShellViewState extends State<HomeShellView> {
  int _currentIndex = 1; // Default to POS
  StreamSubscription<void>? _remoteSyncSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final syncManager = context.read<SyncManager>();
      _remoteSyncSubscription = syncManager.onRemoteDataChanged.listen((_) {
        if (mounted) {
          context.read<InventoryViewModel>().loadProducts();
          context.read<PosViewModel>().loadProducts();
          context.read<DashboardViewModel>().loadDashboardData();
        }
      });
    });
  }

  @override
  void dispose() {
    _remoteSyncSubscription?.cancel();
    super.dispose();
  }

  List<Widget> _buildPages(BuildContext context) {
    return [
      InventoryCatalogScreen(viewModel: context.read<InventoryViewModel>()),
      const PosSalesView(),
      const DashboardOverviewView(),
      const PromotersView(),
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
          // Refresh data to keep views in sync
          if (index == 0 && context.mounted) {
            context.read<InventoryViewModel>().loadProducts();
          } else if (index == 1 && context.mounted) {
            context.read<PosViewModel>().loadProducts();
          } else if (index == 2 && context.mounted) {
            context.read<DashboardViewModel>().loadDashboardData();
          } else if (index == 3 && context.mounted) {
            context.read<PromotersViewModel>().load();
          }
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
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Promotores',
          ),
        ],
      ),
    );
  }
}
