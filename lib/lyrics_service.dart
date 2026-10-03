import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'song.dart';

class LyricLine {
  final Duration time;
  final String english;
  String italian;

  LyricLine(this.time, this.english, [this.italian = '']);
}

/// Scarica il testo sincronizzato (LRCLIB) e le traduzioni (MyMemory).
class LyricsService {
  /// Testo sincronizzato con le traduzioni già salvate sul telefono.
  /// Le traduzioni mancanti si completano poi con [fillTranslations].
  Future<List<LyricLine>> load(Song song) async {
    final prefs = await SharedPreferences.getInstance();
    final lines = await _loadSyncedLyrics(song, prefs);
    final cache = _readCache(song, prefs);
    for (final line in lines) {
      line.italian = cache[_norm(line.english)] ?? '';
    }
    return lines;
  }

  /// Scarica le traduzioni mancanti (MyMemory, a gruppi in parallelo) e chiama [onProgress] ogni volta che ne arrivano di nuove.
  Future<void> fillTranslations(
    Song song,
    List<LyricLine> lines,
    void Function() onProgress,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final cache = _readCache(song, prefs);

    void apply() {
      for (final line in lines) {
        line.italian = cache[_norm(line.english)] ?? line.italian;
      }
      onProgress();
    }

    bool isMissing(String key) => key.isNotEmpty && !cache.containsKey(key);
    if (!lines.any((l) => isMissing(_norm(l.english)))) return;

    // Righe uniche ancora da tradurre (i ritornelli si traducono una volta).
    final todo = {
      for (final l in lines)
        if (isMissing(_norm(l.english))) _norm(l.english): l.english,
    };
    final entries = todo.entries.toList();
    const parallel = 6;
    for (var i = 0; i < entries.length; i += parallel) {
      final chunk = entries.skip(i).take(parallel);
      await Future.wait(
        chunk.map((e) async {
          final t = await _fetchMyMemory(e.value);
          if (t != null) cache[e.key] = t;
        }),
      );
      await prefs.setString(_cacheKey(song), jsonEncode(cache));
      apply();
    }
  }

  String _cacheKey(Song song) => 'translations:${song.artist}:${song.title}';

  Map<String, String> _readCache(Song song, SharedPreferences prefs) =>
      Map<String, String>.from(
        jsonDecode(prefs.getString(_cacheKey(song)) ?? '{}') as Map,
      );

  /// Usa il testo salvato sul telefono se c'è, altrimenti lo scarica e lo salva.
  Future<List<LyricLine>> _loadSyncedLyrics(
    Song song,
    SharedPreferences prefs,
  ) async {
    final key = 'lrc:${song.artist}:${song.title}';
    var lrc = prefs.getString(key);
    if (lrc == null) {
      lrc = await _fetchLrc(song);
      await prefs.setString(key, lrc);
    }
    return _parseLrc(lrc);
  }

  Future<String> _fetchLrc(Song song) async {
    final params = {'artist_name': song.artist, 'track_name': song.title};
    final res = await http.get(Uri.https('lrclib.net', '/api/get', params));
    if (res.statusCode == 200) {
      final lrc = (jsonDecode(res.body) as Map)['syncedLyrics'] as String?;
      if (lrc != null) return lrc;
    }

    // Ricerca: tra le versioni sincronizzate sceglie quella con la durata
    // più vicina al video.
    final search = await http.get(
      Uri.https('lrclib.net', '/api/search', params),
    );
    if (search.statusCode != 200) {
      throw Exception('Lyrics not found (LRCLIB ${search.statusCode})');
    }
    final synced = (jsonDecode(search.body) as List)
        .cast<Map>()
        .where((r) => r['syncedLyrics'] != null)
        .toList();
    if (synced.isEmpty) {
      throw Exception('Synced lyrics not available');
    }
    final target = song.durationSeconds;
    if (target != null) {
      num gap(Map r) => ((r['duration'] as num? ?? 0) - target).abs();
      synced.sort((a, b) => gap(a).compareTo(gap(b)));
    }
    return synced.first['syncedLyrics'] as String;
  }

  List<LyricLine> _parseLrc(String lrc) {
    final re = RegExp(r'^\[(\d+):(\d+(?:\.\d+)?)\]\s*(.*)$');
    final lines = <LyricLine>[];
    for (final raw in const LineSplitter().convert(lrc)) {
      final m = re.firstMatch(raw.trim());
      if (m == null) continue;
      final ms = (int.parse(m[1]!) * 60000 + double.parse(m[2]!) * 1000)
          .round();
      lines.add(LyricLine(Duration(milliseconds: ms), m[3]!));
    }
    return lines;
  }

  Future<String?> _fetchMyMemory(String text) async {
    try {
      final uri = Uri.https('api.mymemory.translated.net', '/get', {
        'q': text,
        'langpair': 'en|it',
      });
      final res = await http.get(uri);
      final t =
          (jsonDecode(res.body) as Map)['responseData']['translatedText']
              as String?;
      return t?.replaceAll('&#39;', "'").replaceAll('&quot;', '"');
    } catch (_) {
      return null;
    }
  }

  /// Normalizza una riga per confrontare fonti diverse (apostrofi, punteggiatura).
  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r"[′'’`]"), '')
      .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
