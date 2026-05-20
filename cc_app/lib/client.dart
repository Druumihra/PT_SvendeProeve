import 'dart:convert';
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
  final String apiUrl = "";
  final FirebaseAuth _auth = FirebaseAuth.instance;
  /*

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
