import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';

class User {
  String id;
  String username;
  String? email;
  String? pfpUrl;

  User.fromJson(Map<String, dynamic> obj)
    : id = obj["id"].toString(),
      username = obj["user"],
      email = obj["email"],
      pfpUrl = obj["profilepicture"];
}

Map<String, dynamic> decodeToken(String token) {
  final decodedToken = JwtDecoder.decode(token);

  return Map<String, dynamic>.from(decodedToken["data"]);
}

String? encodedToken;
Map<String, dynamic>? token;

class Client {
  static final String authUrl = "http://157.180.66.30:4000";
  static final String apiUrl = "http://157.180.66.30:4001";
  String? pfpUrl;

  // User endpoints
  Future<String> login(String username, String password) async {
    final body = json.encode({"username": username, "password": password});

    final res = await http.post(
      Uri.parse("$authUrl/login"),
      headers: {"Content-Type": "application/json"},
      body: body,
    );

    final message = json.decode(res.body);

    if (res.statusCode == 200) {
      encodedToken = message["token"];
      token = decodeToken(message["token"]) as Map<String, dynamic>?;

      return message.toString();
    } else {
      throw message.toString();
    }
  }

  Future<String> logout(String logoutToken) async {
    final res = await http.post(
      Uri.parse("$authUrl/logout"),
      headers: {"Authorization": "Bearer $logoutToken"},
    );

    final message = json.decode(res.body);
    token = null;
    encodedToken = null;

    return "Logged out successfully";
    /* 
    if (res.statusCode == 200) {
      return message.toString();
    } else {
      throw message;
    }
    */
  }

  Future<String> register(
    String username,
    String email,
    String password,
  ) async {
    final body = json.encode({
      "username": username,
      "password": password,
      "email": email,
    });

    final res = await http.post(
      Uri.parse("$authUrl/createUser"),
      headers: {"Content-Type": "application/json"},
      body: body,
    );

    final message = json.decode(res.body).toString();

    if (res.statusCode == 201) {
      return message;
    } else {
      throw message;
    }
  }

  static Future<String> getUserInfo(int userId) async {
    final res = await http.get(
      Uri.parse("$apiUrl/user/getUser/$userId"),
      headers: {
        "Content-Type": "application/json",
        "include": "credentials",
        "Authorization": "Bearer $encodedToken",
      },
    );

    final message = json.decode(res.body).toString();

    if (res.statusCode == 200) {
      return message;
    } else {
      throw message;
    }
  }

  // Group endpoints
  Future<String> createGroup(String groupName) async {
    final body = json.encode({"groupName": groupName, "userId": token!["id"]});

    final res = await http.post(
      Uri.parse("$apiUrl/group/create"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $encodedToken",
      },
      body: body,
    );

    dynamic decodedData;
    try {
      decodedData = json.decode(res.body);
    } catch (_) {
      decodedData = res.body;
    }

    if (res.statusCode == 200 || res.statusCode == 201) {
      if (decodedData is Map) {
        return decodedData["message"];
      }
      return decodedData.toString();
    } else {
      String errorMessage = "An error occurred while creating the group.";
      throw Exception(errorMessage);
    }
  }

  static Future<List> myGroups(int userId) async {
    debugPrint("Fetching groups for user ID: $userId");
    final res = await http.get(
      Uri.parse("$apiUrl/user/$userId/getgroups"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $encodedToken",
      },
    );
    final message = json.decode(res.body);

    debugPrint("Response status: ${message.toString()}");

    if (res.statusCode == 200) {
      return message as List;
    } else {
      throw Exception(message["message"] ?? "Failed to load groups");
    }
  }

  static Future<List<dynamic>> getGroupMembers(int groupId) async {
    final res = await http.get(
      Uri.parse("$apiUrl/group/$groupId/getMembers"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $encodedToken",
      },
    );

    final message = json.decode(res.body);

    debugPrint("getGroupMembers response: ${message.toString()}");

    if (res.statusCode == 200) {
      if (message is Map<String, dynamic>) {
        return message['members'] as List<dynamic>? ?? [];
      }
      return [];
    } else {
      final String errorMessage = message is Map && message["message"] != null
          ? message["message"].toString()
          : "Failed to load group members";

      throw Exception(errorMessage);
    }
  }

