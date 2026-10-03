import 'dart:convert';

import 'package:http/http.dart' as http;

import 'favorites_store.dart';
import 'song.dart';

/// Risultato di un'importazione.
class ImportResult {
  final String playlistName;
  final int added;

  /// Canzoni senza testo sincronizzato su LRCLIB: in TapeTalk non servono.
  final int skipped;

  const ImportResult(this.playlistName, this.added, this.skipped);
}

/// Importa una playlist pubblica di Spotify dal suo link. Legge la pagina
/// pubblica del lettore incorporato di Spotify (senza API ufficiali) e, per
/// ogni canzone, cerca il testo sincronizzato su LRCLIB. Il video YouTube si
/// cerca solo quando la canzone si apre.
class PlaylistImport {
  static const _userAgent =
      'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/130.0 Mobile Safari/537.36';

  static Future<ImportResult> fromSpotify(
    String link, {
    void Function(int done, int total)? onProgress,
  }) async {
    final id = await _playlistId(link.trim());
    if (id == null) throw const FormatException('Not a Spotify playlist link');

    final res = await http.get(
      Uri.https('open.spotify.com', '/embed/playlist/$id'),
      headers: {'User-Agent': _userAgent},
    );
    final m = RegExp(
      r'<script id="__NEXT_DATA__"[^>]*>(.*?)</script>',
      dotAll: true,
    ).firstMatch(res.body);
    if (res.statusCode != 200 || m == null) {
      throw Exception('Playlist not found (Spotify ${res.statusCode})');
    }
    final entity =
        jsonDecode(m[1]!)['props']['pageProps']['state']['data']['entity']
            as Map;
    final tracks = (entity['trackList'] as List).cast<Map>();

    var added = 0;
    var skipped = 0;
    var done = 0;
    onProgress?.call(0, tracks.length);
    // A gruppi in parallelo, ma aggiunte nell'ordine della playlist.
    const parallel = 6;
    for (var i = 0; i < tracks.length; i += parallel) {
      final chunk = tracks.skip(i).take(parallel);
      final songs = await Future.wait(
        chunk.map(
          (t) => _withLyrics(
            title: t['title'] as String,
            artist: t['subtitle'] as String,
            durationMs: t['duration'] as int?,
          ),
        ),
      );
      for (final song in songs) {
        if (song == null) {
          skipped++;
        } else if (!FavoritesStore.contains(song)) {
          await FavoritesStore.toggle(song);
          added++;
        }
      }
      done += chunk.length;
      onProgress?.call(done, tracks.length);
    }
    return ImportResult(entity['name'] as String? ?? '', added, skipped);
  }

  /// L'id della playlist da un link (anche quelli corti spotify.link, che
  /// rimandano a quello completo) o da un URI spotify:playlist:...
  static Future<String?> _playlistId(String link) async {
    final direct = RegExp(r'playlist[/:]([A-Za-z0-9]{22})').firstMatch(link);
    if (direct != null) return direct[1];
    var url = Uri.tryParse(link);
    for (var hop = 0; url != null && url.hasScheme && hop < 4; hop++) {
      final req = http.Request('GET', url)
        ..followRedirects = false
        ..headers['User-Agent'] = _userAgent;
      final res = await http.Client().send(req);
      final location = res.headers['location'];
      if (location == null) {
        // Alcuni link corti rimandano con una pagina invece che con un
        // redirect: cerco il link completo nel testo.
        final body = await res.stream.bytesToString();
        final m = RegExp(r'playlist/([A-Za-z0-9]{22})').firstMatch(body);
        return m?[1];
      }
      final found = RegExp(
        r'playlist[/:]([A-Za-z0-9]{22})',
      ).firstMatch(location);
      if (found != null) return found[1];
      url = url.resolve(location);
    }
    return null;
  }

  /// La canzone come la conosce LRCLIB, se ha il testo sincronizzato.
  static Future<Song?> _withLyrics({
    required String title,
    required String artist,
    int? durationMs,
  }) async {
    try {
      final res = await http.get(
        Uri.https('lrclib.net', '/api/search', {
          'track_name': _cleanTitle(title),
          'artist_name': _firstArtist(artist),
        }),
      );
      if (res.statusCode != 200) return null;
      final synced = (jsonDecode(res.body) as List)
          .cast<Map>()
          .where((r) => r['syncedLyrics'] != null)
          .toList();
      if (synced.isEmpty) return null;
      var best = synced.first;
      if (durationMs != null) {
        final target = durationMs / 1000;
        num gap(Map r) => ((r['duration'] as num? ?? 0) - target).abs();
        best = synced.reduce((a, b) => gap(b) < gap(a) ? b : a);
        // Durata troppo diversa: probabilmente un'altra canzone.
        if (gap(best) > 15) return null;
      }
      return Song(
        title: best['trackName'] as String,
        artist: best['artistName'] as String,
        youtubeId: '',
        durationSeconds: (best['duration'] as num?)?.round(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Toglie le aggiunte di Spotify che LRCLIB non ha nel titolo:
  /// "Song - Remastered 2011", "Song (feat. X)".
  static String _cleanTitle(String title) => title
      .split(' - ')
      .first
      .replaceAll(
        RegExp(r'\s*[(\[](feat|with|ft)\.?[^)\]]*[)\]]', caseSensitive: false),
        '',
      )
      .trim();

  /// Spotify mette tutti gli artisti separati da virgole: basta il primo.
  static String _firstArtist(String artists) =>
      artists.split(',').first.replaceAll(' ', ' ').trim();
}
