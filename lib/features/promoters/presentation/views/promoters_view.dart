import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/promoters_viewmodel.dart';
import '../widgets/promoter_tile.dart';

class PromotersView extends StatefulWidget {
  const PromotersView({super.key});
  @override
  State<PromotersView> createState() => _PromotersViewState();
}

class _PromotersViewState extends State<PromotersView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<PromotersViewModel>().load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Promotores')),
      body: Consumer<PromotersViewModel>(
        builder: (context, vm, _) {
          if (vm.isLoading) return const Center(child: CircularProgressIndicator());
          if (vm.error != null) return Center(child: Text(vm.error!));
          return ListView.builder(
            itemCount: vm.promoters.length,
            itemBuilder: (_, i) => PromoterTile(promoter: vm.promoters[i]),
          );
        },
      ),
    );
  }
}
