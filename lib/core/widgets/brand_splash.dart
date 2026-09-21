import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'logo_widget.dart';

const _splashColor = Color(0xFF669DF2);
const _holdDuration = Duration(milliseconds: 900);
const _fadeDuration = Duration(milliseconds: 420);
const _resumeAfter = Duration(milliseconds: 600);

class BrandSplashHost extends StatefulWidget {
  const BrandSplashHost({
    super.key,
    required this.child,
    required this.showOnLaunch,
  });

  final Widget child;
  final bool showOnLaunch;

  @override
  State<BrandSplashHost> createState() => _BrandSplashHostState();
}

class _BrandSplashHostState extends State<BrandSplashHost>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _fade;
  Timer? _holdTimer;
  DateTime? _pausedAt;
  var _visible = false;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(
      vsync: this,
      duration: _fadeDuration,
      value: 1,
    );
    WidgetsBinding.instance.addObserver(this);
    if (widget.showOnLaunch && _isMobile) {
      _visible = true;
      _scheduleHold();
    }
  }

  bool get _isMobile => Platform.isIOS || Platform.isAndroid;

  void _scheduleHold() {
    _holdTimer?.cancel();
    _holdTimer = Timer(_holdDuration, _dismiss);
  }

  Future<void> _present() async {
    _holdTimer?.cancel();
    _fade.value = 1;
    if (mounted) {
      setState(() => _visible = true);
    }
    _scheduleHold();
  }

  Future<void> _dismiss() async {
    if (!_visible || !mounted) return;
    await _fade.reverse();
    if (mounted) {
      setState(() => _visible = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isMobile) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _pausedAt = DateTime.now();
      return;
    }
    if (state != AppLifecycleState.resumed) return;
    final pausedAt = _pausedAt;
    _pausedAt = null;
    if (pausedAt == null) return;
    if (DateTime.now().difference(pausedAt) < _resumeAfter) return;
    _present();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _holdTimer?.cancel();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_visible)
          FadeTransition(
            opacity: _fade,
            child: const AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle.light,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(color: _splashColor),
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 48),
                      child: ForgottenThingsLogo(
                        assetPath: 'assets/clue_logo.svg',
                        height: 72,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