  Future<String> inviteUserToGroup(int adminId, int userId, int groupId) async {
    final body = json.encode({
      "adminId": adminId,
      "userId": userId,
      "groupId": groupId,
    });

    final res = await http.post(
      Uri.parse("$apiUrl/group/$groupId/addUser"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $encodedToken",
      },
      body: body,
    );

    final message = json.decode(res.body);

    debugPrint("test " + message.toString());

    if (res.statusCode == 200) {
      return message.toString();
    } else {
      throw Exception(message.toString());
    }
  }

  Future<String> kickUsersFromGroup(String username, int groupId) async {
    final body = json.encode({"username": username, "groupId": groupId});

    final res = await http.post(
      Uri.parse("$apiUrl/group/{$groupId}/kickUser"),
      headers: {"Content-Type": "application/json"},
      body: body,
    );

    final resData = json.decode(res.body);

    if (resData["ok"]) {
      return resData["token"];
    } else {
      throw Exception(resData["message"]);
    }
  }

  Future<String> deleteGroup(int groupId) async {
    final res = await http.delete(
      Uri.parse("$apiUrl/group/{$groupId}/delete"),
      headers: {"Content-Type": "application/json"},
    );

    final resData = json.decode(res.body);

    if (resData["ok"]) {
      return resData["token"];
    } else {
      throw Exception(resData["message"]);
    }
  }

  // Challenge endpoints
  Future<String> createChallenge(
    String challengeName,
    int score,
    String groupName,
  ) async {
    debugPrint(token.toString());

    final groups = await Client.myGroups(token!["id"]);
    debugPrint(groups.toString());

    final matchingGroup = groups.firstWhere(
      (group) => group['group']["name"] == groupName,
      orElse: () => null,
    );

    if (matchingGroup == null) {
      throw Exception("Group '$groupName' not found.");
    }

    final int groupId = matchingGroup["groupsId"];
    String description = "No description provided";

    final body = json.encode({
      "challengeName": challengeName,
      "description": description,
      "score": score,
      "groupId": groupId,
    });

    final res = await http.post(
      Uri.parse("$apiUrl/challenge/create"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $encodedToken",
      },
      body: body,
    );
    debugPrint("dd" + res.toString());

    final message = json.decode(res.body);

    debugPrint(message.toString());

    if (res.statusCode == 200) {
      debugPrint("Challenge created successfully");
      return message.toString();
    } else {
      throw Exception(message.toString());
    }
  }

  Future<String> getChallengesFromGroup(int groupId) async {
    final res = await http.post(
      Uri.parse("$apiUrl/challenges/$groupId/getAll"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $encodedToken",
      },
    );

    if (res.statusCode == 200) {
      return res.body;
    } else {
      try {
        final message = json.decode(res.body);
        throw Exception(
          message["message"] ?? "Server returned error ${res.statusCode}",
        );
      } catch (_) {
        throw Exception("Failed to load challenges: ${res.statusCode}");
      }
    }
  }

  Future<String> editChallenge(int challengeId) async {
    final body = json.encode({"challengeId": challengeId});

    final res = await http.post(
      Uri.parse("$apiUrl/challenge/{$challengeId}/edit"),
      headers: {"Content-Type": "application/json"},
      body: body,
    );

    final resData = json.decode(res.body);

    if (resData["ok"]) {
      return resData["token"];
    } else {
      throw Exception(resData["message"]);
    }
  }

  Future<String> endChallenge(int challengeId) async {
    final body = json.encode({"challengeId": challengeId});

    final res = await http.post(
      Uri.parse("$apiUrl/challenge/{$challengeId}/end"),
      headers: {"Content-Type": "application/json"},
      body: body,
    );

    final resData = json.decode(res.body);

    if (resData["ok"]) {
      return resData["token"];
    } else {
      throw Exception(resData["message"]);
    }
  }

  Future<String> deleteChallenge(int challengeId) async {
    final res = await http.delete(
      Uri.parse("$apiUrl/challenge/{$challengeId}/delete"),
      headers: {"Content-Type": "application/json"},
    );

    final resData = json.decode(res.body);

    if (resData["ok"]) {
      return resData["token"];
    } else {
      throw Exception(resData["message"]);
    }
  }

  Future<String> submitChallenge(int challengeId) async {
    final body = json.encode({"challengeId": challengeId});

    final res = await http.post(
      Uri.parse("$apiUrl/challenge/{$challengeId}/submit"),
      headers: {"Content-Type": "application/json"},
      body: body,
    );

    final resData = json.decode(res.body);

    if (resData["ok"]) {
      return resData["token"];
    } else {
      throw Exception(resData["message"]);
    }
  }

