import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'song.dart';

/// Una playlist di chi usa l'app.
class Playlist {
  final String id;
  final String name;
  final List<Song> songs;

  const Playlist(this.id, this.name, this.songs);

  Playlist copyWith({String? name, List<Song>? songs}) =>
      Playlist(id, name ?? this.name, songs ?? this.songs);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'songs': [for (final s in songs) s.toJson()],
  };

  factory Playlist.fromJson(Map json) => Playlist(
    json['id'] as String,
    json['name'] as String,
    [for (final s in json['songs'] as List) Song.fromJson(s as Map)],
  );
}

/// Le playlist di chi usa l'app, salvate solo sul suo telefono. Una è quella
/// aperta: il cuore, la ricerca e l'importazione lavorano su quella, e
/// [songs] sono le sue canzoni, in ordine di aggiunta. Si salva la canzone
/// intera, perché può venire dalla ricerca. Al primo avvio c'è una sola
/// playlist vuota, "My favorites".
class FavoritesStore {
  static const _key = 'playlists';
  static const _currentKey = 'current_playlist';
  static const defaultName = 'My favorites';

  /// Versioni precedenti: una sola lista di canzoni, poi solo gli id YouTube
  /// delle canzoni del [catalog].
  static const _singleListKey = 'favorite_songs';
  static const _oldKey = 'favorites';

  static final playlists = ValueNotifier<List<Playlist>>([]);
  static final currentId = ValueNotifier<String>('');

  /// Le canzoni della playlist aperta.
  static final songs = ValueNotifier<List<Song>>([]);

  static Playlist get current =>
      playlists.value.firstWhere((p) => p.id == currentId.value);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null) {
      playlists.value = [
        for (final j in jsonDecode(saved) as List) Playlist.fromJson(j as Map),
      ];
    } else {
      // Prima c'era una sola lista: diventa la playlist "My favorites".
      final single = prefs.getString(_singleListKey);
      final oldIds = prefs.getStringList(_oldKey);
      final List<Song> first = single != null
          ? [
              for (final j in jsonDecode(single) as List)
                Song.fromJson(j as Map),
            ]
          : oldIds != null
          ? [
              for (final id in oldIds)
                ...catalog.where((s) => s.youtubeId == id),
            ]
          : [];
      playlists.value = [Playlist(_newId(), defaultName, first)];
    }
    if (playlists.value.isEmpty) {
      playlists.value = [Playlist(_newId(), defaultName, [])];
    }
    final savedCurrent = prefs.getString(_currentKey);
    currentId.value = playlists.value.any((p) => p.id == savedCurrent)
        ? savedCurrent!
        : playlists.value.first.id;
    songs.value = current.songs;
  }

  // ----- Canzoni della playlist aperta -----

  static bool contains(Song song) => songs.value.any((s) => s.key == song.key);

  /// [song] deve avere già il video (vedi SongSearch.withVideo).
  static Future<void> toggle(Song song) async {
    final next = [...songs.value];
    final before = next.length;
    next.removeWhere((s) => s.key == song.key);
    if (next.length == before) next.add(song);
    await _saveSongs(next);
  }

  /// Toglie [song] e restituisce dov'era, per poterla rimettere con [insert].
  static Future<int> remove(Song song) async {
    final next = [...songs.value];
    final index = next.indexWhere((s) => s.key == song.key);
    if (index < 0) return -1;
    next.removeAt(index);
    await _saveSongs(next);
    return index;
  }

  /// Rimette [song] alla posizione [index] (annulla di [remove]).
  static Future<void> insert(Song song, int index) async {
    if (contains(song)) return;
    final next = [...songs.value];
    next.insert(index.clamp(0, next.length), song);
    await _saveSongs(next);
  }

  /// Aggiorna una canzone (es. con il video trovato) in tutte le playlist
  /// che la contengono; dove non c'è, non fa niente.
  static Future<void> replace(Song song) async {
    playlists.value = [
      for (final p in playlists.value)
        p.copyWith(
          songs: [for (final s in p.songs) s.key == song.key ? song : s],
        ),
    ];
    await _save();
  }

  /// Toglie tutte le canzoni dalla playlist aperta.
  static Future<void> clear() => _saveSongs([]);

  // ----- Playlist -----

  /// Crea una playlist vuota e la apre.
  static Future<void> create(String name) async {
    final p = Playlist(_newId(), name, []);
    playlists.value = [...playlists.value, p];
    currentId.value = p.id;
    await _save();
  }

  static Future<void> open(String id) async {
    currentId.value = id;
    await _save();
  }

  static Future<void> rename(String name) async {
    playlists.value = [
      for (final p in playlists.value)
        p.id == currentId.value ? p.copyWith(name: name) : p,
    ];
    await _save();
  }

  /// Elimina la playlist aperta e apre la prima rimasta. Se era l'unica,
  /// al suo posto c'è una nuova "My favorites" vuota.
  static Future<void> deleteCurrent() async {
    final rest = [
      for (final p in playlists.value)
        if (p.id != currentId.value) p,
    ];
    playlists.value = rest.isEmpty
        ? [Playlist(_newId(), defaultName, [])]
        : rest;
    currentId.value = playlists.value.first.id;
    await _save();
  }

  static Future<void> _saveSongs(List<Song> next) async {
    playlists.value = [
      for (final p in playlists.value)
        p.id == currentId.value ? p.copyWith(songs: next) : p,
    ];
    await _save();
  }

  static Future<void> _save() async {
    songs.value = current.songs;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode([for (final p in playlists.value) p.toJson()]),
    );
    await prefs.setString(_currentKey, currentId.value);
  }

  static String _newId() => DateTime.now().microsecondsSinceEpoch.toString();
}
