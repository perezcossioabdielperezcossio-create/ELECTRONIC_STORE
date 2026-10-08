import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/sync/domain/services/sync_manager.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../../auth/presentation/views/login_view.dart';
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

import '../../../deliveries/presentation/widgets/delivery_management_dialog.dart';

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

  List<Widget> _buildPages(BuildContext context, bool isAdmin) {
    if (isAdmin) {
      return [
        InventoryCatalogScreen(viewModel: context.read<InventoryViewModel>()),
        const PosSalesView(),
        const DashboardOverviewView(),
        const PromotersView(),
      ];
    } else {
      return [
        InventoryCatalogScreen(viewModel: context.read<InventoryViewModel>()),
        const PosSalesView(),
        const DashboardOverviewView(),
      ];
    }
  }

  List<BottomNavigationBarItem> _buildNavItems(bool isAdmin) {
    if (isAdmin) {
      return const [
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
      ];
    } else {
      return const [
        BottomNavigationBarItem(
          icon: Icon(Icons.inventory_2_outlined),
          label: 'Catálogo',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.point_of_sale),
          label: 'POS',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_outlined),
          label: 'Dashboard',
        ),
      ];
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que deseas salir del sistema?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      final authViewModel = context.read<AuthViewModel>();
      await authViewModel.logout();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginView()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel?>();
    final isAdmin = auth?.isAdmin ?? true;
    final user = auth?.currentUser;

    final pages = _buildPages(context, isAdmin);
    if (_currentIndex >= pages.length) {
      _currentIndex = 0;
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ElectronicStore POS',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (user != null)
              Text(
                '${user.nombre} • ${user.tiendaNombre} (${user.isAdmin ? "Admin" : "Vendedor"})',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delivery_dining),
            tooltip: 'Gestionar Deliveries / Repartidores',
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const DeliveryManagementDialog(),
              );
            },
          ),
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
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  children: [
                    Icon(
                      isOnline ? Icons.cloud_done : Icons.cloud_off,
                      color: isOnline ? Colors.green : Colors.orange,
                    ),
                    if (pendingCount > 0) ...[
                      const SizedBox(width: 4),
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
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: 'Cerrar Sesión',
            onPressed: () => _handleLogout(context),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
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
          } else if (index == 3 && isAdmin && context.mounted) {
            context.read<PromotersViewModel>().load();
          }
        },
        type: BottomNavigationBarType.fixed,
        items: _buildNavItems(isAdmin),
      ),
    );
  }
}

