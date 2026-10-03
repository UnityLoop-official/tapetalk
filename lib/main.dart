import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'cover_service.dart';
import 'favorites_store.dart';
import 'logo.dart';
import 'lyrics_screen.dart';
import 'song.dart';
import 'song_search.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FavoritesStore.load();
  runApp(const TapeTalkApp());
}

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
        // Numero di versione, per sapere quale c'è su ogni telefono.
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: FutureBuilder(
              future: PackageInfo.fromPlatform(),
              builder: (context, snap) => Text(
                snap.hasData
                    ? 'v${snap.data!.version} (${snap.data!.buildNumber})'
                    : '',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54, fontSize: 13),
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
    void openCatalog() => Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CatalogScreen()));
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('I miei preferiti'),
        actions: [
          IconButton(
            tooltip: 'Aggiungi canzoni',
            icon: const Icon(Icons.add),
            onPressed: openCatalog,
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: FavoritesStore.songs,
        builder: (context, songs, _) {
          if (songs.isEmpty) {
            return Center(
              child: TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Aggiungi la prima canzone'),
                onPressed: openCatalog,
              ),
            );
          }
          return ListView.separated(
            itemCount: songs.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) => SongTile(
              song: songs[i],
              trailing: const Icon(Icons.chevron_right),
            ),
          );
        },
      ),
    );
  }
}

/// Cerca canzoni nuove; senza ricerca mostra quelle suggerite.
/// Il cuore le aggiunge o le toglie dai preferiti.
class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final _query = TextEditingController();
  Future<List<Song>>? _results;

  void _search() {
    final q = _query.text.trim();
    setState(() => _results = q.isEmpty ? null : SongSearch.search(q));
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Widget _list(List<Song> songs) => ListView.separated(
    itemCount: songs.length,
    separatorBuilder: (_, _) => const Divider(height: 1),
    itemBuilder: (context, i) => SongTile(
      song: songs[i],
      trailing: FavoriteButton(song: songs[i]),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: TextField(
          controller: _query,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Cerca titolo o artista',
            border: InputBorder.none,
          ),
          onSubmitted: (_) => _search(),
        ),
        actions: [
          IconButton(
            tooltip: 'Cerca',
            icon: const Icon(Icons.search),
            onPressed: _search,
          ),
        ],
      ),
      body: _results == null
          ? _list(catalog)
          : FutureBuilder(
              future: _results,
              builder: (context, snap) {
                if (snap.hasError) {
                  return const Center(
                    child: Text('Ricerca non riuscita. Controlla la rete.'),
                  );
                }
                final songs = snap.data;
                if (songs == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (songs.isEmpty) {
                  return const Center(
                    child: Text('Nessuna canzone con il testo sincronizzato.'),
                  );
                }
                return _list(songs);
              },
            ),
    );
  }
}

/// La canzone pronta da suonare: se viene dalla ricerca cerca il video,
/// con una rotella mentre aspetta. Null se il video non si trova.
Future<Song?> _readySong(BuildContext context, Song song) async {
  if (song.youtubeId.isNotEmpty) return song;
  final saved = FavoritesStore.songs.value.where((s) => s.key == song.key);
  if (saved.isNotEmpty) return saved.first;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );
  try {
    return await SongSearch.withVideo(song);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video non trovato per questa canzone')),
      );
    }
    return null;
  } finally {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  }
}

class SongTile extends StatelessWidget {
  final Song song;
  final Widget trailing;

  const SongTile({super.key, required this.song, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: AlbumCover(song: song, size: 64),
      title: Text(song.title),
      subtitle: Text(song.artist),
      trailing: trailing,
      onTap: () async {
        final ready = await _readySong(context, song);
        if (ready == null || !context.mounted) return;
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => SongScreen(song: ready)));
      },
    );
  }
}

/// Cuore pieno se la canzone è tra i preferiti; un tocco la aggiunge o la toglie.
class FavoriteButton extends StatelessWidget {
  final Song song;

  const FavoriteButton({super.key, required this.song});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: FavoritesStore.songs,
      builder: (context, _, _) {
        final isFavorite = FavoritesStore.contains(song);
        return IconButton(
          tooltip: isFavorite ? 'Togli dai preferiti' : 'Aggiungi ai preferiti',
          icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
          color: isFavorite ? Theme.of(context).colorScheme.primary : null,
          onPressed: () async {
            final ready = await _readySong(context, song);
            if (ready != null) await FavoritesStore.toggle(ready);
          },
        );
      },
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
      appBar: AppBar(
        backgroundColor: Colors.black,
        actions: [FavoriteButton(song: song)],
      ),
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
