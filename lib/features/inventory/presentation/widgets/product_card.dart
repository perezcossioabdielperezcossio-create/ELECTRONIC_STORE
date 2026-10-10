import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../../auth/presentation/widgets/admin_approval_dialog.dart';
import '../../domain/entities/product.dart';
import '../viewmodels/inventory_viewmodel.dart';
import '../screens/edit_product_sheet.dart';
import '../screens/add_lot_sheet.dart';
import '../screens/receive_stock_sheet.dart';
import 'stock_status_badge.dart';

class ProductCard extends StatelessWidget {
  final Product product;

  const ProductCard({
    super.key,
    required this.product,
  });

  Future<void> _handleDeleteProduct(BuildContext context) async {
    final viewModel = context.read<InventoryViewModel>();
    
    // Solicitar autorización obligatoria por PIN Admin
    final pin = await showDialog<String>(
      context: context,
      builder: (_) => const AdminApprovalDialog(),
    );

    if (pin == null || !context.mounted) return;

    final success = await viewModel.deleteProduct(product.id);
    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Producto anulado/eliminado con éxito.'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al eliminar producto: ${viewModel.errorMessage ?? 'Desconocido'}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleDeleteLot(BuildContext context, String lotId) async {
    final viewModel = context.read<InventoryViewModel>();

    // Solicitar autorización obligatoria por PIN Admin
    final pin = await showDialog<String>(
      context: context,
      builder: (_) => const AdminApprovalDialog(),
    );

    if (pin == null || !context.mounted) return;

    final success = await viewModel.deleteLot(lotId);
    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lote anulado/eliminado con éxito.'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al anular lote: ${viewModel.errorMessage ?? 'Desconocido'}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel?>();
    bool isSeller = false;
    bool isAdmin = true;
    try {
      if (auth?.currentUser != null) {
        isSeller = auth!.currentUser!.role == UserRole.seller;
        isAdmin = auth.currentUser!.role == UserRole.admin;
      } else if (auth != null) {
        try {
          isSeller = auth.isSeller;
        } catch (_) {}
        try {
          isAdmin = auth.isAdmin;
        } catch (_) {}
        if (isSeller) {
          isAdmin = false;
        }
      }
    } catch (_) {}

    final visibleLots = isAdmin 
        ? product.lots.where((l) => l.isActive).toList()
        : product.lots.where((l) => l.isActive && l.isTienda).toList();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            product.name.isNotEmpty ? product.name[0].toUpperCase() : '?',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        title: Text(
          product.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.expand_more),
            if (isAdmin)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) async {
                  final viewModel = context.read<InventoryViewModel>();
                  if (value == 'edit') {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => EditProductSheet(
                        viewModel: viewModel,
                        product: product,
                      ),
                    );
                  } else if (value == 'add_lot') {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => AddLotSheet(
                        viewModel: viewModel,
                        product: product,
                      ),
                    );
                  } else if (value == 'delete') {
                    await _handleDeleteProduct(context);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 20),
                        SizedBox(width: 8),
                        Text('Editar Producto'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'add_lot',
                    child: Row(
                      children: [
                        Icon(Icons.add_box, size: 20, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('Añadir Lote'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 20, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Eliminar Producto', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              )
            else
              IconButton(
                icon: const Icon(Icons.add_shopping_cart, color: Colors.teal),
                tooltip: 'Recibir Mercancía',
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => ReceiveStockSheet(
                      viewModel: context.read<InventoryViewModel>(),
                      initialProduct: product,
                    ),
                  );
                },
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4.0),
            Text(
              'SKU: ${product.sku} · ${product.brand} (${product.category})',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6.0),
            if (!isAdmin) ...[
              // Métricas específicas para vendedor
              Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.teal.shade200),
                    ),
                    child: Text(
                      'Disponible en Tienda: ${product.stockInTienda}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade800,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.indigo.shade200),
                    ),
                    child: Text(
                      'En Almacén Central: ${product.stockInAlmacen}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.indigo.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6.0),
            ],
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Stock Total: ${product.availableStock}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                StockStatusBadge(status: product.status),
              ],
            ),
            const SizedBox(height: 6.0),
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Estándar: Bs. ${product.standardSellingPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
                if (isAdmin && product.promoterBasePrice != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Mayorista: Bs. ${product.promoterBasePrice!.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ),
                if (isAdmin)
                  Text(
                    'Último Costo: ${product.latestCost != null ? 'Bs. ${product.latestCost!.toStringAsFixed(2)}' : 'N/A'}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),
          ],
        ),
        children: [
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    isAdmin ? 'Lotes Activos (Almacén y Tienda):' : 'Lotes en Tienda Física:',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${visibleLots.length} lote(s)',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          ...visibleLots.map((lot) {
            final isTienda = lot.isTienda;
            return ListTile(
              dense: true,
              leading: Icon(
                isTienda ? Icons.storefront : Icons.warehouse,
                size: 20,
                color: isTienda ? Colors.teal : Colors.indigo,
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Lote #${lot.id.substring(0, lot.id.length > 8 ? 8 : lot.id.length)} · ${_formatDate(lot.purchaseDate)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isTienda ? Colors.teal.shade50 : Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isTienda ? Colors.teal.shade300 : Colors.indigo.shade300,
                      ),
                    ),
                    child: Text(
                      lot.location,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isTienda ? Colors.teal.shade800 : Colors.indigo.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              subtitle: Text(
                isAdmin
                    ? 'Disp: ${lot.currentQuantity}/${lot.initialQuantity} · Costo: Bs. ${lot.realUnitCost.toStringAsFixed(2)}'
                    : 'Disponible en Tienda: ${lot.currentQuantity} unid.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: isAdmin
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Bs. ${lot.totalHoldingCapital.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                          tooltip: 'Anular Lote',
                          onPressed: () => _handleDeleteLot(context, lot.id),
                        ),
                      ],
                    )
                  : null,
            );
          }),
          if (visibleLots.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                isAdmin 
                    ? 'No hay lotes activos para este producto.'
                    : 'No hay lotes disponibles en tienda física.',
                style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
