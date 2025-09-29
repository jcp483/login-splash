import 'dart:async';
import 'package:flutter/material.dart';

enum SheetMode { onboarding, login }
enum AuthPane { microsoft, admin }


class SplashRoot extends StatefulWidget {
  const SplashRoot({super.key});

  
  @override
  State<SplashRoot> createState() => _SplashRootState();
}


class _SplashRootState extends State<SplashRoot> with TickerProviderStateMixin {
  // ---- Splash sequence state ----
  bool _teaser = true;
  bool _sheetVisible = false;
  double _sheetSize = _minSize;
  

  int _phase = 0; // 0..4
  late final AnimationController _titleCtrl;
  Timer? _sequenceTimer;

  // ---- Bottom sheet state ----
  final _sheetCtrl = DraggableScrollableController();
  SheetMode _mode = SheetMode.onboarding;
  AuthPane _authPane = AuthPane.microsoft;

  // Sheet sizes: collapsed peek + expanded panel
  static const double _minSize = 0.10;
  static const double _maxSize = 0.45;

  // Slower timings & distinct sizes per frame
  static const _phaseDurations = <Duration>[
    Duration(milliseconds: 650),
    Duration(milliseconds: 650),
    Duration(milliseconds: 650),
    Duration(milliseconds: 900), // title fade-in
    Duration(milliseconds: 800),
  ];
  static const _sizes = <double>[116, 204, 204, 204, 204];

  @override
  void initState() {
    super.initState();
    _titleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _runSplashSequence();

  }

  void _runSplashSequence() {
  int i = 0;
  void step() {
    if (!mounted) return;
    setState(() => _phase = i.clamp(0, 4));
    if (i == 3) _titleCtrl.forward();

    if (i++ < _phaseDurations.length - 1) {
      _sequenceTimer = Timer(_phaseDurations[i], step);
    } else {
      // ✅ Splash done → reveal the sheet after a tiny pause
     Future.delayed(const Duration(milliseconds: 150), () {
  if (!mounted) return;
  setState(() {
    _sheetVisible = true;  // reveal teaser/real sheet later
    _teaser = true;        // start with teaser (blank pull-up)
  });
});
    }
  }
  _sequenceTimer = Timer(_phaseDurations.first, step);
}

  @override
  void dispose() {
    _sequenceTimer?.cancel();
    _titleCtrl.dispose();
    _sheetCtrl.dispose();
    super.dispose();
  }

  // Called by Onboarding when user taps Start
  Future<void> _completeOnboarding() async {
    // Wait a frame to ensure controller is attached.
    await Future.delayed(Duration.zero);
    if (!mounted) return;
    try {
      await _sheetCtrl.animateTo(
        _minSize,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
      );
    } catch (_) {
      // ignore if not yet attached
    }
    if (!mounted) return;
    setState(() {
      _mode = SheetMode.login;
      _authPane = AuthPane.microsoft;
    });
  }

  Future<void> _goOnboarding() async {
  // optional: nudge logo upward before transition
  setState(() => _sheetSize = _maxSize);
  await Future.delayed(const Duration(milliseconds: 120));

  // Navigate to your full-screen onboarding
  // If you already have an OnboardingScreen route, use pushNamed.
  await Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const OnboardingScreen()),
  );

  // Back from onboarding → show the real login sheet
  setState(() {
    _teaser = false;          // switch from teaser to real sheet
    _sheetSize = _minSize;    // reset logo position
  });

  // Start listening to the real DraggableScrollableSheet now
}


  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final images = [
      'assets/logo_stage1.png',
      'assets/logo_stage2.png',
      'assets/logo_stage3.png',
      'assets/logo_badge.png',
      'assets/logo_badge.png',
    ];

    final bool lockCenter = _teaser || !_sheetVisible; // teaser covers screen


    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Centered splash visuals
            // Centered initially; animates to top as the sheet expands
            
           // Logo/title that stays centered during splash + teaser,
