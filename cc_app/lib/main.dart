import 'package:cc_app/pages/register.dart';
import 'package:flutter/material.dart';
import 'package:cc_app/prefs.dart';
import 'package:cc_app/pages/login.dart';
import 'package:cc_app/pages/home.dart';
import 'package:cc_app/controllers/user.dart';
import 'package:cc_app/client.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: LoginPage(),
    ),
  );
}


/*
void main() async {
  final prefs = await SharedPrefs.loadPrefs();
  final client = Client();
  runApp(App(prefs: prefs, client: client));
}

class App extends StatelessWidget {
  final Prefs prefs;
  final Client client;

  const App({super.key, required this.prefs, required this.client});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<UserController>(
          create: (_) => UserController(prefs: prefs, client: client),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true),
        home: Consumer<UserController>(
          builder: (_, controller, __) =>
              controller.session == null ? LoginPage() : HomePage(),
        ),
      ),
    );
  }
}
*/