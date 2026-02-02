import 'package:flutter/material.dart';

class InfoTileWidget extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const InfoTileWidget({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey[700]),
      title: Text(label, style: const TextStyle(fontSize: 13)),
      subtitle: Text(
        value,
        style: TextStyle(color: valueColor),
      ),
      dense: true,
    );
  }
}