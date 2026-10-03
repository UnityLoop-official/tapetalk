import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'song.dart';

/// Trova l'URL della copertina del disco con la ricerca di iTunes
/// (gratuita, senza chiave) e lo salva sul telefono.
class CoverService {
  static Future<String?> coverUrl(Song song) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'cover:${song.artist}:${song.title}';
    final cached = prefs.getString(key);
    if (cached != null) return cached;

    try {
      final uri = Uri.https('itunes.apple.com', '/search', {
        'term': '${song.artist} ${song.title}',
        'entity': 'song',
        'limit': '5',
      });
      final res = await http.get(uri);
      final results = (jsonDecode(res.body) as Map)['results'] as List;
      final match = results.cast<Map>().firstWhere(
        (r) =>
            (r['artistName'] as String).toLowerCase() ==
            song.artist.toLowerCase(),
        orElse: () => results.isEmpty ? {} : results.first as Map,
      );
      final small = match['artworkUrl100'] as String?;
      if (small == null) return null;
      final url = small.replaceAll('100x100bb', '300x300bb');
      await prefs.setString(key, url);
      return url;
    } catch (_) {
      return null;
    }
  }
}
