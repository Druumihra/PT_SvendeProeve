import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class User {
  String id;
  String username;

  User.fromJson(Map<String, dynamic> obj)
    : id = obj["id"],
      username = obj["username"];
}

class Client {
  final String apiUrl = "http://localhost:4001";
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // User endpoints
  Future<String> login(String username, String password) async {
    final body = json.encode({"username": username, "password": password});

    final res = await http.post(
      Uri.parse("$apiUrl/login"),
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

  Future<String> register(String username, String password) async {
    final body = json.encode({"username": username, "password": password});

    final res = await http.post(
      Uri.parse("$apiUrl/createUser"),
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

  // Group endpoints
  Future<String> createGroup(String groupName, List<String> emails) async {
    final body = json.encode({
      "name": groupName,
      "members": emails,
      "admin": _auth.currentUser?.email ?? "",
    });

    final res = await http.post(
      Uri.parse("$apiUrl/group/create"),
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
    String description,
    int groupId,
  ) async {
    final body = json.encode({
      "name": challengeName,
      "description": description,
      "groupsId": groupId,
    });

    final res = await http.post(
      Uri.parse("$apiUrl/challenge/create"),
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
