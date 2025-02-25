import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_read_email_client/firebase_options.dart';
import 'package:firebase_read_email_client/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:logging/logging.dart';
import 'package:firebase_read_email_client/email_view_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Google Auth Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AuthPage(),
    );
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  UserCredential? _userData;

  // New state variables for emails
  bool _isFetchingEmails = false;
  List<dynamic> _emails = [];

  // New method to load emails from Firebase
  Future<void> _loadEmails() async {
    setState(() {
      _isFetchingEmails = true;
    });
    await _authService.fetchEmailsFromFirestore();
    setState(() {
      _emails = _authService.emails;
      _isFetchingEmails = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_userData != null) {
      // User is signed in
      final name = _userData!.user!.displayName;
      final email = _userData!.user!.email;
      final photoUrl = _userData!.user!.photoURL;
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _handleSignOut,
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              if (photoUrl != null)
                CircleAvatar(
                  radius: 50,
                  backgroundImage: NetworkImage(photoUrl),
                ),
              const SizedBox(height: 16),
              Text(
                name ?? 'No Name',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                email ?? 'No Email',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              Text(
                'Refresh Token Available: ${_userData!.user!.refreshToken != null}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadEmails,
                child: _isFetchingEmails
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text("Reload Emails"),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _getEmails,
                child: const Text("Fetchemails"),
              ),
              Expanded(
                child: _emails.isEmpty
                    ? const Center(child: Text("No emails found."))
                    : ListView.builder(
                        itemCount: _emails.length,
                        itemBuilder: (context, index) {
                          final emailData = _emails[index];
                          return ListTile(
                            title: Text(emailData['subject'] ?? 'No Subject'),
                            subtitle: Text(
                              (emailData['date'] as Timestamp).toDate().toString(),
                            ),
                            onTap: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EmailViewPage(
                                      htmlContent:
                                          emailData['body']?.toString() ?? '',
                                      subject:
                                          emailData['subject'] ?? 'No Subject',
                                    ),
                                  ));
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    }

    // User is not signed in
    return Scaffold(
      appBar: AppBar(
        title: const Text('Google Auth Demo'),
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : ElevatedButton(
                onPressed: _handleSignIn,
                child: const Text('Sign in with Google'),
              ),
      ),
    );
  }

  Future<void> _handleSignIn() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _authService.signInWithGoogle();
      if (result != null) {
        setState(() {
          _userData = result;
        });
        await _loadEmails();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing in: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _getEmails() async {
    await _authService.getEmails();
    _loadEmails();
  }

  Future<void> _handleSignOut() async {
    try {
      await _authService.signOut();
      setState(() {
        _userData = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: $e')),
      );
    }
  }
}
