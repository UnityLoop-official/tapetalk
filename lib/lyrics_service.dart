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

/// Scarica il testo sincronizzato (LRCLIB) e le traduzioni
/// (Musixmatch, con MyMemory come riserva per le righe mancanti).
class LyricsService {
  static const _userAgent =
      'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/130.0 Mobile Safari/537.36';

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

  /// Scarica le traduzioni mancanti (Musixmatch, poi MyMemory a gruppi in
  /// parallelo) e chiama [onProgress] ogni volta che ne arrivano di nuove.
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

    cache.addAll(await _fetchMusixmatch(song));
    apply();

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
      throw Exception('Testo non trovato (LRCLIB ${search.statusCode})');
    }
    final synced = (jsonDecode(search.body) as List)
        .cast<Map>()
        .where((r) => r['syncedLyrics'] != null)
        .toList();
    if (synced.isEmpty) {
      throw Exception('Testo sincronizzato non disponibile');
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

  /// Legge la mappa "riga inglese -> riga italiana" dal JSON __NEXT_DATA__
  /// della pagina Musixmatch. Fragile per natura: solo per test.
  Future<Map<String, String>> _fetchMusixmatch(Song song) async {
    final url = song.musixmatchUrl;
    if (url == null) return {};
    try {
      final res = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': _userAgent, 'Accept-Language': 'it'},
      );
      final m = RegExp(
        r'<script id="__NEXT_DATA__"[^>]*>(.*?)</script>',
        dotAll: true,
      ).firstMatch(res.body);
      if (m == null) return {};
      final data =
          jsonDecode(
                m[1]!,
              )['props']['pageProps']['data']['crowdTranslationGet']['data']
              as Map;
      return {
        for (final e in data.entries) _norm(e.key as String): e.value as String,
      };
    } catch (_) {
      return {};
    }
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
