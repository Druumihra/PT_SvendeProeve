import 'dart:convert';

import 'package:cc_app/app_flushbar.dart';
import 'package:cc_app/client.dart';
import 'package:cc_app/pages/groups.dart';
import 'package:cc_app/pages/search_for_friends.dart';
import 'package:cc_app/pages/user.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _friendGroupsStorageKey = 'friend_groups';
const String _myGroupsStorageKey = 'my_groups';
const String _selectedGroupStorageKey = 'selected_group';
const String _challengesPrefix = 'challenges_';
const String _pointsPrefix = 'challenge_points_';
const String _membersPrefix = 'group_members_';
const String _userPointsPrefix = 'user_points_';

String _sanitizeKey(String groupName) =>
    groupName.replaceAll(RegExp(r"[^a-zA-Z0-9_]"), '_');

String _dateKey(DateTime date) => DateUtils.dateOnly(date).toIso8601String();

String _currentMemberLabel() {
  final user = FirebaseAuth.instance.currentUser;
  return user?.displayName ?? token?["user"] ?? 'You';
}

class _ChallengeSnapshot {
  final String title;
  final int points;
  final Set<String> completedDates;

  const _ChallengeSnapshot({
    required this.title,
    required this.points,
    required this.completedDates,
  });

  factory _ChallengeSnapshot.fromStoredValue(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic>) {
        final rawDates = decoded['completedDates'];
        return _ChallengeSnapshot(
          title:
              (decoded['title'] ?? decoded['name'])?.toString() ??
              'Untitled challenge',
          points:
              int.tryParse(
                (decoded['points'] ?? decoded['score'])?.toString() ?? '',
              ) ??
              0,
          completedDates: rawDates is List
              ? rawDates.map((date) => date.toString()).toSet()
              : <String>{},
        );
      }
    } catch (_) {}

    return _ChallengeSnapshot(
      title: value,
      points: 1,
      completedDates: const <String>{},
    );
  }
}

class HomePage extends StatefulWidget {
  final String? successMessage;

