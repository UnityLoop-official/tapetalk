import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'cover_service.dart';
import 'favorites_store.dart';
import 'import_screen.dart';
import 'lyrics_screen.dart';
import 'lyrics_service.dart';
import 'mouth_logo.dart';
import 'song.dart';
import 'song_search.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FavoritesStore.load();
  await LyricsService.removeMusixmatchTranslations();
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
                  RotatingMouthLogo(
                    size: 260,
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
                    label: const Text('My favorites'),
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
    final purple = Theme.of(context).colorScheme.primary;
    void openCatalog() => Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CatalogScreen()));
    return ValueListenableBuilder(
      valueListenable: FavoritesStore.songs,
      builder: (context, songs, _) => Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: const Text('My favorites'),
          actions: [
            IconButton(
              tooltip: 'Import a playlist',
              icon: const Icon(Icons.playlist_add),
              onPressed: () => _openImport(context),
            ),
          ],
        ),
        // Pulsante grande e viola, sempre in vista finché c'è la lista.
        floatingActionButton: songs.isEmpty
            ? null
            : FloatingActionButton.extended(
                backgroundColor: purple,
                foregroundColor: Colors.black,
                icon: const Icon(Icons.add, size: 30),
                label: const Text(
                  'Add songs',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                onPressed: openCatalog,
              ),
        body: songs.isEmpty
            ? _EmptyPlaylist(onCreate: openCatalog)
            : ListView.separated(
                // Spazio in fondo per non coprire l'ultima canzone.
                padding: const EdgeInsets.only(bottom: 96),
                itemCount: songs.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) => _RemovableSongTile(song: songs[i]),
              ),
      ),
    );
  }
}

/// Canzone della playlist: scorrendola verso sinistra si toglie, con
/// "Undo" per rimetterla dov'era.
class _RemovableSongTile extends StatelessWidget {
  final Song song;

  const _RemovableSongTile({required this.song});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(song.key),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red.shade700,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Remove',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.delete, color: Colors.white),
          ],
        ),
      ),
      onDismissed: (_) async {
        final messenger = ScaffoldMessenger.of(context);
        final index = await FavoritesStore.remove(song);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('"${song.title}" removed from favorites'),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () => FavoritesStore.insert(song, index),
              ),
            ),
          );
      },
      child: SongTile(song: song, trailing: const Icon(Icons.chevron_right)),
    );
  }
}

/// Lista vuota: invita a creare la propria playlist.
class _EmptyPlaylist extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyPlaylist({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final purple = Theme.of(context).colorScheme.primary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.queue_music, size: 96, color: purple),
            const SizedBox(height: 24),
            const Text(
              'Create your playlist!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            const Text(
              'Search for the songs you love and add them with the heart: '
              "you'll find them here, ready to sing along.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, color: Colors.white70),
            ),
            const SizedBox(height: 36),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: purple,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 20,
                ),
                textStyle: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              icon: const Icon(Icons.add, size: 30),
              label: const Text('Add songs'),
              onPressed: onCreate,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: purple,
                side: BorderSide(color: purple),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                textStyle: const TextStyle(fontSize: 16),
              ),
              icon: const Icon(Icons.playlist_add),
              label: const Text('Import from Spotify or Shazam'),
              onPressed: () => _openImport(context),
            ),
          ],
        ),
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
            hintText: 'Search title or artist',
            border: InputBorder.none,
          ),
          onSubmitted: (_) => _search(),
        ),
        actions: [
          IconButton(
            tooltip: 'Search',
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
                    child: Text('Search failed. Check your connection.'),
                  );
                }
                final songs = snap.data;
                if (songs == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (songs.isEmpty) {
                  return const Center(
                    child: Text('No songs with synced lyrics found.'),
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
void _openImport(BuildContext context) => Navigator.of(
  context,
).push(MaterialPageRoute(builder: (_) => const ImportScreen()));

Future<Song?> _readySong(BuildContext context, Song song) async {
  if (song.youtubeId.isNotEmpty) return song;
  final saved = FavoritesStore.songs.value.where(
    (s) => s.key == song.key && s.youtubeId.isNotEmpty,
  );
  if (saved.isNotEmpty) return saved.first;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );
  try {
    final ready = await SongSearch.withVideo(song);
    // Canzone importata senza video: si salva il video trovato.
    await FavoritesStore.replace(ready);
    return ready;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No video found for this song')),
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
          tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
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
