import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'cover_service.dart';
import 'logo.dart';
import 'lyrics_screen.dart';
import 'song.dart';

void main() => runApp(const TapeTalkApp());

class TapeTalkApp extends StatelessWidget {
  const TapeTalkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TapeTalk',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            systemNavigationBarColor: Colors.black,
            systemNavigationBarIconBrightness: Brightness.light,
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

/// Schermata principale: colore del pulsante Play, logo e accesso ai preferiti.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Icone di stato scure, leggibili sullo sfondo viola.
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: scheme.primary,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: scheme.primary,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RotatingLogo(
                    size: 200,
                    color: Colors.black,
                    background: scheme.primary,
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'TapeTalk',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Slogan scritto "a pennarello", come le etichette delle cassette.
                  Text(
                    'Sing along, learn along!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.permanentMarker(
                      color: Colors.black,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 58),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: scheme.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 18,
                      ),
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                    icon: const Icon(Icons.favorite),
                    label: const Text('I miei preferiti'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const FavoritesScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('I miei preferiti'),
      ),
      body: ListView.separated(
        itemCount: favorites.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final song = favorites[i];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: AlbumCover(song: song, size: 64),
            title: Text(song.title),
            subtitle: Text(song.artist),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => SongScreen(song: song))),
          );
        },
      ),
    );
  }
}

/// Scheda della canzone: titolo, artista e Play.
class SongScreen extends StatelessWidget {
  final Song song;

  const SongScreen({super.key, required this.song});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.black),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                song.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                song.artist,
                style: const TextStyle(fontSize: 20, color: Colors.grey),
              ),
              const SizedBox(height: 48),
              IconButton.filled(
                iconSize: 64,
                icon: const Icon(Icons.play_arrow),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => LyricsScreen(song: song)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Copertina del disco, scaricata a runtime. Mostra una nota finché non arriva.
class AlbumCover extends StatelessWidget {
  final Song song;
  final double size;

  const AlbumCover({super.key, required this.song, this.size = 56});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: size,
      height: size,
      color: Colors.white10,
      child: const Icon(Icons.music_note, color: Colors.grey),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: FutureBuilder<String?>(
        future: CoverService.coverUrl(song),
        builder: (context, snap) {
          final url = snap.data;
          if (url == null) return placeholder;
          return Image.network(
            url,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => placeholder,
          );
        },
      ),
    );
  }
}