// then slides up & shrinks as the REAL pull-up sheet expands.

            AnimatedAlign(
              alignment: lockCenter
                  ? Alignment.center
                  : (_sheetSize > 0.35 ? Alignment.topCenter : Alignment.center),
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOut,
              child: Padding(
                padding: EdgeInsets.only(
                  top: (!lockCenter && _sheetSize > 0.35) ? 28 : 0,
                ),
                child: _ScaledSplash(
                  // 1.00 → 0.88 as sheet goes from min → max; locked at 1.0 during teaser/splash
                  scale: lockCenter
                      ? 1.0
                      : (() {
                          final k = ((_sheetSize - _minSize) / (_maxSize - _minSize))
                              .clamp(0.0, 1.0);
                          return 1.0 - 0.12 * k;
                        })(),
                  phase: _phase,
                  sizes: _sizes, // e.g., [116, 204, 204, 204, 204] per your Figma
                  images: const [
                    'assets/logo_stage1.png',
                    'assets/logo_stage2.png',
                    'assets/logo_stage3.png',
                    'assets/logo_badge.png',
                    'assets/logo_badge.png',
                  ],
                  titleOpacity: _titleCtrl,
                  textTheme: Theme.of(context).textTheme,
                ),
              ),
            ),

            // Pull-up bottom sheet (anchored at the bottom of the screen)
            if(_sheetVisible) 
              if (_sheetVisible)
  Align(
    alignment: Alignment.bottomCenter,
    child: _teaser
        // --- Teaser (blank; no controller used) ---
        ? _TeaserSheet(
            onTrigger: _goOnboarding,
          )
        // --- Real draggable sheet (single instance with controller) ---
        : NotificationListener<DraggableScrollableNotification>(
            onNotification: (n) {
              setState(() => _sheetSize = n.extent);
              return false;
            },
            child: _PullUpSheet(
              //key: const ValueKey('realSheet'), // stabilizes rebuilds
              controller: _sheetCtrl,
              minSize: _minSize,
              maxSize: _maxSize,
              childBuilder: (context, scrollController) {
                return _LoginPane(
                  pane: _authPane,
                  onPaneChange: (p) => setState(() => _authPane = p),
                );
              },
            ),
          ),
        )
          ],
        ),
      ),
    );
  }
}

/// Bottom pull-up container with a grabber and rounded top corners.
/// Uses a ListView to avoid SliverFillRemaining constraint issues.
class _PullUpSheet extends StatelessWidget {
  final DraggableScrollableController controller;
  final double minSize;
  final double maxSize;
  final Widget Function(BuildContext, ScrollController) childBuilder;

  const _PullUpSheet({
    required this.controller,
    required this.minSize,
    required this.maxSize,
    required this.childBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      controller: controller,
      initialChildSize: minSize,
      minChildSize: minSize,
      maxChildSize: maxSize,
      expand: false, // keep stable; you can re-enable snap later if desired
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                blurRadius: 24,
                offset: Offset(0, -8),
                color: Color(0x1F000000),
              )
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.only(bottom: 20),
            children: [
              const SizedBox(height: 8),
              // Grabber
              Center(
                child: Container(
                  width: 90,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Dynamic pane content
              Builder(
                builder: (context) => childBuilder(context, scrollController),
              ),
            ],
          ),
        );
      },
    );
  }
}

/* ----------------------- ONBOARDING ----------------------- */

class _OnboardingPane extends StatefulWidget {
  final VoidCallback onFinish;
  final bool showHeader;
  final bool fullscreen;  
  const _OnboardingPane({
    required this.onFinish,
    this.showHeader = true,
    this.fullscreen = false,
    super.key,
    });

  @override
  State<_OnboardingPane> createState() => _OnboardingPaneState();
}

class _OnboardingPaneState extends State<_OnboardingPane> {
  final _page = PageController();
  int _index = 0;

