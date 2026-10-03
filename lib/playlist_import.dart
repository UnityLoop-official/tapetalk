import 'dart:convert';

import 'package:http/http.dart' as http;

import 'favorites_store.dart';
import 'song.dart';

/// Risultato di un'importazione.
class ImportResult {
  /// Da dove arrivano: il nome della playlist Spotify tra virgolette, o Shazam.
  final String source;
  final int added;

  /// Canzoni senza testo sincronizzato su LRCLIB: in TapeTalk non servono.
  final int skipped;

  const ImportResult(this.source, this.added, this.skipped);
}

/// Una canzone da importare, come la descrive Spotify o Shazam.
class _Track {
  final String title;
  final String artist;
  final int? durationMs;

  /// Da un elenco scritto a mano: titolo e artista potrebbero essere
  /// invertiti, quindi si prova anche al contrario.
  final bool maybeSwapped;

  const _Track(
    this.title,
    this.artist, [
    this.durationMs,
    this.maybeSwapped = false,
  ]);
}

/// Importa canzoni da link incollati: playlist pubbliche di Spotify e
/// canzoni di Shazam (anche più link insieme, o il testo che Shazam mette
/// quando si condivide). Senza link, accetta un elenco con una canzone per
/// riga: "Artista - Titolo". Legge le pagine pubbliche dei due servizi (senza API
/// ufficiali) e, per ogni canzone, cerca il testo sincronizzato su LRCLIB.
/// Il video YouTube si cerca solo quando la canzone si apre.
class PlaylistImport {
  static const _userAgent =
      'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/130.0 Mobile Safari/537.36';

  /// Shazam risponde con la pagina della canzone solo alle anteprime dei
  /// link (come quelle delle app di messaggi), non ai browser.
  static const _previewAgent = 'facebookexternalhit/1.1';

  static Future<ImportResult> fromText(
    String text, {
    void Function(int done, int total)? onProgress,
  }) async {
    final links = [
      for (final m in RegExp(r'(https?://|spotify:)\S+').allMatches(text))
        m[0]!,
    ];
    final spotify = [
      for (final l in links)
        if (l.contains('spotify')) l,
    ];
    final shazam = [
      for (final l in links)
        if (l.contains('shazam.com') || l.contains('shz.am')) l,
    ];
    if (spotify.isEmpty && shazam.isEmpty) {
      final lines = _songLines(text);
      if (lines.isEmpty) throw const FormatException('Nothing to import');
      return _addAll(lines, 'your list', onProgress);
    }

    final tracks = <_Track?>[];
    final names = <String>[];
    for (final link in spotify) {
      final (name, list) = await _spotifyPlaylist(link);
      names.add('"$name"');
      tracks.addAll(list);
    }
    if (shazam.isNotEmpty) {
      names.add('Shazam');
      tracks.addAll(await Future.wait(shazam.map(_shazamSong)));
    }
    return _addAll(tracks, names.join(' and '), onProgress);
  }

  /// Righe "Artista - Titolo" (o "Titolo - Artista").
  static List<_Track> _songLines(String text) => [
    for (final line in const LineSplitter().convert(text))
      if (line.indexOf(' - ') case final dash when dash > 0)
        _Track(
          line.substring(dash + 3).trim(),
          line.substring(0, dash).trim(),
          null,
          true,
        ),
  ];

