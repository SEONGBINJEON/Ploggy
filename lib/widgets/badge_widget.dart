import 'package:flutter/material.dart';

class BadgeWidget extends StatelessWidget {
  final String badgeName;
  final String imageUrl;
  const BadgeWidget({required this.badgeName, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Image.network(imageUrl, width: 48, height: 48),
        Text(badgeName),
      ],
    );
  }
} 