  final _slides = const [
    _Slide(
      image: 'assets/onb1.png',
      body:
          'Connect smarter, check availability and request meetings without knocking.',
    ),
    _Slide(
      image: 'assets/onb2.png',
      body:
          'Set when you’re available, manage student requests, and avoid interruptions.',
    ),
    _Slide(
      image: 'assets/onb3.png',
      body:
          'Skip the knocking, skip the hassle, knock through your phone instead.',
    ),
  ];

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    // Reusable slide content (art + body)
    Widget slideContent(_Slide s) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 260,
              height: 170,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 20,
                    offset: Offset(0, 10),
                    color: Color(0x14000000),
                  )
                ],
              ),
              alignment: Alignment.center,
              child: Image.asset(s.image, width: 160, fit: BoxFit.contain),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                s.body,
                style: t.titleMedium?.copyWith(color: Colors.black87),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        );

    // PageView used in both modes
    Widget pager(double height) => SizedBox(
          height: height,
          child: PageView.builder(
            controller: _page,
            onPageChanged: (i) => setState(() => _index = i),
            itemCount: _slides.length,
            itemBuilder: (_, i) => slideContent(_slides[i]),
          ),
        );

    final isFull = widget.fullscreen && !widget.showHeader;

   if (isFull) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final h = constraints.maxHeight;

      // Bigger art area so the 318x191 fits comfortably
      final slideHeight = h * 0.46; // tweak 0.44–0.50 if needed

      Widget pager() => SizedBox(
        height: slideHeight,
        child: PageView.builder(
          controller: _page,
          onPageChanged: (i) => setState(() => _index = i),
          itemCount: _slides.length,
          itemBuilder: (_, i) {
            final s = _slides[i];
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Card behind the PNG (keeps your shadowed look)
                Container(
                  width: 340, // a bit wider than the PNG
                  height: 210,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        blurRadius: 20,
                        offset: Offset(0, 10),
                        color: Color(0x14000000),
                      )
                    ],
                  ),
                  alignment: Alignment.center,
                  // 🔶 Figma sizes for the PNG
                  child: Image.asset(
                    s.image,
                    width: 318,
                    height: 191,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    s.body,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: Colors.black87),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            );
          },
        ),
      );

      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, // ⬅️ hard center
          children: [
            pager(),
            const SizedBox(height: 16),
            _Dots(count: _slides.length, index: _index),
            const SizedBox(height: 18),

            // 🔶 Next button — Figma 120x45, brand yellow, pill radius
            Center(
              child: SizedBox(
                width: 120,
                height: 45,
                child: FilledButton(
                  onPressed: () {
                    if (_index < _slides.length - 1) {
                      _page.nextPage(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOut,
                      );
                    } else {
                      widget.onFinish();
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF4C21A), // brand yellow
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text('Next'),
                      SizedBox(width: 6),
                      Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 18),

            // 🔶 Back button — 50x50 circular, under Next
            Center(
              child: IconButton(
                onPressed: _index == 0
                    ? null
                    : () => _page.previousPage(
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOut,
                        ),
                icon: const Icon(Icons.chevron_left_rounded),
                style: IconButton.styleFrom(
                  shape: const CircleBorder(),
                  backgroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFEDEDED),
                  // force exact size
                  fixedSize: const Size(50, 50),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}



    // SHEET MODE (existing layout; header at top)
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (widget.showHeader) ...[
            Text('Login', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            Text('Welcome Back!',
                style: t.bodyMedium?.copyWith(color: Colors.black54, fontWeight: FontWeight.w400)),
            const SizedBox(height: 8),
          ],
          pager(320), // fixed height inside sheet
          const SizedBox(height: 10),
          _Dots(count: _slides.length, index: _index),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton.filledTonal(
                onPressed: _index == 0
                    ? null
                    : () => _page.previousPage(
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOut,
                        ),
                style: IconButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(14),
                ),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () {
                  if (_index < _slides.length - 1) {
                    _page.nextPage(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOut,
                    );
                  } else {
                    widget.onFinish();
                  }
                },
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_index < _slides.length - 1 ? 'Next' : 'Start'),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Slide {
  final String image;
  final String body;
  const _Slide({required this.image, required this.body});
}

class _Dots extends StatelessWidget {
  final int count;
  final int index;
  const _Dots({super.key, required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 18,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(count, (i) {
          final active = i == index;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 5),
            height: 6,
            width: active ? 26 : 6,
            decoration: BoxDecoration(
              color: active ? Colors.black87 : Colors.black26,
              borderRadius: BorderRadius.circular(6),
            ),
          );
        }),
      ),
    );
  }
}

/* ------------------------ LOGIN PANE ------------------------ */

class _LoginPane extends StatefulWidget {
  final AuthPane pane;
  final ValueChanged<AuthPane> onPaneChange;

  const _LoginPane({
    required this.pane,
    required this.onPaneChange,
  });

  @override
  State<_LoginPane> createState() => _LoginPaneState();
}

class _LoginPaneState extends State<_LoginPane> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pwd = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _pwd.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Column(
        children: [
          Text('Login', style: t.titleLarge),
          Text('Welcome Back!',
              style: t.bodyMedium?.copyWith(color: Colors.black54)),
          const SizedBox(height: 10),

          if (widget.pane == AuthPane.microsoft)
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      // TODO: hook up MSAL / OAuth here
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Microsoft Sign-in (stub)')),
                      );
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: const Color(0xFFF4C21A),
                      foregroundColor: Colors.black,
                      textStyle: const TextStyle(fontWeight: FontWeight.w500),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Sign in with Microsoft'),
                  ),
                ),
                const SizedBox(height: 14),
                TextButton(
                  onPressed: () => widget.onPaneChange(AuthPane.admin),
                  child: const Text('Admin Login'),
                ),
              ],
            ),

          if (widget.pane == AuthPane.admin)
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Admin Email',
                      prefixIcon: const Icon(Icons.mail_outline),
                      filled: true,
                      fillColor: const Color(0xFFF7F7F8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Email required' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _pwd,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                            _obscure ? Icons.visibility : Icons.visibility_off),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF7F7F8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Password required' : null,
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _loading
                          ? null
                          : () async {
                              if (_formKey.currentState?.validate() != true) return;
                              setState(() => _loading = true);
                              await Future.delayed(
                                  const Duration(milliseconds: 900));
                              if (!mounted) return;
                              setState(() => _loading = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Admin login (stub)')),
                              );
                            },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: const Color(0xFFF4C21A),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Sign in as Admin'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => widget.onPaneChange(AuthPane.microsoft),
                    child: const Text('Back to Microsoft Login'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ScaledSplash extends StatelessWidget {
  final double scale;
  final int phase;
  final List<double> sizes;
  final List<String> images;
  final Animation<double> titleOpacity;
  final TextTheme textTheme;

  const _ScaledSplash({
    required this.scale,
    required this.phase,
    required this.sizes,
    required this.images,
    required this.titleOpacity,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      scale: scale,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: Container(
              key: ValueKey(phase),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 18,
                    offset: Offset(0, 10),
                    color: Color(0x1A000000),
                  )
                ],
              ),
              child: Image.asset(
                images[phase],
                width: sizes[phase],
                height: sizes[phase],
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 16),
          FadeTransition(
            opacity: titleOpacity,
            child: Column(
              children: [
                Text('KnockSense', style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                  'Where Availability Meets Simplicity.',
                  style: textTheme.bodyMedium?.copyWith(color: Colors.black54, fontWeight: FontWeight.w400),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TeaserSheet extends StatefulWidget {
  final VoidCallback onTrigger;
  final ValueChanged<double>? onProgress; // 0..1 for logo movement
  const _TeaserSheet({required this.onTrigger, this.onProgress});

  @override
  State<_TeaserSheet> createState() => _TeaserSheetState();
}

class _TeaserSheetState extends State<_TeaserSheet> {
  // How far the user has pulled up (in px), limited to _stretch
  double _pull = 0;
  static const double _peekHeight = 90; // visible height at rest
  static const double _stretch = 28;    // how much it can “flex” before triggering

  void _reportProgress() {
    final p = (_pull.abs() / _stretch).clamp(0.0, 1.0); // 0..1
    widget.onProgress?.call(p);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragUpdate: (d) {
        if (d.primaryDelta == null) return;
        // Negative delta = dragging up
        final next = (_pull + (-d.primaryDelta!)).clamp(0.0, _stretch);
        setState(() => _pull = next);
        _reportProgress();
      },
      onVerticalDragEnd: (d) {
        final v = d.velocity.pixelsPerSecond.dy; // negative = up
        final trigger = _pull >= (_stretch * 0.6) || v < -500;
        if (trigger) {
          widget.onTrigger();
        } else {
          setState(() => _pull = 0);
          _reportProgress();
        }
      },
      onTap: widget.onTrigger, // tap also starts onboarding
      child: Container(
        // Slight elastic feel as you pull
        height: _peekHeight + _pull,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(blurRadius: 24, offset: Offset(0, -8), color: Color(0x1F000000)),
          ],
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            // Grabber
            Container(
              width: 90,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 14),
            // Intentionally “blank” — matches your Figma teaser
          ],
        ),
      ),
    );
  }
}

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        // Reuse your existing onboarding content; “Start” should pop:
        child: _OnboardingPane(
          showHeader: false,
          fullscreen: true,
          onFinish: () => Navigator.of(context).pop(), // done → return
        ),
      ),
    );
  }
}
