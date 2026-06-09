import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cc_app/pages/login.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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