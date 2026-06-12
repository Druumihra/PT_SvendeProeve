import 'package:flutter/material.dart';
import 'package:cc_app/client.dart';
import 'package:cc_app/prefs.dart';

class UserController extends ChangeNotifier {
  final Prefs prefs;
  final Client client;
  String username = "";
  String? email;
  String? token;
  List<dynamic> myGroups = [];

  UserController({
    required this.prefs,
    required this.client,
    required this.token,
    required this.username,
    this.email,
  }) {
    _loadFromPrefs();
  }

  void _loadFromPrefs() async {
    final savedToken = await prefs.getToken();
    if (savedToken == null) {
      return;
    }
    token = savedToken;
    notifyListeners();
  }

  Future<String> login(String username, String password) async {
    final res = await client.login(username, password);

    token = res.split("token: ").last.split("}").first;

    String message = res
        .split("message: ")
        .last
        .split("}")
        .first
        .split(",")
        .first;

    return message;
  }

  Future<void> logout() async {
    if (token != null) {
      await client.logout(token!);
    }

    token = null;
    username = "";
    email = null;
    myGroups = [];

    notifyListeners();
  }
}
