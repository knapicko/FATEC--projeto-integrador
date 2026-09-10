import 'package:flutter/material.dart';

class BotaoGoogle extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;

  const BotaoGoogle({
    super.key,
    required this.onPressed,
    this.label = 'Continuar com Google',
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Image.asset('assets/images/icone/google-logo.png', height: 22),
        label: Text(
          label,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.grey.shade300, width: 1.5),
          elevation: 0,
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }
}

Widget buildSeparadorOu() {
  return Row(
    children: [
      Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text('ou', style: TextStyle(color: Colors.grey.shade400)),
      ),
      Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
    ],
  );
}
