import 'dart:convert';

import 'package:cc_app/pages/groups.dart';
import 'package:cc_app/pages/home.dart';
import 'package:cc_app/pages/search_for_friends.dart';
import 'package:cc_app/pages/user.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _sanitizeKey(String groupName) =>
    groupName.replaceAll(RegExp(r"[^a-zA-Z0-9_]"), '_');

String _todayKey() => DateUtils.dateOnly(DateTime.now()).toIso8601String();

const String _selectedGroupStorageKey = 'selected_group';

class ChallengeEntry {
  final String title;
  final int points;
  final Set<String> completedDates;

  ChallengeEntry({
    required this.title,
    required this.points,
    Set<String>? completedDates,
  }) : completedDates = completedDates ?? <String>{};

  factory ChallengeEntry.fromStoredValue(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic>) {
        final dates = decoded['completedDates'];
        return ChallengeEntry(
          title: decoded['title']?.toString() ?? 'Untitled challenge',
          points: int.tryParse(decoded['points']?.toString() ?? '') ?? 0,
          completedDates: dates is List
              ? dates.map((date) => date.toString()).toSet()
              : <String>{},
        );
      }
    } catch (_) {}

    return ChallengeEntry(title: value, points: 1);
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'points': points,
    'completedDates': completedDates.toList(),
  };

  String toStoredValue() => jsonEncode(toJson());

  bool completedOn(String dateKey) => completedDates.contains(dateKey);
}

class GroupDetailPage extends StatefulWidget {
  final String groupName;
  const GroupDetailPage({super.key, required this.groupName});

  @override
  State<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<GroupDetailPage> {
  static const String _challengesPrefix = 'challenges_';
  static const String _pointsPrefix = 'challenge_points_';
  static const String _membersPrefix = 'group_members_';
  static const String _userPointsPrefix = 'user_points_';

  int _selectedIndex = 1;
  bool _isLoading = true;
  int _groupPoints = 0;
  List<ChallengeEntry> _challenges = [];
  List<String> _members = [];

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
    _setAsSelectedGroup();
    _loadGroupData();
  }