  Future<String> getPlayerPoints(int challengeId) async {
    final res = await http.get(
      Uri.parse("$apiUrl/challenge/{$challengeId}/getPlayerPoints"),
      headers: {"Content-Type": "application/json"},
    );

    final resData = json.decode(res.body);

    if (resData["ok"]) {
      return resData["token"];
    } else {
      throw Exception(resData["message"]);
    }
  }

  // Friend endpoints
  static Future<List<dynamic>> findUsers(
    String query,
    Map<String, dynamic>? tokenMap,
  ) async {
    final res = await http.get(
      Uri.parse("$apiUrl/user/findUsers/${query}"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $encodedToken",
      },
    );

    if (res.statusCode == 200) {
      return json.decode(res.body) as List<dynamic>;
    } else {
      final message = json.decode(res.body);
      throw Exception(message["message"]);
    }
  }

  static Future<String> sendFriendRequest(int usersId, int friendId) async {
    final body = json.encode({"usersId": usersId, "friendId": friendId});

    final res = await http.post(
      Uri.parse("$apiUrl/user/addFriend"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $encodedToken",
      },
      body: body,
    );

    dynamic message;
    try {
      message = json.decode(res.body);
    } catch (_) {
      message = res.body;
    }

    if (res.statusCode == 200 || res.statusCode == 400) {
      if (message is Map) {
        return message["message"]?.toString() ?? "Success";
      }
      return message.toString();
    } else {
      throw Exception(message["message"].toString());
    }
  }

  static Future<List<dynamic>> getFriendRequests(dynamic id) async {
    final body = json.encode({"id": id});

    final res = await http.post(
      Uri.parse("$apiUrl/user/getFriendRequests"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $encodedToken",
      },
      body: body,
    );

    if (res.statusCode == 200) {
      final message = json.decode(res.body);
      if (message is List) {
        return message;
      } else if (message != null) {
        return [message];
      }
      return [];
    } else {
      throw Exception("Failed to load friend requests");
    }
  }

  static Future<bool> acceptFriendRequest(int userId, int requestId) async {
    final res = await http.put(
      Uri.parse("$apiUrl/user/acceptFriend"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $encodedToken",
      },
      body: json.encode({"userId": requestId, "friendId": userId}),
    );

    return res.statusCode == 200;
  }

  static Future<bool> declineFriendRequest(
    dynamic requestId,
    bool accept,
  ) async {
    final res = await http.post(
      Uri.parse("$apiUrl/user/declineFriend"),
      headers: {"Content-Type": "application/json"},
      body: json.encode({"requestId": requestId}),
    );
    return res.statusCode == 200;
  }

  static Future<String> removeFriend(int userId, int friendId) async {
    final res = await http.delete(
      Uri.parse("$apiUrl/user/removeFriend"),
      headers: {"Content-Type": "application/json"},
      body: json.encode({"userId": userId, "friendId": friendId}),
    );

    final message = json.decode(res.body).toString();

    if (res.statusCode == 200) {
      return message;
    } else {
      throw "deleteFriend failed: $message";
    }
  }

  static Future<List<dynamic>> getFriends(int id) async {
    final body = json.encode({"id": id});

    final res = await http.post(
      Uri.parse("$apiUrl/user/getFriends"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $encodedToken",
      },
      body: body,
    );

    final message = json.decode(res.body);

    if (res.statusCode == 200) {
      if (message is List) {
        return message;
      } else if (message != null) {
        return [message];
      }
      return [];
    } else {
      throw Exception("Failed to load friends list");
    }
  }

  /*
  Future<void> _sendTokenToBackend(String idToken, String email) async {
    try {
      final body = json.encode({"idToken": idToken, "email": email});

      final res = await http.post(
        Uri.parse("$apiUrl/auth/google"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $idToken",
        },
        body: body,
      );

      if (res.statusCode != 200) {
        throw Exception("Backend authentication failed");
      }
    } catch (e) {
      print("Error sending token to backend: $e");
    }
  }

  User? getCurrentUser() {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser != null) {
      return User.fromJson({
        "id": firebaseUser.uid,
        "username": firebaseUser.displayName ?? firebaseUser.email ?? "User",
      });
    }
    return null;
  }

  bool isLoggedIn() {
    return _auth.currentUser != null;
  }

*/
}
