import 'package:flutter/material.dart';

class Header extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const Header({super.key, required this.icon, required this.title, required this.subtitle});
  
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(children: [
      Icon(icon, size: 48, color: cs.primary),
      const SizedBox(height: 16),
      Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
    ]);
  }
}