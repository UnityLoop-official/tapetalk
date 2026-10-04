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
    void openCatalog() => Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CatalogScreen()));
    return ValueListenableBuilder(
      valueListenable: FavoritesStore.playlists,
      builder: (context, _, _) {
        final playlist = FavoritesStore.current;
        final songs = playlist.songs;
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.black,
            title: Text(playlist.name),
            actions: const [_PlaylistMenu()],
          ),
          // Barra fissa in basso, come quella del sito di Roomee sul telefono.
          bottomNavigationBar: songs.isEmpty
              ? null
              : _PlaylistBar(
                  onAdd: openCatalog,
                  onImport: () => _openImport(context),
                ),
          body: songs.isEmpty
              ? _EmptyPlaylist(onCreate: openCatalog)
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 8),
                  itemCount: songs.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) =>
                      _RemovableSongTile(song: songs[i]),
                ),
        );
      },
    );
  }
}

/// Menu in alto a destra per gestire le playlist, a livelli: "Playlists"
/// apre l'elenco per passare da una all'altra o crearne una nuova; poi
/// rinominare, svuotare o eliminare quella aperta.
class _PlaylistMenu extends StatelessWidget {
  const _PlaylistMenu();

  @override
  Widget build(BuildContext context) {
    // Si ricostruisce a ogni cambio, così parla sempre della playlist aperta.
    return ValueListenableBuilder(
      valueListenable: FavoritesStore.playlists,
      builder: (context, _, _) => _menu(context, FavoritesStore.current),
    );
  }

  Widget _menu(BuildContext context, Playlist playlist) {
    return MenuAnchor(
      builder: (context, menu, _) => IconButton(
        tooltip: 'Manage playlists',
        icon: const Icon(Icons.more_vert),
        onPressed: () => menu.isOpen ? menu.close() : menu.open(),
      ),
      menuChildren: [
        SubmenuButton(
          leadingIcon: const Icon(Icons.queue_music),
          menuChildren: [
            for (final p in FavoritesStore.playlists.value)
              MenuItemButton(
                leadingIcon: Icon(
                  p.id == playlist.id ? Icons.check : Icons.queue_music,
                ),
                onPressed: () => FavoritesStore.open(p.id),
                child: Text('${p.name} (${p.songs.length})'),
              ),
            const Divider(height: 1),
            MenuItemButton(
              leadingIcon: const Icon(Icons.add),
              onPressed: () async {
                final name = await _askName(context, 'New playlist', '');
                if (name != null) await FavoritesStore.create(name);
              },
              child: const Text('New playlist…'),
            ),
          ],
          child: const Text('Playlists'),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.edit),
          onPressed: () async {
            final name = await _askName(
              context,
              'Rename playlist',
              playlist.name,
            );
            if (name != null) await FavoritesStore.rename(name);
          },
          child: const Text('Rename playlist…'),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.clear_all),
          onPressed: playlist.songs.isEmpty
              ? null
              : () async {
                  final ok = await _confirm(
                    context,
                    icon: Icons.clear_all,
                    title: 'Clear playlist?',
                    message:
                        'All ${playlist.songs.length} songs will be removed '
                        'from "${playlist.name}". The playlist stays.',
                    action: 'Clear',
                  );
                  if (ok) await FavoritesStore.clear();
                },
          child: const Text('Clear playlist'),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.delete, color: Colors.redAccent),
          onPressed: () async {
            final ok = await _confirm(
              context,
              icon: Icons.delete,
              title: 'Delete playlist?',
              message:
                  '"${playlist.name}" and its ${playlist.songs.length} songs '
                  'will be deleted.',
              action: 'Delete',
            );
            if (ok) await FavoritesStore.deleteCurrent();
          },
          child: const Text(
            'Delete playlist',
            style: TextStyle(color: Colors.redAccent),
          ),
        ),
      ],
    );
  }
}

