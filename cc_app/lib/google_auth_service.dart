import 'package:google_sign_in_all_platforms/google_sign_in_all_platforms.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GoogleAuthService {
  GoogleAuthService._();

  static final GoogleSignIn googleSignIn = GoogleSignIn(
    params: GoogleSignInParams(
      clientId: dotenv.env['CLIENT_ID'],
      clientSecret: dotenv.env['CLIENT_SECRET'],
      scopes: ['openid', 'profile', 'email'],
    ),
  );

  static Future<GoogleSignInCredentials?> signIn() async {
    final credentials = await googleSignIn.signInOnline();
    return credentials;
  }

  static Future<GoogleSignInCredentials?> signInFresh() async {
    await signOut();
    final credentials = await googleSignIn.signInOnline();
    return credentials;
  }

  static Future<void> signOut() async {
    await googleSignIn.signOut();
  }
}
