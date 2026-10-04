import 'dart:async';

import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import 'lyrics_service.dart';
import 'mouth_logo.dart';
import 'song.dart';
import 'video_sync.dart';
import 'word_timing_service.dart';

class LyricsScreen extends StatefulWidget {
  final Song song;

  const LyricsScreen({super.key, required this.song});

  @override
  State<LyricsScreen> createState() => _LyricsScreenState();
}

class _LyricsScreenState extends State<LyricsScreen> {
  late final YoutubePlayerController _player;
  final _scroll = ScrollController();
  final _keys = <GlobalKey>[];
  Timer? _ticker;

  List<LyricLine>? _lines;
  String? _error;
  int _current = -1;

  /// Per ogni riga, l'istante in cui viene cantata ciascuna parola.
  List<List<Duration>> _wordStarts = [];

  /// Parole già cantate nella riga corrente (diventano viola).
  int _sung = 0;

  /// Attesa prima del testo (intro) o in una pausa lunga senza canto:
  /// si mostra una barra e, negli ultimi 3 secondi, il conto alla rovescia.
  _Wait? _wait;

  /// Logo che compare per un istante alla fine del conto alla rovescia.
  bool _go = false;

  /// Durata e sottotitoli del video (vedi VideoSync).
  VideoSync _sync = VideoSync.empty;
  bool _playing = true;

  /// A volte il WebView non fa partire il video da solo: lo rilancio
  /// finché non parte, a meno che non l'abbia fermato chi usa l'app.
  Timer? _startWatchdog;
  int _startAttempts = 0;
  bool _userPaused = false;

  /// Audio tolto per farlo partire (il video muto parte sempre): si
  /// rimette appena il video suona.
  bool _mutedToStart = false;

  /// Sottotitoli di YouTube già tolti dal video.
  bool _captionsOff = false;

  /// Video nascosto (occhio chiuso): il player continua a suonare ma quasi
  /// non occupa spazio, così il testo ha più posto e niente distrae.
  /// All'inizio è nascosto: chi vuole vedere il video lo apre con l'occhio.
  bool _videoHidden = true;

  /// Velocità disponibili: oltre lo 0.75× la voce inizia a suonare innaturale.
  static const _speeds = [1.0, 0.85, 0.75];
  int _speedIndex = 0;

