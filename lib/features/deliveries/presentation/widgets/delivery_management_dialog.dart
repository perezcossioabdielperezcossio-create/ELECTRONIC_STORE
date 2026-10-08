import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/entities/delivery.dart';
import '../../../pos/presentation/viewmodels/pos_viewmodel.dart';

class DeliveryManagementDialog extends StatefulWidget {
  const DeliveryManagementDialog({super.key});

  @override
  State<DeliveryManagementDialog> createState() => _DeliveryManagementDialogState();
}

class _DeliveryManagementDialogState extends State<DeliveryManagementDialog> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PosViewModel>().loadDeliveries();
    });
  }

  Future<void> _launchWhatsApp(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('https://wa.me/$cleanPhone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}
    _launchCall(phone);
  }

  Future<void> _launchCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {}
  }

  void _showAddEditDeliveryDialog(BuildContext context, PosViewModel vm, [Delivery? delivery]) {
    final nameCtrl = TextEditingController(text: delivery?.nombre ?? '');
    final phoneCtrl = TextEditingController(text: delivery?.telefono ?? '');
    final vehicleCtrl = TextEditingController(text: delivery?.vehiculo ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(delivery == null ? Icons.person_add : Icons.edit, color: Colors.deepPurple),
            const SizedBox(width: 8),
            Text(delivery == null ? 'Nuevo Repartidor' : 'Editar Repartidor'),
          ],
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre Completo *',
                    hintText: 'Ej. Roberto Gómez',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa el nombre' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono / WhatsApp *',
                    hintText: 'Ej. +591 71234567',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa el teléfono' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: vehicleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Vehículo / Notas',
                    hintText: 'Ej. Moto Honda / Auto',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.two_wheeler),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Guardar'),
            onPressed: () async {
              if (formKey.currentState?.validate() == true) {
                await vm.saveDelivery(
                  id: delivery?.id,
                  nombre: nameCtrl.text.trim(),
                  telefono: phoneCtrl.text.trim(),
                  vehiculo: vehicleCtrl.text.trim().isEmpty ? null : vehicleCtrl.text.trim(),
                  activo: delivery?.activo ?? true,
                );
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Repartidor "${nameCtrl.text.trim()}" guardado.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(20),
        child: Consumer<PosViewModel>(
          builder: (context, vm, child) {
            final deliveries = vm.deliveries;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.delivery_dining, color: Colors.deepPurple, size: 26),
                        SizedBox(width: 8),
                        Text(
                          'Gestión de Repartidores',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 8),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${deliveries.length} registrados',
                      style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
                    ),
                    FilledButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Nuevo Repartidor'),
                      onPressed: () => _showAddEditDeliveryDialog(context, vm),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Flexible(
                  child: vm.isLoadingDeliveries
                      ? const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
                      : deliveries.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.two_wheeler, size: 48, color: Colors.grey.shade400),
                                    const SizedBox(height: 8),
                                    const Text('No hay repartidores registrados.', style: TextStyle(color: Colors.grey)),
                                  ],
                                ),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: deliveries.length,
                              separatorBuilder: (_, index) => const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final d = deliveries[i];
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  leading: CircleAvatar(
                                    backgroundColor: d.activo ? Colors.green.shade50 : Colors.grey.shade200,
                                    child: Icon(
                                      Icons.two_wheeler,
                                      color: d.activo ? Colors.green.shade800 : Colors.grey,
                                    ),
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          d.nombre,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            decoration: d.activo ? null : TextDecoration.lineThrough,
                                          ),
                                        ),
                                      ),
                                      if (d.vehiculo != null && d.vehiculo!.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.deepPurple.shade50,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            d.vehiculo!,
                                            style: TextStyle(fontSize: 11, color: Colors.deepPurple.shade700, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                    ],
                                  ),
                                  subtitle: Text(d.telefono, style: const TextStyle(fontSize: 13)),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // WhatsApp Direct
                                      IconButton(
                                        icon: const Icon(Icons.chat, color: Colors.green, size: 20),
                                        tooltip: 'Enviar WhatsApp',
                                        onPressed: () => _launchWhatsApp(d.telefono),
                                      ),
                                      // Llamada Directa
                                      IconButton(
                                        icon: const Icon(Icons.call, color: Colors.blue, size: 20),
                                        tooltip: 'Llamar',
                                        onPressed: () => _launchCall(d.telefono),
                                      ),
                                      // Editar
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.deepPurple, size: 20),
                                        tooltip: 'Editar',
                                        onPressed: () => _showAddEditDeliveryDialog(context, vm, d),
                                      ),
                                      // Eliminar
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                        tooltip: 'Eliminar',
                                        onPressed: () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (confirmCtx) => AlertDialog(
                                              title: const Text('Eliminar Repartidor'),
                                              content: Text('¿Deseas eliminar a ${d.nombre}?'),
                                              actions: [
                                                TextButton(onPressed: () => Navigator.pop(confirmCtx, false), child: const Text('Cancelar')),
                                                FilledButton(
                                                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                                  onPressed: () => Navigator.pop(confirmCtx, true),
                                                  child: const Text('Eliminar'),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirm == true) {
                                            await vm.deleteDelivery(d.id);
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
