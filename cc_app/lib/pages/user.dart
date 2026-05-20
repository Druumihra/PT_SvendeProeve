import 'package:cc_app/pages/groups.dart';
import 'package:cc_app/pages/home.dart';
import 'package:cc_app/pages/login.dart';
import 'package:cc_app/pages/search_for_friends.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class UserPage extends StatefulWidget {
  const UserPage({super.key});

  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  int _selectedIndex = 3;

  void _setSelectedIndex(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String semanticLabel,
    VoidCallback? onTap,
  }) {
    final bool isSelected = _selectedIndex == index;
    final VoidCallback handleTap = onTap ?? () => _setSelectedIndex(index);

    return Semantics(
      button: true,
      selected: isSelected,
      label: semanticLabel,
      child: GestureDetector(
        onTap: handleTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.white.withOpacity(0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.white,
      ),
      body: Center(
        child: user == null
            ? const Text(
                'No user is signed in.',
                style: TextStyle(color: Colors.white),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (user.photoURL != null)
                    CircleAvatar(
                      radius: 48,
                      backgroundImage: NetworkImage(user.photoURL!),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    user.displayName ?? 'No display name',
                    style: const TextStyle(color: Colors.white, fontSize: 20),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user.email ?? 'No email',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                      if (!context.mounted) return;
                      Navigator.of(context).pushAndRemoveUntil(
                        PageRouteBuilder(
                          pageBuilder: (_, __, ___) => LoginPage(),
                          transitionDuration: Duration.zero,
                          reverseTransitionDuration: Duration.zero,
                        ),
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                    ),
                    child: const Text(
                      'Sign out',
                      style: TextStyle(color: Colors.white),
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
                  onTap: () {
                    _setSelectedIndex(0);
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) => const HomePage(),
                        transitionDuration: Duration.zero,
                        reverseTransitionDuration: Duration.zero,
                      ),
                    );
                  },
                ),
                _buildNavItem(
                  index: 1,
                  icon: Icons.groups,
                  semanticLabel: 'Groups',
                  onTap: () {
                    _setSelectedIndex(1);
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) => const GroupsPage(),
                        transitionDuration: Duration.zero,
                        reverseTransitionDuration: Duration.zero,
                      ),
                    );
                  },
                ),
                _buildNavItem(
                  index: 2,
                  icon: Icons.person_add,
                  semanticLabel: 'Search',
                  onTap: () {
                    _setSelectedIndex(2);
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) => const SearchPage(),
                        transitionDuration: Duration.zero,
                        reverseTransitionDuration: Duration.zero,
                      ),
                    );
                  },
                ),
                _buildNavItem(
                  index: 3,
                  icon: Icons.person,
                  semanticLabel: 'Profile',
                  onTap: () {
                    _setSelectedIndex(3);
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) => const UserPage(),
                        transitionDuration: Duration.zero,
                        reverseTransitionDuration: Duration.zero,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
