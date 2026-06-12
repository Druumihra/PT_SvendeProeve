import 'dart:convert';

import 'package:cc_app/app_flushbar.dart';
import 'package:cc_app/client.dart';
import 'package:cc_app/pages/groups.dart';
import 'package:cc_app/pages/home.dart';
import 'package:cc_app/pages/search_for_friends.dart';
import 'package:cc_app/pages/user.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

class VoteEntry {
  final String title;
  final String suggestedBy;
  final Map<String, bool> votesByMember;

  VoteEntry({
    required this.title,
    required this.suggestedBy,
    Map<String, bool>? votesByMember,
  }) : votesByMember = votesByMember ?? <String, bool>{};

  factory VoteEntry.fromStoredValue(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic>) {
        final rawVotes = decoded['votes'];
        final legacyVoters = decoded['voters'];
        final votesByMember = <String, bool>{};

        if (rawVotes is Map) {
          for (final entry in rawVotes.entries) {
            final key = entry.key.toString();
            final val = entry.value;
            if (val is bool) {
              votesByMember[key] = val;
            } else {
              final s = val.toString().trim().toLowerCase();
              votesByMember[key] = s == 'no' ? false : true;
            }
          }
        } else if (legacyVoters is List) {
          for (final voter in legacyVoters) {
            votesByMember[voter.toString()] = true;
          }
        }

        return VoteEntry(
          title: decoded['title']?.toString() ?? 'Untitled vote',
          suggestedBy: decoded['suggestedBy']?.toString() ?? 'Unknown',
          votesByMember: votesByMember,
        );
      }
    } catch (_) {}

    return VoteEntry(title: value, suggestedBy: 'Unknown');
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'suggestedBy': suggestedBy,
    'votes': votesByMember.map((k, v) => MapEntry(k, v)),
    'voters': votesByMember.entries
        .where((entry) => entry.value == true)
        .map((entry) => entry.key)
        .toList(),
  };

  String toStoredValue() => jsonEncode(toJson());

  bool? voteFor(String who) => votesByMember[who];

  bool hasVoted(String who) => votesByMember.containsKey(who);

  int get yesCount => votesByMember.values.where((v) => v == true).length;

  int get noCount => votesByMember.values.where((v) => v == false).length;
}

class GroupDetailPage extends StatefulWidget {
  final String groupName;
  final int groupId;
  const GroupDetailPage({
    super.key,
    required this.groupName,
    required this.groupId,
  });

