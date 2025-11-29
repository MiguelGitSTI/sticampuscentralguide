import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> register({
    required String email,
    required String password,
    required String fullName,
    required String username,
    required String section,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await cred.user?.updateDisplayName(fullName);

    final uid = cred.user!.uid;
    await _db.collection('users').doc(uid).set({
      'email': email,
      'fullName': fullName,
      'username': username,
      'section': section,
      'admin': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Cache offline
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_full_name', fullName);
    await prefs.setString('user_username', username);
    await prefs.setString('user_section', section);
    await prefs.setBool('user_admin', false);
  }

  Future<void> loginWithEmailOrUsername({
    required String identifier,
    required String password,
  }) async {
    String email = identifier.trim();
    if (!identifier.contains('@')) {
      // treat as username; fetch email from Firestore
      final snap = await _db
          .collection('users')
          .where('username', isEqualTo: identifier.trim())
          .limit(1)
          .get();
      if (snap.docs.isEmpty) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'No user found for that username.',
        );
      }
      email = snap.docs.first.data()['email'] as String;
    }

    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    // After login, cache profile data
    final uid = cred.user!.uid;
    final doc = await _db.collection('users').doc(uid).get();
    final data = doc.data();
    if (data != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_full_name', (data['fullName'] ?? '') as String);
      await prefs.setString('user_username', (data['username'] ?? '') as String);
      await prefs.setString('user_section', (data['section'] ?? '') as String);
      await prefs.setBool('user_admin', (data['admin'] ?? false) as bool);
      // Store the user's UID to detect account switches
      await prefs.setString('profile_user_uid', uid);
    }
  }

  Future<void> deleteAccountAndData() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final uid = user.uid;
    // Delete Firestore user doc
    await _db.collection('users').doc(uid).delete().catchError((_) {});
    // Delete auth account (may require recent login)
    await user.delete();
    // Clear local cache
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_full_name');
    await prefs.remove('user_username');
    await prefs.remove('user_section');
    await prefs.remove('user_admin');
  }
}