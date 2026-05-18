import 'package:cc_app/pages/create_group.dart';
import 'package:cc_app/pages/group_detail.dart';
import 'package:cc_app/pages/search.dart';
import 'package:cc_app/widgets/bottom_options.dart';
import 'package:cc_app/pages/home.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _friendGroupsStorageKey = 'friend_groups';
const String _myGroupsStorageKey = 'my_groups';
const String _selectedGroupStorageKey = 'selected_group';

class GroupsPage extends StatefulWidget {
  const GroupsPage({super.key});

  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  int _selectedIndex = 2;
  bool _isLoading = true;
  String? _loadError;
  List<String> _friendGroups = const [];
  List<String> _myGroups = const [];

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
  void initState() {
    super.initState();
    _loadFriendGroups();
  }

  Future<void> _loadFriendGroups() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedGroups = prefs.getStringList(_friendGroupsStorageKey) ?? [];
      final storedMyGroups = prefs.getStringList(_myGroupsStorageKey) ?? [];

      if (!mounted) {
        return;
      }

      setState(() {
        _friendGroups = storedGroups;
        _myGroups = storedMyGroups;
        _loadError = null;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadError = 'Could not load groups right now.';
        _isLoading = false;
      });
    }
  }

  Widget _buildGroupCard(
    String groupName, {
    required String subtitle,
    Color leadingColor = Colors.black,
  }) {
    return GestureDetector(
      onTap: () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_selectedGroupStorageKey, groupName);
        if (!mounted) {
          return;
        }
        _setSelectedIndex(2);
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => GroupDetailPage(groupName: groupName),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: leadingColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.groups, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    groupName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: Center(
        child: SizedBox(
          height: 804,
          width: 350,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
              ),
              child: RefreshIndicator(
                color: Colors.black,
                backgroundColor: Colors.white,
                onRefresh: _loadFriendGroups,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  children: [
                    Stack(
                      children: [
                        Align(
                          alignment: Alignment.topCenter,
                          child: Text(
                            'Groups',
                            style: Theme.of(context).textTheme.headlineLarge
                                ?.copyWith(color: Colors.black),
                          ),
                        ),
                        Align(
                          alignment: Alignment.topRight,
                          child: IconButton(
                            onPressed: () {
                              _setSelectedIndex(2);
                              Navigator.of(context).push(
                                PageRouteBuilder(
                                  pageBuilder: (_, __, ___) =>
                                      const CreateGroupPage(),
                                  transitionDuration: Duration.zero,
                                  reverseTransitionDuration: Duration.zero,
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.add_circle,
                              color: Colors.black,
                              size: 32,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: Colors.black12, thickness: 1),
                    const SizedBox(height: 16),
                    Text(
                      'Groups I\'m in',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: CircularProgressIndicator(color: Colors.black),
                        ),
                      )
                    else if (_loadError != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          _loadError!,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.black54),
                        ),
                      )
                    else ...[
                      if (_myGroups.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'You haven\'t created or joined any groups yet.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.black54),
                          ),
                        )
                      else
                        ..._myGroups.map(
                          (g) => _buildGroupCard(
                            g,
                            subtitle: 'Your group',
                            leadingColor: Colors.black,
                          ),
                        ),

                      const SizedBox(height: 20),

                      Text(
                        'Groups a friend is part of',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.black,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (_friendGroups.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'Pull down to refresh when your friend joins a group.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.black54),
                          ),
                        )
                      else
                        ..._friendGroups.map(
                          (g) => _buildGroupCard(g, subtitle: 'Friend group'),
                        ),
                      SizedBox(height: 80),
                    ],
                  ],
                ),
              ),
            ),
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
                  icon: Icons.search,
                  semanticLabel: 'Search',
                  onTap: () {
                    _setSelectedIndex(1);
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
                  index: 2,
                  icon: Icons.groups,
                  semanticLabel: 'Groups',
                  onTap: () {
                    _setSelectedIndex(2);
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
                  index: 3,
                  icon: Icons.person,
                  semanticLabel: 'Profile',
                  onTap: () => showBottomOptions(context, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