  @override
  State<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<GroupDetailPage> {
  int _selectedIndex = 1;
  bool _isLoading = true;
  int _groupPoints = 0;
  List<ChallengeEntry> _challenges = [];
  List<dynamic> _members = [];
  List<VoteEntry> _votes = [];

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

  String _currentMemberLabel() {
    final user = FirebaseAuth.instance.currentUser;
    return user?.displayName ?? 'You';
  }

  List<String> _voteParticipants() {
    final memberNames = _members.map((m) {
      final memberData = m['member'] as Map<String, dynamic>?;
      return memberData?['name']?.toString() ?? 'Unknown';
    }).toList();

    final participants = <String>{...memberNames, _currentMemberLabel()};
    final ordered = participants.toList();
    ordered.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return ordered;
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

  Future<void> _loadGroupData() async {
    setState(() => _isLoading = true);
    try {
      final members = await Client.getGroupMembers(widget.groupId);

      final String rawChallengesString = await Client().getChallengesFromGroup(
        widget.groupId,
      );

      List<ChallengeEntry> parsedChallenges = [];

      try {
        final decodedBody = jsonDecode(rawChallengesString);
        List<dynamic> rawList = [];

        if (decodedBody is Map && decodedBody['challenges'] is List) {
          rawList = decodedBody['challenges'];
        }

        parsedChallenges = rawList.map((item) {
          final normalizedItem = {
            ...item,
            'title': item['name'],
            'points': item['score'],
          };

          return ChallengeEntry.fromStoredValue(jsonEncode(normalizedItem));
        }).toList();
      } catch (parseError) {
        debugPrint("Error formatting challenge items: $parseError");
      }

      if (!mounted) return;
      setState(() {
        _members = members;
        _challenges = parsedChallenges;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppFlushbar.error(context, 'Failed to sync group data: $error');
    }
  }

  Future<void> _addChallenge(String title, int points) async {
    await _loadGroupData();
  }

  Future<void> _addVote(String title) async {
    await _loadGroupData();
  }

  Future<void> _setVoteAt(int index, String member, bool vote) async {
    if (index < 0 || index >= _votes.length) return;
    final prefs = await SharedPreferences.getInstance();
    final current = _votes[index];
    final updatedVotes = Map<String, bool>.from(current.votesByMember);
    updatedVotes[member] = vote;

    final updated = VoteEntry(
      title: current.title,
      suggestedBy: current.suggestedBy,
      votesByMember: updatedVotes,
    );

    await _loadGroupData();
  }

  Future<void> _showCreateVoteDialog() async {
    final titleController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Create challenge vote'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                hintText: 'Suggested challenge',
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
              if (text.isNotEmpty) Navigator.of(ctx).pop(true);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.black),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _addVote(titleController.text.trim());
    }
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

    await _loadGroupData();

    if (!mounted) return;
    AppFlushbar.success(
      context,
      'Challenge submitted! +${challenge.points} points awarded.',
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
    }
  }

  Future<void> _showMembersDialog() async {
    final Future<List<dynamic>> friendsFuture = Client.getFriends(token?["id"]);
    final Set<String> checkedUserIds = {};

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        List<dynamic> dialogMembers = List<dynamic>.from(_members);

        Future<void> saveMembers() async {
          await _loadGroupData();
        }

        Future<void> inviteCheckedMembers(
          void Function(void Function()) setDialogState,
        ) async {
          if (checkedUserIds.isEmpty) {
            if (context.mounted) {
              AppFlushbar.error(
                context,
                'Please check at least one friend to invite.',
              );
            }
            return;
          }
          try {
            for (String userId in checkedUserIds) {
              final int? parsedUserId = int.tryParse(userId);
              final message = await Client().inviteUserToGroup(
                token?["id"],
                parsedUserId!,
                widget.groupId,
              );
              debugPrint('Invite response for user $userId: $message');
              if (context.mounted) {
                AppFlushbar.success(context, message);
              }
            }

            setDialogState(() {
              checkedUserIds.clear();
            });

            await saveMembers();
          } catch (error) {
            if (context.mounted) {
              AppFlushbar.error(context, error.toString());
            }
          }
        }

        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: Colors.white,
            title: const Text(
              'Group Management',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SizedBox(
              width: 360,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select friends to invite',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 150,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: FutureBuilder<List<dynamic>>(
                        future: friendsFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(
                                color: Colors.black,
                              ),
                            );
                          }
                          if (snapshot.hasError ||
                              !snapshot.hasData ||
                              snapshot.data!.isEmpty) {
                            return const Center(
                              child: Text(
                                'No friends found.',
                                style: TextStyle(color: Colors.black54),
                              ),
                            );
                          }

                          final allFriends = snapshot.data!;

                          final Set<String> currentMemberIds = _members.map((
                            m,
                          ) {
                            final memberData =
                                m['member'] as Map<String, dynamic>?;
                            return memberData?['id']?.toString() ?? '';
                          }).toSet();

                          final inviteableFriends = allFriends.where((friend) {
                            final friendData =
                                friend['friendof'] as Map<String, dynamic>?;
                            final String friendId =
                                friendData?['id']?.toString() ?? '';
                            return !currentMemberIds.contains(friendId);
                          }).toList();

                          if (inviteableFriends.isEmpty) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  'All your friends are already in this group!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.black54,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            );
                          }

                          return ListView.builder(
                            itemCount: inviteableFriends.length,
                            itemBuilder: (context, index) {
                              final friend = inviteableFriends[index];
                              final String friendId = friend['friendof']!['id']
                                  .toString();
                              final String friendName =
                                  friend['friendof']!['name'].toString();
                              final isChecked = checkedUserIds.contains(
                                friendId,
                              );

                              return CheckboxListTile(
                                title: Text(
                                  friendName,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 14,
                                  ),
                                ),
                                value: isChecked,
                                activeColor: Colors.black,
                                checkColor: Colors.white,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                dense: true,
                                onChanged: (bool? value) {
                                  setDialogState(() {
                                    if (value == true) {
                                      checkedUserIds.add(friendId);
                                    } else {
                                      checkedUserIds.remove(friendId);
                                    }
                                  });
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 20),
                    Text(
                      dialogMembers.isEmpty
                          ? 'No users in this group yet.'
                          : 'Current Members',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 150,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: dialogMembers.isEmpty
                          ? const Center(
                              child: Text(
                                'Group is currently empty.',
                                style: TextStyle(color: Colors.black54),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              itemCount: dialogMembers.length,
                              separatorBuilder: (_, __) => const Divider(
                                height: 1,
                                color: Colors.black12,
                              ),
                              itemBuilder: (_, memberIndex) {
                                final memberItem = dialogMembers[memberIndex];
                                final memberData =
                                    memberItem['member']
                                        as Map<String, dynamic>?;
                                final String memberName =
                                    memberData?['name']?.toString() ??
                                    'Unknown';
                                return Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        memberName,
                                        style: const TextStyle(
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        dialogMembers = [...dialogMembers]
                                          ..removeAt(memberIndex);
                                        setDialogState(() {});
                                        saveMembers();
                                      },
                                      icon: const Icon(
                                        Icons.remove_circle,
                                        color: Colors.black87,
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
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                style: TextButton.styleFrom(foregroundColor: Colors.black),
                child: const Text('Close'),
              ),
              ElevatedButton(
                onPressed: () => inviteCheckedMembers(setDialogState),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Invite checked'),
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
            onPressed: () async {
              final message = await Client().createChallenge(
                titleController.text.trim(),
                int.tryParse(pointsController.text.trim()) ?? 0,
                widget.groupName,
              );

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

  Widget _buildVoteChoiceButton({
    required int index,
    required String member,
    required bool vote,
    required String label,
    required bool? currentVote,
  }) {
    final isSelected = currentVote == vote;

    return ElevatedButton(
      onPressed: () => _setVoteAt(index, member, vote),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.black : Colors.white,
        foregroundColor: isSelected ? Colors.white : Colors.black,
        side: const BorderSide(color: Colors.black12),
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      child: Text(label),
    );
  }

  Widget _buildVoteStatusChip(bool? vote) {
    final text = vote == null ? 'Not voted' : (vote ? 'Yes' : 'No');
    final color = vote == null
        ? Colors.grey.shade200
        : (vote ? Colors.green.shade100 : Colors.red.shade100);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: const TextStyle(color: Colors.black87)),
    );
  }

  Widget _buildChallengesSection() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: CircularProgressIndicator(color: Colors.black),
        ),
      );
    }

    if (_challenges.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.black12),
        ),
        child: const Text('No active challenges.'),
      );
    }

    final today = _todayKey();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _challenges.length,
      itemBuilder: (context, index) {
        final challenge = _challenges[index];
        final bool isCompletedToday = challenge.completedOn(today);

        return Card(
          color: Colors.white,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          elevation: 0.5,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            title: Text(
              challenge.title,
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w600,
                decoration: isCompletedToday
                    ? TextDecoration.lineThrough
                    : null,
              ),
            ),
            subtitle: Text(
              '${challenge.points} Points',
              style: TextStyle(
                color: isCompletedToday ? Colors.green : Colors.black54,
                fontSize: 13,
                fontWeight: isCompletedToday
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: Colors.black38,
                    size: 20,
                  ),
                  onPressed: () => _showEditChallengeDialog(index),
                ),
                IconButton(
                  icon: Icon(
                    isCompletedToday
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: isCompletedToday ? Colors.green : Colors.black87,
                    size: 26,
                  ),
                  onPressed: () => _submitChallenge(index),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentMember = _currentMemberLabel();
    final voteParticipants = _voteParticipants();

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
                    'Votes',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: Colors.white),
                  ),
                  ElevatedButton(
                    onPressed: _showCreateVoteDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Create vote'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_isLoading)
                const SizedBox.shrink()
              else if (_votes.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: const Text('No active votes.'),
                )
              else
                Column(
                  children: _votes.asMap().entries.map((entry) {
                    final index = entry.key;
                    final v = entry.value;
                    final pendingCount = voteParticipants
                        .where((member) => !v.hasVoted(member))
                        .length;
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      v.title,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyLarge,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Suggested by ${v.suggestedBy} • ${v.yesCount} yes / ${v.noCount} no / $pendingCount pending',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Vote breakdown',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 8),
                              ...voteParticipants.map((member) {
                                final memberVote = v.voteFor(member);
                                final isCurrentMember = member == currentMember;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          isCurrentMember
                                              ? '$member (You)'
                                              : member,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      if (isCurrentMember)
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            _buildVoteChoiceButton(
                                              index: index,
                                              member: member,
                                              vote: true,
                                              label: 'Yes',
                                              currentVote: memberVote,
                                            ),
                                            _buildVoteChoiceButton(
                                              index: index,
                                              member: member,
                                              vote: false,
                                              label: 'No',
                                              currentVote: memberVote,
                                            ),
                                          ],
                                        )
                                      else
                                        _buildVoteStatusChip(memberVote),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
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
                    child: const Text('Create challenge'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildChallengesSection(),
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
