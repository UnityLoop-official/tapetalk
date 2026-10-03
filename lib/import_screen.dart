import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'installed_apps.dart';
import 'playlist_import.dart';

/// Importa canzoni da link incollati: playlist di Spotify e canzoni di
/// Shazam. Mostra i loghi di Spotify e Shazam e dice se sono installati.
/// Tutti gli Shazam insieme si importano passando da Spotify ("My Shazam
/// Tracks").
class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final _link = TextEditingController();
  late final Future<bool> _hasSpotify;
  late final Future<bool> _hasShazam;

  bool _importing = false;
  int _done = 0;
  int _total = 0;
  String? _message;

  @override
  void initState() {
    super.initState();
    _hasSpotify = InstalledApps.isInstalled(ExternalApp.spotify);
    _hasShazam = InstalledApps.isInstalled(ExternalApp.shazam);
  }

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) setState(() => _link.text = data!.text!.trim());
  }

  Future<void> _import() async {
    if (_link.text.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _importing = true;
      _message = null;
      _done = 0;
      _total = 0;
    });
    try {
      final r = await PlaylistImport.fromText(
        _link.text,
        onProgress: (done, total) {
          if (mounted) {
            setState(() {
              _done = done;
              _total = total;
            });
          }
        },
      );
      _message =
          'Added ${r.added} ${r.added == 1 ? 'song' : 'songs'} from ${r.source}.'
          '${r.skipped > 0 ? '\n${r.skipped} skipped: no synced lyrics.' : ''}';
    } on FormatException {
      _message =
          'Paste a Spotify playlist link, Shazam song links, or one song per '
          'line as Artist - Title.';
    } catch (_) {
      _message = "Couldn't import. Is the Spotify playlist public?";
    }
    if (mounted) setState(() => _importing = false);
  }

  @override
  Widget build(BuildContext context) {
    final purple = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Import songs'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _AppStatus(
            app: ExternalApp.spotify,
            name: 'Spotify',
            installed: _hasSpotify,
            whenInstalled:
                'Open a playlist in Spotify, tap Share → Copy link and paste '
                'it here. The playlist must be public.',
            whenMissing:
                "Spotify isn't installed on this phone. You can still paste "
                'the link of a public playlist from the Spotify website.',
            action: TextButton.icon(
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open Spotify'),
              onPressed: () => InstalledApps.open(ExternalApp.spotify),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _link,
            enabled: !_importing,
            minLines: 1,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Spotify or Shazam links, or Artist - Title lines',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: 'Paste',
                icon: const Icon(Icons.content_paste),
                onPressed: _importing ? null : _paste,
              ),
            ),
            onSubmitted: (_) => _import(),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: purple,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            icon: const Icon(Icons.download),
            label: const Text('Import'),
            onPressed: _importing ? null : _import,
          ),
          if (_importing) ...[
            const SizedBox(height: 20),
            LinearProgressIndicator(value: _total == 0 ? null : _done / _total),
            const SizedBox(height: 8),
            Text(
              _total == 0
                  ? 'Reading the playlist…'
                  : 'Looking for synced lyrics… $_done/$_total',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
          if (_message != null) ...[
            const SizedBox(height: 20),
            Text(
              _message!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ],
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          _AppStatus(
            app: ExternalApp.shazam,
            name: 'Shazam',
            installed: _hasShazam,
            whenInstalled:
                'In Shazam, open a song and tap Share → Copy link, then paste '
                'it above: you can paste several links at once.\n\n'
                'To import all your Shazams together, connect Spotify in '
                'Shazam (Settings → Spotify): they are saved in the Spotify '
                'playlist "My Shazam Tracks". Import that playlist above.',
            whenMissing:
                "Shazam isn't installed on this phone. You can still paste "
                'links of Shazam songs.',
            action: TextButton.icon(
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open Shazam'),
              onPressed: () => InstalledApps.open(ExternalApp.shazam),
            ),
          ),
        ],
      ),
    );
  }
}

/// Riga con il nome dell'app, se è installata e cosa fare.
class _AppStatus extends StatelessWidget {
  final ExternalApp app;
  final String name;
  final Future<bool> installed;
  final String whenInstalled;
  final String whenMissing;
  final Widget? action;

  const _AppStatus({
    required this.app,
    required this.name,
    required this.installed,
    required this.whenInstalled,
    required this.whenMissing,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: installed,
      builder: (context, snap) {
        final ok = snap.data;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _AppLogo(app: app),
                const SizedBox(width: 12),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 10),
                if (ok != null)
                  Icon(
                    ok ? Icons.check_circle : Icons.cancel,
                    size: 20,
                    color: ok ? Colors.green : Colors.redAccent,
                  ),
                const Spacer(),
                if (ok == true && action != null) action!,
              ],
            ),
            const SizedBox(height: 6),
            if (ok != null)
              Text(
                ok ? whenInstalled : whenMissing,
                style: const TextStyle(color: Colors.white70, fontSize: 15),
              ),
          ],
        );
      },
    );
  }
}

/// Il logo dell'app: la sua icona vera, presa dal telefono se è installata;
/// altrimenti un segnaposto grigio.
class _AppLogo extends StatelessWidget {
  final ExternalApp app;

  const _AppLogo({required this.app});

  @override
  Widget build(BuildContext context) {
    const size = 40.0;
    return FutureBuilder<Uint8List?>(
      future: InstalledApps.icon(app),
      builder: (context, snap) {
        final png = snap.data;
        if (png != null) {
          return Image.memory(png, width: size, height: size);
        }
        return Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: Colors.white12,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.music_note, color: Colors.grey),
        );
      },
    );
  }
}
