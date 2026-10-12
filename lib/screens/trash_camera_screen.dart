import 'package:flutter/material.dart';
import '../widgets/trash_classifier.dart';

class TrashCameraScreen extends StatelessWidget {
  const TrashCameraScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(child: TrashClassifier()),
    );
  }
}
