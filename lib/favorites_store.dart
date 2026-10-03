import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'song.dart';

/// I preferiti di chi usa l'app, salvati solo sul suo telefono, in ordine di
/// aggiunta. Si salva la canzone intera, perché può venire dalla ricerca.
/// Al primo avvio è vuota: ognuno si crea la sua playlist.
class FavoritesStore {
  static const _key = 'favorite_songs';

  /// Versione precedente: solo gli id YouTube delle canzoni del [catalog].
  static const _oldKey = 'favorites';

  static final songs = ValueNotifier<List<Song>>([]);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    final oldIds = prefs.getStringList(_oldKey);
    if (saved != null) {
      songs.value = [
        for (final j in jsonDecode(saved) as List) Song.fromJson(j as Map),
      ];
    } else if (oldIds != null) {
      songs.value = [
        for (final id in oldIds) ...catalog.where((s) => s.youtubeId == id),
      ];
    }
  }

  static bool contains(Song song) => songs.value.any((s) => s.key == song.key);

  /// [song] deve avere già il video (vedi SongSearch.withVideo).
  static Future<void> toggle(Song song) async {
    final next = [...songs.value];
    final before = next.length;
    next.removeWhere((s) => s.key == song.key);
    if (next.length == before) next.add(song);
    songs.value = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode([for (final s in next) s.toJson()]));
  }
}
