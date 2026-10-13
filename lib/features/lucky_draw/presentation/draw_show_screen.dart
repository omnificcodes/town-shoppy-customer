import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/error_state.dart';
import '../../scratch_cards/presentation/confetti_burst.dart';
import '../application/draws_list_controller.dart';
import '../data/models/draw.dart';
import '../data/models/draw_winner.dart';
import '../data/models/prize.dart';
import 'draw_status_display.dart';

/// "Watch the draw" (BR-44): a full-screen replay of an already-decided
/// result. The screen reads the draw, its winners and a shuffled sample of
/// entries, and never writes anything -- skipping, replaying or leaving
/// cannot change who won.
///
///   curtain  -> "Start the show" (the tap that lets the app make sound)
///   intro    -> the prizes parade past while the entry count climbs
///   names    -> entrant names stream upward ever faster, ticking
///   spin     -> a reel slows onto each prize unit's winner (drum roll)
///   winner   -> the winner card lands with confetti and the win chime
///   complete -> the results board
class DrawShowScreen extends ConsumerStatefulWidget {
  const DrawShowScreen({super.key, required this.drawId, required this.detailsPath});

  final int drawId;

  /// Where "View full details" goes.
  final String detailsPath;

  @override
  ConsumerState<DrawShowScreen> createState() => _DrawShowScreenState();
}

enum _Stage { curtain, intro, names, spin, winner, complete }

const _introDuration = Duration(seconds: 7);
const _namesDuration = Duration(seconds: 8);
const _spinDuration = Duration(milliseconds: 5200);
const _winnerHold = Duration(milliseconds: 3600);

class _DrawShowScreenState extends ConsumerState<DrawShowScreen> with TickerProviderStateMixin {
  _Stage _stage = _Stage.curtain;
  int _winnerIndex = 0;
  bool _soundOn = true;
  Timer? _timer;
  Timer? _roll;

  final _tick = AudioPlayer();
  final _tom = AudioPlayer();
  final _win = AudioPlayer();

  late final AnimationController _confetti = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void dispose() {
    _timer?.cancel();
    _roll?.cancel();
    _confetti.dispose();
    _tick.dispose();
    _tom.dispose();
    _win.dispose();
    super.dispose();
  }

  Future<void> _play(AudioPlayer player, String asset) async {
    if (!_soundOn) return;
    try {
      await player.stop();
      await player.play(AssetSource('sounds/$asset'));
    } catch (_) {
      // No audio device, or the platform refused -- the show goes on silently.
    }
  }

  void _playTick() => _play(_tick, 'draw_tick.wav');

  void _startRoll() {
    _roll?.cancel();
    final started = DateTime.now();
    void beat() {
      final progress = (DateTime.now().difference(started).inMilliseconds / _spinDuration.inMilliseconds).clamp(0.0, 1.0);
      _play(_tom, 'draw_tom.wav');
      HapticFeedback.lightImpact();
      if (progress < 1 && mounted) {
        _roll = Timer(Duration(milliseconds: (220 - progress * 170).round()), beat);
      }
    }
    beat();
  }

  void _stopRoll() {
    _roll?.cancel();
    _roll = null;
  }

  void _go(_Stage next, List<DrawWinner> winners) {
    _timer?.cancel();
    _stopRoll();
    if (!mounted) return;
    setState(() => _stage = next);

    switch (next) {
      case _Stage.intro:
        _timer = Timer(_introDuration, () => _go(winners.isEmpty ? _Stage.complete : _Stage.names, winners));
      case _Stage.names:
        _timer = Timer(_namesDuration, () {
          _winnerIndex = 0;
          _go(_Stage.spin, winners);
        });
      case _Stage.spin:
        _startRoll();
        _timer = Timer(_spinDuration, () {
          _stopRoll();
          _play(_win, 'scratch_win.wav');
          HapticFeedback.heavyImpact();
          _confetti.forward(from: 0);
          _go(_Stage.winner, winners);
        });
      case _Stage.winner:
        _timer = Timer(_winnerHold, () {
          if (_winnerIndex + 1 < winners.length) {
            setState(() => _winnerIndex++);
            _go(_Stage.spin, winners);
          } else {
            _finish();
          }
        });
      case _Stage.complete:
        _play(_win, 'scratch_win.wav');
        _confetti.forward(from: 0);
      case _Stage.curtain:
        break;
    }
  }

