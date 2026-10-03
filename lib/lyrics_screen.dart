import 'dart:async';

import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import 'lyrics_service.dart';
import 'song.dart';

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
  bool _playing = true;

  /// Velocità disponibili: oltre lo 0.75× la voce inizia a suonare innaturale.
  static const _speeds = [1.0, 0.85, 0.75];
  int _speedIndex = 0;

  @override
  void initState() {
    super.initState();
    _player = YoutubePlayerController.fromVideoId(
      videoId: widget.song.youtubeId,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showControls: false,
        showFullscreenButton: false,
        playsInline: true,
      ),
    );
    _player.listen((v) {
      final playing = v.playerState == PlayerState.playing;
      if (playing != _playing && mounted) setState(() => _playing = playing);
    });
    _loadLyrics();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
  }

  Future<void> _loadLyrics() async {
    setState(() => _error = null);
    try {
      final service = LyricsService();
      final lines = await service.load(widget.song);
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

  String _speedLabel(double s) => '${s.toString().replaceAll('.', ',')}×';

  @override
  void dispose() {
    _ticker?.cancel();
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
            // Il player deve restare a schermo per funzionare: lo teniamo piccolo.
            SizedBox(
              height: 90,
              child: Center(
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: YoutubePlayer(controller: _player),
                ),
              ),
            ),
            Expanded(child: _buildLyrics()),
            Padding(
              padding: const EdgeInsets.only(bottom: 24, top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _SmallControl(
                    icon: Icons.replay,
                    label: 'Ricomincia',
                    onPressed: _restart,
                  ),
                  const SizedBox(width: 32),
                  IconButton.filled(
                    iconSize: 48,
                    icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
                    onPressed: () =>
                        _playing ? _player.pauseVideo() : _player.playVideo(),
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
                'Impossibile caricare il testo.\nControlla la connessione.',
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
                label: const Text('Riprova'),
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
    return SizedBox(
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
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}
