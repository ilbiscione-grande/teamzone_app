// lib/core/widgets/custom_bottom_nav_bar.dart
import 'package:flutter/material.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTapPage;

  const CustomBottomNavBar({
    Key? key,
    required this.currentIndex,
    required this.onTapPage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: currentIndex,
      onTap: onTapPage,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Team'),
        BottomNavigationBarItem(icon: Icon(Icons.event), label: 'Events'),
        BottomNavigationBarItem(
          icon: Icon(Icons.home, size: 32),
          label: 'Home',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.message), label: 'Messages'),
        BottomNavigationBarItem(icon: Icon(Icons.insert_chart), label: 'Stats'),
      ],
    );
  }
}
