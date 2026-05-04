import 'package:flutter/material.dart';

class TipCard extends StatelessWidget {
  final String text;
  const TipCard({Key? key, required this.text}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.green.shade100,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.green.shade50,
            blurRadius: 4,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.tips_and_updates, color: Colors.green.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 16),
              softWrap: true,
              maxLines: 3,
              overflow: TextOverflow.fade,
            ),
          ),
        ],
      ),
    );
  }
}
