import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'dart:ui' show ImageFilter;
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../Items/building_items.dart';
import '../Items/building_special.dart';
import '../theme/theme_provider.dart';
// Local soft-shadow helper to avoid extra imports in this screen.

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin {
  static const String _tigerIdleAsset =
      'assets/images/map/tiger/tiger_idle1.png';
  static const String _tigerTalkingAsset =
      'assets/images/map/tiger/tiger_talking1.png';
  static const String _tigerExcitedTalkingAsset =
      'assets/images/map/tiger/tiger_excited_talking1.png';
  static const String _tigerLinesAsset = 'assets/data/tiger_lines.json';
  static const Duration _tigerTalkDuration = Duration(seconds: 2);
  static const double _tigerExcitedTalkProbability = 0.35;

  // Tiger + action row transition tuning
  static const Duration _actionBarTransitionDuration = Duration(
    milliseconds: 180,
  );
  static const Curve _actionBarInCurve = Curves.easeOutCubic;
  static const Curve _actionBarOutCurve = Curves.easeInCubic;
  static const double _actionBarSlideDistance = 0.18;
  static const Duration _navigateOverlayEnterDuration = Duration(
    milliseconds: 240,
  );
  static const double _navigateOverlayEnterYOffset = 28.0;
  static const Duration _mapAutoLineInterval = Duration(seconds: 5);
  static const Duration _infoAutoLineInterval = Duration(seconds: 5);
  static const Duration _infoAutoResumeDelay = Duration(seconds: 5);
  static const Duration _infoImageScrollDuration = Duration(milliseconds: 360);

  // Tiger tuning: map mode (no info/navigation overlay open).
  // Normalized placement where x/y are 0.0..1.0.
  static const double _tigerMapViewportX = 1.0;
  static const double _tigerMapViewportY = 1.0;
  static const double _tigerMapViewportXOffset = 50.0;
  static const double _tigerMapViewportYOffset = 0.0;
  static const double _tigerMapLiftWhenActionsVisible = 55.0;

  // Tiger tuning: info/navigation mode (overlay open).
  static const double _tigerOverlayViewportX = 1.0;
  static const double _tigerOverlayViewportY = 1.0;
  static const double _tigerOverlayViewportXOffset = 100.0;
  static const double _tigerOverlayViewportYOffset = 0.0;

  // Tiger size tuning.
  static const double _tigerSize = 256.0;
  static const double _tigerOverlayScale = 1.24;
  static const double _tigerHeightFactor = 0.20;

  // Chat bubble tuning: map mode.
  static const double _tigerBubbleWidthFactor = 0.56;
  static const double _tigerBubbleMinWidth = 170.0;
  static const double _tigerBubbleMaxWidth = 260.0;
  static const double _tigerBubbleXOffset = 60.0;
  static const double _tigerBubbleYOffset = 60.0;

  // Chat bubble tuning: info/navigation mode.
  static const double _tigerBubbleWidthFactorOverlay = 0.68;
  static const double _tigerBubbleMinWidthOverlay = 220.0;
  static const double _tigerBubbleMaxWidthOverlay = 220.0;
  static const double _tigerBubbleXOffsetOverlay = 60.0;
  static const double _tigerBubbleYOffsetOverlay = 60.0;

  // Shared bubble animation tuning.
  static const double _tigerBubbleOldXShift = 0.0;
  static const double _tigerBubbleStackGap = 16.0;
  static const double _tigerBubbleNewEntryDelayFraction = 0.7;
  static const Duration _tigerBubbleAnimationDuration = Duration(
    milliseconds: 240,
  );
  static const Map<String, List<String>> _buildingImageLines = {
    'airport': [
      'The airport is a place where students and visitors alike can hang out.',
      'The airport is also a place to pay or submit requirements to the registrar!',
      'The airport is also where you enroll as a new student!',
    ],
    'building_c': [
      'Building C is mainly a place for students to study in their classrooms.',
      'Building C also holds a canteen of their own!',
      'Building C also holds activities sometimes!',
    ],
    'building_b': [
      'Building B is a building for students. It also contains the Proware for clothes.',
      'This is the 3rd floor, a place to hang out, and also guides to the guidance office!',
      'This is the library, seen at the 7th floor. Be quiet over here!',
    ],
    'gym_top_right': [
      'This is the gym. This place holds two areas: one for events, and one for PE!',
      'This is usually where events get held in the Gym building!',
      'This is the underground area of the Gym building, made for students taking their PE classes!',
    ],
  };

  static const Map<String, List<String>> _buildingTigerExtraLines = {
    'airport': [
      'You can check announcements and student services around this area.',
      'If you are unsure where to queue, ask the staff at the counters.',
      'Peak hours can get busy, so arrive a little earlier.',
      'Most enrollment and payment concerns are handled in this building.',
      'Keep your documents ready so transactions are faster.',
    ],
    'building_c': [
      'Class schedules here can vary by floor, so check your room first.',
      'The hallways can get crowded between subjects.',
      'You can take a short break at the canteen before your next class.',
      'Student activities are often posted near common areas.',
      'This building is one of the main study spots on campus.',
    ],
    'building_b': [
      'If you need uniforms or supplies, Proware is the go-to stop.',
      'Guidance-related directions are easier to find on upper floors.',
      'Please keep voices low when passing the library area.',
      'Reading corners are best used quietly and respectfully.',
      'Building B is a solid place to study, shop, and ask for help.',
    ],
    'gym_top_right': [
      'Expect larger crowds here during school programs and assemblies.',
      'The event area is usually arranged based on the activity schedule.',
      'PE classes use the lower area for drills and practical exercises.',
      'Check posted schedules to know which section uses the gym.',
      'This is one of the most active buildings across the school day.',
    ],
  };

  late final TransformationController _transformationController;
  final GlobalKey _viewerKey = GlobalKey();
  String?
  _activeBuildingId; // building with overlay card open (also drives scale)
  bool _cardVisible = false; // when true, show the info card above the map
  _OverlayAction _activeAction =
      _OverlayAction.info; // which action's content to show
  bool _hasInitializedPosition = false;
  List<String> _tigerLines = const <String>[];
  final List<_TigerBubbleEntry> _visibleTigerBubbles = <_TigerBubbleEntry>[];
  int _nextTigerLineIndex = 0;
  int _nextTigerBubbleId = 0;
  final Random _random = Random();
  Timer? _tigerTalkTimer;
  Timer? _mapAutoLineTimer;
  Timer? _infoAutoPlaybackTimer;
  Timer? _infoAutoResumeTimer;
  late final PageController _infoImagePageController;
  String _activeTigerAsset = _tigerIdleAsset;

  late final AnimationController _zoomController;
  Matrix4? _zoomBegin;
  Matrix4? _zoomEnd;

  List<BoxShadow> _softShadow(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return [
        BoxShadow(
          color: Colors.black.withOpacity(0.10),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];
    } else {
      return const [
        BoxShadow(
          color: Color(0x1F000000),
          blurRadius: 8,
          offset: Offset(0, 4),
        ),
        BoxShadow(
          color: Color(0x14000000),
          blurRadius: 3,
          offset: Offset(0, 1.5),
        ),
      ];
    }
  }

  // Allow external callers (HomeScreen) to highlight a building
  void highlightBuilding(String buildingId) {
    final b = _tryGetBuilding(buildingId);
    if (b == null) return;
    setState(() {
      _activeBuildingId = buildingId;
      _cardVisible = false;
    });
    _zoomToBuilding(b);
  }

  BuildingItem? _tryGetBuilding(String buildingId) {
    for (final b in kBuildingItems) {
      if (b.id == buildingId) return b;
    }
    return null;
  }

  void _clearSelection() {
    if (_activeBuildingId == null && !_cardVisible) return;
    _stopInfoAutoPlayback();
    setState(() {
      _activeBuildingId = null;
      _cardVisible = false;
    });
    _startMapAutoLineLoop();
  }

  void _closeCard() {
    if (!_cardVisible) return;
    _stopInfoAutoPlayback();
    _tigerTalkTimer?.cancel();
    setState(() {
      _cardVisible = false;
      _visibleTigerBubbles.clear();
      _activeTigerAsset = _tigerIdleAsset;
    });
    _startMapAutoLineLoop();
  }

  void _onMapBackgroundTap() {
    // If a section card is open, tapping empty space should just close the card.
    if (_cardVisible) {
      _closeCard();
      return;
    }
    _clearSelection();
  }

  Future<void> _loadTigerLines() async {
    try {
      final raw = await rootBundle.loadString(_tigerLinesAsset);
      final decoded = jsonDecode(raw);
      final list = decoded is Map<String, dynamic> ? decoded['map_line'] : null;
      final parsed = list is List
          ? list
                .map((entry) {
                  if (entry is String) return entry.trim();
                  if (entry is Map) {
                    final line = entry['line'];
                    if (line is String) return line.trim();
                  }
                  return '';
                })
                .where((line) => line.isNotEmpty)
                .toList(growable: false)
          : const <String>[];

      if (!mounted) return;
      setState(() {
        _tigerLines = parsed;
        _nextTigerLineIndex = 0;
        _nextTigerBubbleId = 0;
        _visibleTigerBubbles.clear();
      });
      _startMapAutoLineLoop();
    } catch (error) {
      assert(() {
        debugPrint('[Map] Failed to load tiger lines: $error');
        return true;
      }());
    }
  }

  void _emitTigerLine(String line) {
    final trimmedLine = line.trim();
    if (trimmedLine.isEmpty || !mounted) return;

    final nextTalkAsset = _random.nextDouble() < _tigerExcitedTalkProbability
        ? _tigerExcitedTalkingAsset
        : _tigerTalkingAsset;
    _tigerTalkTimer?.cancel();

    setState(() {
      _visibleTigerBubbles.add(
        _TigerBubbleEntry(id: _nextTigerBubbleId++, text: trimmedLine),
      );
      if (_visibleTigerBubbles.length > 2) {
        _visibleTigerBubbles.removeAt(0);
      }
      _activeTigerAsset = nextTalkAsset;
    });

    _tigerTalkTimer = Timer(_tigerTalkDuration, () {
      if (!mounted) return;
      setState(() {
        _activeTigerAsset = _tigerIdleAsset;
      });
    });
  }

  void _animateTigerTalkOnly() {
    if (!mounted) return;
    final nextTalkAsset = _random.nextDouble() < _tigerExcitedTalkProbability
        ? _tigerExcitedTalkingAsset
        : _tigerTalkingAsset;
    _tigerTalkTimer?.cancel();

    setState(() {
      _activeTigerAsset = nextTalkAsset;
    });

    _tigerTalkTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() {
        _activeTigerAsset = _tigerIdleAsset;
      });
    });
  }

  void _startMapAutoLineLoop() {
    _mapAutoLineTimer?.cancel();
    _mapAutoLineTimer = Timer.periodic(_mapAutoLineInterval, (_) {
      if (!mounted || _cardVisible || _tigerLines.isEmpty) return;
      final line = _tigerLines[_nextTigerLineIndex % _tigerLines.length];
      _nextTigerLineIndex = (_nextTigerLineIndex + 1) % _tigerLines.length;
      _emitTigerLine(line);
    });
  }

  void _stopMapAutoLineLoop() {
    _mapAutoLineTimer?.cancel();
    _mapAutoLineTimer = null;
  }

  List<String> _infoLinesForBuilding(String buildingId) {
    final lines = _buildingImageLines[buildingId] ?? const <String>[];
    final imageCount = _infoImagePathsForBuilding(buildingId).length;
    final total = min(lines.length, imageCount);
    if (total <= 0) return const <String>[];
    return lines.take(total).toList(growable: false);
  }

  void _onInfoImageChanged(String buildingId, int index) {
    if (!mounted ||
        !_cardVisible ||
        _activeAction != _OverlayAction.info ||
        _activeBuildingId != buildingId) {
      return;
    }

    final lines = _infoLinesForBuilding(buildingId);
    if (index < 0 || index >= lines.length) return;
    _emitTigerLine(lines[index]);
  }

  void _startInfoAutoPlayback(String buildingId) {
    _stopInfoAutoPlayback();
    final lines = _infoLinesForBuilding(buildingId);
    if (lines.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_cardVisible ||
          _activeAction != _OverlayAction.info ||
          _activeBuildingId != buildingId) {
        return;
      }
      if (_infoImagePageController.hasClients) {
        _infoImagePageController.jumpToPage(0);
      }
    });

    _emitTigerLine(lines.first);
    if (lines.length == 1) return;

    int nextIndex = 1;
    _infoAutoPlaybackTimer = Timer.periodic(_infoAutoLineInterval, (timer) {
      if (!mounted ||
          !_cardVisible ||
          _activeAction != _OverlayAction.info ||
          _activeBuildingId != buildingId) {
        timer.cancel();
        return;
      }

      if (nextIndex >= lines.length) {
        timer.cancel();
        return;
      }

      if (_infoImagePageController.hasClients) {
        _infoImagePageController.animateToPage(
          nextIndex,
          duration: _infoImageScrollDuration,
          curve: Curves.easeOutCubic,
        );
      } else {
        _onInfoImageChanged(buildingId, nextIndex);
      }

      if (nextIndex >= lines.length - 1) {
        timer.cancel();
        return;
      }

      nextIndex++;
    });
  }

  void _startInfoAutoPlaybackFromCurrent(String buildingId) {
    _infoAutoPlaybackTimer?.cancel();
    final lines = _infoLinesForBuilding(buildingId);
    if (lines.length <= 1) return;

    int currentIndex = 0;
    if (_infoImagePageController.hasClients) {
      final page = _infoImagePageController.page;
      if (page != null) {
        currentIndex = page.round().clamp(0, lines.length - 1);
      }
    }

    int nextIndex = currentIndex + 1;

    bool advance(Timer? timer) {
      if (!mounted ||
          !_cardVisible ||
          _activeAction != _OverlayAction.info ||
          _activeBuildingId != buildingId) {
        timer?.cancel();
        return true;
      }

      if (nextIndex >= lines.length) {
        timer?.cancel();
        return true;
      }

      if (_infoImagePageController.hasClients) {
        _infoImagePageController.animateToPage(
          nextIndex,
          duration: _infoImageScrollDuration,
          curve: Curves.easeOutCubic,
        );
      } else {
        _onInfoImageChanged(buildingId, nextIndex);
      }

      final reachedLast = nextIndex >= lines.length - 1;
      nextIndex++;
      if (reachedLast) {
        timer?.cancel();
        return true;
      }
      return false;
    }

    if (advance(null)) return;

    _infoAutoPlaybackTimer = Timer.periodic(_infoAutoLineInterval, (timer) {
      advance(timer);
    });
  }

  void _scheduleInfoAutoResume(String buildingId) {
    _infoAutoResumeTimer?.cancel();
    _infoAutoResumeTimer = Timer(_infoAutoResumeDelay, () {
      if (!mounted ||
          !_cardVisible ||
          _activeAction != _OverlayAction.info ||
          _activeBuildingId != buildingId) {
        return;
      }
      _startInfoAutoPlaybackFromCurrent(buildingId);
    });
  }

  void _onInfoManualScrollStart(String buildingId) {
    if (!_cardVisible ||
        _activeAction != _OverlayAction.info ||
        _activeBuildingId != buildingId) {
      return;
    }
    _stopInfoAutoPlayback(cancelResumeTimer: false);
    _scheduleInfoAutoResume(buildingId);
  }

  void _stopInfoAutoPlayback({bool cancelResumeTimer = true}) {
    _infoAutoPlaybackTimer?.cancel();
    _infoAutoPlaybackTimer = null;
    if (cancelResumeTimer) {
      _infoAutoResumeTimer?.cancel();
      _infoAutoResumeTimer = null;
    }
  }

  void _onTigerTap() {
    final lines = _resolveTigerLines();
    if (lines.isEmpty) return;

    final line = lines[_nextTigerLineIndex % lines.length];
    _nextTigerLineIndex = (_nextTigerLineIndex + 1) % lines.length;
    _emitTigerLine(line);
  }

  List<String> _resolveTigerLines() {
    final activeBuildingId = _activeBuildingId;
    if (_cardVisible && activeBuildingId != null) {
      final extraLines = _buildingTigerExtraLines[activeBuildingId];
      if (extraLines != null && extraLines.isNotEmpty) {
        return extraLines;
      }
    }
    return _tigerLines;
  }

  void _openBuildingAction(_OverlayAction action) {
    final activeBuildingId = _activeBuildingId;
    if (activeBuildingId == null) return;

    _stopMapAutoLineLoop();
    _stopInfoAutoPlayback();
    _tigerTalkTimer?.cancel();

    setState(() {
      _activeAction = action;
      _cardVisible = true;
      _visibleTigerBubbles.clear();
      _activeTigerAsset = _tigerIdleAsset;
    });

    if (action == _OverlayAction.info) {
      _startInfoAutoPlayback(activeBuildingId);
    } else {
      _animateTigerTalkOnly();
    }
  }

  void _cancelZoomAnimation() {
    // Null out BEFORE reset so _onZoomTick won't snap back to _zoomBegin
    _zoomBegin = null;
    _zoomEnd = null;
    _zoomController.reset();
  }

  void _animateTransformTo(Matrix4 target) {
    // Null out BEFORE reset so _onZoomTick won't snap back to old _zoomBegin
    _zoomBegin = null;
    _zoomEnd = null;
    _zoomController.reset();
    _zoomBegin = _transformationController.value.clone();
    _zoomEnd = target.clone();
    _zoomController.forward();
  }

  /// Compute building center in the coordinate space of the constrained child.
  /// With constrained:true, the SizedBox(1024,768) is sized to the viewport.
  /// Building widget width = b.scale * MapSpec.width (absolute px, unclamped).
  /// Align formula: offset = (parent - child) * (alignment + 1) / 2.
  Offset _buildingViewportCenter(BuildingItem b, Size viewportSize) {
    final cw = b.scale * MapSpec.width;
    final cx = (viewportSize.width - cw) * (b.x + 1) / 2.0 + cw / 2.0;
    final cy = (b.y + 1) / 2.0 * viewportSize.height;
    return Offset(cx, cy);
  }

  void _zoomToBuilding(BuildingItem b) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final viewerContext = _viewerKey.currentContext;
      if (viewerContext == null) return;
      final render = viewerContext.findRenderObject();
      if (render is! RenderBox || !render.hasSize) return;

      final vp = render.size;
      final currentScale = _transformationController.value.getMaxScaleOnAxis();
      // Use 2.4 as default, but if user is zoomed in more, bring it back down to 2.4
      final targetScale = currentScale > 2.4
          ? 2.4
          : (currentScale < 2.4 ? 2.4 : currentScale);

      final center = _buildingViewportCenter(b, vp);

      assert(() {
        debugPrint(
          '[Map] Zoom → ${b.id}: center=(${center.dx.toStringAsFixed(1)}, ${center.dy.toStringAsFixed(1)}), vp=(${vp.width.toStringAsFixed(0)}x${vp.height.toStringAsFixed(0)})',
        );
        return true;
      }());

      final target = Matrix4.identity()
        ..translate(vp.width / 2, vp.height / 2)
        ..scale(targetScale)
        ..translate(-center.dx, -center.dy);

      _animateTransformTo(target);
    });
  }

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _infoImagePageController = PageController(viewportFraction: 1.0);

    _zoomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _zoomController.addListener(_onZoomTick);
    _loadTigerLines();
    _startMapAutoLineLoop();
  }

  void _onZoomTick() {
    final begin = _zoomBegin;
    final end = _zoomEnd;
    if (begin == null || end == null) return;
    final t = Curves.easeOutCubic.transform(_zoomController.value);
    final lerped = Matrix4Tween(begin: begin, end: end).lerp(t);
    _transformationController.value = lerped;
  }

  bool _hasNavigationImages(String buildingId) {
    switch (buildingId) {
      case 'gym_top_right':
      case 'building_b':
      case 'building_c':
      case 'airport':
        return true;
      default:
        return false;
    }
  }

  String _buildActionBodyText(BuildingOverlaySpec spec) {
    switch (_activeAction) {
      case _OverlayAction.info:
        return '';
      case _OverlayAction.navigate:
        // If a building has a dedicated navigation image, let the image be the content.
        if (_hasNavigationImages(spec.id)) return '';
        return spec.navigateText ??
            'Navigate to ${spec.title}. This opens your preferred maps app with campus directions and nearest entrances.';
    }
  }

  @override
  void dispose() {
    _stopInfoAutoPlayback();
    _stopMapAutoLineLoop();
    _tigerTalkTimer?.cancel();
    _zoomBegin = null;
    _zoomEnd = null;
    _infoImagePageController.dispose();
    _zoomController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final overlayTopPadding = kToolbarHeight + 8;
    final activeBuildingId = _activeBuildingId;
    final shouldDimMap = _cardVisible && activeBuildingId != null;
    final showActionBar = activeBuildingId != null && !_cardVisible;
    final showCenteredNavigation =
        shouldDimMap &&
        _activeAction == _OverlayAction.navigate &&
        _hasNavigationImages(activeBuildingId);
    return PopScope(
      canPop: !_cardVisible && _activeBuildingId == null,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_cardVisible) {
          _closeCard();
          return;
        }
        if (_activeBuildingId != null) {
          _clearSelection();
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text('Ortigas-Cainta Campus'),
          centerTitle: true,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          foregroundColor: cs.onSurface,
          elevation: 0,
        ),
        body: SafeArea(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  decoration: BoxDecoration(
                    // Map viewport background image
                    image: const DecorationImage(
                      image: AssetImage(
                        'assets/images/map/background/map_map_background.webp',
                      ),
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.medium,
                    ),
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: _softShadow(context),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: InteractiveViewer(
                      key: _viewerKey,
                      transformationController: _transformationController,
                      minScale: 1.0,
                      maxScale: 4.0,
                      boundaryMargin: EdgeInsets.zero,
                      clipBehavior: Clip.hardEdge,
                      panEnabled: !_cardVisible,
                      scaleEnabled: !_cardVisible,
                      onInteractionStart: (_) {
                        _cancelZoomAnimation();
                        // Mark as initialized once user interacts
                        if (!_hasInitializedPosition) {
                          _hasInitializedPosition = true;
                        }
                      },
                      child: SizedBox(
                        width: MapSpec.width,
                        height: MapSpec.height,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Image.asset(
                                'assets/images/map/base/map_map.png',
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.medium,
                              ),
                            ),
                            // Tap empty space to clear the current selection.
                            if (_activeBuildingId != null || _cardVisible)
                              Positioned.fill(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.translucent,
                                  onTap: _onMapBackgroundTap,
                                  child: const SizedBox.expand(),
                                ),
                              ),
                            ..._buildings(
                              excludeId: shouldDimMap ? null : activeBuildingId,
                            ),
                            // Slight dim + blur on the whole map while building panel is open.
                            if (shouldDimMap)
                              Positioned.fill(
                                child: IgnorePointer(
                                  ignoring: true,
                                  child: ClipRect(
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(
                                        sigmaX: 2.2,
                                        sigmaY: 2.2,
                                      ),
                                      child: Container(
                                        color: Colors.black.withValues(
                                          alpha: 0.50,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (!shouldDimMap && activeBuildingId != null)
                              ..._buildSelectedBuilding(activeBuildingId),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // When a card is open, freeze map gestures/taps and allow tapping empty space to close.
              // (Overlay card itself is above this layer and remains interactive.)
              if (_cardVisible && !showCenteredNavigation)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _closeCard,
                    onScaleStart: (_) {},
                    child: const SizedBox.expand(),
                  ),
                ),

              // Bottom buttons outside the map, above nav bar
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: AnimatedSwitcher(
                    duration: _actionBarTransitionDuration,
                    switchInCurve: _actionBarInCurve,
                    switchOutCurve: _actionBarOutCurve,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.0, _actionBarSlideDistance),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: showActionBar
                        ? KeyedSubtree(
                            key: const ValueKey<String>('action-bar-visible'),
                            child: _buildBottomButtons(activeBuildingId),
                          )
                        : const SizedBox(
                            key: ValueKey<String>('action-bar-hidden'),
                          ),
                  ),
                ),
              ),
              if (activeBuildingId != null &&
                  _cardVisible &&
                  showCenteredNavigation)
                Positioned.fill(
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey<String>('navigate-overlay-$activeBuildingId'),
                    tween: Tween<double>(begin: 0.0, end: 1.0),
                    duration: _navigateOverlayEnterDuration,
                    builder: (context, value, child) {
                      final eased = Curves.easeOutCubic.transform(value);
                      return Opacity(
                        opacity: eased,
                        child: Transform.translate(
                          offset: Offset(
                            0,
                            (1.0 - eased) * _navigateOverlayEnterYOffset,
                          ),
                          child: Transform.scale(
                            scale: 0.96 + (0.04 * eased),
                            alignment: Alignment.center,
                            child: child,
                          ),
                        ),
                      );
                    },
                    child: _BuildingNavImages(
                      buildingId: activeBuildingId,
                      overlayMode: true,
                      onTapOutsideVisible: _closeCard,
                    ),
                  ),
                ),
              if (activeBuildingId != null &&
                  _cardVisible &&
                  !showCenteredNavigation)
                Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, overlayTopPadding, 16, 0),
                    child: _buildOverlayCard(activeBuildingId),
                  ),
                ),
              _buildTigerMascot(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildings({String? excludeId}) {
    final items = List<BuildingItem>.from(kBuildingItems)
      ..removeWhere((b) => b.hidden)
      ..sort((a, b) => a.z.compareTo(b.z));
    return items.where((b) => b.id != excludeId).map((b) {
      return _buildBuildingWidget(b);
    }).toList();
  }

  List<Widget> _buildSelectedBuilding(String buildingId) {
    final match = kBuildingItems.firstWhere(
      (b) => b.id == buildingId,
      orElse: () => const BuildingItem(
        id: '',
        asset: '',
        x: 0,
        y: 0,
        scale: 0,
        hidden: true,
      ),
    );
    if (match.hidden || match.id.isEmpty) return const [];
    return [_buildBuildingWidget(match)];
  }

  Widget _buildBuildingWidget(BuildingItem b) {
    final w = b.scale * MapSpec.width;
    final isActive = _activeBuildingId == b.id;
    return Align(
      key: ValueKey<String>('building-${b.id}'),
      alignment: Alignment(b.x, b.y),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          final alreadyActive = _activeBuildingId == b.id;
          setState(() {
            _activeBuildingId = b.id;
            _cardVisible = false;
          });
          if (!alreadyActive) {
            _zoomToBuilding(b);
          }
        },
        child: AnimatedScale(
          scale: isActive ? 1.10 : 1.0,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: SizedBox(
            width: w,
            child: Stack(
              children: [
                Image.asset(
                  b.asset,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                ),
                if (isActive)
                  ColorFiltered(
                    colorFilter: const ColorFilter.mode(
                      Color(0x66FFD200),
                      BlendMode.srcATop,
                    ),
                    child: Image.asset(
                      b.asset,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverlayCard(String buildingId) {
    final spec = kBuildingOverlays[buildingId];
    if (spec == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    // Top-centered overlay card (above the map view)
    final media = MediaQuery.of(context).size;
    final maxW = media.width * 0.85;
    final cardW = maxW.clamp(260.0, 420.0);

    final bodyText = _buildActionBodyText(spec);

    // Navigate view: show an outer card containing an inner pannable/zoomable image card.
    if (_activeAction == _OverlayAction.navigate &&
        _hasNavigationImages(buildingId)) {
      final navMaxW = (media.width * 0.94).clamp(280.0, 720.0);
      return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: navMaxW),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: _BuildingNavImages(buildingId: buildingId),
        ),
      );
    }

    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 150),
      child: Material(
        color: isDark
            ? cs.surfaceContainerHigh.withValues(alpha: 0.95)
            : Colors.white.withOpacity(0.96),
        elevation: 12,
        shadowColor: isDark
            ? Colors.black.withValues(alpha: 0.50)
            : Colors.black26,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: cardW),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  spec.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? cs.onSurface : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                // Building images: info uses *_desc, navigate uses *_navigation
                if (_activeAction == _OverlayAction.navigate)
                  _BuildingNavImages(buildingId: buildingId)
                else
                  TweenAnimationBuilder<double>(
                    key: ValueKey<String>('info-image-enter-$buildingId'),
                    tween: Tween<double>(begin: 0.0, end: 1.0),
                    duration: _navigateOverlayEnterDuration,
                    builder: (context, value, child) {
                      final eased = Curves.easeOutCubic.transform(value);
                      return Opacity(
                        opacity: eased,
                        child: Transform.translate(
                          offset: Offset(
                            0,
                            (1.0 - eased) * _navigateOverlayEnterYOffset,
                          ),
                          child: Transform.scale(
                            scale: 0.96 + (0.04 * eased),
                            alignment: Alignment.center,
                            child: child,
                          ),
                        ),
                      );
                    },
                    child: _BuildingDescImages(
                      buildingId: buildingId,
                      pageController: _infoImagePageController,
                      onImageIndexChanged: (index) =>
                          _onInfoImageChanged(buildingId, index),
                      onManualScrollStart: () =>
                          _onInfoManualScrollStart(buildingId),
                    ),
                  ),
                const SizedBox(height: 8),
                if (bodyText.trim().isNotEmpty)
                  Text(
                    bodyText,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? cs.onSurface.withValues(alpha: 0.90)
                          : Colors.black87,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Bottom button bar outside the map canvas
  Widget _buildBottomButtons(String buildingId) {
    final canNavigate =
        _hasNavigationImages(buildingId) &&
        buildingId != 'cottage' &&
        buildingId != 'gate';
    final buttons = <_OverlayBtnSpec>[
      const _OverlayBtnSpec(
        icon: Icons.info_outline,
        label: 'Info',
        action: _OverlayAction.info,
      ),
      if (canNavigate)
        const _OverlayBtnSpec(
          icon: Icons.map_outlined,
          label: 'Navigate',
          action: _OverlayAction.navigate,
        ),
    ];

    return Material(
      color: Colors.transparent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double containerHPad =
              12; // matches Container horizontal padding
          final double innerSpacing = 8; // spacing between buttons
          final int count = buttons.length;
          final double availableW =
              constraints.maxWidth -
              (2 * containerHPad) -
              ((count - 1) * innerSpacing);
          final double perBtnW = (availableW / count).clamp(92.0, 160.0);

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: ThemeProvider.navyBlue.withOpacity(0.70),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int i = 0; i < buttons.length; i++) ...[
                      SizedBox(
                        width: perBtnW,
                        child: _OverlayButton(
                          icon: buttons[i].icon,
                          label: buttons[i].label,
                          onTap: () => _openBuildingAction(buttons[i].action),
                        ),
                      ),
                      if (i != buttons.length - 1)
                        SizedBox(width: innerSpacing),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTigerMascot() {
    final isBottomActionRowVisible = _activeBuildingId != null && !_cardVisible;
    final isOverlayActionVisible = _activeBuildingId != null && _cardVisible;
    final media = MediaQuery.of(context);
    final sw = media.size.width / 411.0;
    final navHeight = (72 * sw).clamp(60.0, 84.0);
    final navBottomPadding = 8.0 + media.padding.bottom;
    final navTopPadding = 6.0;
    final navReserved = navHeight + navBottomPadding + navTopPadding;
    final tigerScale = isOverlayActionVisible ? _tigerOverlayScale : 1.0;
    final tigerWidth = _tigerSize * tigerScale;
    final tigerHeight = tigerWidth * _tigerHeightFactor;
    final tigerViewportX = isOverlayActionVisible
        ? _tigerOverlayViewportX
        : _tigerMapViewportX;
    final tigerViewportY = isOverlayActionVisible
        ? _tigerOverlayViewportY
        : _tigerMapViewportY;
    final tigerViewportXOffset = isOverlayActionVisible
        ? _tigerOverlayViewportXOffset
        : _tigerMapViewportXOffset;
    final tigerViewportYOffset = isOverlayActionVisible
        ? _tigerOverlayViewportYOffset
        : _tigerMapViewportYOffset;
    final tigerLift = isBottomActionRowVisible
        ? _tigerMapLiftWhenActionsVisible
        : 0.0;
    final bubbleCount = _visibleTigerBubbles.length;
    final bubbleWidthFactor = isOverlayActionVisible
        ? _tigerBubbleWidthFactorOverlay
        : _tigerBubbleWidthFactor;
    final bubbleMinWidth = isOverlayActionVisible
        ? _tigerBubbleMinWidthOverlay
        : _tigerBubbleMinWidth;
    final bubbleMaxWidth = isOverlayActionVisible
        ? _tigerBubbleMaxWidthOverlay
        : _tigerBubbleMaxWidth;
    final bubbleXOffset = isOverlayActionVisible
        ? _tigerBubbleXOffsetOverlay
        : _tigerBubbleXOffset;
    final bubbleYOffset = isOverlayActionVisible
        ? _tigerBubbleYOffsetOverlay
        : _tigerBubbleYOffset;

    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth =
              (constraints.maxWidth - tigerWidth).clamp(0.0, double.infinity)
                  as double;
          final availableHeight =
              (constraints.maxHeight - navReserved - tigerHeight).clamp(
                    0.0,
                    double.infinity,
                  )
                  as double;

          final left =
              (availableWidth * tigerViewportX.clamp(0.0, 1.0)) +
              tigerViewportXOffset;
          final top =
              (availableHeight * tigerViewportY.clamp(0.0, 1.0)) +
              tigerViewportYOffset;
          final liftedTop =
              (top - tigerLift).clamp(0.0, availableHeight) as double;
          final bubbleWidth =
              (constraints.maxWidth * bubbleWidthFactor).clamp(
                    bubbleMinWidth,
                    bubbleMaxWidth,
                  )
                  as double;
          final newBubbleLeft =
              (left + bubbleXOffset - bubbleWidth).clamp(
                    8.0,
                    constraints.maxWidth - bubbleWidth - 8.0,
                  )
                  as double;
          final newBubbleTop =
              (liftedTop + tigerHeight + bubbleYOffset).clamp(
                    8.0,
                    constraints.maxHeight - 96.0,
                  )
                  as double;
          final oldBubbleLeft =
              (newBubbleLeft + _tigerBubbleOldXShift).clamp(
                    8.0,
                    constraints.maxWidth - bubbleWidth - 8.0,
                  )
                  as double;
          final oldBubbleTop =
              (newBubbleTop - _tigerBubbleStackGap).clamp(
                    8.0,
                    constraints.maxHeight - 88.0,
                  )
                  as double;

          final bubbleWidgets = <Widget>[];
          for (int i = 0; i < bubbleCount; i++) {
            final entry = _visibleTigerBubbles[i];
            final isOldBubble = bubbleCount == 2 && i == 0;
            final isNewestBubble = i == bubbleCount - 1;
            final delayFraction =
                (!isOldBubble && bubbleCount == 2 && isNewestBubble)
                ? _tigerBubbleNewEntryDelayFraction
                : 0.0;

            bubbleWidgets.add(
              AnimatedPositioned(
                key: ValueKey<int>(entry.id),
                duration: _tigerBubbleAnimationDuration,
                curve: Curves.easeOutCubic,
                left: isOldBubble ? oldBubbleLeft : newBubbleLeft,
                top: isOldBubble ? oldBubbleTop : newBubbleTop,
                child: _TigerAnimatedBubble(
                  key: ValueKey<int>(entry.id),
                  text: isOldBubble ? '' : entry.text,
                  width: bubbleWidth,
                  isBackground: isOldBubble,
                  delayFraction: delayFraction,
                ),
              ),
            );
          }

          return Stack(
            children: [
              ...bubbleWidgets,
              AnimatedPositioned(
                duration: _actionBarTransitionDuration,
                curve: _actionBarInCurve,
                left: left,
                top: liftedTop,
                child: AnimatedScale(
                  duration: _actionBarTransitionDuration,
                  curve: _actionBarInCurve,
                  scale: tigerScale,
                  alignment: Alignment.bottomCenter,
                  child: _TigerHitTestImage(
                    asset: _activeTigerAsset,
                    width: _tigerSize,
                    onTap: _onTigerTap,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TigerBubbleEntry {
  final int id;
  final String text;

  const _TigerBubbleEntry({required this.id, required this.text});
}

typedef _AlphaHitTestPredicate = bool Function(Offset localPosition, Size size);

class _AlphaHitTestRegion extends SingleChildRenderObjectWidget {
  final _AlphaHitTestPredicate predicate;

  const _AlphaHitTestRegion({required this.predicate, super.child});

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderAlphaHitTestRegion(predicate);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderAlphaHitTestRegion renderObject,
  ) {
    renderObject.predicate = predicate;
  }
}

class _RenderAlphaHitTestRegion extends RenderProxyBox {
  _RenderAlphaHitTestRegion(this._predicate);

  _AlphaHitTestPredicate _predicate;

  set predicate(_AlphaHitTestPredicate value) {
    if (_predicate == value) return;
    _predicate = value;
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position)) return false;
    if (!_predicate(position, size)) return false;

    child?.hitTest(result, position: position);
    result.add(BoxHitTestEntry(this, position));
    return true;
  }
}

class _TigerHitTestImage extends StatefulWidget {
  final String asset;
  final double width;
  final VoidCallback? onTap;

  const _TigerHitTestImage({
    required this.asset,
    required this.width,
    this.onTap,
  });

  @override
  State<_TigerHitTestImage> createState() => _TigerHitTestImageState();
}

class _TigerHitTestImageState extends State<_TigerHitTestImage> {
  Uint8List? _rgba;
  int _imgWidth = 0;
  int _imgHeight = 0;

  @override
  void initState() {
    super.initState();
    _loadAlphaData();
  }

  @override
  void didUpdateWidget(covariant _TigerHitTestImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset != widget.asset) {
      _loadAlphaData();
    }
  }

  Future<void> _loadAlphaData() async {
    final data = await rootBundle.load(widget.asset);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);

    if (!mounted) {
      image.dispose();
      return;
    }

    setState(() {
      _imgWidth = image.width;
      _imgHeight = image.height;
      _rgba = rgba?.buffer.asUint8List();
    });

    image.dispose();
  }

  bool _isOpaqueAt(Offset localPosition, Size size) {
    final rgba = _rgba;
    if (rgba == null || _imgWidth == 0 || _imgHeight == 0) return false;
    if (size.width <= 0 || size.height <= 0) return false;

    final px = ((localPosition.dx / size.width) * _imgWidth).floor().clamp(
      0,
      _imgWidth - 1,
    );
    final py = ((localPosition.dy / size.height) * _imgHeight).floor().clamp(
      0,
      _imgHeight - 1,
    );

    final alphaIndex = ((py * _imgWidth) + px) * 4 + 3;
    if (alphaIndex < 0 || alphaIndex >= rgba.length) return false;
    return rgba[alphaIndex] > 8;
  }

  @override
  Widget build(BuildContext context) {
    return _AlphaHitTestRegion(
      predicate: _isOpaqueAt,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: SizedBox(
          width: widget.width,
          child: Image.asset(
            widget.asset,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}

class _TigerSpeechBubble extends StatelessWidget {
  final String text;
  final double width;
  final bool isBackground;

  const _TigerSpeechBubble({
    required this.text,
    required this.width,
    this.isBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isBackground
        ? const Color(0xFFD0D5DD)
        : const Color(0xFF1E88E5);
    final borderColor = isBackground
        ? const Color(0xFFB8C0CC)
        : const Color(0xFF1565C0);
    final textColor = isBackground
        ? Colors.black.withValues(alpha: 0.82)
        : Colors.white;

    return IgnorePointer(
      child: Opacity(
        opacity: isBackground ? 0.92 : 1.0,
        child: SizedBox(
          width: width,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: isBackground ? 0.05 : 0.10,
                  ),
                  blurRadius: isBackground ? 6 : 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TigerAnimatedBubble extends StatelessWidget {
  final String text;
  final double width;
  final bool isBackground;
  final double delayFraction;

  const _TigerAnimatedBubble({
    super.key,
    required this.text,
    required this.width,
    this.isBackground = false,
    this.delayFraction = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final slideDistance = isBackground ? 8.0 : 14.0;
    final clampedDelay = delayFraction.clamp(0.0, 0.95) as double;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: _MapScreenState._tigerBubbleAnimationDuration,
      builder: (context, value, child) {
        final delayedProgress = value <= clampedDelay
            ? 0.0
            : ((value - clampedDelay) / (1.0 - clampedDelay)).clamp(0.0, 1.0)
                  as double;
        final eased = Curves.easeOutCubic.transform(delayedProgress);
        return Opacity(
          opacity: eased,
          child: Transform.translate(
            offset: Offset(0, (1.0 - eased) * slideDistance),
            child: child,
          ),
        );
      },
      child: _TigerSpeechBubble(
        text: text,
        width: width,
        isBackground: isBackground,
      ),
    );
  }
}

class _OverlayBtnSpec {
  final IconData icon;
  final String label;
  final _OverlayAction action;
  const _OverlayBtnSpec({
    required this.icon,
    required this.label,
    required this.action,
  });
}

class _OverlayButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _OverlayButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: ThemeProvider.navyBlue,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: ThemeProvider.gold),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: ThemeProvider.gold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _OverlayAction { info, navigate }

class _BuildingNavImages extends StatefulWidget {
  final String buildingId;
  final bool overlayMode;
  final VoidCallback? onTapOutsideVisible;
  const _BuildingNavImages({
    required this.buildingId,
    this.overlayMode = false,
    this.onTapOutsideVisible,
  });

  @override
  State<_BuildingNavImages> createState() => _BuildingNavImagesState();
}

class _BuildingNavImagesState extends State<_BuildingNavImages> {
  static const double _cardMinZoom = 1.2;
  static const double _cardMaxZoom = 6.0;
  static const double _overlayMinZoom = 1.0;
  static const double _overlayMaxZoom = 4.5;

  late final TransformationController _controller;
  Uint8List? _overlayRgba;
  int _overlayImgWidth = 0;
  int _overlayImgHeight = 0;

  @override
  void initState() {
    super.initState();
    _controller = TransformationController(
      Matrix4.identity()
        ..scale(widget.overlayMode ? _overlayMinZoom : _cardMinZoom),
    );
    _loadOverlayAlphaData();
  }

  @override
  void didUpdateWidget(covariant _BuildingNavImages oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.buildingId != widget.buildingId ||
        oldWidget.overlayMode != widget.overlayMode) {
      _controller.value = Matrix4.identity()
        ..scale(widget.overlayMode ? _overlayMinZoom : _cardMinZoom);
    }
    if (oldWidget.buildingId != widget.buildingId) {
      _loadOverlayAlphaData();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _fileFor(String id) {
    switch (id) {
      case 'gym_top_right':
        return 'assets/images/map/navigation/gym_navigation.png';
      case 'building_b':
        return 'assets/images/map/navigation/buildingb_navigation.png';
      case 'building_c':
        return 'assets/images/map/navigation/buildingc_navigation.png';
      case 'airport':
        // "Building A" navigation asset is used for Airport.
        return 'assets/images/map/navigation/buildinga_navigation.png';
      default:
        return null;
    }
  }

  Future<void> _loadOverlayAlphaData() async {
    final path = _fileFor(widget.buildingId);
    if (path == null) {
      if (!mounted) return;
      setState(() {
        _overlayRgba = null;
        _overlayImgWidth = 0;
        _overlayImgHeight = 0;
      });
      return;
    }

    try {
      final data = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);

      if (!mounted) {
        image.dispose();
        return;
      }

      setState(() {
        _overlayImgWidth = image.width;
        _overlayImgHeight = image.height;
        _overlayRgba = rgba?.buffer.asUint8List();
      });

      image.dispose();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _overlayRgba = null;
        _overlayImgWidth = 0;
        _overlayImgHeight = 0;
      });
    }
  }

  Rect _overlayImageRect(Size viewportSize, double imageW, double imageH) {
    final left = (viewportSize.width - imageW) / 2.0;
    final top = (viewportSize.height - imageH) * 0.1;
    return Rect.fromLTWH(left, top, imageW, imageH);
  }

  bool _isOpaqueAtOverlayPosition({
    required Offset viewportPoint,
    required Size viewportSize,
    required double imageW,
    required double imageH,
  }) {
    final inverse = Matrix4.copy(_controller.value);
    if (inverse.invert() == 0.0) return true;

    final childPoint = MatrixUtils.transformPoint(inverse, viewportPoint);
    final imageRect = _overlayImageRect(viewportSize, imageW, imageH);
    if (!imageRect.contains(childPoint)) return false;

    final rgba = _overlayRgba;
    if (rgba == null || _overlayImgWidth == 0 || _overlayImgHeight == 0) {
      return true;
    }

    final local = childPoint - imageRect.topLeft;
    final px =
        (((local.dx / imageRect.width) * _overlayImgWidth).floor()).clamp(
              0,
              _overlayImgWidth - 1,
            )
            as int;
    final py =
        (((local.dy / imageRect.height) * _overlayImgHeight).floor()).clamp(
              0,
              _overlayImgHeight - 1,
            )
            as int;

    final alphaIndex = ((py * _overlayImgWidth) + px) * 4 + 3;
    if (alphaIndex < 0 || alphaIndex >= rgba.length) return false;
    return rgba[alphaIndex] > 8;
  }

  void _handleOverlayTap(
    TapUpDetails details,
    Size viewportSize,
    double imageW,
    double imageH,
  ) {
    final onTapOutsideVisible = widget.onTapOutsideVisible;
    if (onTapOutsideVisible == null) return;

    final hitOpaque = _isOpaqueAtOverlayPosition(
      viewportPoint: details.localPosition,
      viewportSize: viewportSize,
      imageW: imageW,
      imageH: imageH,
    );
    if (!hitOpaque) {
      onTapOutsideVisible();
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = _fileFor(widget.buildingId);
    if (path == null) return const SizedBox.shrink();

    if (widget.overlayMode) {
      return LayoutBuilder(
        builder: (context, constraints) {
          // All navigation PNGs are currently 2048x1536 (4:3).
          final imageW =
              (constraints.maxHeight * (4 / 3) <= constraints.maxWidth)
              ? constraints.maxHeight * (4 / 3)
              : constraints.maxWidth;
          final imageH = imageW * (3 / 4);
          final viewportW = constraints.maxWidth;
          final viewportH = constraints.maxHeight;
          final viewportSize = Size(viewportW, viewportH);

          return Stack(
            children: [
              InteractiveViewer(
                transformationController: _controller,
                minScale: _overlayMinZoom,
                maxScale: _overlayMaxZoom,
                panEnabled: true,
                scaleEnabled: true,
                constrained: true,
                boundaryMargin: EdgeInsets.zero,
                child: SizedBox(
                  width: viewportW,
                  height: viewportH,
                  child: Align(
                    alignment: const Alignment(0, -0.8),
                    child: SizedBox(
                      width: imageW,
                      height: imageH,
                      child: Image.asset(
                        path,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.medium,
                        errorBuilder: (context, error, stack) =>
                            _ImageNameFallback(
                              path: path,
                              width: imageW,
                              height: imageH,
                            ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTapUp: (details) =>
                      _handleOverlayTap(details, viewportSize, imageW, imageH),
                ),
              ),
            ],
          );
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        // Slightly larger max height for navigation images, since users will zoom/pan.
        final h = (w * 9 / 16).clamp(160.0, 320.0);
        return SizedBox(
          width: w,
          height: h,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: InteractiveViewer(
              transformationController: _controller,
              minScale: _cardMinZoom,
              maxScale: _cardMaxZoom,
              panEnabled: true,
              scaleEnabled: true,
              boundaryMargin: const EdgeInsets.all(24),
              child: Material(
                color: Colors.white,
                elevation: 3,
                borderRadius: BorderRadius.circular(18),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  path,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (context, error, stack) =>
                      _ImageNameFallback(path: path, width: w, height: h),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

List<String> _infoImagePathsForBuilding(String id) {
  switch (id) {
    case 'airport':
      return [
        'assets/images/STI Pics/airport1.jpg',
        'assets/images/STI Pics/airport2.jpg',
        'assets/images/STI Pics/airport3.jpg',
      ];
    case 'building_b':
      return [
        'assets/images/STI Pics/buildingb1.jpg',
        'assets/images/STI Pics/buildingb2.jpg',
        'assets/images/STI Pics/buildingb3.jpg',
      ];
    case 'building_c':
      return [
        'assets/images/STI Pics/buildingc3.jpg',
        'assets/images/STI Pics/buildingc2.jpg',
        'assets/images/STI Pics/buildingc1.jpg',
      ];
    case 'cottage':
      return ['assets/images/map/descriptions/cottage_desc.jpg'];
    case 'gym_top_right':
      return [
        'assets/images/STI Pics/gym1.jpg',
        'assets/images/STI Pics/gym2.jpg',
        'assets/images/STI Pics/gym3.jpg',
      ];
    default:
      return const [];
  }
}

class _BuildingDescImages extends StatelessWidget {
  final String buildingId;
  final PageController pageController;
  final ValueChanged<int>? onImageIndexChanged;
  final VoidCallback? onManualScrollStart;

  const _BuildingDescImages({
    required this.buildingId,
    required this.pageController,
    this.onImageIndexChanged,
    this.onManualScrollStart,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final files = _infoImagePathsForBuilding(buildingId);
    if (files.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = (w * 9 / 16).clamp(
          120.0,
          220.0,
        ); // fit to card width, reasonable height
        Widget buildImageCard(Widget child) {
          return Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A2230) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark
                    ? const Color(0x33FFFFFF)
                    : const Color(0x14000000),
              ),
            ),
            padding: const EdgeInsets.all(2),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: child,
            ),
          );
        }

        if (files.length == 1) {
          final path = files.first;
          return SizedBox(
            width: w,
            height: h,
            child: buildImageCard(
              GestureDetector(
                onTap: () =>
                    _showMapImageViewer(context, paths: files, initialIndex: 0),
                child: Image.asset(
                  path,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (context, error, stack) =>
                      _ImageNameFallback(path: path, width: w, height: h),
                ),
              ),
            ),
          );
        }

        // 2+ images: snapping carousel
        return SizedBox(
          width: w,
          height: h,
          child: buildImageCard(
            NotificationListener<ScrollStartNotification>(
              onNotification: (notification) {
                if (notification.dragDetails != null) {
                  onManualScrollStart?.call();
                }
                return false;
              },
              child: PageView.builder(
                controller: pageController,
                physics: const PageScrollPhysics(),
                itemCount: files.length,
                onPageChanged: onImageIndexChanged,
                itemBuilder: (context, index) {
                  final path = files[index];
                  return GestureDetector(
                    onTap: () => _showMapImageViewer(
                      context,
                      paths: files,
                      initialIndex: index,
                    ),
                    child: Image.asset(
                      path,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (context, error, stack) =>
                          _ImageNameFallback(path: path, width: w, height: h),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

Future<void> _showMapImageViewer(
  BuildContext context, {
  required List<String> paths,
  int initialIndex = 0,
}) async {
  if (paths.isEmpty) return;
  final safeIndex = initialIndex.clamp(0, paths.length - 1).toInt();
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close image viewer',
    barrierColor: Colors.black.withOpacity(0.92),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (context, animation, secondaryAnimation) {
      return _MapImageViewer(paths: paths, initialIndex: safeIndex);
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      );
    },
  );
}

class _MapImageViewer extends StatefulWidget {
  final List<String> paths;
  final int initialIndex;

  const _MapImageViewer({required this.paths, required this.initialIndex});

  @override
  State<_MapImageViewer> createState() => _MapImageViewerState();
}

class _MapImageViewerState extends State<_MapImageViewer> {
  late final PageController _pageController;
  final Map<int, TransformationController> _zoomControllers =
      <int, TransformationController>{};
  late int _activeIndex;
  bool _isActivePageZoomed = false;

  TransformationController _controllerFor(int index) {
    return _zoomControllers.putIfAbsent(index, TransformationController.new);
  }

  @override
  void initState() {
    super.initState();
    _activeIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _activeIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final controller in _zoomControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.94),
      child: SafeArea(
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                return PageView.builder(
                  controller: _pageController,
                  itemCount: widget.paths.length,
                  physics: _isActivePageZoomed
                      ? const NeverScrollableScrollPhysics()
                      : const PageScrollPhysics(),
                  onPageChanged: (index) {
                    final activeController = _controllerFor(index);
                    final zoomed =
                        activeController.value.getMaxScaleOnAxis() > 1.02;
                    setState(() {
                      _activeIndex = index;
                      _isActivePageZoomed = zoomed;
                    });
                  },
                  itemBuilder: (context, index) {
                    final path = widget.paths[index];
                    final zoomController = _controllerFor(index);
                    return InteractiveViewer(
                      transformationController: zoomController,
                      minScale: 1.0,
                      maxScale: 8.0,
                      panEnabled: true,
                      scaleEnabled: true,
                      boundaryMargin: EdgeInsets.zero,
                      onInteractionUpdate: (_) {
                        if (index != _activeIndex) return;
                        final zoomed =
                            zoomController.value.getMaxScaleOnAxis() > 1.02;
                        if (zoomed == _isActivePageZoomed) return;
                        setState(() {
                          _isActivePageZoomed = zoomed;
                        });
                      },
                      onInteractionEnd: (_) {
                        if (zoomController.value.getMaxScaleOnAxis() <= 1.02) {
                          zoomController.value = Matrix4.identity();
                          if (index == _activeIndex && _isActivePageZoomed) {
                            setState(() {
                              _isActivePageZoomed = false;
                            });
                          }
                        }
                      },
                      child: SizedBox(
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Image.asset(
                            path,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                            errorBuilder: (context, error, stack) => Center(
                              child: _ImageNameFallback(
                                path: path,
                                width: 220,
                                height: 120,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
            if (widget.paths.length > 1)
              Positioned(
                bottom: 18,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${_activeIndex + 1} / ${widget.paths.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ImageNameFallback extends StatelessWidget {
  final String path;
  final double width;
  final double height;
  const _ImageNameFallback({
    required this.path,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final fileName = path.split('/').last;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          fileName,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
          ),
        ),
      ),
    );
  }
}