  void _finish() {
    _timer?.cancel();
    _stopRoll();
    if (!mounted) return;
    setState(() => _stage = _Stage.complete);
    _play(_win, 'scratch_win.wav');
    _confetti.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final draw = ref.watch(drawDetailProvider(widget.drawId));
    final winners = ref.watch(drawWinnersProvider(widget.drawId)).value ?? const <DrawWinner>[];
    final sample = ref.watch(drawEntriesSampleProvider(widget.drawId)).value;

    return Scaffold(
      backgroundColor: const Color(0xFF1B0608),
      body: draw.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFFFC857))),
        error: (error, _) => SafeArea(
          child: Column(
            children: [
              _TopBar(title: 'Lucky Draw', soundOn: _soundOn, onToggleSound: null, onSkip: null),
              Expanded(
                child: Center(
                  child: ErrorState(
                    error: error is AppException ? error : const UnknownAppException(),
                    title: 'Could not load this draw',
                    onRetry: () => ref.invalidate(drawDetailProvider(widget.drawId)),
                  ),
                ),
              ),
            ],
          ),
        ),
        data: (drawData) {
          final ordered = _orderWinners(drawData, winners);
          final names = _names(sample?.map((e) => e.displayName).toList() ?? const [], ordered);
          final current = _winnerIndex < ordered.length ? ordered[_winnerIndex] : null;
          final showing = _stage != _Stage.curtain && _stage != _Stage.complete;

          return Stack(
            children: [
              const Positioned.fill(child: _Backdrop()),
              SafeArea(
                child: Column(
                  children: [
                    _TopBar(
                      title: '${drawCadenceTitle(drawData.cadence)}${drawData.associationName != null ? ' · ${drawData.associationName}' : ''}',
                      soundOn: _soundOn,
                      onToggleSound: () => setState(() => _soundOn = !_soundOn),
                      onSkip: showing ? _finish : null,
                    ),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 450),
                        child: switch (_stage) {
                          _Stage.curtain => _Curtain(
                            key: const ValueKey('curtain'),
                            draw: drawData,
                            winnerCount: ordered.length,
                            onStart: () {
                              HapticFeedback.mediumImpact();
                              if (MediaQuery.of(context).disableAnimations) {
                                _finish();
                              } else {
                                _go(_Stage.intro, ordered);
                              }
                            },
                          ),
                          _Stage.intro => _Intro(key: const ValueKey('intro'), draw: drawData),
                          _Stage.names => _NamesStream(
                            key: const ValueKey('names'),
                            names: names,
                            total: drawData.poolSize ?? names.length,
                            onTick: _playTick,
                          ),
                          _Stage.spin => current == null
                              ? const SizedBox.shrink()
                              : _Reel(
                                  key: ValueKey('spin-$_winnerIndex'),
                                  names: names,
                                  winner: current,
                                  index: _winnerIndex,
                                  total: ordered.length,
                                  onTick: _playTick,
                                ),
                          _Stage.winner => current == null
                              ? const SizedBox.shrink()
                              : _WinnerCard(key: ValueKey('winner-$_winnerIndex'), winner: current, index: _winnerIndex, total: ordered.length),
                          _Stage.complete => _Results(
                            key: const ValueKey('complete'),
                            draw: drawData,
                            winners: ordered,
                            onReplay: () => _go(_Stage.intro, ordered),
                            onDetails: () => context.go(widget.detailsPath),
                          ),
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Positioned.fill(child: ConfettiBurst(progress: _confetti)),
            ],
          );
        },
      ),
    );
  }

  /// Winners in prize order, one per unit, forfeited ones left out (their
  /// replacement is already in the list).
  static List<DrawWinner> _orderWinners(Draw draw, List<DrawWinner> winners) {
    final order = {for (var i = 0; i < draw.prizes.length; i++) draw.prizes[i].id: i};
    final list = winners.where((w) => w.status != 'forfeited').toList()
      ..sort((a, b) {
        final byPrize = (order[a.prize?.id] ?? 99).compareTo(order[b.prize?.id] ?? 99);
        return byPrize != 0 ? byPrize : a.id.compareTo(b.id);
      });
    return list;
  }

  static List<String> _names(List<String> sample, List<DrawWinner> winners) {
    final pool = sample.isNotEmpty ? sample : winners.map((w) => w.displayName).toList();
    if (pool.isEmpty) return const ['Entries'];
    final padded = <String>[...pool];
    while (padded.length < 24) {
      padded.addAll(pool);
    }
    return padded;
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.6, -0.9),
          radius: 1.4,
          colors: [Color(0x55FFC857), Color(0xFF1B0608)],
          stops: [0, 0.6],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.9, 1),
            radius: 1.2,
            colors: [Color(0x66E11D48), Color(0x001B0608)],
            stops: [0, 0.7],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.soundOn, required this.onToggleSound, required this.onSkip});

  final String title;
  final bool soundOn;
  final VoidCallback? onToggleSound;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xs, AppSpacing.xs, AppSpacing.xs, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            onPressed: () => context.canPop() ? context.pop() : context.go('/lucky-draw'),
          ),
          Expanded(
            child: Text(
              title,
              style: AppTypography.caption.copyWith(color: const Color(0xFFFFC857), fontWeight: FontWeight.w800, letterSpacing: 1.2),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onSkip != null)
            TextButton.icon(
              onPressed: onSkip,
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              icon: const Icon(Icons.fast_forward_rounded, size: AppIconSize.sm),
              label: const Text('Skip'),
            ),
          IconButton(
            tooltip: soundOn ? 'Mute' : 'Unmute',
            icon: Icon(soundOn ? Icons.volume_up_rounded : Icons.volume_off_rounded, color: Colors.white),
            onPressed: onToggleSound,
          ),
        ],
      ),
    );
  }
}