  @override
  void initState() {
    super.initState();
    _player = YoutubePlayerController.fromVideoId(
      videoId: widget.song.youtubeId,
      autoPlay: true,
      // Sempre dall'inizio: YouTube a volte riprende da dove si era
      // lasciato, e si perderebbero l'intro e il conto alla rovescia.
      startSeconds: 0,
      params: const YoutubePlayerParams(
        showControls: false,
        showFullscreenButton: false,
        playsInline: true,
        // Niente sottotitoli né annotazioni dentro il video: il testo è
        // già sotto, a tempo e tradotto.
        enableCaption: false,
        showVideoAnnotations: false,
      ),
    );
    _player.listen((v) {
      final playing = v.playerState == PlayerState.playing;
      if (playing && !_captionsOff) {
        // YouTube a volte accende i sottotitoli da solo (es. se la lingua
        // del telefono è diversa da quella del video): li si scarica.
        _captionsOff = true;
        _player.webViewController.runJavaScript(
          'try { player.unloadModule("captions"); player.unloadModule("cc"); }'
          ' catch (e) {}',
        );
      }
      if (playing && _mutedToStart) {
        _mutedToStart = false;
        _player.unMute();
      }
      if (playing != _playing && mounted) setState(() => _playing = playing);
    });
    _startWatchdog = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _ensureStarted(),
    );
    _loadLyrics();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
  }

  /// Se dopo l'avvio il video è ancora fermo, riprova a farlo partire:
  /// prima normalmente, poi senza audio (che si rimette appena parte).
  Future<void> _ensureStarted() async {
    final state = _player.value.playerState;
    if (_userPaused ||
        state == PlayerState.playing ||
        state == PlayerState.ended ||
        _startAttempts >= 8) {
      _startWatchdog?.cancel();
      return;
    }
    if (state == PlayerState.buffering) return;
    _startAttempts++;
    if (_startAttempts >= 2 && !_mutedToStart) {
      _mutedToStart = true;
      await _player.mute();
    }
    await _player.playVideo();
  }

  Future<void> _loadLyrics() async {
    setState(() => _error = null);
    try {
      final service = LyricsService();
      // Durata e sottotitoli del video: per scegliere la versione giusta del
      // testo e metterlo a tempo con il video. Se tardano, si va avanti senza.
      final sync = await VideoSync.load(
        widget.song.youtubeId,
      ).timeout(const Duration(seconds: 8), onTimeout: () => VideoSync.empty);
      var lines = await service.load(widget.song, videoSeconds: sync.seconds);
      // Il video può essere spostato rispetto al testo (un'intro più lunga)
      // o montato in modo diverso: le righe prendono i tempi del video.
      final times = sync.alignedTimes(lines);
      if (times != null) {
        lines = [
          for (var i = 0; i < lines.length; i++)
            LyricLine(times[i], lines[i].english, lines[i].italian),
        ];
      }
      _sync = sync;
      if (!mounted) return;
      _keys
        ..clear()
        ..addAll(List.generate(lines.length, (_) => GlobalKey()));
      setState(() {
        _lines = lines;
        _wordStarts = [
          for (var i = 0; i < lines.length; i++) _estimateWordStarts(lines, i),
        ];
      });
      _loadRealWordTimes(lines);
      // Le traduzioni mancanti compaiono man mano che arrivano.
      await service.fillTranslations(widget.song, lines, () {
        if (mounted) setState(() {});
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  /// Il testo sincronizzato ha i tempi solo per riga: stimo quando viene
  /// cantata ogni parola dividendo il tempo della riga in proporzione alla
  /// lunghezza delle parole, a un ritmo di canto realistico.
  static List<Duration> _estimateWordStarts(List<LyricLine> lines, int i) {
    final words = _words(lines[i].english);
    if (words.isEmpty) return [];
    final start = lines[i].time;
    // Peso di una parola: le lettere più una base, così anche "I" o "a"
    // durano un po'.
    final weights = [for (final w in words) w.length + 2];
    final total = weights.fold(0, (a, b) => a + b);
    // La riga si canta in quasi tutto il tempo fino alla successiva
    // (con un po' di respiro alla fine). Se dopo c'è una lunga pausa
    // strumentale, non si va oltre una lettera ogni 150 ms.
    var span = Duration(milliseconds: total * 150);
    if (i + 1 < lines.length) {
      final gap = (lines[i + 1].time - start) * 0.85;
      if (gap < span) span = gap;
    }
    final starts = <Duration>[];
    var acc = 0;
    for (final w in weights) {
      starts.add(start + span * (acc / total));
      acc += w;
    }
    return starts;
  }

  /// Se il video ha i sottotitoli automatici di YouTube, sostituisce la
  /// stima con i tempi veri delle parole.
  Future<void> _loadRealWordTimes(List<LyricLine> lines) async {
    try {
      final offset = Duration(
        milliseconds: (widget.song.offsetSeconds * 1000).round(),
      );
      final timed = [
        for (final w in _sync.words) TimedWord(w.word, w.time - offset),
      ];
      if (timed.isEmpty || !mounted || _lines != lines) return;
      setState(() {
        _wordStarts = [
          for (var i = 0; i < lines.length; i++)
            WordTimingService.align(
              words: _words(lines[i].english),
              lineStart: lines[i].time,
              lineEnd: i + 1 < lines.length
                  ? lines[i + 1].time
                  : lines[i].time + const Duration(seconds: 10),
              estimate: _wordStarts[i],
              timed: timed,
            ),
        ];
      });
    } catch (_) {
      // Senza sottotitoli resta la stima.
    }
  }

  static List<String> _words(String line) =>
      line.split(' ').where((w) => w.isNotEmpty).toList();

  Future<void> _tick() async {
    final lines = _lines;
    if (lines == null || lines.isEmpty) return;
    final seconds = await _player.currentTime - widget.song.offsetSeconds;
    final pos = Duration(milliseconds: (seconds * 1000).round());
    var idx = -1;
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].time <= pos) idx = i;
    }
    _updateWait(lines, idx, pos);
    final starts = idx >= 0 ? _wordStarts[idx] : const <Duration>[];
    final sung = starts.where((t) => t <= pos).length;
    if (idx == _current && sung != _sung && mounted) {
      setState(() => _sung = sung);
    }
    if (idx != _current && mounted) {
      setState(() {
        _current = idx;
        _sung = sung;
      });
      final ctx = idx >= 0 ? _keys[idx].currentContext : null;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.4,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      } else if (_scroll.hasClients) {
        // Prima della prima riga (es. canzone ricominciata): torna in cima.
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  /// C'è un'attesa se la prossima riga cantata è lontana: almeno 4 secondi
  /// di intro prima della prima riga, almeno 8 secondi in una pausa a metà
  /// canzone (contati da quando finisce di essere cantata la riga prima).
  void _updateWait(List<LyricLine> lines, int idx, Duration pos) {
    _Wait? wait;
    final next = lines.indexWhere((l) => l.english.trim().isNotEmpty, idx + 1);
    if (next >= 0) {
      final Duration start;
      if (idx < 0) {
        start = Duration.zero;
      } else if (lines[idx].english.trim().isEmpty) {
        start = lines[idx].time;
      } else {
        final words = _wordStarts[idx];
        start =
            (words.isEmpty ? lines[idx].time : words.last) +
            const Duration(milliseconds: 1500);
      }
      final end = lines[next].time;
      final minimum = Duration(seconds: idx < 0 ? 4 : 8);
      if (end - start >= minimum && pos >= start && pos < end) {
        wait = _Wait(start, end, pos, intro: idx < 0);
      }
    }
    if (mounted && (wait != null || _wait != null)) {
      // Il conto alla rovescia è finito (non si è saltato avanti): per un
      // istante compare il logo, come un "via!".
      final countdownDone =
          wait == null &&
          _wait != null &&
          _wait!.remaining <= const Duration(seconds: 3) &&
          pos >= _wait!.end &&
          pos < _wait!.end + const Duration(seconds: 1);
      setState(() {
        _wait = wait;
        if (countdownDone) _go = true;
      });
      if (countdownDone) {
        Timer(const Duration(milliseconds: 900), () {
          if (mounted) setState(() => _go = false);
        });
      }
    }
  }

  void _pause() {
    _userPaused = true;
    _player.pauseVideo();
  }

  Future<void> _restart() async {
    await _player.seekTo(seconds: 0, allowSeekAhead: true);
    await _player.playVideo();
    if (!mounted) return;
    setState(() {
      _current = -1;
      _sung = 0;
    });
    if (_scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _nextSpeed() async {
    final i = (_speedIndex + 1) % _speeds.length;
    _player.setPlaybackRate(_speeds[i]);
    setState(() => _speedIndex = i);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    debugPrint(
      'Velocità richiesta ${_speeds[i]}, effettiva ${await _player.playbackRate}',
    );
  }

  String _speedLabel(double s) => '$s×';

  @override
  void dispose() {
    _ticker?.cancel();
    _startWatchdog?.cancel();
    _player.close();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        scrolledUnderElevation: 0,
        title: Text(
          '${widget.song.artist} – ${widget.song.title}',
          style: const TextStyle(fontSize: 16),
        ),
      ),
      // SafeArea: i controlli restano sopra la barra di navigazione di Android.
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Il player deve restare a schermo per funzionare. I termini delle
            // API di YouTube chiedono almeno 200x200: in 16:9 viene 356x200.
            // Con l'occhio chiuso si riduce a una riga di 1 pixel: il player
            // di YouTube si disegna sopra a tutto, quindi non si può coprire.
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: _videoHidden ? 1 : 200,
              child: Center(
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: YoutubePlayer(controller: _player),
                ),
              ),
            ),
            // Sotto il video e non sopra: il player di YouTube copre i
            // pulsanti disegnati sopra di lui. Nasconde il video, non lo ferma.
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.grey),
              icon: Icon(
                _videoHidden ? Icons.visibility_off : Icons.visibility,
              ),
              label: Text(_videoHidden ? 'Show video' : 'Hide video'),
              onPressed: () => setState(() => _videoHidden = !_videoHidden),
            ),
            Expanded(
              child: Stack(
                children: [
                  _buildLyrics(),
                  if (_wait case final wait?)
                    Positioned(
                      top: 16,
                      left: 20,
                      right: 20,
                      child: _WaitIndicator(wait),
                    ),
                  if (_go && _wait == null)
                    const Positioned(
                      top: 16,
                      left: 0,
                      right: 0,
                      child: Center(child: _GoLogo()),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 24, top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _SmallControl(
                    icon: Icons.replay,
                    label: 'Restart',
                    onPressed: _restart,
                  ),
                  const SizedBox(width: 32),
                  IconButton.filled(
                    iconSize: 48,
                    icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
                    onPressed: () => _playing ? _pause() : _player.playVideo(),
                  ),
                  const SizedBox(width: 32),
                  _SmallControl(
                    icon: Icons.speed,
                    label: _speedLabel(_speeds[_speedIndex]),
                    onPressed: _nextSpeed,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Riga corrente: le parole già cantate sono viola.
  Widget _karaokeText(String english) {
    final purple = Theme.of(context).colorScheme.primary;
    final words = _words(english);
    return Text.rich(
      TextSpan(
        children: [
          for (var w = 0; w < words.length; w++)
            TextSpan(
              text: w < words.length - 1 ? '${words[w]} ' : words[w],
              style: w < _sung ? TextStyle(color: purple) : null,
            ),
        ],
      ),
    );
  }

  Widget _buildLyrics() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Couldn't load the lyrics.\nCheck your connection.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadLyrics,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }
    final lines = _lines;
    if (lines == null) {
      return const Center(child: CircularProgressIndicator());
    }
    // Tutte le righe restano costruite (sono poche), così lo scorrimento
    // automatico trova sempre la riga corrente, anche tornando indietro.
    return SingleChildScrollView(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 200),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(lines.length, (i) {
          final line = lines[i];
          final active = i == _current;
          if (line.english.isEmpty) {
            return SizedBox(key: _keys[i], height: 24);
          }
          return AnimatedOpacity(
            key: _keys[i],
            duration: const Duration(milliseconds: 300),
            opacity: active ? 1 : 0.35,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 300),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: active ? 26 : 20,
                      fontWeight: active ? FontWeight.bold : FontWeight.normal,
                    ),
                    child: active
                        ? _karaokeText(line.english)
                        : Text(line.english),
                  ),
                  if (line.italian.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        line.italian,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Il logo di TapeTalk che appare con un piccolo salto dopo 3 - 2 - 1.
class _GoLogo extends StatelessWidget {
  const _GoLogo();

  @override
  Widget build(BuildContext context) {
    final purple = Theme.of(context).colorScheme.primary;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.5, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Container(
        width: 96,
        height: 96,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: purple,
          borderRadius: BorderRadius.circular(24),
        ),
        child: MouthLogo(size: 72, color: Colors.black, background: purple),
      ),
    );
  }
}

class _Wait {
  final Duration start;
  final Duration end;
  final Duration pos;
  final bool intro;

  const _Wait(this.start, this.end, this.pos, {required this.intro});

  Duration get remaining => end - pos;
}

/// Durante l'attesa una barra viola che si riempie fino all'arrivo del
/// testo; negli ultimi 3 secondi, al suo posto, 3 - 2 - 1 grandi.
class _WaitIndicator extends StatelessWidget {
  final _Wait wait;

  const _WaitIndicator(this.wait);

  static const _countdown = Duration(seconds: 3);

  @override
  Widget build(BuildContext context) {
    final purple = Theme.of(context).colorScheme.primary;
    final remaining = wait.remaining;
    final Widget child;
    if (remaining <= _countdown) {
      final n = (remaining.inMilliseconds / 1000).ceil().clamp(1, 3);
      child = AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
        child: Text(
          '$n',
          key: ValueKey(n),
          style: TextStyle(
            color: purple,
            fontSize: 72,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
      );
    } else {
      // La barra si riempie fino all'inizio del conto alla rovescia.
      final total = wait.end - wait.start - _countdown;
      final progress = total.inMilliseconds <= 0
          ? 1.0
          : ((wait.pos - wait.start).inMilliseconds / total.inMilliseconds)
                .clamp(0.0, 1.0);
      final seconds = (remaining.inMilliseconds / 1000).ceil();
      child = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '♪ ${wait.intro ? 'Intro' : 'Instrumental'} · ${seconds}s',
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              color: purple,
              backgroundColor: Colors.white12,
            ),
          ),
        ],
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

/// Pulsante secondario più piccolo, con una breve etichetta sotto.
class _SmallControl extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _SmallControl({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    // Si può toccare anche la scritta sotto, non solo l'icona.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton.filledTonal(
              iconSize: 26,
              icon: Icon(icon),
              onPressed: onPressed,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
