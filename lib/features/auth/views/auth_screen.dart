import 'dart:io' show Platform;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/auth/guest_provider.dart';
import '../../../core/constants/icon_assets.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/custom_toast.dart';
import '../../../core/widgets/logo_widget.dart';

// Re-enable when enrolled in the paid Apple Developer Program (Sign In with Apple).
const _appleSignInEnabled = false;
const _signInCoral = Color(0xFF992929);
const _authButtonHeight = 56.0;
const _splashRevealDuration = Duration(milliseconds: 1000);
const _splashHoldDuration = Duration(milliseconds: 700);
const _emailTransitionDuration = Duration(milliseconds: 1000);
const _authMotionCurve = Cubic(0.33, 1, 0.68, 1);

TextStyle _authTaglineStyle() {
  return GoogleFonts.nunito(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    height: 26 / 18,
    letterSpacing: -0.25,
    color: AppTheme.charcoal50,
    fontFeatures: const [
      FontFeature.disable('liga'),
      FontFeature.disable('clig'),
    ],
  );
}

class _AuthBrandingContent extends StatelessWidget {
  const _AuthBrandingContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const ForgottenThingsLogo(
          assetPath: 'assets/clue_logo.svg',
          height: 96,
        ),
        const SizedBox(height: 12),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'Fast access to the things you forget',
            maxLines: 1,
            softWrap: false,
            textAlign: TextAlign.center,
            style: _authTaglineStyle(),
          ),
        ),
      ],
    );
  }
}

