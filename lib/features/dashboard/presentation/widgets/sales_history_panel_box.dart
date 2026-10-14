import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/sales_history_entry.dart';

/// Agrupa entradas planas de historial por ventaId para presentarlas
/// como tarjetas de venta con sus líneas de detalle expandibles.
class SalesHistoryPanelBox extends StatelessWidget {
  final List<SalesHistoryEntry> entries;
  final bool isLoading;

  const SalesHistoryPanelBox({
    super.key,
    required this.entries,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Agrupa por ventaId manteniendo el orden DESC (la primera ocurrencia de
    // cada ventaId marca la posición de la venta en la lista).
    final Map<String, List<SalesHistoryEntry>> byVenta = {};
    for (final e in entries) {
      byVenta.putIfAbsent(e.ventaId, () => []).add(e);
    }
    final ventaIds = byVenta.keys.toList(); // orden natural = DESC por fecha

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Header del panel ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primary,
                  colorScheme.primary.withAlpha(200),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.receipt_long, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Historial de Ventas — Desglose por Producto',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _CountBadge(
                  label: '${ventaIds.length} ventas',
                  secondary: '${entries.length} líneas',
                ),
              ],
            ),
          ),

          // ─── Contenido ──────────────────────────────────────────────────
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (entries.isEmpty)
            _EmptyState()
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: ventaIds.length,
              separatorBuilder: (context, index) =>
                  Divider(height: 1, color: Colors.grey.shade200),
              itemBuilder: (context, idx) {
                final ventaId = ventaIds[idx];
                final lines = byVenta[ventaId]!;
                return _SaleCard(lines: lines);
              },
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// _SaleCard  —  encabezado colapsable + filas de detalle
// ═══════════════════════════════════════════════════════════════════════════════
class _SaleCard extends StatelessWidget {
  final List<SalesHistoryEntry> lines;

  const _SaleCard({required this.lines});