class _Curtain extends StatelessWidget {
  const _Curtain({super.key, required this.draw, required this.winnerCount, required this.onStart});

  final Draw draw;
  final int winnerCount;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.page),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _Float(
            child: Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0x26FFC857),
                border: Border.all(color: const Color(0x66FFC857)),
              ),
              child: const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFC857), size: 64),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('The draw is ready', textAlign: TextAlign.center, style: AppTypography.textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${draw.poolSize ?? 0} entries. ${draw.prizes.length} prize${draw.prizes.length == 1 ? '' : 's'}. '
            '$winnerCount winner${winnerCount == 1 ? '' : 's'}. Turn the sound up.',
            textAlign: TextAlign.center,
            style: AppTypography.textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton.icon(
            onPressed: onStart,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFFC857),
              foregroundColor: const Color(0xFF1B0608),
              minimumSize: const Size(220, 56),
              shape: const StadiumBorder(),
              textStyle: AppTypography.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Start the show'),
          ),
        ],
      ),
    );
  }
}

/// Gentle up-and-down hover for the curtain's trophy.
class _Float extends StatefulWidget {
  const _Float({required this.child});

  final Widget child;

  @override
  State<_Float> createState() => _FloatState();
}

class _FloatState extends State<_Float> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        return Transform.translate(offset: Offset(0, -12 * t), child: Transform.rotate(angle: (t - 0.5) * 0.08, child: child));
      },
      child: widget.child,
    );
  }
}

class _Intro extends StatefulWidget {
  const _Intro({super.key, required this.draw});

  final Draw draw;

  @override
  State<_Intro> createState() => _IntroState();
}

class _IntroState extends State<_Intro> {
  final _pager = PageController(viewportFraction: 0.72);
  Timer? _advance;

  @override
  void initState() {
    super.initState();
    if (widget.draw.prizes.length > 1) {
      _advance = Timer.periodic(const Duration(milliseconds: 1700), (_) {
        if (!_pager.hasClients) return;
        final next = ((_pager.page ?? 0).round() + 1) % widget.draw.prizes.length;
        _pager.animateToPage(next, duration: const Duration(milliseconds: 600), curve: Curves.easeInOutCubic);
      });
    }
  }