TextStyle _authButtonTextStyle({required Color color}) {
  return GoogleFonts.nunito(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1,
    color: color,
  );
}

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with TickerProviderStateMixin {
  bool _isGoogleLoading = false;
  bool _isAppleLoading = false;
  bool _isEmailLoading = false;
  bool _isEmailSignUp = false;
  late final AnimationController _revealController;
  late final Animation<double> _revealAnimation;
  late final AnimationController _emailTransitionController;
  late final Animation<double> _emailTransition;
  final _emailFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _revealController = AnimationController(
      vsync: this,
      duration: _splashRevealDuration,
    );
    _revealAnimation = CurvedAnimation(
      parent: _revealController,
      curve: _authMotionCurve,
    );
    _emailTransitionController = AnimationController(
      vsync: this,
      duration: _emailTransitionDuration,
    );
    _emailTransition = CurvedAnimation(
      parent: _emailTransitionController,
      curve: _authMotionCurve,
      reverseCurve: _authMotionCurve.flipped,
    );
    Future<void>.delayed(_splashHoldDuration, () {
      if (mounted) {
        _revealController.forward();
      }
    });
  }

  @override
  void dispose() {
    _revealController.dispose();
    _emailTransitionController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _openEmailAuth() {
    if (_revealAnimation.value < 1 ||
        _emailTransitionController.isAnimating) {
      return;
    }
    _emailTransitionController.forward();
  }

  void _closeEmailAuth() {
    if (_emailTransitionController.isAnimating) return;
    _emailTransitionController.reverse();
  }

  Future<void> _submitEmailAuth() async {
    if (!_emailFormKey.currentState!.validate()) return;

    setState(() => _isEmailLoading = true);
    final authService = ref.read(authServiceProvider);

    try {
      if (_isEmailSignUp) {
        await authService.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        if (mounted) {
          CustomToast.show(
            context,
            'Account created! Check your email for verification.',
            isSuccess: true,
          );
          setState(() => _isEmailSignUp = false);
        }
      } else {
        await authService.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        if (mounted) {
          CustomToast.show(context, 'Welcome back!', isSuccess: true);
        }
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(
          context,
          e.toString().replaceAll('Exception: ', ''),
          isSuccess: false,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isEmailLoading = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isGoogleLoading = true);
    final authService = ref.read(authServiceProvider);

    try {
      await authService.signInWithGoogle();
      if (mounted) {
        CustomToast.show(context, 'Signed in with Google!', isSuccess: true);
      }
    } catch (e) {
      if (mounted) {
        final errorText = e.toString();
        final message = errorText.contains('cancel')
            ? 'Google Sign-In was cancelled'
            : kDebugMode
            ? 'Google Sign-In failed: $errorText'
            : 'Google Sign-In failed. Please try again.';
        CustomToast.show(context, message, isSuccess: false);
      }
    } finally {
      if (mounted) {
        setState(() => _isGoogleLoading = false);
      }
    }
  }

  Future<void> _signInWithApple() async {
    if (!_appleSignInEnabled) {
      CustomToast.show(
        context,
        'Apple Sign-In is not available yet.',
        isSuccess: false,
      );
      return;
    }

    setState(() => _isAppleLoading = true);
    final authService = ref.read(authServiceProvider);

    try {
      await authService.signInWithApple();
      if (mounted) {
        CustomToast.show(context, 'Signed in with Apple!', isSuccess: true);
      }
    } catch (e) {
      if (mounted) {
        final message = e.toString().contains('cancelled')
            ? 'Apple Sign-In was cancelled'
            : 'Apple Sign-In failed. Please try again.';
        CustomToast.show(context, message, isSuccess: false);
      }
    } finally {
      if (mounted) {
        setState(() => _isAppleLoading = false);
      }
    }
  }

  bool get _showApple {
    try {
      return Platform.isIOS || Platform.isMacOS;
    } catch (_) {
      return false;
    }
  }

  double _estimatedSignInContentHeight(double bodyHeight) {
    final contentHeight = _showApple ? 340.0 : 268.0;
    return contentHeight.clamp(0, bodyHeight * 0.7);
  }

  double _estimatedEmailContentHeight(double bodyHeight) {
    return 400.0.clamp(0, bodyHeight * 0.7);
  }

  double _contentHeightForEmailTransition(double bodyHeight, double emailT) {
    return lerpDouble(
          _estimatedSignInContentHeight(bodyHeight),
          _estimatedEmailContentHeight(bodyHeight),
          emailT,
        ) ??
        _estimatedSignInContentHeight(bodyHeight);
  }

  double _fullSheetHeight(
    double bodyHeight,
    double bottomPadding,
    double keyboardInset,
    double emailT,
  ) {
    final contentHeight = _contentHeightForEmailTransition(bodyHeight, emailT);
    return contentHeight +
        32 +
        bottomPadding +
        (emailT > 0 ? keyboardInset : 0);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return PopScope(
      canPop: _emailTransition.value == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _emailTransition.value > 0) {
          _closeEmailAuth();
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
        backgroundColor: AppTheme.primaryOcean,
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return AnimatedBuilder(
                animation: Listenable.merge([
                  _revealAnimation,
                  _emailTransition,
                ]),
                builder: (context, child) {
                  final revealT = _revealAnimation.value;
                  final emailT = _emailTransition.value;
                  final fullSheetHeight = _fullSheetHeight(
                    constraints.maxHeight,
                    bottomPadding,
                    keyboardInset,
                    emailT,
                  );
                  final sheetSlideOffset = (1 - revealT) * fullSheetHeight;
                  final logoBottomInset = fullSheetHeight * revealT;

                  return Stack(
                    fit: StackFit.expand,
                    clipBehavior: Clip.hardEdge,
                    children: [
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        bottom: logoBottomInset,
                        child: Center(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 48),
                            child: const _AuthBrandingContent(),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: fullSheetHeight,
                        child: ClipRect(
                          child: Transform.translate(
                            offset: Offset(0, sheetSlideOffset),
                            child: IgnorePointer(
                              ignoring: revealT < 1,
                              child: _buildBottomSheetSection(
                                bottomPadding: bottomPadding,
                                keyboardInset: keyboardInset,
                                maxWidth: constraints.maxWidth,
                                bodyHeight: constraints.maxHeight,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildBottomSheetSection({
    required double bottomPadding,
    required double keyboardInset,
    required double maxWidth,
    required double bodyHeight,
  }) {
    final emailT = _emailTransition.value;
    final signInHeight = _estimatedSignInContentHeight(bodyHeight);
    final emailHeight = _estimatedEmailContentHeight(bodyHeight);
    final visibleHeight = _contentHeightForEmailTransition(bodyHeight, emailT);
    final carouselHeight = signInHeight > emailHeight ? signInHeight : emailHeight;

    return _AuthGlassSheetShell(
      bottomPadding: bottomPadding,
      keyboardInset: emailT > 0 ? keyboardInset : 0,
      child: ClipRect(
        child: SizedBox(
          height: visibleHeight,
          width: maxWidth,
          child: OverflowBox(
            alignment: Alignment.topCenter,
            minHeight: carouselHeight,
            maxHeight: carouselHeight,
            child: SizedBox(
              height: carouselHeight,
              width: maxWidth,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Transform.translate(
                    offset: Offset(-emailT * maxWidth, 0),
                    child: SizedBox(
                      width: maxWidth,
                      height: carouselHeight,
                      child: IgnorePointer(
                        ignoring: emailT > 0,
                        child: _AuthSignInSheetContent(
                          showApple: _showApple,
                          isGoogleLoading: _isGoogleLoading,
                          isAppleLoading: _isAppleLoading,
                          onGoogleTap:
                              (_isGoogleLoading || _isAppleLoading)
                                  ? null
                                  : _signInWithGoogle,
                          onAppleTap:
                              (_isGoogleLoading || _isAppleLoading)
                                  ? null
                                  : _signInWithApple,
                          onEmailTap: _openEmailAuth,
                          onGuestTap: () {
                            ref.read(guestModeProvider.notifier).state = true;
                            CustomToast.show(
                              context,
                              'Entering Guest Mode.',
                              isSuccess: true,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  Transform.translate(
                    offset: Offset((1 - emailT) * maxWidth, 0),
                    child: SizedBox(
                      width: maxWidth,
                      height: carouselHeight,
                      child: IgnorePointer(
                        ignoring: emailT < 1,
                        child: _EmailAuthSheetContent(
                          formKey: _emailFormKey,
                          isSignUp: _isEmailSignUp,
                          isLoading: _isEmailLoading,
                          emailController: _emailController,
                          passwordController: _passwordController,
                          onBack: _closeEmailAuth,
                          onSubmit:
                              _isEmailLoading ? null : _submitEmailAuth,
                          onModeChanged: (isSignUp) => setState(
                            () => _isEmailSignUp = isSignUp,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthGlassSheetShell extends StatelessWidget {
  const _AuthGlassSheetShell({
    required this.bottomPadding,
    required this.keyboardInset,
    required this.child,
  });

  final double bottomPadding;
  final double keyboardInset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final surface = Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        bottomPadding + 16 + keyboardInset,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: AppTheme.charcoal900.withValues(alpha: 0.12)),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 2, spreadRadius: 1),
        ],
      ),
      child: child,
    );

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: !kIsWeb && defaultTargetPlatform == TargetPlatform.android
          ? surface
          : BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: surface,
            ),
    );
  }
}

class _AuthSignInSheetContent extends StatelessWidget {
  const _AuthSignInSheetContent({
    super.key,
    required this.showApple,
    required this.isGoogleLoading,
    required this.isAppleLoading,
    required this.onGoogleTap,
    required this.onAppleTap,
    required this.onEmailTap,
    required this.onGuestTap,
  });

  final bool showApple;
  final bool isGoogleLoading;
  final bool isAppleLoading;
  final VoidCallback? onGoogleTap;
  final VoidCallback? onAppleTap;
  final VoidCallback onEmailTap;
  final VoidCallback onGuestTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
          _SocialAuthButton(
            label: 'Continue with Google',
            isLoading: isGoogleLoading,
            onTap: onGoogleTap,
            icon: SvgPicture.asset(
              'assets/google_logo.svg',
              width: 24,
              height: 24,
              colorFilter: const ColorFilter.mode(
                AppTheme.charcoal50,
                BlendMode.srcIn,
              ),
            ),
          ),
          if (showApple) ...[
            const SizedBox(height: 16),
            _SocialAuthButton(
              label: 'Continue with Apple',
              isLoading: isAppleLoading,
              onTap: onAppleTap,
              icon: SvgPicture.asset(
                IconAssets.getPath('apple'),
                width: 24,
                height: 24,
                colorFilter: const ColorFilter.mode(
                  AppTheme.charcoal50,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          SecondaryButton(
            height: _authButtonHeight,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            onTap: onEmailTap,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  IconAssets.getPath('email-alt2'),
                  width: 24,
                  height: 24,
                  colorFilter: const ColorFilter.mode(
                    _signInCoral,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Continue with email',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _signInCoral,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 2,
                  color: AppTheme.ocean100,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'OR',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryOcean,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  height: 2,
                  color: AppTheme.ocean100,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SecondaryButton(
            height: _authButtonHeight,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            onTap: onGuestTap,
            child: Text(
              'Continue as Guest',
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _signInCoral,
              ),
            ),
          ),
        ],
    );
  }
}

class _SocialAuthButton extends StatelessWidget {
  const _SocialAuthButton({
    required this.label,
    required this.icon,
    required this.isLoading,
    required this.onTap,
  });

  final String label;
  final Widget icon;
  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PrimaryButton(
      width: double.infinity,
      height: _authButtonHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      onTap: onTap ?? () {},
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isLoading)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppTheme.charcoal50,
              ),
            )
          else ...[
            icon,
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.charcoal50,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmailAuthSheetContent extends StatelessWidget {
  const _EmailAuthSheetContent({
    super.key,
    required this.formKey,
    required this.isSignUp,
    required this.isLoading,
    required this.emailController,
    required this.passwordController,
    required this.onBack,
    required this.onSubmit,
    required this.onModeChanged,
  });

  final GlobalKey<FormState> formKey;
  final bool isSignUp;
  final bool isLoading;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final VoidCallback onBack;
  final VoidCallback? onSubmit;
  final ValueChanged<bool> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
            Row(
              children: [
                SecondaryButton(
                  width: 48,
                  height: 48,
                  padding: EdgeInsets.zero,
                  onTap: onBack,
                  child: SvgPicture.asset(
                    IconAssets.getLinePath('arrow-left-alt2'),
                    width: 24,
                    height: 24,
                    colorFilter: const ColorFilter.mode(
                      AppTheme.charcoal900,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Sign in with email',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.06,
                      color: AppTheme.charcoal900,
                    ),
                  ),
                ),
                const SizedBox(width: 48, height: 48),
              ],
            ),
            const SizedBox(height: 16),
            _AuthModeSegmentedToggle(
              isSignUp: isSignUp,
              onChanged: onModeChanged,
            ),
            const SizedBox(height: 32),
            _AuthGlassTextField(
              controller: emailController,
              iconName: 'email-alt2',
              hintText: 'Email',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your email';
                }
                if (!RegExp(
                  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                ).hasMatch(value.trim())) {
                  return 'Please enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _AuthGlassTextField(
              controller: passwordController,
              iconName: 'lock-locked',
              hintText: 'Password',
              obscureText: true,
              textInputAction: TextInputAction.done,
              autofillHints: isSignUp
                  ? const [AutofillHints.newPassword]
                  : const [AutofillHints.password],
              onFieldSubmitted: (_) => onSubmit?.call(),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your password';
                }
                if (value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),
            PrimaryButton(
              width: double.infinity,
              height: _authButtonHeight,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              onTap: onSubmit ?? () {},
              child: isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppTheme.charcoal50,
                      ),
                    )
                  : Text(
                      isSignUp ? 'Create Account' : 'Sign in',
                      style: _authButtonTextStyle(color: AppTheme.charcoal50),
                    ),
            ),
          ],
        ),
    );
  }
}

class _AuthModeSegmentedToggle extends StatelessWidget {
  const _AuthModeSegmentedToggle({
    required this.isSignUp,
    required this.onChanged,
  });

  static const _segmentGap = 12.0;

  final bool isSignUp;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _authButtonHeight,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(200),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const _AuthModeToggleTrack(),
            const _AuthModeToggleTrackInnerShadow(),
            Padding(
              padding: const EdgeInsets.all(4),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final segmentWidth =
                      (constraints.maxWidth - _segmentGap) / 2;
                  final pillLeft =
                      isSignUp ? segmentWidth + _segmentGap : 0.0;

                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 250),
                        curve: _authMotionCurve,
                        left: pillLeft,
                        top: 0,
                        bottom: 0,
                        width: segmentWidth,
                        child: const PrimaryButtonSurface(),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => onChanged(false),
                              child: Center(
                                child: Text(
                                  'Sign in',
                                  style: GoogleFonts.nunito(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    height: 24 / 16,
                                    color: isSignUp
                                        ? AppTheme.ocean900
                                        : AppTheme.charcoal50,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: _segmentGap),
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => onChanged(true),
                              child: Center(
                                child: Text(
                                  'Create Account',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.nunito(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    height: 24 / 16,
                                    color: isSignUp
                                        ? AppTheme.charcoal50
                                        : AppTheme.ocean900,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthModeToggleTrack extends StatelessWidget {
  const _AuthModeToggleTrack();

  @override
  Widget build(BuildContext context) {
    final track = DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.charcoal50.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(200),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 2),
        ],
      ),
    );

    if (kIsWeb || defaultTargetPlatform == TargetPlatform.android) {
      return track;
    }

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: track,
    );
  }
}

class _AuthModeToggleTrackInnerShadow extends StatelessWidget {
  const _AuthModeToggleTrackInnerShadow();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(200),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.96),
              blurRadius: 2,
              offset: const Offset(-1, -1),
              blurStyle: BlurStyle.inner,
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.96),
              blurRadius: 2,
              offset: const Offset(1, 1),
              blurStyle: BlurStyle.inner,
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.75),
              blurRadius: 8,
              offset: const Offset(0, 4),
              blurStyle: BlurStyle.inner,
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthGlassTextField extends StatelessWidget {
  const _AuthGlassTextField({
    required this.controller,
    required this.iconName,
    required this.hintText,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onFieldSubmitted,
    this.validator,
  });

  final TextEditingController controller;
  final String iconName;
  final String hintText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onFieldSubmitted;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    final fieldBody = Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.charcoal50.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(200),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.96),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.96),
            blurRadius: 2,
            offset: const Offset(-1, -1),
            blurStyle: BlurStyle.inner,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.96),
            blurRadius: 2,
            offset: const Offset(1, 1),
            blurStyle: BlurStyle.inner,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
            blurStyle: BlurStyle.inner,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.75),
            blurRadius: 16,
            offset: const Offset(0, 16),
            blurStyle: BlurStyle.inner,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SvgPicture.asset(
            IconAssets.getPath(iconName),
            width: 24,
            height: 24,
            colorFilter: const ColorFilter.mode(
              _signInCoral,
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Theme(
              data: Theme.of(context).copyWith(
                inputDecorationTheme: const InputDecorationTheme(
                  filled: true,
                  fillColor: Colors.transparent,
                ),
              ),
              child: TextFormField(
                controller: controller,
                obscureText: obscureText,
                keyboardType: keyboardType,
                textInputAction: textInputAction,
                autofillHints: autofillHints,
                onFieldSubmitted: onFieldSubmitted,
                validator: validator,
                cursorColor: AppTheme.charcoal900,
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  height: 1,
                  color: AppTheme.charcoal900,
                ),
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    height: 1,
                    color: AppTheme.charcoal500,
                  ),
                  filled: true,
                  fillColor: Colors.transparent,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  isDense: true,
                  isCollapsed: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(200)),
        boxShadow: [
          BoxShadow(color: Color(0x0A000000), blurRadius: 2, spreadRadius: 1),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(200),
        child: !kIsWeb && defaultTargetPlatform == TargetPlatform.android
            ? fieldBody
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: fieldBody,
              ),
      ),
    );
  }
}
