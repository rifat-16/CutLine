import 'package:cutline/ui/theme/cutline_theme.dart';
import 'package:flutter/material.dart';

class ChatsScreen extends StatelessWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CutlineAppBar(title: 'Chats', centerTitle: true),
      backgroundColor: CutlineColors.secondaryBackground,
      body: Center(
        child: CutlineAnimations.entrance(
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey),
              SizedBox(height: CutlineSpacing.sm),
              Text('Coming Soon', style: CutlineTextStyles.title),
              SizedBox(height: CutlineSpacing.xs),
              Text('Chat feature is on the way!', style: CutlineTextStyles.subtitle),
            ],
          ),
        ),
      ),
    );
  }
}
