import 'package:flutter/material.dart';
import '../widgets/trash_classifier.dart';

class TrashCameraScreen extends StatelessWidget {
  const TrashCameraScreen({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: TrashClassifier(),
    );
  }
} 