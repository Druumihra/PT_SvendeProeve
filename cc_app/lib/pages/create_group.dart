import 'package:cc_app/pages/groups.dart';
import 'package:cc_app/pages/home.dart';
import 'package:cc_app/pages/search_for_friends.dart';
import 'package:cc_app/pages/user.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _friendGroupsStorageKey = 'friend_groups';
const String _myGroupsStorageKey = 'my_groups';
const String _groupMembersPrefix = 'group_members_';
const String _selectedGroupStorageKey = 'selected_group';

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key});

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  int _selectedIndex = 1;
  late TextEditingController _groupNameController;
  late TextEditingController _emailController;
  List<String> _invitedEmails = [];

  void _setSelectedIndex(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _addEmail() {
    final email = _emailController.text.trim();
    if (email.isNotEmpty && email.contains('@')) {
      setState(() {
        if (!_invitedEmails.contains(email)) {
          _invitedEmails.add(email);
          _emailController.clear();
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address')),
      );
    }
  }

  void _removeEmail(String email) {
    setState(() {
      _invitedEmails.remove(email);
    });
  }

  Future<void> _sendInvitations() async {
    if (_groupNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a group name')),
      );
      return;
    }
    if (_invitedEmails.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one email')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final groupName = _groupNameController.text.trim();

    final existingMyGroups = prefs.getStringList(_myGroupsStorageKey) ?? [];
    if (!existingMyGroups.contains(groupName)) {
      existingMyGroups.insert(0, groupName);
      await prefs.setStringList(_myGroupsStorageKey, existingMyGroups);
    }

    await prefs.setStringList(
      '$_groupMembersPrefix${groupName.replaceAll(RegExp(r"[^a-zA-Z0-9_]"), '_')}',
      _invitedEmails,
    );
    await prefs.setString(_selectedGroupStorageKey, groupName);

    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const GroupsPage(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _groupNameController = TextEditingController();
    _emailController = TextEditingController();
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String semanticLabel,
    VoidCallback? onTap,
  }) {
    final isSelected = _selectedIndex == index;
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
                ? Colors.white.withValues(alpha: 0.18)
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
    return Scaffold(
      backgroundColor: Colors.black87,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 300,
                height: 50,
                child: TextField(
                  controller: _groupNameController,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Colors.white,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.group, color: Colors.white54),
                    hintText: 'Group Name',
                    hintStyle: TextStyle(color: Colors.white54),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(25)),
                      borderSide: BorderSide(color: Colors.white54),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(25)),
                      borderSide: BorderSide(color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 300,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _emailController,
                            style: const TextStyle(color: Colors.white),
                            cursorColor: Colors.white,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(
                                Icons.email,
                                color: Colors.white54,
                              ),
                              hintText: 'Invite by email',
                              hintStyle: TextStyle(color: Colors.white54),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(25),
                                ),
                                borderSide: BorderSide(color: Colors.white54),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(25),
                                ),
                                borderSide: BorderSide(color: Colors.white),
                              ),
                            ),
                            onSubmitted: (_) => _addEmail(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _addEmail,
                          icon: const Icon(
                            Icons.add_circle,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ],
                    ),
                    if (_invitedEmails.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Invited users:',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24),
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _invitedEmails.map((email) {
                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white30),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      email,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: () => _removeEmail(email),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white54,
                                      size: 16,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 64),
              SizedBox(
                width: 150,
                height: 50,
                child: ElevatedButton(
                  onPressed: _sendInvitations,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    overlayColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: const Text(
                    'Create group',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
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
