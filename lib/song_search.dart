import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import 'song.dart';

/// Cerca canzoni nuove: titolo e artista da LRCLIB (solo quelle con il testo
/// sincronizzato, che serve all'app), il video da YouTube.
class SongSearch {
  /// Risultati senza video ([Song.youtubeId] vuoto): si cerca con [withVideo].
  static Future<List<Song>> search(String query) async {
    final res = await http.get(
      Uri.https('lrclib.net', '/api/search', {'q': query}),
    );
    if (res.statusCode != 200) {
      throw Exception('Search failed (LRCLIB ${res.statusCode})');
    }
    final songs = <String, Song>{};
    final copies = <String, int>{};
    for (final r in (jsonDecode(res.body) as List).cast<Map>()) {
      if (r['syncedLyrics'] == null) continue;
      final song = Song(
        title: r['trackName'] as String,
        artist: r['artistName'] as String,
        youtubeId: '',
        durationSeconds: (r['duration'] as num?)?.round(),
      );
      // Stessa canzone in più album: basta la prima.
      songs.putIfAbsent(song.key, () => song);
      copies.update(song.key, (n) => n + 1, ifAbsent: () => 1);
    }
    // Prima le canzoni presenti in più album: quella vera di solito c'è più
    // volte, i doppioni caricati a mano ("Queen - Bohemian Rhapsody") una.
    final order = songs.keys.toList();
    final ranked = [...order]
      ..sort((a, b) {
        final byCopies = copies[b]!.compareTo(copies[a]!);
        return byCopies != 0
            ? byCopies
            : order.indexOf(a).compareTo(order.indexOf(b));
      });
    return [for (final k in ranked) songs[k]!];
  }

  /// Trova il video YouTube con la durata più vicina alla canzone.
  static Future<Song> withVideo(Song song) async {
    if (song.youtubeId.isNotEmpty) return song;
    final yt = YoutubeExplode();
    try {
      final videos = (await yt.search.search(
        '${song.artist} ${song.title}',
      )).where((v) => !v.isLive).take(8).toList();
      if (videos.isEmpty) throw Exception('Video not found');
      var best = videos.first;
      final target = song.durationSeconds;
      if (target != null) {
        int gap(Video v) => ((v.duration?.inSeconds ?? 0) - target).abs();
        // Il primo nell'ordine di YouTube (il più pertinente) con la durata
        // giusta; se nessuno ce l'ha, il più vicino.
        best = videos.firstWhere(
          (v) => gap(v) <= 5,
          orElse: () => videos.reduce((a, b) => gap(b) < gap(a) ? b : a),
        );
      }
      return song.withVideo(best.id.value);
    } finally {
      yt.close();
    }
  }
}
