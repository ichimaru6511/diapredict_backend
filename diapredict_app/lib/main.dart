import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/account_status_screen.dart';

void main() async {
  // needed before using Firebase
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const DiaPredictApp());
}

class DiaPredictApp extends StatelessWidget {
  const DiaPredictApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DiaPredict',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const AuthGate(),
    );
  }
}

// Step 1: is anyone signed in?
//   No  -> Login screen
//   Yes -> ProfileGate checks the user's account status in Firestore
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }
        final user = snapshot.data;
        if (user == null) {
          return const LoginScreen();
        }
        // the key makes a new ProfileGate if a different user signs in
        return ProfileGate(key: ValueKey(user.uid), uid: user.uid);
      },
    );
  }
}

// Step 2: read users/{uid} from Firestore and route by account status.
// Only approved accounts can reach the app; everyone else sees a status screen.
class ProfileGate extends StatefulWidget {
  final String uid;

  const ProfileGate({super.key, required this.uid});

  @override
  State<ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<ProfileGate> {
  late Stream<DocumentSnapshot<Map<String, dynamic>>> _profileStream;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  // created once (and again only when retrying), so the stream is not
  // restarted on every rebuild
  void _listen() {
    _profileStream = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _profileStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          // when signing out, the old listener fails with permission-denied
          // for a moment; that is expected, so just wait for the Login screen
          if (FirebaseAuth.instance.currentUser == null) {
            return const _LoadingScreen();
          }
          debugPrint('ProfileGate error: ${snapshot.error}');
          return AccountStatusScreen(
            status: 'error',
            onRetry: () => setState(_listen),
          );
        }

        if (!snapshot.hasData) {
          return const _LoadingScreen();
        }

        final data = snapshot.data!.data();
        if (data == null) {
          return const AccountStatusScreen(status: 'missing');
        }

        // ignore capital letters and extra spaces (e.g. "Approved ")
        final status =
            (data['status'] ?? 'pending').toString().trim().toLowerCase();

        if (status == 'approved') {
          // role-based home screens (Doctor / Nurse / Admin) will be added later
          return const HomeScreen();
        }
        return AccountStatusScreen(status: status);
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}