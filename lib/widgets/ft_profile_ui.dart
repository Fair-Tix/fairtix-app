import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'ft_dark_ui.dart';
import 'ft_dashboard_ui.dart' show FtPressScale;
import 'ft_verified_ui.dart' show FtVerifiedColors;

/// Building blocks for the redesigned "My Profile" tab (dark design).
/// Presentation only: every action and every value is handed in by
/// ProfileScreen, which keeps its existing handlers and session data.

/// The large rounded-square avatar with the camera badge. Shows the photo if
/// there is one, otherwise the initials, and a spinner while a photo is
/// being uploaded or removed. [onTap] is the existing photo-options sheet.
class FtProfileHero extends StatelessWidget {
  const FtProfileHero({
    super.key,
    required this.initials,
    required this.onTap,
    this.photoUrl,
    this.busy = false,
    this.size = 112,
  });

  final String initials;
  final String? photoUrl;
  final bool busy;
  final VoidCallback? onTap;
  final double size;

  Widget _initials() => Center(
        child: Text(
          initials,
          style: GoogleFonts.plusJakartaSans(
            fontSize: size * 0.36,
            height: 1,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: 'Change profile photo',
      excludeSemantics: true,
      child: FtPressScale(
        onTap: onTap,
        child: SizedBox(
          width: size + 12,
          height: size + 12,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                top: 0,
                child: Container(
                  width: size,
                  height: size,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(size * 0.29),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        FtColors.progressStart.withValues(alpha: 0.4),
                        FtColors.otpFill,
                      ],
                    ),
                    border: Border.all(color: FtColors.progressStart, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: FtColors.glow.withValues(alpha: 0.35),
                        blurRadius: 26,
                      ),
                    ],
                  ),
                  child: busy
                      ? const Center(
                          child: SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.6,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : photoUrl != null
                          ? Image.network(
                              photoUrl!,
                              width: size,
                              height: size,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => _initials(),
                            )
                          : _initials(),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: FtColors.progressStart,
                    border: Border.all(color: FtColors.bgBottom, width: 3),
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A titled dark card that holds one group of rows.
class FtInfoCard extends StatelessWidget {
  const FtInfoCard({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      decoration: BoxDecoration(
        color: FtColors.otpFill.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: FtColors.otpBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 19,
                height: 1.2,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

/// Thin divider used between rows inside a card.
class FtRowDivider extends StatelessWidget {
  const FtRowDivider({super.key, this.vertical = 0});

  final double vertical;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: vertical),
      child: const Divider(height: 1, thickness: 1, color: FtColors.otpBorder),
    );
  }
}

/// A read-only value with a small caps label and a lock icon.
class FtLockedField extends StatelessWidget {
  const FtLockedField({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value. Locked, cannot be changed.',
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                    color: FtColors.otpSecondary,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Icon(Icons.lock_outline_rounded, size: 18, color: FtColors.otpSecondary),
          ),
        ],
      ),
    );
  }
}

/// ID type with a status pill, for the ID Verification card.
class FtIdStatusRow extends StatelessWidget {
  const FtIdStatusRow({
    super.key,
    required this.idType,
    required this.verified,
  });

  final String idType;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    final green = FtVerifiedColors.green;
    final accent = verified ? green : FtColors.otpSecondary;

    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: verified
                ? FtVerifiedColors.badge
                : FtColors.progressStart.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            verified ? Icons.verified_user_outlined : Icons.shield_outlined,
            size: 22,
            color: accent,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                idType,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                verified
                    ? 'Your government/school ID has been verified.'
                    : 'Your ID has not been verified yet.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  height: 1.3,
                  color: FtColors.otpSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: verified
                ? FtVerifiedColors.badge
                : FtColors.progressTrack.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(shape: BoxShape.circle, color: accent),
              ),
              const SizedBox(width: 6),
              Text(
                verified ? 'Verified' : 'Not verified',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: verified ? Colors.white : FtColors.otpSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One tappable settings line: tinted icon tile, label, chevron.
class FtSettingsRow extends StatelessWidget {
  const FtSettingsRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: FtPressScale(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: FtColors.progressStart.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, size: 21, color: FtColors.progressEnd),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16.5,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 24,
                color: FtColors.otpSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Outlined red "Log Out" button.
class FtLogoutButton extends StatelessWidget {
  const FtLogoutButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Log Out',
      excludeSemantics: true,
      child: FtPressScale(
        onTap: onPressed,
        child: Container(
          height: 58,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: FtColors.danger, width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.logout_rounded, size: 20, color: FtColors.danger),
              const SizedBox(width: 10),
              Text(
                'Log Out',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: FtColors.danger,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
