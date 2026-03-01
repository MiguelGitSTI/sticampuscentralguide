import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sticampuscentralguide/theme/theme_provider.dart';
import 'package:sticampuscentralguide/utils/auth_service.dart';
import 'package:sticampuscentralguide/utils/visitor_mode_provider.dart';
import 'package:sticampuscentralguide/Screens/admin_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _profileImagePath;
  String _profileInitials = 'JD';
  User? _user;
  String? _fullName;
  String? _section;
  bool _isAdmin = false;
  final ImagePicker _picker = ImagePicker();
  late final StreamSubscription<User?> _authSubscription;
  String? _lastUid;

  Timer? _adminRevealTimer;
  DateTime? _suppressAdminUntil;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    // Listen for auth changes to detect account switching
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      final newUid = user?.uid;
      if (newUid != _lastUid) {
        _lastUid = newUid;
        _loadProfileData();
      }
    });
  }

  @override
  void dispose() {
    _adminRevealTimer?.cancel();
    _authSubscription.cancel();
    super.dispose();
  }

  void _suppressAdminFor(Duration duration) {
    _adminRevealTimer?.cancel();
    _suppressAdminUntil = DateTime.now().add(duration);
    _adminRevealTimer = Timer(duration, () {
      if (!mounted) return;
      setState(() {
        _suppressAdminUntil = null;
      });
    });
  }

  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    final currentUser = FirebaseAuth.instance.currentUser;
    final storedUid = prefs.getString('profile_user_uid');
    
    // If user changed, clear old cached data
    if (currentUser != null && storedUid != null && storedUid != currentUser.uid) {
      await prefs.remove('user_full_name');
      await prefs.remove('user_section');
      await prefs.remove('user_admin');
      await prefs.remove('profile_image_path');
      await prefs.setString('profile_user_uid', currentUser.uid);
    } else if (currentUser != null && storedUid == null) {
      await prefs.setString('profile_user_uid', currentUser.uid);
    }
    
    // Load profile image from local storage
    final imagePath = prefs.getString('profile_image_path');
    if (imagePath != null && File(imagePath).existsSync()) {
      _profileImagePath = imagePath;
    } else {
      _profileImagePath = null;
    }
    
    _user = currentUser;
    _fullName = prefs.getString('user_full_name');
    _section = prefs.getString('user_section');
    _isAdmin = prefs.getBool('user_admin') ?? false;
    
    // Derive initials from email
    if (_user != null) {
      final email = _user!.email ?? '';
      final prefix = email.split('@').first;
      if (prefix.isNotEmpty) {
        final parts = prefix.split(RegExp(r'[._-]'));
        final initials = parts.take(2).map((p) => p.isNotEmpty ? p[0].toUpperCase() : '').join();
        if (initials.trim().isNotEmpty) {
          _profileInitials = initials;
        }
      }
    }
    
    if (mounted) setState(() {});
  }

  Future<void> _saveProfileImage(String imagePath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_image_path', imagePath);
  }

  Future<void> _removeProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('profile_image_path');
    setState(() {
      _profileImagePath = null;
    });
  }

  Future<void> _changeProfilePicture() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Change Profile Picture',
            style: TextStyle(
              color: Color(0xFF123CBE),
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Choose an option:'),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _actionButton(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    onTap: () => _pickImage(ImageSource.camera),
                  ),
                  _actionButton(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    onTap: () => _pickImage(ImageSource.gallery),
                  ),
                  if (_profileImagePath != null)
                    _actionButton(
                      icon: Icons.delete_outline_rounded,
                      label: 'Remove',
                      onTap: () {
                        Navigator.of(context).pop();
                        _removeProfileImage();
                      },
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Color(0xFF123CBE)),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 300,
        maxHeight: 300,
        imageQuality: 80,
      );
      
      if (image != null) {
        setState(() {
          _profileImagePath = image.path;
        });
        await _saveProfileImage(image.path);
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF123CBE),
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x25000000),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: const Color(0xFFFFB206),
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF123CBE),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isVisitor = context.watch<VisitorModeProvider>().isVisitor;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
        scrolledUnderElevation: 0,
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: cs.onSurface,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile section
              Text(
                'Profile',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              // Custom profile widget for settings
              GestureDetector(
                onTap: _changeProfilePicture,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: themeProvider.isDarkMode ? cs.surfaceVariant : cs.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: themeProvider.isDarkMode
                        ? const [
                            BoxShadow(
                              color: Color(0xCC000000),
                              blurRadius: 8,
                              spreadRadius: 0,
                              offset: Offset(0, 4),
                            ),
                            BoxShadow(
                              color: Color(0x66000000),
                              blurRadius: 3,
                              spreadRadius: 0,
                              offset: Offset(0, 2),
                            ),
                          ]
                        : const [
                            BoxShadow(
                              color: Color(0x18000000),
                              blurRadius: 8,
                              spreadRadius: 0,
                              offset: Offset(0, 4),
                            ),
                            BoxShadow(
                              color: Color(0x12000000),
                              blurRadius: 3,
                              spreadRadius: 0,
                              offset: Offset(0, 2),
                            ),
                            BoxShadow(
                              color: Color(0x0A000000),
                              blurRadius: 1,
                              spreadRadius: 0,
                              offset: Offset(0, 1),
                            ),
                          ],
                  ),
                  child: Row(
                    children: [
                      // Profile avatar
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: (isVisitor && _user == null)
                              ? const Color(0xFF123CBE)
                              : (_profileImagePath == null ? const Color(0xFF123CBE) : null),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x25000000),
                              blurRadius: 10,
                              spreadRadius: 0,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: _profileImagePath != null && !(isVisitor && _user == null)
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  File(_profileImagePath!),
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Center(
                                child: Text(
                                  (isVisitor && _user == null) ? 'V' : _profileInitials,
                                  style: const TextStyle(
                                    color: Color(0xFFFFB206),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(width: 16),
                      // Profile info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (isVisitor && _user == null)
                                  ? 'Visitor'
                                  : (_fullName ?? _user?.displayName ?? 'Campus User'),
                              style: TextStyle(
                                color: cs.onSurface,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              (isVisitor && _user == null)
                                  ? 'Not signed in'
                                  : (_user?.email ?? 'Not signed in'),
                              style: TextStyle(
                                color: cs.onSurface.withOpacity(0.7),
                                fontSize: 14,
                              ),
                            ),
                            if (isVisitor && _user == null) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Section: No Section (Visitor)',
                                style: TextStyle(
                                  color: cs.onSurface.withOpacity(0.7),
                                  fontSize: 13,
                                ),
                              ),
                            ] else if (_section != null && _section!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Section: ${_section!}',
                                style: TextStyle(
                                  color: cs.onSurface.withOpacity(0.7),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Edit icon
                      const Icon(
                        Icons.edit_outlined,
                        color: Color(0xFF123CBE),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // Settings sections placeholder
              Text(
                'App Settings',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              // Dark Mode Toggle
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: themeProvider.isDarkMode ? cs.surfaceVariant : cs.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: themeProvider.isDarkMode
                      ? const [
                          BoxShadow(
                            color: Color(0xCC000000),
                            blurRadius: 8,
                            spreadRadius: 0,
                            offset: Offset(0, 4),
                          ),
                          BoxShadow(
                            color: Color(0x66000000),
                            blurRadius: 3,
                            spreadRadius: 0,
                            offset: Offset(0, 2),
                          ),
                        ]
                      : const [
                          BoxShadow(
                            color: Color(0x18000000),
                            blurRadius: 8,
                            spreadRadius: 0,
                            offset: Offset(0, 4),
                          ),
                          BoxShadow(
                            color: Color(0x12000000),
                            blurRadius: 3,
                            spreadRadius: 0,
                            offset: Offset(0, 2),
                          ),
                          BoxShadow(
                            color: Color(0x0A000000),
                            blurRadius: 1,
                            spreadRadius: 0,
                            offset: Offset(0, 1),
                          ),
                        ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.dark_mode_outlined,
                      color: Color(0xFF123CBE),
                      size: 24,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dark Mode',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Switch to dark theme',
                            style: TextStyle(
                              fontSize: 14,
                              color: cs.onSurface.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Consumer<ThemeProvider>(
                      builder: (context, themeProvider, child) {
                        return Switch(
                          value: themeProvider.isDarkMode,
                          onChanged: (value) {
                            themeProvider.toggleTheme();
                          },
                          activeColor: const Color(0xFF123CBE),
                          activeTrackColor: const Color(0xFF123CBE).withOpacity(0.3),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Additional settings placeholder
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: themeProvider.isDarkMode ? cs.surfaceVariant : cs.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: themeProvider.isDarkMode
                      ? const [
                          BoxShadow(
                            color: Color(0xCC000000),
                            blurRadius: 8,
                            spreadRadius: 0,
                            offset: Offset(0, 4),
                          ),
                        ]
                      : const [
                          BoxShadow(
                            color: Color(0x18000000),
                            blurRadius: 8,
                            spreadRadius: 0,
                            offset: Offset(0, 4),
                          ),
                        ],
                ),
                child: Text(
                  'More settings coming soon...',
                  style: TextStyle(
                    color: cs.onSurface.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (isVisitor && _user == null)
                Center(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.login),
                    label: const Text('Log In'),
                    onPressed: () async {
                      // Avoid flashing the admin button during the transition.
                      _suppressAdminFor(const Duration(seconds: 1));
                      await context.read<VisitorModeProvider>().setVisitor(false);
                      if (mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                ),
              if (isVisitor && _user == null) const SizedBox(height: 12),
              if (_user != null)
                Center(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign Out'),
                    onPressed: () async {
                      await context.read<VisitorModeProvider>().setVisitor(false);
                      await FirebaseAuth.instance.signOut();
                      if (mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                ),
              const SizedBox(height: 12),
              if (_user != null)
                Center(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.delete_outline),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    label: const Text('Delete Account'),
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete account?'),
                          content: const Text('This will permanently delete your account and data.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        try {
                          await AuthService().deleteAccountAndData();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Account deleted')),);
                          Navigator.of(context).pop();
                        } on FirebaseAuthException catch (e) {
                          // Requires recent login
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Delete failed: ${e.message ?? e.code}. Please sign in again.')),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Delete failed. Please try again.')),
                          );
                        }
                      }
                    },
                  ),
                ),
              const SizedBox(height: 12),
              if (_isAdmin && !isVisitor && (_suppressAdminUntil == null || DateTime.now().isAfter(_suppressAdminUntil!)))
                Center(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.admin_panel_settings),
                    label: const Text('Admin Page'),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AdminScreen()),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
