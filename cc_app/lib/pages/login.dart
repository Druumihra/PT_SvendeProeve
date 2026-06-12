import 'package:cc_app/app_flushbar.dart';
import 'package:cc_app/controllers/user.dart';
import 'package:cc_app/pages/home.dart';
import 'package:cc_app/pages/register.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_sign_in_all_platforms/google_sign_in_all_platforms.dart';
import 'package:cc_app/google_auth_service.dart';
import 'package:provider/provider.dart';

class LoginPage extends StatefulWidget {
  final String? successMessage;

  const LoginPage({super.key, this.successMessage});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

final username = TextEditingController();
final password = TextEditingController();

class _LoginPageState extends State<LoginPage> {
  final username = TextEditingController();
  final password = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  bool _navigatedToHome = false;

  void _goToHome() {
    if (!mounted || _navigatedToHome) {
      return;
    }

    _navigatedToHome = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const HomePage(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _auth.authStateChanges().listen((user) {
      if (user != null && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
          });
          _goToHome();
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_auth.currentUser != null) {
        setState(() {
          _isLoading = false;
        });
        _goToHome();
      }
    });
  }

  Future<UserCredential?> _firebaseSignInFromGoogleCredentials(
    GoogleSignInCredentials credentials,
  ) async {
    final hasIdToken = (credentials.idToken ?? '').isNotEmpty;
    final hasAccessToken = credentials.accessToken.isNotEmpty;

    if (!hasIdToken && !hasAccessToken) {
      return null;
    }

    final credential = GoogleAuthProvider.credential(
      accessToken: hasAccessToken ? credentials.accessToken : null,
      idToken: hasIdToken ? credentials.idToken : null,
    );

    return _auth.signInWithCredential(credential);
  }

  Future<void> _signInWithGoogle() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      UserCredential? userCredential;

      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        userCredential = await _auth.signInWithPopup(provider);
      } else {
        final credentials = await GoogleAuthService.signIn();

        if (credentials == null) {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
          });
          return;
        }

        userCredential = await _firebaseSignInFromGoogleCredentials(
          credentials,
        );
      }

      if (userCredential == null) {
        throw FirebaseAuthException(
          code: 'invalid-credential',
          message: 'Google sign-in did not return usable tokens.',
        );
      }

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _goToHome();
    } on FirebaseAuthException catch (error) {
      if (error.code == 'invalid-credential' && !kIsWeb) {
        try {
          final refreshedCredentials = await GoogleAuthService.signInFresh();
          if (refreshedCredentials != null) {
            final retriedUserCredential =
                await _firebaseSignInFromGoogleCredentials(
                  refreshedCredentials,
                );

            if (retriedUserCredential != null && mounted) {
              setState(() {
                _isLoading = false;
              });
              _goToHome();
              return;
            }
          }
        } catch (_) {}
      }

      debugPrint('Error signing in with Google: $error');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to sign in: ${error.message}')),
        );
      }
    } catch (error) {
      debugPrint('Error signing in with Google: $error');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to sign in: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.successMessage != null) {
        AppFlushbar.success(context, widget.successMessage!);
      }
    });

    return Scaffold(
      backgroundColor: Colors.black87,
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 300,
                height: 50,
                child: TextField(
                  controller: username,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Colors.white,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.person, color: Colors.white54),
                    hintText: 'Username',
                    hintStyle: TextStyle(color: Colors.white54),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(25)),
                      borderSide: BorderSide(color: Colors.white54),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(25)),
                      borderSide: BorderSide(color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 300,
                height: 50,
                child: TextField(
                  controller: password,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Colors.white,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.lock, color: Colors.white54),
                    hintText: 'Password',
                    hintStyle: TextStyle(color: Colors.white54),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(25)),
                      borderSide: BorderSide(color: Colors.white54),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(25)),
                      borderSide: BorderSide(color: Colors.white),
                    ),
                  ),
                  obscureText: true,
                ),
              ),
              const SizedBox(height: 64),
              SizedBox(
                width: 150,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    try {
                      final message = await context
                          .read<UserController>()
                          .login(username.text, password.text);

                      if (context.mounted) {
                        AppFlushbar.success(context, message);
                        if (context.mounted) {
                          Navigator.of(context).pushReplacement(
                            PageRouteBuilder(
                              pageBuilder: (_, __, ___) =>
                                  HomePage(successMessage: message),
                              transitionDuration: Duration.zero,
                              reverseTransitionDuration: Duration.zero,
                            ),
                          );
                        }
                        if (context.mounted) {
                          Navigator.of(context).pushReplacement(
                            PageRouteBuilder(
                              pageBuilder: (_, __, ___) =>
                                  HomePage(successMessage: message),
                              transitionDuration: Duration.zero,
                              reverseTransitionDuration: Duration.zero,
                            ),
                          );
                        }
                        Navigator.of(context).pushReplacement(
                          PageRouteBuilder(
                            pageBuilder: (_, __, ___) =>
                                HomePage(successMessage: message),
                            transitionDuration: Duration.zero,
                            reverseTransitionDuration: Duration.zero,
                          ),
                        );
                      }
                    } catch (error) {
                      if (context.mounted) {
                        AppFlushbar.error(context, error.toString());
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    overlayColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: const Text(
                    'Login',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  PageRouteBuilder(
                    pageBuilder: (_, __, ___) => RegisterPage(),
                    transitionDuration: Duration.zero,
                    reverseTransitionDuration: Duration.zero,
                  ),
                ),
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: RichText(
                  text: const TextSpan(
                    text: 'Don\'t have an account? Click here to register.',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Divider(
                color: Colors.white54,
                thickness: 3,
                indent: 25,
                endIndent: 25,
              ),
              const SizedBox(height: 16),
              const Text(
                'Or login with',
                style: TextStyle(color: Colors.white54),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 150,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          _signInWithGoogle();
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    overlayColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    disabledBackgroundColor: Colors.black26,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : ClipOval(
                          child: Image.asset(
                            "assets/google_icon.jpg",
                            width: 36,
                            height: 36,
                            fit: BoxFit.cover,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    super.dispose();
  }
}