  @override
  void dispose() {
    _advance?.cancel();
    _pager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draw = widget.draw;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("TONIGHT'S PRIZES", style: AppTypography.badgeLabel.copyWith(color: const Color(0xCCFFC857), letterSpacing: 3)),
        const SizedBox(height: AppSpacing.sm),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: (draw.poolSize ?? 0).toDouble()),
          duration: const Duration(milliseconds: 2500),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => Text(
            '${value.round()}',
            // An explicit style: the app's text theme defines no display
            // sizes, so a copyWith on one would silently fall back to the
            // default body text.
            style: const TextStyle(color: Colors.white, fontSize: 56, height: 1.1, fontWeight: FontWeight.w900, fontFeatures: [FontFeature.tabularFigures()]),
          ),
        ),
        Text('entries in the pool', style: AppTypography.textTheme.bodyLarge?.copyWith(color: Colors.white70)),
        const SizedBox(height: AppSpacing.xl),
        SizedBox(
          height: 240,
          child: draw.prizes.isEmpty
              ? const SizedBox.shrink()
              : PageView.builder(
                  controller: _pager,
                  itemCount: draw.prizes.length,
                  itemBuilder: (context, index) => AnimatedBuilder(
                    animation: _pager,
                    builder: (context, child) {
                      final page = _pager.hasClients && _pager.position.haveDimensions ? (_pager.page ?? index.toDouble()) : index.toDouble();
                      final distance = (page - index).abs().clamp(0.0, 1.0);
                      return Transform.scale(scale: 1 - distance * 0.12, child: Opacity(opacity: 1 - distance * 0.45, child: child));
                    },
                    child: _PrizePoster(prize: draw.prizes[index]),
                  ),
                ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const _Pulse(child: Text('Shuffling every eligible coupon…', style: TextStyle(color: Colors.white70))),
      ],
    );
  }
}

class _PrizePoster extends StatelessWidget {
  const _PrizePoster({required this.prize});

