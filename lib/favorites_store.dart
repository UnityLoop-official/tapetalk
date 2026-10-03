import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'song.dart';

/// I preferiti di chi usa l'app, salvati solo sul suo telefono
/// (id YouTube, in ordine di aggiunta). Al primo avvio c'è tutto il [catalog].
class FavoritesStore {
  static const _key = 'favorites';

  static final ids = ValueNotifier<List<String>>([]);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    ids.value =
        prefs.getStringList(_key) ?? [for (final s in catalog) s.youtubeId];
  }

  static List<Song> get songs => [
    for (final id in ids.value) ...catalog.where((s) => s.youtubeId == id),
  ];

  static bool contains(Song song) => ids.value.contains(song.youtubeId);

  static Future<void> toggle(Song song) async {
    final next = [...ids.value];
    if (!next.remove(song.youtubeId)) next.add(song.youtubeId);
    ids.value = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, next);
  }
}
