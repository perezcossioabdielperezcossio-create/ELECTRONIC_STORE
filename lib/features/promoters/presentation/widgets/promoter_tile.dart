import 'package:flutter/material.dart';
import '../../domain/entities/promoter.dart';

class PromoterTile extends StatelessWidget {
  final Promoter promoter;
  const PromoterTile({super.key, required this.promoter});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.person)),
      title:    Text(promoter.name),
      subtitle: Text(promoter.phone),
      trailing: const Chip(label: Text('%')),
    );
  }
}