  final Prize prize;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0x4DFFC857), Color(0x4DE11D48)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              ),
              child: prize.imageUrl != null
                  ? Image.network(prize.imageUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.card_giftcard_rounded, color: Color(0xFFFFE0A3), size: 56))
                  : const Icon(Icons.card_giftcard_rounded, color: Color(0xFFFFE0A3), size: 56),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.smd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(prize.name, style: AppTypography.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('Sponsored by ${prize.sponsorMerchantName ?? 'a Town Shoppy shop'}', style: AppTypography.caption.copyWith(color: Colors.white60), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: AppSpacing.xxs),
                Text('${prize.unitsInDraw} unit${prize.unitsInDraw == 1 ? '' : 's'}', style: AppTypography.caption.copyWith(color: const Color(0xFFFFE0A3), fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Entrant names streaming upward, faster and faster, with a tick per
/// name that crosses the middle.
class _NamesStream extends StatefulWidget {
  const _NamesStream({super.key, required this.names, required this.total, required this.onTick});

  final List<String> names;
  final int total;
  final VoidCallback onTick;

  @override
  State<_NamesStream> createState() => _NamesStreamState();
}

class _NamesStreamState extends State<_NamesStream> with SingleTickerProviderStateMixin {
  static const _rowHeight = 56.0;

  late final Ticker _ticker;
  double _offset = 0;
  Duration _last = Duration.zero;
  final _started = DateTime.now();
  int _lastRow = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onFrame)..start();
  }

  void _onFrame(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    final progress = (DateTime.now().difference(_started).inMilliseconds / _namesDuration.inMilliseconds).clamp(0.0, 1.0);
    final speed = 120 + progress * 900; // px per second
    setState(() => _offset += speed * dt);
    final row = (_offset / _rowHeight).floor();
    if (row != _lastRow) {
      _lastRow = row;
      widget.onTick();
      HapticFeedback.selectionClick();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final names = widget.names;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('EVERY ENTRY IS IN', style: AppTypography.badgeLabel.copyWith(color: const Color(0xCCFFC857), letterSpacing: 3)),
        const SizedBox(height: AppSpacing.xs),
        Text('${widget.total} coupons, one draw', textAlign: TextAlign.center, style: AppTypography.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          height: 360,
          child: ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
              stops: [0, 0.18, 0.82, 1],
            ).createShader(rect),
            blendMode: BlendMode.dstIn,
            child: ClipRect(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final visible = (constraints.maxHeight / _rowHeight).ceil() + 2;
                  final first = (_offset / _rowHeight).floor();
                  final shift = _offset % _rowHeight;
                  return Stack(
                    children: [
                      for (var i = 0; i < visible; i++)
                        Positioned(
                          top: i * _rowHeight - shift,
                          left: AppSpacing.page,
                          right: AppSpacing.page,
                          height: _rowHeight - AppSpacing.xs,
                          child: _NameTile(name: names[(first + i) % names.length]),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NameTile extends StatelessWidget {
  const _NameTile({required this.name, this.highlight = false, this.scale = 1});

  final String name;
  final bool highlight;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: scale,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: highlight ? const Color(0x33FFC857) : const Color(0x14FFFFFF),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: highlight ? const Color(0xFFFFC857) : const Color(0x1FFFFFFF), width: highlight ? 2 : 1),
        ),
        child: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: highlight ? FontWeight.w900 : FontWeight.w600),
        ),
      ),
    );
  }
}

/// The reel: a long strip of names that slows and lands on the winner.
class _Reel extends StatefulWidget {
  const _Reel({super.key, required this.names, required this.winner, required this.index, required this.total, required this.onTick});

  final List<String> names;
  final DrawWinner winner;
  final int index;
  final int total;
  final VoidCallback onTick;

  @override
  State<_Reel> createState() => _ReelState();
}

class _ReelState extends State<_Reel> with SingleTickerProviderStateMixin {
  static const _rowHeight = 60.0;
  static const _rows = 5;

  late final List<String> _strip;
  late final AnimationController _controller = AnimationController(vsync: this, duration: _spinDuration);
  int _lastStep = 0;

  @override
  void initState() {
    super.initState();
    final random = Random(widget.winner.id * 7919 + widget.index);
    final shuffled = [...widget.names]..shuffle(random);
    final length = 70 + random.nextInt(10);
    final strip = <String>[];
    while (strip.length < length) {
      strip.addAll(shuffled);
    }
    _strip = strip.take(length).toList()..[length - 1] = widget.winner.displayName;

    _controller.addListener(() {
      final step = (_position).floor();
      if (step != _lastStep) {
        _lastStep = step;
        widget.onTick();
      }
    });
    _controller.forward();
  }

  double get _position => Curves.easeOutQuart.transform(_controller.value) * (_strip.length - 1);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prize = widget.winner.prize;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          widget.total > 1 ? 'PRIZE ${widget.index + 1} OF ${widget.total}' : 'THE PRIZE',
          style: AppTypography.badgeLabel.copyWith(color: const Color(0xCCFFC857), letterSpacing: 3),
        ),
        const SizedBox(height: AppSpacing.xs),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
          child: Text(
            prize?.name ?? 'Lucky Draw prize',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
          ),
        ),
        if (prize?.sponsorMerchantName != null)
          Text('Sponsored by ${prize!.sponsorMerchantName}', style: AppTypography.caption.copyWith(color: Colors.white60)),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          height: _rowHeight * _rows,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final position = _position;
              final center = position.round();
              return ShaderMask(
                shaderCallback: (rect) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
                  stops: [0, 0.25, 0.75, 1],
                ).createShader(rect),
                blendMode: BlendMode.dstIn,
                child: Stack(
                  children: [
                    for (var i = 0; i < _rows; i++)
                      Builder(
                        builder: (context) {
                          final rowIndex = center - _rows ~/ 2 + i;
                          final distance = (rowIndex - position).abs();
                          final name = rowIndex < 0 ? '' : _strip[rowIndex % _strip.length];
                          return Positioned(
                            top: (i + (center - position)) * _rowHeight,
                            left: AppSpacing.page,
                            right: AppSpacing.page,
                            height: _rowHeight - AppSpacing.xs,
                            child: Opacity(
                              opacity: (1 - distance * 0.4).clamp(0.15, 1.0),
                              child: _NameTile(name: name, highlight: distance < 0.5, scale: (1.08 - distance * 0.12).clamp(0.8, 1.08)),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const _Pulse(child: Text('Drawing a winner…', style: TextStyle(color: Colors.white70))),
      ],
    );
  }
}

class _WinnerCard extends StatefulWidget {
  const _WinnerCard({super.key, required this.winner, required this.index, required this.total});

  final DrawWinner winner;
  final int index;
  final int total;

  @override
  State<_WinnerCard> createState() => _WinnerCardState();
}

class _WinnerCardState extends State<_WinnerCard> with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final winner = widget.winner;
    final prize = winner.prize;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.page),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            widget.total > 1 ? 'WINNER ${widget.index + 1} OF ${widget.total}' : 'THE WINNER',
            style: AppTypography.badgeLabel.copyWith(color: const Color(0xCCFFC857), letterSpacing: 3),
          ),
          const SizedBox(height: AppSpacing.md),
          ScaleTransition(
            scale: CurvedAnimation(parent: _pop, curve: Curves.elasticOut),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0x26FFFFFF), Color(0x0DFFFFFF)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(color: const Color(0x80FFC857)),
                boxShadow: const [BoxShadow(color: Color(0x66FFC857), blurRadius: 48, spreadRadius: 2)],
              ),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(color: Color(0xFFFFC857), shape: BoxShape.circle),
                    child: const Icon(Icons.emoji_events_rounded, color: Color(0xFF1B0608), size: 44),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    winner.displayName,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
                  ),
                  if (winner.winnerName != null) Text(winner.winnerLabel, style: AppTypography.caption.copyWith(color: Colors.white60)),
                  const SizedBox(height: AppSpacing.sm),
                  Text.rich(
                    TextSpan(
                      text: 'wins ',
                      style: AppTypography.textTheme.titleMedium?.copyWith(color: Colors.white),
                      children: [
                        TextSpan(text: prize?.name ?? 'the prize', style: const TextStyle(color: Color(0xFFFFE0A3), fontWeight: FontWeight.w800)),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      if (prize?.sponsorMerchantName != null) _DarkChip(icon: Icons.storefront_rounded, label: 'Gift from ${prize!.sponsorMerchantName}'),
                      if (winner.earnedAtShopName != null) _DarkChip(icon: Icons.confirmation_number_rounded, label: 'Coupon earned at ${winner.earnedAtShopName}'),
                      if (winner.couponCode != null) _DarkChip(icon: Icons.tag_rounded, label: winner.couponCode!),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text('Congratulations!', style: TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({super.key, required this.draw, required this.winners, required this.onReplay, required this.onDetails});

  final Draw draw;
  final List<DrawWinner> winners;
  final VoidCallback onReplay;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.xxl),
      children: [
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(color: Color(0x3338EF7D), shape: BoxShape.circle),
            child: const Icon(Icons.celebration_rounded, color: Color(0xFF38EF7D), size: 32),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Draw complete!', textAlign: TextAlign.center, style: AppTypography.textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          '${winners.length} winner${winners.length == 1 ? '' : 's'} from ${draw.poolSize ?? 0} entries · '
          '${draw.sponsorShops.length} sponsor shop${draw.sponsorShops.length == 1 ? '' : 's'}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (winners.isEmpty)
          const Text('No eligible coupons were found for this draw -- no winners were selected.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
        for (final prize in draw.prizes) ...[
          _ResultCard(prize: prize, winners: winners.where((w) => w.prize?.id == prize.id).toList()),
          const SizedBox(height: AppSpacing.sm),
        ],
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          onPressed: onDetails,
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFFC857), foregroundColor: const Color(0xFF1B0608), minimumSize: const Size.fromHeight(52), shape: const StadiumBorder()),
          icon: const Icon(Icons.list_alt_rounded),
          label: const Text('View full details', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: onReplay,
          style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54), minimumSize: const Size.fromHeight(52), shape: const StadiumBorder()),
          icon: const Icon(Icons.replay_rounded),
          label: const Text('Replay the show'),
        ),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.prize, required this.winners});

  final Prize prize;
  final List<DrawWinner> winners;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.smd),
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: AppSize.avatarMd,
                height: AppSize.avatarMd,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  gradient: const LinearGradient(colors: [Color(0x4DFFC857), Color(0x4DE11D48)]),
                ),
                clipBehavior: Clip.antiAlias,
                child: prize.imageUrl != null
                    ? Image.network(prize.imageUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.card_giftcard_rounded, color: Color(0xFFFFE0A3)))
                    : const Icon(Icons.card_giftcard_rounded, color: Color(0xFFFFE0A3)),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(prize.name, style: AppTypography.textTheme.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('Sponsored by ${prize.sponsorMerchantName ?? '—'}', style: AppTypography.caption.copyWith(color: Colors.white60), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (winners.isEmpty)
            Text('No winner -- the pool ran out before this prize.', style: AppTypography.caption.copyWith(color: Colors.white60))
          else
            for (final winner in winners)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                  decoration: BoxDecoration(color: const Color(0x40000000), borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
                  child: Row(
                    children: [
                      const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFC857), size: AppIconSize.sm),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(child: Text(winner.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      if (winner.earnedAtShopName != null)
                        Text(winner.earnedAtShopName!, style: AppTypography.caption.copyWith(color: Colors.white60), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _DarkChip extends StatelessWidget {
  const _DarkChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppSpacing.radiusPill), border: Border.all(color: const Color(0x33FFFFFF))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppIconSize.xs, color: Colors.white70),
          const SizedBox(width: AppSpacing.xxs),
          Flexible(child: Text(label, style: AppTypography.caption.copyWith(color: Colors.white70), maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

/// Fades a caption in and out while a stage runs.
class _Pulse extends StatefulWidget {
  const _Pulse({required this.child});

  final Widget child;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: Tween(begin: 0.45, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)), child: widget.child);
  }
}
