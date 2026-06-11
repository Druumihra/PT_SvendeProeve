import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
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
  static final String authUrl = "http://localhost:4000";
  static final String apiUrl = "http://localhost:4001";
  final FirebaseAuth _auth = FirebaseAuth.instance;
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

    if (res.statusCode == 200) {
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
        "bearer": "session=$encodedToken",
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
        "bearer": "session=$encodedToken",
      },
      body: body,
    );

    final message = json.decode(res.body);

    if (res.statusCode == 200) {
      return message;
    } else {
      throw Exception(message["message"]);
    }
  }

  static Future<List> myGroups(int userId) async {
    final res = await http.get(
      Uri.parse("$apiUrl/group/getgroups/$userId"),
      headers: {"Content-Type": "application/json"},
    );

    final message = json.decode(res.body);

    if (res.statusCode == 200) {
      return message['groups'] as List;
    } else {
      throw Exception(message["message"] ?? "Failed to load groups");
    }
  }

  Future<List> getMembersFromGroup(int groupId) async {
    final res = await http.get(
      Uri.parse("$apiUrl/group/{$groupId}/getMembers"),
      headers: {"Content-Type": "application/json"},
    );

    final resData = json.decode(res.body);

    if (resData["ok"]) {
      return resData["token"];
    } else {
      throw Exception(resData["message"]);
    }
  }

  Future<String> addUsersToGroup(
    String groupName,
    List<String> emails,
    int groupId,
  ) async {
    final body = json.encode({
      "members": emails, // List of emails to add
    });

    final res = await http.post(
      Uri.parse("$apiUrl/group/{$groupId}/addUsers"),
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
      (group) => group["name"] == groupName,
      orElse: () => null,
    );

    if (matchingGroup == null) {
      throw Exception("Group '$groupName' not found.");
    }

    final int groupId = matchingGroup["id"];
    String description = "No description provided";

    final body = json.encode({
      "challengeName": challengeName,
      "challengeDescription": description,
      "score": score,
      "groupId": groupId,
    });

    final res = await http.post(
      Uri.parse("$apiUrl/challenge/create"),
      headers: {"Content-Type": "application/json"},
      body: body,
    );
    debugPrint("dd" + res.toString());

    final message = json.decode(res.body);

    debugPrint(message.toString());

    if (res.statusCode == 200) {
      debugPrint("Challenge created successfully");
      return message["message"].toString();
    } else {
      throw Exception(message["message"].toString());
    }
  }

  Future<String> getChallengesFromGroup(int groupId) async {
    final res = await http.get(
      Uri.parse("$apiUrl/challenges/{$groupId}/getAll"),
      headers: {"Content-Type": "application/json"},
    );

    final resData = json.decode(res.body);

    if (resData["ok"]) {
      return resData["token"];
    } else {
      throw Exception(resData["message"]);
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
    final res = await http.post(
      Uri.parse("$apiUrl/user/findUsers/${query}"),
      headers: {"Content-Type": "application/json"},
    );

    if (res.statusCode == 200) {
      return json.decode(res.body) as List<dynamic>;
    } else {
      final message = json.decode(res.body);
      throw Exception(message["message"]);
    }
  }

  static Future<List<dynamic>> getFriends(int id, int userId) async {
    final body = json.encode({"id": id, "userId": userId});

    debugPrint(body.toString());

    final res = await http.post(
      Uri.parse("$apiUrl/user/getFriends"),
      headers: {"Content-Type": "application/json"},
      body: body,
    );

    final message = json.decode(res.body);

    debugPrint(message.toString());

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
