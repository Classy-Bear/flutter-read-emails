import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logging/logging.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'https://www.googleapis.com/auth/gmail.readonly',
    ],
    serverClientId:
        '1081346852166-g69r676noa0rp83shu6q5plef81d6iue.apps.googleusercontent.com',
    forceCodeForRefreshToken: true,
  );
  final Logger _logger = Logger('AuthService');
  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream to listen to auth changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      final googleUser = await _googleSignIn.signIn();
      _logger.info('Google user: ${googleUser?.id}');
      if (googleUser == null) return null;
      // Obtain the auth details from the request
      final googleAuth = await googleUser.authentication;
      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      _logger.info('Credential retrieved');
      final userCredential = await _auth.signInWithCredential(credential);
      _logger.info('User credential: ${userCredential.user?.uid}');
      final callable = _functions.httpsCallable('storeRefreshToken');
      final response = await callable.call(<String, dynamic>{
        'authCode': googleUser.serverAuthCode,
      });
      _logger.info('Start email watching result: $response');
      return userCredential;
    } catch (e) {
      _logger.severe('Error signing in with Google: $e');
      return null;
    }
  }

  Future<dynamic> getEmails() async {
    try {
      final callable = _functions.httpsCallable('getEmails');
      final response = await callable
          .call(<String, dynamic>{'maxResults': 10, 'q': 'from:@proton.me'});
      _logger.info('getEmails result: ${response.data}');
      return response.data;
    } catch (e) {
      _logger.severe('Error calling getEmails: $e');
      return null;
    }
  }

  List<dynamic> _emails = [];
  List<dynamic> get emails => _emails;

  // Stream subscription for real-time email updates
  StreamSubscription<QuerySnapshot>? _emailSubscription;

  // Stream controller to broadcast email updates
  final StreamController<List<dynamic>> _emailStreamController =
      StreamController<List<dynamic>>.broadcast();

  // Stream that clients can listen to for email updates
  Stream<List<dynamic>> get emailStream => _emailStreamController.stream;

  // Start listening for real-time email updates
  void startEmailListener() {
    if (_emailSubscription != null) {
      _logger.info('Email listener already active');
      return;
    }

    if (currentUser?.uid == null) {
      _logger.warning('Cannot start email listener: No authenticated user');
      return;
    }

    try {
      _logger.info('Starting real-time email listener');
      _emailSubscription = FirebaseFirestore.instance
          .collection('emails')
          .doc(currentUser!.uid)
          .collection('messages')
          .orderBy('date', descending: true)
          .limit(20)
          .snapshots()
          .listen((snapshot) {
        _emails = snapshot.docs.map((doc) => doc.data()).toList();
        _emailStreamController.add(_emails);
        _logger.info('Email update received: ${_emails.length} emails');
      }, onError: (error) {
        _logger.severe('Error in email listener: $error');
      });
    } catch (e) {
      _logger.severe('Failed to start email listener: $e');
    }
  }

  // Stop listening for email updates
  void stopEmailListener() {
    _emailSubscription?.cancel();
    _emailSubscription = null;
    _logger.info('Email listener stopped');
  }

  Future<void> fetchEmailsFromFirestore() async {
    debugPrint(currentUser?.uid);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('emails')
          .doc(currentUser?.uid)
          .collection('messages')
          .orderBy('date', descending: true)
          .limit(20)
          .get();
      _emails = snapshot.docs.map((doc) {
        final data = doc.data();
        return data;
      }).toList();
      _logger.info('Fetched emails from Firestore: ${_emails.length} emails');
      // Add fetched emails to the stream
      _emailStreamController.add(_emails);
    } catch (e) {
      _logger.severe('Error fetching emails from Firestore: $e');
    }
  }

  // Sign out
  Future<void> signOut() async {
    stopEmailListener();
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // Dispose method to clean up resources
  void dispose() {
    stopEmailListener();
    _emailStreamController.close();
  }
}