  const HomePage({super.key, this.successMessage});
  final Color barColor = Colors.black;
  final Color touchedBarColor = Colors.green;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  bool _isLoading = true;
  String? _selectedGroup;
  List<_ChallengeSnapshot> _challenges = const [];
  List<String> _myGroups = const [];
  List<MapEntry<String, int>> _leaderboardEntries = const [];
  List<FlSpot> _weeklySpots = const [];
  List<DateTime> _weekDates = const [];
  int _groupPoints = 0;
  int touchedIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadHomeData();
    _loadFriendGroups();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.successMessage != null) {
        AppFlushbar.success(context, widget.successMessage!);
      }
    });
  }

  Future<void> _loadFriendGroups() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dynamic rawResponse = await Client.myGroups(token!["id"]);

      final List<dynamic> rawGroups = rawResponse is List
          ? rawResponse
          : [rawResponse];
      final List<String> parsedNames = [];
      final prefs = await SharedPreferences.getInstance();

      for (var item in rawGroups) {
        if (item == null) continue;

        final Map<String, dynamic> groupData =
            item['group'] is Map<String, dynamic>
            ? item['group']
            : (item is Map<String, dynamic> ? item : {});

        final String name = groupData['name']?.toString() ?? '';

        if (name.isNotEmpty) {
          parsedNames.add(name);

          if (groupData['challenges'] is List) {
            final List<dynamic> backendChallenges = groupData['challenges'];
            final List<String> serializedChallenges = backendChallenges
                .map((challenge) => jsonEncode(challenge))
                .toList();

            final key = _sanitizeKey(name);
            await prefs.setStringList(
              '$_challengesPrefix$key',
              serializedChallenges,
            );
          }
        }
      }

      await prefs.setStringList(_myGroupsStorageKey, parsedNames);

      if (!mounted) return;

      setState(() {
        _myGroups = parsedNames;
      });

      await _loadHomeData();
    } catch (e) {
      debugPrint("Error parsing backend groups payload: $e");
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _setSelectedIndex(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _loadHomeData() async {
    final prefs = await SharedPreferences.getInstance();
    final myGroups = prefs.getStringList(_myGroupsStorageKey) ?? const [];
    final friendGroups =
        prefs.getStringList(_friendGroupsStorageKey) ?? const [];

    final groups = <String>[
      ...myGroups,
      ...friendGroups.where((group) => !myGroups.contains(group)),
    ];

    String? selectedGroup = prefs.getString(_selectedGroupStorageKey);
    if (selectedGroup != null && !groups.contains(selectedGroup)) {
      selectedGroup = null;
      await prefs.remove(_selectedGroupStorageKey);
    }
    if (selectedGroup == null && groups.isNotEmpty) {
      selectedGroup = groups.first;
      await prefs.setString(_selectedGroupStorageKey, selectedGroup);
    }

    if (selectedGroup == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedGroup = null;
        _challenges = const [];
        _myGroups = const [];
        _groupPoints = 0;
        _weekDates = List<DateTime>.generate(
          7,
          (index) => DateUtils.dateOnly(
            DateTime.now().subtract(Duration(days: 6 - index)),
          ),
        );
        _weeklySpots = List<FlSpot>.generate(
          7,
          (index) => FlSpot(index.toDouble(), 0),
        );
        _isLoading = false;
      });
      return;
    }
    final key = _sanitizeKey(selectedGroup);
    final storedChallenges =
        prefs.getStringList('$_challengesPrefix$key') ?? [];
    final challenges = storedChallenges
        .map(_ChallengeSnapshot.fromStoredValue)
        .toList();
    final members = prefs.getStringList('$_membersPrefix$key') ?? const [];
    final groupPoints = prefs.getInt('$_pointsPrefix$key') ?? 0;
    final currentMember = _currentMemberLabel();
    final userPoints = _readUserPoints(
      prefs.getString('$_userPointsPrefix$key'),
    );
    if (userPoints.containsKey('You') &&
        !userPoints.containsKey(currentMember)) {
      userPoints[currentMember] = userPoints['You'] ?? 0;
    }

    final participants = <String>{currentMember, ...members};
    final leaderboardEntries =
        participants
            .map(
              (name) => MapEntry(
                name == currentMember ? '$name (You)' : name,
                userPoints[name] ?? 0,
              ),
            )
            .toList()
          ..sort((a, b) {
            final scoreCompare = b.value.compareTo(a.value);
            if (scoreCompare != 0) {
              return scoreCompare;
            }
            return a.key.toLowerCase().compareTo(b.key.toLowerCase());
          });

    final today = DateTime.now();
    final weekDates = List<DateTime>.generate(
      7,
      (index) => DateUtils.dateOnly(today.subtract(Duration(days: 6 - index))),
    );

    final spots = List<FlSpot>.generate(7, (index) {
      final dayKey = _dateKey(weekDates[index]);
      final dayTotal = challenges
          .where((challenge) => challenge.completedDates.contains(dayKey))
          .fold<int>(0, (sum, challenge) => sum + challenge.points);
      return FlSpot(index.toDouble(), dayTotal.toDouble());
    });

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedGroup = selectedGroup;
      _challenges = challenges;
      _myGroups = myGroups;
      _leaderboardEntries = leaderboardEntries;
      _groupPoints = groupPoints;
      _weekDates = weekDates;
      _weeklySpots = spots;
      _isLoading = false;
    });
  }

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

  String _weekdayLongLabel(DateTime date) {
    return switch (date.weekday) {
      DateTime.monday => 'Monday',
      DateTime.tuesday => 'Tuesday',
      DateTime.wednesday => 'Wednesday',
      DateTime.thursday => 'Thursday',
      DateTime.friday => 'Friday',
      DateTime.saturday => 'Saturday',
      DateTime.sunday => 'Sunday',
      _ => '',
    };
  }

  String _weekdayShortLabel(DateTime date) {
    return switch (date.weekday) {
      DateTime.monday => 'M',
      DateTime.tuesday => 'T',
      DateTime.wednesday => 'W',
      DateTime.thursday => 'T',
      DateTime.friday => 'F',
      DateTime.saturday => 'S',
      DateTime.sunday => 'S',
      _ => '',
    };
  }

  Future<void> _showGroupSelectionDialog() async {
    final groups = _myGroups;
    debugPrint("2" + groups.toString());

    if (!mounted) {
      return;
    }

    if (groups.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Choose a group'),
          content: const Text('You are not part of any groups yet.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: TextButton.styleFrom(foregroundColor: Colors.black),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final selectedGroup = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Choose a group'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var index = 0; index < groups.length; index++) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.groups),
                    title: Text(groups[index]),
                    onTap: () => Navigator.of(dialogContext).pop(groups[index]),
                  ),
                  if (index < groups.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: TextButton.styleFrom(foregroundColor: Colors.black),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (!mounted || selectedGroup == null) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedGroupStorageKey, selectedGroup);
    await _loadHomeData();

    if (!mounted) {
      return;
    }

    AppFlushbar.success(context, 'Selected group: $selectedGroup');
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

  double getTotalPoints() {
    return _weeklySpots.fold<double>(0, (sum, spot) => sum + spot.y);
  }

  LineChartData mainLineData() {
    final spots = _weeklySpots;
    final maxSpot = spots.fold<double>(0, (max, spot) {
      return spot.y > max ? spot.y : max;
    });
    return LineChartData(
      lineTouchData: LineTouchData(
        enabled: true,
        touchTooltipData: LineTouchTooltipData(
          fitInsideHorizontally: true,
          fitInsideVertically: true,
          tooltipPadding: const EdgeInsets.all(8),
          getTooltipItems: (touchedSpots) => touchedSpots.map((t) {
            final index = t.x.toInt();
            final day = index >= 0 && index < _weekDates.length
                ? _weekdayLongLabel(_weekDates[index])
                : '';
            return LineTooltipItem(
              '$day\n',
              const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
              children: [
                TextSpan(
                  text: t.y.toStringAsFixed(1),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
        touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
          setState(() {
            if (!event.isInterestedForInteractions ||
                response == null ||
                response.lineBarSpots == null ||
                response.lineBarSpots!.isEmpty) {
              touchedIndex = -1;
              return;
            }
            touchedIndex = response.lineBarSpots!.first.spotIndex;
          });
        },
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 1,
            getTitlesWidget: getTitles,
            reservedSize: 38,
          ),
        ),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      gridData: const FlGridData(show: false),
      minY: 0,
      maxY: (maxSpot + 2).clamp(6, 100),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: false,
          color: widget.barColor,
          barWidth: 3,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) {
              final isTouched = index == touchedIndex;
              return FlDotCirclePainter(
                radius: isTouched ? 6 : 3,
                color: isTouched ? widget.touchedBarColor : widget.barColor,
                strokeWidth: 0,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget getTitles(double value, TitleMeta meta) {
    const style = TextStyle(
      color: Colors.black,
      fontWeight: FontWeight.bold,
      fontSize: 14,
    );
    if (value != value.roundToDouble()) {
      return const SizedBox.shrink();
    }

    final index = value.toInt();
    final text = index >= 0 && index < _weekDates.length
        ? _weekdayShortLabel(_weekDates[index])
        : '';
    return SideTitleWidget(
      meta: meta,
      space: 16,
      child: Text(text, style: style),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupName = _selectedGroup;

    return Scaffold(
      backgroundColor: Colors.black87,
      body: SingleChildScrollView(
        child: Align(
          alignment: Alignment.topCenter,
          child: Column(
            children: [
              const SizedBox(height: 30),
              SizedBox(
                width: 350,
                height: 215,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(25),
                  child: Container(
                    color: Colors.white,
                    alignment: Alignment.topCenter,
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            groupName == null
                                ? 'No group selected'
                                : 'Group: $_selectedGroup',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: SizedBox(
                            width: double.infinity,
                            child: _isLoading
                                ? const Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.black,
                                    ),
                                  )
                                : LineChart(
                                    mainLineData(),
                                    duration: const Duration(milliseconds: 150),
                                    curve: Curves.linear,
                                  ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.bottomLeft,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Points this week:',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color: Colors.black,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    child: Text(
                                      getTotalPoints().round() == 1
                                          ? '${getTotalPoints().toStringAsFixed(0)} Point'
                                          : '${getTotalPoints().toStringAsFixed(0)} Points',
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              IconButton(
                                onPressed: _showGroupSelectionDialog,
                                icon: const Icon(Icons.repeat),
                                style: IconButton.styleFrom(
                                  overlayColor: Colors.black.withValues(
                                    alpha: 0.1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: 350,
                height: 200,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(25),
                  child: Container(
                    color: Colors.white,
                    alignment: Alignment.topCenter,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text(
                          'Challenges',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 12),
                        if (_isLoading)
                          const Expanded(
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Colors.black,
                              ),
                            ),
                          )
                        else if (groupName == null)
                          Expanded(
                            child: Center(
                              child: Text(
                                'Select a group to view challenges.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: Colors.black),
                              ),
                            ),
                          )
                        else if (_challenges.isEmpty)
                          Expanded(
                            child: Center(
                              child: Text(
                                'No active challenges in this group yet.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: Colors.black),
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: ListView.separated(
                              itemCount: _challenges.length > 4
                                  ? 4
                                  : _challenges.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (_, index) {
                                final challenge = _challenges[index];
                                return Row(
                                  children: [
                                    const Icon(
                                      Icons.flag_outlined,
                                      size: 18,
                                      color: Colors.black87,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        challenge.title,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text('${challenge.points} pts'),
                                  ],
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: 350,
                height: 325,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(25),
                  child: Container(
                    color: Colors.white,
                    alignment: Alignment.topCenter,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text(
                          'Leaderboard',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 12),
                        if (_isLoading)
                          const Expanded(
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Colors.black,
                              ),
                            ),
                          )
                        else if (groupName == null)
                          Expanded(
                            child: Center(
                              child: Text(
                                'Select a group to view leaderboard data.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: Colors.black),
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: Column(
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Deserting users in this group',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleSmall,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Expanded(
                                  child: ListView.separated(
                                    itemCount: _leaderboardEntries.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 8),
                                    itemBuilder: (_, index) {
                                      final entry = _leaderboardEntries[index];
                                      final isTop = index == 0;
                                      return Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: isTop
                                              ? Colors.black.withValues(
                                                  alpha: 0.08,
                                                )
                                              : Colors.black.withValues(
                                                  alpha: 0.04,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Text(
                                              '#${index + 1}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                entry.key,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Text('${entry.value} pts'),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    'Group total: $_groupPoints pts',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: Colors.black),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
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
