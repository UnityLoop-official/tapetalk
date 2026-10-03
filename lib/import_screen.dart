import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'installed_apps.dart';
import 'playlist_import.dart';

/// Importa una playlist di Spotify dal suo link. Le canzoni di Shazam si
/// importano passando da Spotify (playlist "My Shazam Tracks").
/// Dice se Spotify e Shazam sono installati sul telefono.
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
      final r = await PlaylistImport.fromSpotify(
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
          'Added ${r.added} songs from "${r.playlistName}".'
          '${r.skipped > 0 ? '\n${r.skipped} skipped: no synced lyrics.' : ''}';
    } on FormatException {
      _message = "That doesn't look like a Spotify playlist link.";
    } catch (_) {
      _message = "Couldn't import the playlist. Is it public?";
    }
    if (mounted) setState(() => _importing = false);
  }

  @override
  Widget build(BuildContext context) {
    final purple = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Import a playlist'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _AppStatus(
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
            decoration: InputDecoration(
              hintText: 'https://open.spotify.com/playlist/…',
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
            name: 'Shazam',
            installed: _hasShazam,
            whenInstalled:
                'In Shazam, connect Spotify (Settings → Spotify): your Shazams '
                'are saved in the Spotify playlist "My Shazam Tracks". Import '
                'that playlist here.',
            whenMissing: "Shazam isn't installed on this phone.",
          ),
        ],
      ),
    );
  }
}

/// Riga con il nome dell'app, se è installata e cosa fare.
class _AppStatus extends StatelessWidget {
  final String name;
  final Future<bool> installed;
  final String whenInstalled;
  final String whenMissing;
  final Widget? action;

  const _AppStatus({
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
