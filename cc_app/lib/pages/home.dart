import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  void _setSelectedIndex(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String semanticLabel,
  }) {
    final bool isSelected = _selectedIndex == index;

    return Semantics(
      button: true,
      selected: isSelected,
      label: semanticLabel,
      child: GestureDetector(
        onTap: () => _setSelectedIndex(index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.white.withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: Center(
        child: Column(
          children: [
            SizedBox(height: 30),
            SizedBox(
              width: 350,
              height: 215,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: Container(color: Colors.white),
              ),
            ),
            SizedBox(height: 30),
            SizedBox(
              width: 350,
              height: 175,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: Container(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        color: const Color(0xCC3C3C43),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildNavItem(
                  index: 0,
                  icon: Icons.home_filled,
                  semanticLabel: 'Home',
                ),
                _buildNavItem(
                  index: 1,
                  icon: Icons.search,
                  semanticLabel: 'Search',
                ),
                _buildNavItem(index: 2, icon: Icons.add, semanticLabel: 'Add'),
                _buildNavItem(
                  index: 3,
                  icon: Icons.person,
                  semanticLabel: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
