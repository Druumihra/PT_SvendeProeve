import 'dart:convert';
import 'package:http/http.dart' as http;

class User {
  String id;
  String username;

  User.fromJson(Map<String, dynamic> obj)
    : id = obj["id"],
      username = obj["username"];
}

class Client {
  final String apiUrl = "";

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
}