/// Chiede il nome di una playlist; null se si annulla o si lascia vuoto.
Future<String?> _askName(
  BuildContext context,
  String title,
  String initial,
) async {
  final controller = TextEditingController(text: initial);
  final name = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Playlist name'),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: const Text('OK'),
        ),
      ],
    ),
  );
  controller.dispose();
  final trimmed = name?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

/// Barra fissa in basso, sul modello di quella di roomee.dk sul telefono:
/// due pulsanti a pillola, aggiungere canzoni e importare da Spotify o
/// Shazam.
class _PlaylistBar extends StatelessWidget {
  final VoidCallback onAdd;
  final VoidCallback onImport;

  const _PlaylistBar({required this.onAdd, required this.onImport});

  @override
  Widget build(BuildContext context) {
    final purple = Theme.of(context).colorScheme.primary;
    const textStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.w700);
    const padding = EdgeInsets.symmetric(vertical: 12);
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x24000000),
              blurRadius: 24,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: purple,
                  foregroundColor: Colors.black,
                  padding: padding,
                  textStyle: textStyle,
                ),
                icon: const Icon(Icons.add, size: 22),
                label: const Text('Add songs'),
                onPressed: onAdd,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: purple.withValues(alpha: 0.35),
                  foregroundColor: Colors.black,
                  padding: padding,
                  textStyle: textStyle,
                ),
                icon: const Icon(Icons.playlist_add, size: 22),
                label: const Text('Import'),
                onPressed: onImport,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pulsante viola bordato per importare una playlist da Spotify o Shazam.
class _ImportButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _ImportButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final purple = Theme.of(context).colorScheme.primary;
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: purple,
        side: BorderSide(color: purple),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: const TextStyle(fontSize: 16),
      ),
      icon: const Icon(Icons.playlist_add),
      label: const Text('Import from Spotify or Shazam'),
      onPressed: onPressed,
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
      confirmDismiss: (_) => _confirmRemove(context, song),
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
              content: Text(
                '"${song.title}" removed from "${FavoritesStore.current.name}"',
              ),
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
            _ImportButton(onPressed: () => _openImport(context)),
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
/// Chiede conferma prima di togliere una canzone dalla playlist aperta, con una
/// finestra grande al centro: si toglie solo con "Remove".
Future<bool> _confirmRemove(BuildContext context, Song song) => _confirm(
  context,
  icon: Icons.delete,
  title: 'Remove from playlist?',
  message:
      '"${song.title}" by ${song.artist} will be removed from '
      '"${FavoritesStore.current.name}".',
  action: 'Remove',
);

/// Finestra di conferma grande al centro, con il pulsante rosso [action]:
/// true solo se si preme quello.
Future<bool> _confirm(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String message,
  required String action,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Icon(icon, size: 40, color: Colors.redAccent),
      title: Text(title),
      content: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 17),
      ),
      actionsAlignment: MainAxisAlignment.spaceEvenly,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel', style: TextStyle(fontSize: 17)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red.shade700,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(action, style: const TextStyle(fontSize: 17)),
        ),
      ],
    ),
  );
  return ok ?? false;
}

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

  /// Chiamato dopo aver tolto la canzone (es. per tornare alla lista).
  final VoidCallback? onRemoved;

  const FavoriteButton({super.key, required this.song, this.onRemoved});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: FavoritesStore.songs,
      builder: (context, _, _) {
        final isFavorite = FavoritesStore.contains(song);
        return IconButton(
          tooltip: isFavorite ? 'Remove from playlist' : 'Add to playlist',
          icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
          color: isFavorite ? Theme.of(context).colorScheme.primary : null,
          onPressed: () async {
            if (isFavorite && !await _confirmRemove(context, song)) return;
            if (!context.mounted) return;
            final ready = await _readySong(context, song);
            if (ready == null) return;
            await FavoritesStore.toggle(ready);
            if (isFavorite) onRemoved?.call();
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
        actions: [
          // Tolta dai preferiti: si torna alla lista con gli altri.
          FavoriteButton(
            song: song,
            onRemoved: () => Navigator.of(context).pop(),
          ),
        ],
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
