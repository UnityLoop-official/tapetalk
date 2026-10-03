import 'package:flutter/services.dart';

/// App esterne da cui si importano le playlist.
enum ExternalApp {
  spotify('com.spotify.music'),
  shazam('com.shazam.android');

  final String package;

  const ExternalApp(this.package);
}

/// Controlla se un'app è installata sul telefono, ne dà l'icona e la apre
/// (codice Android in MainActivity.kt).
class InstalledApps {
  static const _channel = MethodChannel('tapetalk/apps');

  static Future<bool> isInstalled(ExternalApp app) async =>
      await _channel.invokeMethod<bool>('isInstalled', {
        'package': app.package,
      }) ??
      false;

  /// L'icona dell'app (PNG), o null se non è installata.
  static Future<Uint8List?> icon(ExternalApp app) =>
      _channel.invokeMethod<Uint8List>('icon', {'package': app.package});

  static Future<bool> open(ExternalApp app) async =>
      await _channel.invokeMethod<bool>('open', {'package': app.package}) ??
      false;
}
