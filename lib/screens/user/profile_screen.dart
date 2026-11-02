import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/app_user.dart';
import '../../navigation/tab_index_notifier.dart';
import '../../services/user_auth_service.dart';
import '../../services/user_session.dart';
import '../../theme/fairtix_palette.dart';
import '../../widgets/ft_dark_ui.dart' show FtText;
import '../../widgets/ft_dashboard_ui.dart' show FtProfileAvatar;
import '../../widgets/ft_pending_ui.dart' show FtReveal;
import '../../widgets/ft_profile_ui.dart';
import '../../widgets/ft_verified_ui.dart' show FtVerifiedBadge;
import 'appearance_screen.dart';
import 'change_password_screen.dart';
import 'help_support_screen.dart';
import 'login_screen.dart';
import 'notification_preferences_screen.dart';
import 'transactions_screen.dart';

/// "My Profile" tab: account details, ID verification status, settings, and
/// log out. Dark by default; follows the Light / Dark choice made in
/// Settings > Appearance.
/// [UserSession.instance.account] is populated by [UserAuthService.login]
/// from the real signed-in Supabase user + their `public.users` row.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  static const int _revealMs = 800;
  static const int _profileTab = 3;

  final ImagePicker _picker = ImagePicker();
  bool _isUploadingPhoto = false;

  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _revealMs),
  );
  bool _motionSet = false;
  bool _revealPlayed = false;

  @override
  void initState() {
    super.initState();
    mainShellTabIndex.addListener(_maybePlayReveal);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_motionSet) return;
    _motionSet = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _reveal.value = 1;
      _revealPlayed = true;
    } else {
      _maybePlayReveal();
    }
  }

  @override
  void dispose() {
    mainShellTabIndex.removeListener(_maybePlayReveal);
    _reveal.dispose();
    super.dispose();
  }

  /// This tab lives inside the shell's PageView and is built at app start, so
  /// the entrance plays the first time the tab is actually shown.
  void _maybePlayReveal() {
    if (_revealPlayed || !mounted) return;
    if (mainShellTabIndex.value != _profileTab) return;
    _revealPlayed = true;
    _reveal.forward(from: 0);
  }

  Future<void> _handleLogOut(BuildContext context) async {
    await UserAuthService.instance.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Profile photo is optional (Event Goer only): tap the avatar to take or
  /// choose a photo, or remove the current one.
  void _showPhotoOptions() {
    final p = FairTixPalette.of(context);
    final hasPhoto = UserSession.instance.account?.profilePhotoUrl != null;
    final tileStyle = GoogleFonts.plusJakartaSans(
      fontSize: 15.5,
      fontWeight: FontWeight.w600,
      color: p.textStrong,
    );
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: p.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: Icon(Icons.photo_camera_outlined, color: p.tileAccent),
              title: Text('Take a photo', style: tileStyle),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickAndUpload(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library_outlined, color: p.tileAccent),
              title: Text('Choose from gallery', style: tileStyle),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickAndUpload(ImageSource.gallery);
              },
            ),
            if (hasPhoto)
              ListTile(
                leading: Icon(Icons.delete_outline_rounded, color: p.danger),
                title: Text('Remove photo', style: tileStyle.copyWith(color: p.danger)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _removePhoto();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    XFile? picked;
    try {
      picked = await _picker.pickImage(source: source, maxWidth: 1024, imageQuality: 85);
    } catch (_) {
      if (!mounted) return;
      _showMessage(
        'Could not open the ${source == ImageSource.camera ? 'camera' : 'gallery'}. Please check app permissions.',
      );
      return;
    }
    if (picked == null) return; // backed out without choosing a photo

    setState(() => _isUploadingPhoto = true);
    try {
      final bytes = await picked.readAsBytes();
      final name = picked.name;
      final ext = name.contains('.') ? name.split('.').last : 'jpg';
      await UserAuthService.instance.uploadProfilePhoto(bytes: bytes, fileExtension: ext);
      if (!mounted) return;
      _showMessage('Profile photo updated.');
    } on UserAuthException catch (e) {
      if (!mounted) return;
      _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _removePhoto() async {
    setState(() => _isUploadingPhoto = true);
    try {
      await UserAuthService.instance.removeProfilePhoto();
      if (!mounted) return;
      _showMessage('Profile photo removed.');
    } on UserAuthException catch (e) {
      if (!mounted) return;
      _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Widget _reveal_(int step, Widget child) => FtReveal(
        animation: _reveal,
        startMs: step * 70,
        endMs: step * 70 + 350,
        totalMs: _revealMs,
        slide: 14,
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    final p = FairTixPalette.of(context);
    final user = UserSession.instance.account ??
        const AppUser(
          fullName: 'Guest',
          username: '',
          email: '',
          idType: 'Not verified',
          isVerified: false,
        );
    final photoUrl = UserAuthService.instance.profilePhotoPublicUrl(user.profilePhotoUrl);
    final firstName = user.fullName.trim().split(RegExp(r'\s+')).first;
    final initial = firstName.isEmpty ? 'E' : firstName.substring(0, 1).toUpperCase();
    final photoAction = _isUploadingPhoto ? null : _showPhotoOptions;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: ftOverlayStyle(p),
      child: Scaffold(
        backgroundColor: p.gradientBottom,
        body: FtPaletteBackground(
          child: SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
              child: Column(
                children: [
                  _reveal_(
                    0,
                    Row(
                      children: [
                        Expanded(
                          child: Semantics(
                            header: true,
                            child: Text(
                              'My Profile',
                              style: FtText.title().copyWith(
                                fontSize: 33,
                                letterSpacing: -0.6,
                                color: p.textStrong,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        FtProfileAvatar(
                          initial: initial,
                          photoUrl: photoUrl,
                          onTap: photoAction ?? () {},
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  _reveal_(
                    1,
                    Column(
                      children: [
                        FtProfileHero(
                          initials: user.initials,
                          photoUrl: photoUrl,
                          busy: _isUploadingPhoto,
                          onTap: photoAction,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          user.fullName,
                          textAlign: TextAlign.center,
                          style: FtText.title().copyWith(
                            fontSize: 26,
                            letterSpacing: -0.4,
                            color: p.textStrong,
                          ),
                        ),
                        if (user.username.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            user.username,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              color: p.textSoft,
                            ),
                          ),
                        ],
                        if (user.isVerified) ...[
                          const SizedBox(height: 12),
                          FtVerifiedBadge(
                            background: p.verifiedSurface,
                            foreground: p.verified,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _reveal_(
                    2,
                    FtInfoCard(
                      title: 'Account Details',
                      children: [
                        FtLockedField(label: 'FULL NAME', value: user.fullName),
                        const FtRowDivider(vertical: 16),
                        FtLockedField(label: 'EMAIL ADDRESS', value: user.email),
                        const SizedBox(height: 14),
                        Text(
                          'Locked to your verified ID and cannot be changed.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.5,
                            height: 1.3,
                            fontStyle: FontStyle.italic,
                            color: p.textSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _reveal_(
                    3,
                    FtInfoCard(
                      title: 'ID Verification',
                      children: [
                        FtIdStatusRow(idType: user.idType, verified: user.isVerified),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _reveal_(
                    4,
                    FtInfoCard(
                      title: 'Settings',
                      children: [
                        FtSettingsRow(
                          icon: Icons.lock_outline_rounded,
                          label: 'Change Password',
                          onTap: () => _push(const ChangePasswordScreen()),
                        ),
                        const FtRowDivider(),
                        FtSettingsRow(
                          icon: Icons.receipt_long_outlined,
                          label: 'View Transactions',
                          onTap: () => _push(const TransactionsScreen()),
                        ),
                        const FtRowDivider(),
                        FtSettingsRow(
                          icon: Icons.notifications_none_rounded,
                          label: 'Notification Preferences',
                          onTap: () => _push(const NotificationPreferencesScreen()),
                        ),
                        const FtRowDivider(),
                        FtSettingsRow(
                          icon: Icons.contrast_rounded,
                          label: 'Appearance',
                          value: p.isDark ? 'Dark' : 'Light',
                          onTap: () => _push(const AppearanceScreen()),
                        ),
                        const FtRowDivider(),
                        FtSettingsRow(
                          icon: Icons.help_outline_rounded,
                          label: 'Help & Support',
                          onTap: () => _push(const HelpSupportScreen()),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _reveal_(5, FtLogoutButton(onPressed: () => _handleLogOut(context))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
