import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/auth/guest_provider.dart';
import '../../../core/constants/icon_assets.dart';
import '../../../core/sync/sync_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/custom_toast.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const _signOutCoral = Color(0xFF992929);
  static const _accountGreenBg = Color(0xFFEEFFF3);
  static const _accountGreenBorder = Color(0xFFA2FFBF);

  String _getSyncSubtitle(SyncState state, DateTime? lastSynced) {
    switch (state) {
      case SyncState.syncing:
        return 'Syncing...';
      case SyncState.offline:
        return 'Offline';
      case SyncState.error:
        return 'Sync failed';
      case SyncState.synced:
        if (lastSynced != null) {
          return 'Last synced ${_formatSyncTime(lastSynced)}';
        }
        return 'Up to date';
    }
  }

  String _formatSyncTime(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'pm' : 'am';
    return '$hour:$minute $period';
  }

  String _getAuthProviderLabel(User user) {
    final provider = user.appMetadata['provider'] as String? ??
        (user.identities?.isNotEmpty == true
            ? user.identities!.first.provider
            : null);

    switch (provider) {
      case 'google':
        return 'Signed in by google';
      case 'apple':
        return 'Signed in by apple';
      case 'email':
        return 'Signed in by email';
      default:
        return 'Signed in';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBiometricsEnabled = ref.watch(biometricsEnabledProvider);
    final startAtStartup = ref.watch(startAtStartupProvider);
    final menuBarOnly = ref.watch(menuBarOnlyProvider);
    final syncState = ref.watch(syncStateProvider);
    final lastSyncedAt = ref.watch(lastSyncedAtProvider);
    final currentUser = ref.watch(currentUserProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.charcoal50,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(context, isDark),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                children: [
                  _buildAccountCard(context, ref, isDark, currentUser),
                  const SizedBox(height: 20),
                  if (currentUser != null) ...[
                    _buildSection(
                      isDark: isDark,
                      title: 'Cloud sync',
                      child: _SettingsGlassCard(
                        isDark: isDark,
                        height: 72,
                        child: _buildSettingsRow(
                          isDark: isDark,
                          iconName: 'cloud',
                          title: 'Sync data',
                          subtitle: _getSyncSubtitle(syncState, lastSyncedAt),
                          trailing: SecondaryButton(
                            width: 48,
                            height: 48,
                            padding: EdgeInsets.zero,
                            onTap: () async {
                              await ref.read(syncServiceProvider).sync();
                            },
                            child: SvgPicture.asset(
                              IconAssets.getPath(
                                'arrows-rotate-clockwise-horizontal',
                              ),
                              width: 24,
                              height: 24,
                              colorFilter: ColorFilter.mode(
                                isDark ? Colors.white : AppTheme.charcoal900,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (!kIsWeb &&
                        defaultTargetPlatform == TargetPlatform.macOS) ...[
                      const SizedBox(height: 20),
                      _buildSection(
                        isDark: isDark,
                        title: 'macOS',
                        child: Column(
                          children: [
                            _SettingsGlassCard(
                              isDark: isDark,
                              height: 72,
                              child: _buildSettingsRow(
                                isDark: isDark,
                                iconName: 'power',
                                title: 'Start at startup',
                                subtitle:
                                    'Open Clue automatically when you log in',
                                trailing: _SettingsToggle(
                                  value: startAtStartup,
                                  onChanged: (value) async {
                                    final success = await ref
                                        .read(startAtStartupProvider.notifier)
                                        .setEnabled(value);
                                    if (!success && context.mounted) {
                                      CustomToast.show(
                                        context,
                                        'Failed to update startup setting.',
                                        isSuccess: false,
                                      );
                                    }
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _SettingsGlassCard(
                              isDark: isDark,
                              height: 72,
                              child: _buildSettingsRow(
                                isDark: isDark,
                                iconName: 'menu',
                                title: 'Menu bar only',
                                subtitle:
                                    'Hide Clue from the Dock and run from the menu bar',
                                trailing: _SettingsToggle(
                                  value: menuBarOnly,
                                  onChanged: (value) async {
                                    final success = await ref
                                        .read(menuBarOnlyProvider.notifier)
                                        .setEnabled(value);
                                    if (!success && context.mounted) {
                                      CustomToast.show(
                                        context,
                                        'Failed to update menu bar setting.',
                                        isSuccess: false,
                                      );
                                    } else if (value && context.mounted) {
                                      CustomToast.show(
                                        context,
                                        'Clue is now in the menu bar. Open it from the Clue icon.',
                                        isSuccess: true,
                                      );
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                  ],
                  _buildSection(
                    isDark: isDark,
                    title: 'Security',
                    child: _SettingsGlassCard(
                      isDark: isDark,
                      height: 72,
                      child: _buildSettingsRow(
                        isDark: isDark,
                        iconName: 'id-touch',
                        title: 'Biometric app lock',
                        subtitle: 'Require authentication',
                        trailing: _SettingsToggle(
                          value: isBiometricsEnabled,
                          onChanged: (value) async {
                            final success = await ref
                                .read(biometricsEnabledProvider.notifier)
                                .toggleBiometrics(value);
                            if (!success && context.mounted) {
                              CustomToast.show(
                                context,
                                value
                                    ? 'Biometrics setup failed or not supported.'
                                    : 'Failed to disable biometrics.',
                                isSuccess: false,
                              );
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  if (currentUser != null) ...[
                    const SizedBox(height: 20),
                    SecondaryButton(
                      height: 56,
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      onTap: () => _confirmSignOut(context, ref),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SvgPicture.asset(
                            IconAssets.getLinePath('arrow-fromBracket-right'),
                            width: 24,
                            height: 24,
                            colorFilter: const ColorFilter.mode(
                              _signOutCoral,
                              BlendMode.srcIn,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Sign Out',
                            style: GoogleFonts.nunito(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              height: 1,
                              color: _signOutCoral,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FutureBuilder<PackageInfo>(
                    future: PackageInfo.fromPlatform(),
                    builder: (context, snapshot) {
                      final version = snapshot.data?.version ?? '';
                      if (version.isEmpty) return const SizedBox.shrink();
                      return Center(
                        child: Text(
                          'Ahmed Nageeb · v$version',
                          style: GoogleFonts.nunito(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.38)
                                : AppTheme.ocean900.withValues(alpha: 0.45),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            isDark ? AppTheme.darkSurface : AppTheme.charcoal50,
            isDark
                ? AppTheme.darkSurface.withValues(alpha: 0)
                : Colors.white.withValues(alpha: 0),
          ],
        ),
      ),
      child: Row(
        children: [
          SecondaryButton(
            width: 48,
            height: 48,
            padding: EdgeInsets.zero,
            onTap: () => Navigator.of(context).pop(),
            child: SvgPicture.asset(
              IconAssets.getLinePath('arrow-left-alt2'),
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(
                isDark ? Colors.white : AppTheme.charcoal900,
                BlendMode.srcIn,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Settings',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.06,
                color: isDark ? Colors.white : AppTheme.charcoal900,
              ),
            ),
          ),
          const SizedBox(width: 48, height: 48),
        ],
      ),
    );
  }

  Widget _buildSection({
    required bool isDark,
    required String title,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isDark
                ? Colors.white.withValues(alpha: 0.5)
                : AppTheme.charcoal400,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildAccountCard(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
    User? currentUser,
  ) {
    if (currentUser == null) {
      return _SettingsGlassCard(
        isDark: isDark,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : AppTheme.charcoal50,
                borderRadius: BorderRadius.circular(200),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : AppTheme.charcoal100,
                ),
              ),
              child: SvgPicture.asset(
                IconAssets.getPath('person-plus'),
                width: 24,
                height: 24,
                colorFilter: ColorFilter.mode(
                  isDark ? Colors.white : AppTheme.charcoal900,
                  BlendMode.srcIn,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Guest',
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppTheme.charcoal900,
                    ),
                  ),
                  Text(
                    'Link account to sync',
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.58)
                          : AppTheme.charcoal500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            PrimaryButton(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              onTap: () => _goToSignIn(context, ref),
              child: Text(
                'Sign in',
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.charcoal50,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return _SettingsGlassCard(
      isDark: isDark,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.accentGreen.withValues(alpha: 0.12)
                  : _accountGreenBg,
              borderRadius: BorderRadius.circular(200),
              border: Border.all(
                color: isDark
                    ? AppTheme.accentGreen.withValues(alpha: 0.3)
                    : _accountGreenBorder,
              ),
            ),
            child: SvgPicture.asset(
              IconAssets.getPath('person-checkmark'),
              width: 24,
              height: 24,
              colorFilter: const ColorFilter.mode(
                AppTheme.accentGreen,
                BlendMode.srcIn,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentUser.email ?? 'No email',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppTheme.charcoal900,
                  ),
                ),
                Text(
                  _getAuthProviderLabel(currentUser),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.58)
                        : AppTheme.charcoal500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsRow({
    required bool isDark,
    required String iconName,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SvgPicture.asset(
          IconAssets.getPath(iconName),
          width: 24,
          height: 24,
          colorFilter: ColorFilter.mode(
            isDark
                ? Colors.white.withValues(alpha: 0.5)
                : AppTheme.charcoal400,
            BlendMode.srcIn,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppTheme.charcoal900,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.58)
                      : AppTheme.charcoal500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        trailing,
      ],
    );
  }

  void _goToSignIn(BuildContext context, WidgetRef ref) {
    ref.read(guestModeProvider.notifier).state = false;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text(
          'Are you sure you want to sign out? Your local records will remain here.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.deleteRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(authServiceProvider).signOut();
      ref.read(guestModeProvider.notifier).state = false;
      if (context.mounted) {
        CustomToast.show(context, 'Signed out successfully.', isSuccess: true);
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }
}

class _SettingsGlassCard extends StatelessWidget {
  const _SettingsGlassCard({
    required this.isDark,
    required this.child,
    this.height,
  });

  final bool isDark;
  final Widget child;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final surface = Container(
      height: height,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.white.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : AppTheme.charcoal900.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: isDark ? 0.10 : 0.75),
            blurRadius: 8,
            offset: const Offset(0, 4),
            blurStyle: BlurStyle.inner,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.96),
            blurRadius: 2,
            offset: const Offset(1, 1),
            blurStyle: BlurStyle.inner,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.96),
            blurRadius: 2,
            offset: const Offset(-1, -1),
            blurStyle: BlurStyle.inner,
          ),
        ],
      ),
      child: child,
    );

    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        boxShadow: [
          BoxShadow(color: Color(0x0A000000), blurRadius: 2, spreadRadius: 1),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        child: !kIsWeb && defaultTargetPlatform == TargetPlatform.android
            ? surface
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: surface,
              ),
      ),
    );
  }
}

class _SettingsToggle extends StatelessWidget {
  const _SettingsToggle({
    required this.value,
    required this.onChanged,
  });

  static const _width = 48.0;
  static const _height = 28.0;
  static const _padding = 4.0;
  static const _thumbSize = 20.0;

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: SizedBox(
        width: _width,
        height: _height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(200),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _SettingsToggleTrack(isOn: value),
              _SettingsToggleInnerShadow(isOn: value),
              Padding(
                padding: const EdgeInsets.all(_padding),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  alignment:
                      value ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    width: _thumbSize,
                    height: _thumbSize,
                    decoration: BoxDecoration(
                      color: AppTheme.charcoal50,
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1A141414),
                          offset: Offset(-0.5, -0.5),
                          blurRadius: 2,
                        ),
                        BoxShadow(
                          color: Color(0x26141414),
                          offset: Offset(1, 1),
                          blurRadius: 2,
                        ),
                      ],
                    ),
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

class _SettingsToggleTrack extends StatelessWidget {
  const _SettingsToggleTrack({required this.isOn});

  final bool isOn;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeOutCubic,
      child: isOn
          ? const PrimaryButtonSurface(
              key: ValueKey(true),
              borderRadius: 200,
              blurBackground: false,
            )
          : const _SettingsToggleOffTrack(key: ValueKey(false)),
    );
  }
}

class _SettingsToggleOffTrack extends StatelessWidget {
  const _SettingsToggleOffTrack({super.key});

  @override
  Widget build(BuildContext context) {
    final track = DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.charcoal200.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(200),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 2, spreadRadius: 1),
        ],
      ),
      child: const SizedBox.expand(),
    );

    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: track,
      );
    }

    return track;
  }
}

class _SettingsToggleInnerShadow extends StatelessWidget {
  const _SettingsToggleInnerShadow({required this.isOn});

  final bool isOn;

  @override
  Widget build(BuildContext context) {
    if (isOn) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(200),
          boxShadow: [
            BoxShadow(
              color: AppTheme.charcoal200.withValues(alpha: 0.96),
              blurRadius: 2,
              offset: const Offset(-1, -1),
              blurStyle: BlurStyle.inner,
            ),
            BoxShadow(
              color: AppTheme.charcoal200.withValues(alpha: 0.96),
              blurRadius: 2,
              offset: const Offset(1, 1),
              blurStyle: BlurStyle.inner,
            ),
          ],
        ),
      ),
    );
  }
}