  @override
  Widget build(BuildContext context) {
    final first = lines.first;
    final dtFormat = DateFormat('dd/MM/yyyy HH:mm');
    final totalVenta = lines.fold(0.0, (s, l) => s + l.lineTotal);
    final totalGanancia = lines.fold(0.0, (s, l) => s + l.ganancia);
    final totalUnidades = lines.fold(0, (s, l) => s + l.cantidad);
    final payColor = _paymentColor(first.metodoPago);
    final payIcon = _paymentIcon(first.metodoPago);

    return ExpansionTile(
      key: PageStorageKey(first.ventaId),
      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      childrenPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: payColor.withAlpha(28),
        child: Icon(payIcon, color: payColor, size: 18),
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  first.clienteNombre,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  dtFormat.format(first.fecha),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Bs. ${totalVenta.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
              ),
              _GananciaChip(ganancia: totalGanancia),
            ],
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Row(
          children: [
            _MiniTag(
              label: first.metodoPago,
              color: payColor,
              icon: payIcon,
            ),
            const SizedBox(width: 6),
            _MiniTag(
              label: first.tipoEntrega,
              color: first.tipoEntrega == 'TIENDA'
                  ? Colors.teal.shade700
                  : Colors.blueGrey.shade700,
              icon: first.tipoEntrega == 'TIENDA'
                  ? Icons.storefront
                  : Icons.warehouse_outlined,
            ),
            const SizedBox(width: 6),
            Text(
              '$totalUnidades unid.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
      children: [
        Container(
          color: Colors.grey.shade50,
          child: Column(
            children: [
              // Encabezado de tabla
              _TableHeader(),
              const Divider(height: 1),
              // Filas de producto
              ...lines.map((line) => _DetailRow(line: line)),
              // Total de la venta
              _TotalRow(
                totalVenta: totalVenta,
                totalGanancia: totalGanancia,
                totalUnidades: totalUnidades,
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Color _paymentColor(String method) {
    switch (method.toUpperCase()) {
      case 'QR':
        return Colors.purple.shade700;
      case 'TRANSFERENCIA':
        return Colors.blue.shade700;
      case 'TARJETA':
        return Colors.orange.shade800;
      default:
        return Colors.green.shade700;
    }
  }

  static IconData _paymentIcon(String method) {
    switch (method.toUpperCase()) {
      case 'QR':
        return Icons.qr_code;
      case 'TRANSFERENCIA':
        return Icons.account_balance;
      case 'TARJETA':
        return Icons.credit_card;
      default:
        return Icons.payments;
    }
  }
}

// ─── Encabezado de la tabla de detalle ────────────────────────────────────────
class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.bold,
      color: Colors.grey.shade500,
      letterSpacing: 0.5,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text('PRODUCTO / SKU', style: style)),
          Expanded(flex: 2, child: Text('CANT', style: style, textAlign: TextAlign.center)),
          Expanded(flex: 2, child: Text('P. COMPRA', style: style, textAlign: TextAlign.right)),
          Expanded(flex: 2, child: Text('P. VENTA', style: style, textAlign: TextAlign.right)),
          Expanded(flex: 2, child: Text('GANANCIA', style: style, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

// ─── Fila de un producto en el desglose ───────────────────────────────────────
class _DetailRow extends StatelessWidget {
  final SalesHistoryEntry line;

  const _DetailRow({required this.line});

  @override
  Widget build(BuildContext context) {
    final isGanancia = line.ganancia >= 0;
    final gananciaColor = isGanancia ? Colors.green.shade700 : Colors.red.shade700;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Producto + SKU / ID
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.productName,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  line.sku != null && line.sku!.isNotEmpty
                      ? 'SKU: ${line.sku}'
                      : (line.productId.isNotEmpty ? 'ID: ${line.productId}' : ''),
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          // Cantidad (X unid.)
          Expanded(
            flex: 2,
            child: Text(
              '${line.cantidad} unid.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          // Precio compra (Costo unitario)
          Expanded(
            flex: 2,
            child: Text(
              'Bs. ${line.costoUnitario.toStringAsFixed(2)}',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ),
          // Precio venta (Precio unitario)
          Expanded(
            flex: 2,
            child: Text(
              'Bs. ${line.precioUnitario.toStringAsFixed(2)}',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          // Ganancia (+Bs. XX.XX en verde)
          Expanded(
            flex: 2,
            child: Text(
              '${isGanancia ? '+' : ''}Bs. ${line.ganancia.toStringAsFixed(2)}',
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, color: gananciaColor),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Fila de total de la venta ─────────────────────────────────────────────────
class _TotalRow extends StatelessWidget {
  final double totalVenta;
  final double totalGanancia;
  final int totalUnidades;

  const _TotalRow({
    required this.totalVenta,
    required this.totalGanancia,
    required this.totalUnidades,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Total venta  ·  $totalUnidades uds.',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Bs. ${totalVenta.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    'Gan: Bs. ${totalGanancia.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: totalGanancia >= 0
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Chip de ganancia (positivo/negativo) ──────────────────────────────────────
class _GananciaChip extends StatelessWidget {
  final double ganancia;
  const _GananciaChip({required this.ganancia});

  @override
  Widget build(BuildContext context) {
    final isPos = ganancia >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isPos ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '${isPos ? '+' : ''}Bs. ${ganancia.toStringAsFixed(2)}',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isPos ? Colors.green.shade700 : Colors.red.shade700,
        ),
      ),
    );
  }
}

// ─── Mini etiqueta de método de pago / tipo de entrega ────────────────────────
class _MiniTag extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _MiniTag({required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─── Badge con conteo ──────────────────────────────────────────────────────────
class _CountBadge extends StatelessWidget {
  final String label;
  final String secondary;
  const _CountBadge({required this.label, required this.secondary});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(50),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: const TextStyle(
                fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        Text(secondary,
            style: TextStyle(fontSize: 10, color: Colors.white.withAlpha(180))),
      ],
    );
  }
}

// ─── Estado vacío ─────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'Sin ventas registradas para esta fecha.',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontStyle: FontStyle.italic,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Selecciona otra fecha o sincroniza los datos.',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
