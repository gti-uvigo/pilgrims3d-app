import 'dart:math';
import 'package:flutter/material.dart';

// Widget ahora público y en su propio archivo para mayor limpieza.
class SponsorLogos extends StatelessWidget {
  const SponsorLogos({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).primaryColor, // Asegura el color de fondo
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          double totalWidth = constraints.maxWidth;
          double image1Width = min(totalWidth * 0.15, 80);
          double image2Width = min(totalWidth * 0.22, 110);
          double spacing = min(totalWidth * 0.04, 16);

          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('images/3dataspace.png', width: image1Width),
              SizedBox(width: spacing),
              Image.asset('images/ue.png', width: image2Width),
            ],
          );
        },
      ),
    );
  }
}