  Future<void> _setAsSelectedGroup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedGroupStorageKey, widget.groupName);
  }

  String _challengesKey() =>
      '$_challengesPrefix${_sanitizeKey(widget.groupName)}';

  String _pointsKey() => '$_pointsPrefix${_sanitizeKey(widget.groupName)}';

  String _membersKey() => '$_membersPrefix${_sanitizeKey(widget.groupName)}';

  String _userPointsKey() =>
      '$_userPointsPrefix${_sanitizeKey(widget.groupName)}';

  Map<String, int> _readUserPoints(String? rawValue) {
    if (rawValue == null || rawValue.isEmpty) {
      return <String, int>{};
    }

    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is Map<String, dynamic>) {
        return decoded.map<String, int>(
          (key, value) => MapEntry(key, int.tryParse(value.toString()) ?? 0),
        );
      }
    } catch (_) {}

    return <String, int>{};
  }

  Future<void> _loadGroupData() async {
    final prefs = await SharedPreferences.getInstance();
    final challenges = prefs.getStringList(_challengesKey()) ?? [];
    final points = prefs.getInt(_pointsKey()) ?? 0;
    final members = prefs.getStringList(_membersKey()) ?? [];
    if (!mounted) return;
    setState(() {
      _challenges = challenges.map(ChallengeEntry.fromStoredValue).toList();
      _groupPoints = points;
      _members = members;
      _isLoading = false;
    });
  }

  Future<void> _addChallenge(String title, int points) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_challengesKey()) ?? [];
    final entry = ChallengeEntry(title: title, points: points);
    list.insert(0, entry.toStoredValue());
    await prefs.setStringList(_challengesKey(), list);
    await _loadGroupData();
  }

  Future<void> _updateChallengeAt(int index, ChallengeEntry challenge) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_challengesKey()) ?? [];
    if (index < 0 || index >= list.length) {
      return;
    }

    list[index] = challenge.toStoredValue();
    await prefs.setStringList(_challengesKey(), list);
    await _loadGroupData();
  }

  Future<void> _submitChallenge(int index) async {
    if (index < 0 || index >= _challenges.length) {
      return;
    }

    final challenge = _challenges[index];
    final today = _todayKey();
    if (challenge.completedOn(today)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You already submitted this challenge today.'),
        ),
      );
      return;
    }

    final updatedChallenge = ChallengeEntry(
      title: challenge.title,
      points: challenge.points,
      completedDates: {...challenge.completedDates, today},
    );

    final updatedChallenges = List<ChallengeEntry>.from(_challenges);
    updatedChallenges[index] = updatedChallenge;

    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList(
      _challengesKey(),
      updatedChallenges.map((entry) => entry.toStoredValue()).toList(),
    );
    await prefs.setInt(_pointsKey(), _groupPoints + challenge.points);

    final userPoints = _readUserPoints(prefs.getString(_userPointsKey()));
    final updatedUserPoints = <String, int>{...userPoints};
    updatedUserPoints['You'] =
        (updatedUserPoints['You'] ?? 0) + challenge.points;
    await prefs.setString(_userPointsKey(), jsonEncode(updatedUserPoints));

    await _loadGroupData();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Submitted successfully. +${challenge.points} points awarded.',
        ),
      ),
    );
  }

  Future<void> _showEditChallengeDialog(int index) async {
    if (index < 0 || index >= _challenges.length) {
      return;
    }

    final challenge = _challenges[index];
    final titleController = TextEditingController(text: challenge.title);
    final pointsController = TextEditingController(
      text: challenge.points.toString(),
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Edit challenge'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(hintText: 'Challenge name'),
              cursorColor: Colors.black,
              style: const TextStyle(color: Colors.black),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pointsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'Points per submission',
              ),
              cursorColor: Colors.black,
              style: const TextStyle(color: Colors.black),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(foregroundColor: Colors.black),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = titleController.text.trim();
              final points = int.tryParse(pointsController.text.trim()) ?? 0;
              if (text.isNotEmpty && points > 0) {
                Navigator.of(ctx).pop(true);
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.black),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      final updatedChallenge = ChallengeEntry(
        title: titleController.text.trim(),
        points: int.parse(pointsController.text.trim()),
        completedDates: challenge.completedDates,
      );
      await _updateChallengeAt(index, updatedChallenge);
    }
  }

  Future<void> _showMembersDialog() async {
    final emailController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        List<String> dialogMembers = List<String>.from(_members);

        Future<void> saveMembers() async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setStringList(_membersKey(), dialogMembers);
          await _loadGroupData();
        }

        void addMember(void Function(void Function()) setDialogState) {
          final email = emailController.text.trim();
          if (email.isEmpty || !email.contains('@')) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please enter a valid email address'),
              ),
            );
            return;
          }

          if (dialogMembers.contains(email)) {
            emailController.clear();
            return;
          }

          dialogMembers = [...dialogMembers, email];
          emailController.clear();
          setDialogState(() {});
          saveMembers();
        }

        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: Colors.white,
            title: const Text('Group users'),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      hintText: 'Invite user by email',
                    ),
                    cursorColor: Colors.black,
                    style: const TextStyle(color: Colors.black),
                    onSubmitted: (_) => addMember(setDialogState),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      dialogMembers.isEmpty
                          ? 'No users in this group yet.'
                          : 'Current users',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 220,
                    child: dialogMembers.isEmpty
                        ? const Center(child: Text('Invite someone to start.'))
                        : ListView.separated(
                            itemCount: dialogMembers.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 12),
                            itemBuilder: (_, memberIndex) {
                              final member = dialogMembers[memberIndex];
                              return Row(
                                children: [
                                  Expanded(child: Text(member)),
                                  IconButton(
                                    onPressed: () {
                                      dialogMembers = [...dialogMembers]
                                        ..removeAt(memberIndex);
                                      setDialogState(() {});
                                      saveMembers();
                                    },
                                    icon: const Icon(
                                      Icons.remove_circle,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                style: TextButton.styleFrom(foregroundColor: Colors.black),
                child: const Text('Close'),
              ),
              ElevatedButton(
                onPressed: () => addMember(setDialogState),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Invite'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showCreateChallengeDialog() async {
    final titleController = TextEditingController();
    final pointsController = TextEditingController(text: '1');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Create challenge'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(hintText: 'Challenge name'),
              cursorColor: Colors.black,
              style: const TextStyle(color: Colors.black),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pointsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'Points per submission',
              ),
              cursorColor: Colors.black,
              style: const TextStyle(color: Colors.black),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(foregroundColor: Colors.black),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = titleController.text.trim();
              final points = int.tryParse(pointsController.text.trim()) ?? 0;
              if (text.isNotEmpty && points > 0) Navigator.of(ctx).pop(true);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.black),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result == true) {
      final points = int.parse(pointsController.text.trim());
      await _addChallenge(titleController.text.trim(), points);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(
        title: Text(widget.groupName),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Group users',
            onPressed: _showMembersDialog,
            icon: const Icon(Icons.groups_2, color: Colors.black),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Leaderboard',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Text('Total points earned: $_groupPoints'),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Challenges',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: Colors.white),
                  ),
                  ElevatedButton(
                    onPressed: _showCreateChallengeDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Create'),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_challenges.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: const Text(
                    'No challenges yet. Create one to get started.',
                  ),
                )
              else
                Column(
                  children: _challenges.asMap().entries.map((entry) {
                    final index = entry.key;
                    final c = entry.value;
                    final isCompletedToday = c.completedOn(_todayKey());
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c.title,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${c.points} points per day',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            children: [
                              IconButton(
                                onPressed: () =>
                                    _showEditChallengeDialog(index),
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.black,
                                ),
                                tooltip: 'Edit challenge',
                              ),
                              ElevatedButton(
                                onPressed: isCompletedToday
                                    ? null
                                    : () => _submitChallenge(index),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  foregroundColor: Colors.white,
                                ),
                                child: Text(
                                  isCompletedToday ? 'Done today' : 'Submit',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
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
