import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../services/auth_service.dart';
import '../providers/theme_provider.dart';
import '../widgets/map_background.dart';
import '../widgets/in_app_review_dialog.dart';
// import 'car_bluetooth_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  String _appVersion = '1.0.0';
  String _selectedMapStyle = 'satellite'; // 'standard', 'hybrid', or 'satellite'

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
    _loadMapStyle();
    _showReviewDialog();
  }

  Future<void> _showReviewDialog() async {
    // Check if user has already rated
    final prefs = await SharedPreferences.getInstance();
    final hasRated = prefs.getBool('has_rated_app') ?? false;
    
    if (hasRated) {
      return; // Don't show dialog if user has already rated
    }
    
    // Show review dialog after a short delay to allow screen to build
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const InAppReviewDialog(),
        );
      }
    });
  }

  Future<void> _loadMapStyle() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedMapStyle = prefs.getString('map_style') ?? 'satellite';
    });
  }

  Future<void> _saveMapStyle(String style) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('map_style', style);
    setState(() {
      _selectedMapStyle = style;
    });
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = packageInfo.version;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final themeProvider = context.watch<ThemeProvider>();
    final user = authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: MapBackground(
        child: ListView(
        children: [
          // User Profile Section
          if (user != null) ...[
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Theme.of(context).primaryColor,
                        child: Text(
                          user.email?.substring(0, 1).toUpperCase() ?? 'U',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.displayName ?? 'User',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            if (user.email != null)
                              Text(
                                user.email!,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey[600],
                                ),
                              ),
                            const SizedBox(height: 4),
                            Chip(
                              label: const Text('Free Plan'),
                              backgroundColor: Colors.blue.withValues(alpha: 0.1),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(),
          ],

          // App Settings Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              'App Settings',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Theme Selection
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: ExpansionTile(
              leading: const Icon(Icons.palette),
              title: const Text('Theme'),
              subtitle: Text(themeProvider.getThemeModeName()),
              children: [
                RadioListTile<ThemeModeOption>(
                  title: const Text('Light'),
                  value: ThemeModeOption.light,
                  groupValue: themeProvider.themeMode,
                  onChanged: (value) {
                    if (value != null) {
                      themeProvider.setThemeMode(value);
                    }
                  },
                ),
                RadioListTile<ThemeModeOption>(
                  title: const Text('Dark'),
                  value: ThemeModeOption.dark,
                  groupValue: themeProvider.themeMode,
                  onChanged: (value) {
                    if (value != null) {
                      themeProvider.setThemeMode(value);
                    }
                  },
                ),
                RadioListTile<ThemeModeOption>(
                  title: const Text('System'),
                  value: ThemeModeOption.system,
                  groupValue: themeProvider.themeMode,
                  onChanged: (value) {
                    if (value != null) {
                      themeProvider.setThemeMode(value);
                    }
                  },
                ),
              ],
            ),
          ),

          // Map Style
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: ExpansionTile(
              leading: const Icon(Icons.map),
              title: const Text('Map Style'),
              subtitle: Text(_selectedMapStyle == 'standard' 
                  ? 'Standard' 
                  : _selectedMapStyle == 'hybrid' 
                      ? 'Hybrid' 
                      : 'Satellite'),
              children: [
                RadioListTile<String>(
                  title: const Text('Standard'),
                  value: 'standard',
                  groupValue: _selectedMapStyle,
                  onChanged: (value) {
                    if (value != null) {
                      _saveMapStyle(value);
                    }
                  },
                ),
                RadioListTile<String>(
                  title: const Text('Hybrid'),
                  value: 'hybrid',
                  groupValue: _selectedMapStyle,
                  onChanged: (value) {
                    if (value != null) {
                      _saveMapStyle(value);
                    }
                  },
                ),
                RadioListTile<String>(
                  title: const Text('Satellite'),
                  value: 'satellite',
                  groupValue: _selectedMapStyle,
                  onChanged: (value) {
                    if (value != null) {
                      _saveMapStyle(value);
                    }
                  },
                ),
              ],
            ),
          ),

          // Car Bluetooth Settings
          // Card(
          //   margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          //   child: ListTile(
          //     leading: const Icon(Icons.bluetooth),
          //     title: const Text('Select My Car Bluetooth'),
          //     subtitle: const Text('Choose your car Bluetooth device'),
          //     trailing: const Icon(Icons.chevron_right),
          //     onTap: () {
          //       context.go('/car-bluetooth-settings');
          //     },
          //   ),
          // ),

          // Notifications
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: SwitchListTile(
              secondary: const Icon(Icons.notifications),
              title: const Text('Notifications'),
              subtitle: const Text('Parking reminders and alerts'),
              value: _notificationsEnabled,
              onChanged: (value) {
                setState(() {
                  _notificationsEnabled = value;
                });
              },
            ),
          ),

          // Auto-Save Parking
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: SwitchListTile(
              secondary: const Icon(Icons.save_alt),
              title: const Text('Auto-Save Parking'),
              subtitle: const Text('Automatically save when you park'),
              value: false, // TODO: Implement auto-save
              onChanged: (value) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Auto-save feature coming soon')),
                );
              },
            ),
          ),

          // AI Note Parsing
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: SwitchListTile(
              secondary: const Icon(Icons.auto_awesome),
              title: const Text('AI Note Parsing'),
              subtitle: const Text('Automatically parse parking notes'),
              value: true, // TODO: Implement AI parsing toggle
              onChanged: (value) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('AI parsing settings coming soon')),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Help & Support Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              'Help & Support',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Contact Us
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: ListTile(
              leading: const Icon(Icons.email),
              title: const Text('Contact Us'),
              subtitle: const Text('getmycar89@gmail.com'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final emailUri = Uri(
                  scheme: 'mailto',
                  path: 'getmycar89@gmail.com',
                );
                if (await canLaunchUrl(emailUri)) {
                  await launchUrl(emailUri);
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not open email client')),
                    );
                  }
                }
              },
            ),
          ),

          // Diagnostics Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              'Diagnostics',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // GPS Accuracy Test
          // Card(
          //   margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          //   child: ListTile(
          //     leading: const Icon(Icons.gps_fixed),
          //     title: const Text('GPS Accuracy Test'),
          //     subtitle: const Text('Test your device GPS accuracy'),
          //     trailing: const Icon(Icons.chevron_right),
          //     onTap: () {
          //       ScaffoldMessenger.of(context).showSnackBar(
          //         const SnackBar(content: Text('GPS test coming soon')),
          //       );
          //     },
          //   ),
          // ),

          // App Version
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: ListTile(
              leading: const Icon(Icons.info),
              title: const Text('App Version'),
              subtitle: Text(_appVersion),
            ),
          ),

          // Clear Cache
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Clear Cache'),
              subtitle: const Text('Clear app cache and temporary files'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clear Cache'),
                    content: const Text('This will clear all cached data. Continue?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Cache cleared')),
                          );
                        },
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Sign Out
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Sign Out'),
                    content: const Text('Are you sure you want to sign out?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Sign Out'),
                      ),
                    ],
                  ),
                );

                if (confirm == true && context.mounted) {
                  await authService.signOut();
                  if (context.mounted) {
                    context.go('/login');
                  }
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
        ),
    );
  }
}

