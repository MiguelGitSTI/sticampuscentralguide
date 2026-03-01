import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:sticampuscentralguide/utils/visitor_mode_provider.dart';

class ProfileButton extends StatefulWidget {
  final VoidCallback onTap;
  
  const ProfileButton({
    super.key,
    required this.onTap,
  });

  @override
  State<ProfileButton> createState() => ProfileButtonState();
}

class ProfileButtonState extends State<ProfileButton> {
  String? _profileImagePath;
  String _profileInitials = 'JD';
  String? _fullName;
  String? _email;
  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    loadProfileImage();
    // Listen for auth state changes to update profile when user changes
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (mounted) {
        loadProfileImage();
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUid = currentUser?.uid;
    
    // Check if stored profile matches current user
    final storedUid = prefs.getString('profile_user_uid');
    
    // If user changed, clear old profile data
    if (storedUid != null && storedUid != currentUid) {
      await prefs.remove('profile_image_path');
      await prefs.remove('user_full_name');
      await prefs.remove('profile_user_uid');
    }
    
    // Store current user's UID
    if (currentUid != null) {
      await prefs.setString('profile_user_uid', currentUid);
    }
    
    // Load profile image from local storage
    final imagePath = prefs.getString('profile_image_path');
    if (imagePath != null && File(imagePath).existsSync()) {
      if (mounted) {
        setState(() {
          _profileImagePath = imagePath;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _profileImagePath = null;
        });
      }
    }
    
    _fullName = prefs.getString('user_full_name');
    _email = currentUser?.email;
    
    // If full name is not cached but user is logged in, fetch from Firestore
    if ((_fullName == null || _fullName!.isEmpty) && currentUid != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUid)
            .get();
        final data = doc.data();
        if (data != null && data['fullName'] != null) {
          _fullName = data['fullName'] as String;
          // Cache for future use
          await prefs.setString('user_full_name', _fullName!);
          if (data['section'] != null) {
            await prefs.setString('user_section', data['section'] as String);
          }
          if (data['username'] != null) {
            await prefs.setString('user_username', data['username'] as String);
          }
          await prefs.setBool('user_admin', (data['admin'] ?? false) as bool);
        }
      } catch (e) {
        // Silently fail - will show fallback
        debugPrint('Failed to fetch user data: $e');
      }
    }
    
    // Derive initials from full name if available
    final name = _fullName ?? '';
    if (name.isNotEmpty) {
      final parts = name.trim().split(RegExp(r'\s+'));
      final initials = parts.take(2).map((p) => p.isNotEmpty ? p[0].toUpperCase() : '').join();
      if (initials.trim().isNotEmpty) {
        if (mounted) setState(() { _profileInitials = initials; });
      }
    } else {
      // Reset to default if no name
      if (mounted) setState(() { _profileInitials = 'JD'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width / 411.0;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isVisitor = context.watch<VisitorModeProvider>().isVisitor;

    final showVisitor = isVisitor && FirebaseAuth.instance.currentUser == null;
    final displayName = showVisitor ? 'Visitor' : (_fullName ?? 'Campus User');
    final displayEmail = showVisitor ? 'Not signed in' : (_email ?? 'Not signed in');
    final displayInitials = showVisitor ? 'V' : _profileInitials;
    final showImage = !showVisitor && _profileImagePath != null;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.transparent, // Clear background
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Profile avatar - rounded square matching icon size
            Container(
              width: (44 * sw).clamp(38, 54).toDouble(), // Same as icon buttons
              height: (44 * sw).clamp(38, 54).toDouble(), // Same as icon buttons
              decoration: BoxDecoration(
                color: showImage ? null : const Color(0xFF123CBE), // NavyBlue background
                borderRadius: BorderRadius.circular(12), // Rounded square like icon buttons
                boxShadow: isDark
                    ? const [
                        BoxShadow(
                          color: Color(0xCC000000),
                          blurRadius: 4,
                          spreadRadius: 0,
                          offset: Offset(0, 2),
                        ),
                        BoxShadow(
                          color: Color(0x66000000),
                          blurRadius: 2,
                          spreadRadius: 0,
                          offset: Offset(0, 1),
                        ),
                      ]
                    : const [
                        BoxShadow(
                          color: Color(0x18000000),
                          blurRadius: 4,
                          spreadRadius: 0,
                          offset: Offset(0, 2),
                        ),
                        BoxShadow(
                          color: Color(0x12000000),
                          blurRadius: 2,
                          spreadRadius: 0,
                          offset: Offset(0, 1),
                        ),
                      ],
              ),
              child: showImage
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(_profileImagePath!),
                        width: (44 * sw).clamp(38, 54).toDouble(),
                        height: (44 * sw).clamp(38, 54).toDouble(),
                        fit: BoxFit.cover,
                      ),
                    )
                  : Center(
                      child: Text(
                        displayInitials,
                        style: const TextStyle(
                          color: Color(0xFFFFB206), // Gold initials
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            // Profile info
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayName,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: (14 * sw).clamp(12, 16).toDouble(),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  displayEmail,
                  style: TextStyle(
                    color: cs.onSurface.withOpacity(0.7),
                    fontSize: (12 * sw).clamp(10, 14).toDouble(),
                  ),
                ),
              ],
            ),
          ],
          ),
        ),
      ),
    );
  }
}