  /// Aggiunge ai preferiti le canzoni che hanno il testo sincronizzato;
  /// le altre (e i link non letti, null) contano come saltate.
  static Future<ImportResult> _addAll(
    List<_Track?> tracks,
    String source,
    void Function(int done, int total)? onProgress,
  ) async {
    var added = 0;
    var skipped = 0;
    var done = 0;
    onProgress?.call(0, tracks.length);
    // A gruppi in parallelo, ma aggiunte nell'ordine della lista.
    // Non troppe insieme: LRCLIB rallenta chi fa troppe richieste.
    const parallel = 3;
    for (var i = 0; i < tracks.length; i += parallel) {
      final chunk = tracks.skip(i).take(parallel);
      final songs = await Future.wait(
        chunk.map((t) async {
          if (t == null) return null;
          return await _withLyrics(t) ??
              (t.maybeSwapped
                  ? await _withLyrics(_Track(t.artist, t.title))
                  : null);
        }),
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
    return ImportResult(source, added, skipped);
  }

  /// Nome e canzoni di una playlist pubblica di Spotify.
  static Future<(String, List<_Track>)> _spotifyPlaylist(String link) async {
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
    return (
      entity['name'] as String? ?? '',
      [
        for (final t in (entity['trackList'] as List).cast<Map>())
          _Track(
            t['title'] as String,
            t['subtitle'] as String,
            t['duration'] as int?,
          ),
      ],
    );
  }

  /// Titolo e artista dalla pagina di una canzone di Shazam.
  static Future<_Track?> _shazamSong(String link) async {
    final client = http.Client();
    try {
      // I link di Shazam rimandano alla pagina della canzone (/song/...).
      // Il rimando lo seguo io: seguito in automatico, Shazam risponde con
      // la pagina di un'altra canzone.
      var url = Uri.parse(link);
      for (var hop = 0; hop < 5; hop++) {
        final req = http.Request('GET', url)
          ..followRedirects = false
          ..headers['User-Agent'] = _previewAgent;
        final res = await client.send(req);
        final location = res.headers['location'];
        if (res.isRedirect && location != null) {
          await res.stream.drain<void>();
          url = url.resolve(location);
          continue;
        }
        if (res.statusCode != 200 || !url.path.startsWith('/song/')) {
          return null;
        }
        return _shazamTitle(await res.stream.bytesToString());
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  /// Il titolo della pagina è "Titolo - Artista: Song Lyrics, ...".
  static _Track? _shazamTitle(String page) {
    final m = RegExp(
      r'<meta property="og:title" content="([^"]*)"',
    ).firstMatch(page);
    if (m == null) return null;
    var text = _unescape(m[1]!);
    final suffix = text.lastIndexOf(': Song Lyrics');
    if (suffix > 0) text = text.substring(0, suffix);
    final dash = text.lastIndexOf(' - ');
    if (dash <= 0) return null;
    return _Track(text.substring(0, dash), text.substring(dash + 3));
  }

  static String _unescape(String s) => s
      .replaceAll('&amp;', '&')
      .replaceAll('&#x27;', "'")
      .replaceAll('&#39;', "'")
      .replaceAll('&quot;', '"');

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
  static Future<Song?> _withLyrics(_Track track) async {
    final _Track(:title, :artist, :durationMs) = track;
    try {
      final res = await _lrclibSearch({
        'track_name': _cleanTitle(title),
        'artist_name': _firstArtist(artist),
      });
      if (res.statusCode != 200) return null;
      // Solo risultati con il testo sincronizzato e con titolo e artista
      // che corrispondono: la ricerca di LRCLIB a volte dà altre canzoni.
      final synced = (jsonDecode(res.body) as List)
          .cast<Map>()
          .where(
            (r) =>
                r['syncedLyrics'] != null &&
                _similar(r['trackName'] as String, _cleanTitle(title)) &&
                _similar(r['artistName'] as String, _firstArtist(artist)),
          )
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

  /// Ricerca su LRCLIB. Se risponde "troppe richieste" (429), aspetta il
  /// tempo che indica e riprova, fino a 3 volte.
  static Future<http.Response> _lrclibSearch(Map<String, String> query) async {
    final uri = Uri.https('lrclib.net', '/api/search', query);
    var res = await http.get(uri);
    for (var retry = 0; retry < 3 && res.statusCode == 429; retry++) {
      final wait = int.tryParse(res.headers['retry-after'] ?? '') ?? 2;
      await Future<void>.delayed(Duration(seconds: wait.clamp(1, 30)));
      res = await http.get(uri);
    }
    return res;
  }

  /// Uguali a meno di maiuscole e punteggiatura, o una contenuta nell'altra
  /// ("The Beatles" e "Beatles").
  static bool _similar(String a, String b) {
    String norm(String s) =>
        _fold(s.toLowerCase()).replaceAll(RegExp(r'[^a-z0-9]'), '');
    final x = norm(a);
    final y = norm(b);
    if (x.isEmpty || y.isEmpty) return x == y;
    return x.contains(y) || y.contains(x);
  }

  /// Lettere accentate come quelle semplici ("Dø" = "do", "Æ" = "ae").
  static String _fold(String s) {
    const map = {
      'a': 'àáâãäåā',
      'ae': 'æ',
      'c': 'çč',
      'e': 'èéêëēė',
      'i': 'ìíîïī',
      'n': 'ñń',
      'o': 'òóôõöøō',
      'u': 'ùúûüū',
      'y': 'ýÿ',
      'ss': 'ß',
      's': 'š',
      'z': 'ž',
    };
    final buf = StringBuffer();
    for (final ch in s.split('')) {
      final plain = map.entries.where((e) => e.value.contains(ch));
      buf.write(plain.isEmpty ? ch : plain.first.key);
    }
    return buf.toString();
  }

  /// Toglie le aggiunte che LRCLIB non ha nel titolo: "Song - Remastered
  /// 2011", "Song (feat. X)", "Song (Club Mix)", "Song (Acoustic)"...
  static String _cleanTitle(String title) => title
      .split(' - ')
      .first
      .replaceAll(
        RegExp(
          r'\s*[(\[]([^)\]]*\b(feat|with|ft|mix|remix|edit|version|acoustic|'
          r'live|remaster(ed)?|soundtrack)\b[^)\]]*)[)\]]',
          caseSensitive: false,
        ),
        '',
      )
      .trim();

  /// Spotify mette tutti gli artisti separati da virgole: basta il primo.
  static String _firstArtist(String artists) =>
      artists.split(',').first.replaceAll(' ', ' ').trim();
}
