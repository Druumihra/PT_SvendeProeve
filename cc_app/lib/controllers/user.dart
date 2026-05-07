import 'package:flutter/material.dart';
import 'package:cc_app/client.dart';
import 'package:cc_app/prefs.dart';

class Session {
  final User user;
  final String token;

  const Session({required this.user, required this.token});
}

/*
class UserController extends ChangeNotifier {
  final Prefs prefs;
  final Client client;
  Session? session;

  UserController({required this.prefs, required this.client}) {
    _loadFromPrefs();
  }

  void _loadFromPrefs() async {
    final token = await prefs.getToken();
    if (token == null) {
      return;
    }
    await refreshSessionWithToken(token);
  }
  Future<String> register(String username, String password) async {
    final resData = await client.register(username, password);

    if (resData["ok"]) {
      return resData["token"];
    } else {
      throw Exception(resData["message"]);
    }
  }

  Future<String> login(String username, String password) async {
    final res = await client.login(username, password);
    switch (res) {
      case Ok(data: final token):
        return await refreshSessionWithToken(token);
      case Err(message: final message):
        throw Exception(message);
    }
  }

  Future<Result<Null>> logout() async {
    session = null;
    notifyListeners();
    return Ok(null);
  }

  Future<Result<Null>> refreshSessionWithToken(String token) async {
    final res = await client.getUserInfo(token);
    switch (res) {
      case Ok(data: final user):
        await prefs.setToken(token);
        session = Session(user: user, token: token);
        notifyListeners();
        return Ok(null);
      case Err(message: final message):
        await prefs.removeToken();
        return Err(message);
    }
  }
}
*/
