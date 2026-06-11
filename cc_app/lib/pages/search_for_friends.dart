import 'package:cc_app/client.dart';
import 'package:cc_app/pages/groups.dart';
import 'package:cc_app/pages/home.dart';
import 'package:cc_app/pages/user.dart';
import 'package:flutter/material.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  int _selectedIndex = 2;

  void _setSelectedIndex(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  bool _isSearchFocused = false;
  bool _isLoading = false;
  List<dynamic> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode()
      ..addListener(() {
        setState(() {
          _isSearchFocused = _searchFocusNode.hasFocus;
        });
      });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final results = await Client.findUsers(query, token);
      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      debugPrint("Search error: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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

  Future<void> _showFriendsList() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            'Your Friends',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: 360,
            height: 300,
            child: FutureBuilder<List<dynamic>>(
              future: Client.getFriends(token!["id"], token!["id"]),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.black),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.redAccent),
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                final friends = snapshot.data ?? [];

                if (friends.isEmpty) {
                  return const Center(
                    child: Text(
                      'No friends found.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: friends.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: Colors.black12),
                  itemBuilder: (_, index) {
                    final friend = friends[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: Colors.black12,
                        child: Icon(Icons.person, color: Colors.black87),
                      ),
                      title: Text(
                        friend["name"] ?? "Unknown User",
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: TextButton.styleFrom(foregroundColor: Colors.black),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(
        title: Text("Friends", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: "View Friends List",
            onPressed: _showFriendsList,
            icon: const Icon(Icons.supervised_user_circle_sharp),
            color: Colors.black,
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: SafeArea(
          child: SizedBox.expand(
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeInOut,
              alignment: _isSearchFocused || _searchResults.isNotEmpty
                  ? Alignment.topCenter
                  : Alignment.center,
              child: Padding(
                padding: const EdgeInsets.only(top: 16, left: 20, right: 20),
                child: SizedBox(
                  width: 350,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        focusNode: _searchFocusNode,
                        controller: _searchController,
                        style: const TextStyle(color: Colors.black),
                        cursorColor: Colors.black,
                        onChanged: (value) {
                          _performSearch(value);
                        },
                        decoration: const InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: Icon(Icons.search, color: Colors.black),
                          hintText: 'Search friends...',
                          hintStyle: TextStyle(color: Colors.black54),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(25)),
                            borderSide: BorderSide(color: Colors.white54),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(25)),
                            borderSide: BorderSide(color: Colors.black),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.only(top: 20),
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      else if (_searchResults.isNotEmpty)
                        Expanded(
                          child: ListView.builder(
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final user = _searchResults[index];
                              return Card(
                                color: Colors.white12,
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                child: ListTile(
                                  leading: const CircleAvatar(
                                    backgroundColor: Colors.white24,
                                    child: Icon(
                                      Icons.person,
                                      color: Colors.white,
                                    ),
                                  ),
                                  title: Text(
                                    user["name"] ?? "Unknown",
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(
                                      Icons.person_add,
                                      color: Colors.greenAccent,
                                    ),
                                    onPressed: () {
                                      // send friend request logic here
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                      else if (_searchController.text.isNotEmpty && !_isLoading)
                        const Padding(
                          padding: EdgeInsets.only(top: 20),
                          child: Text(
                            "No users found",
                            style: TextStyle(color: Colors.white54),
                          ),
                        ),
                    ],
                  ),
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
                    FocusScope.of(context).unfocus();
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
