import 'package:flutter/services.dart';

/// App esterne da cui si importano le playlist.
enum ExternalApp {
  spotify('com.spotify.music'),
  shazam('com.shazam.android');

  final String package;

  const ExternalApp(this.package);
}

/// Controlla se un'app è installata sul telefono e la apre
/// (codice Android in MainActivity.kt).
class InstalledApps {
  static const _channel = MethodChannel('tapetalk/apps');

  static Future<bool> isInstalled(ExternalApp app) async =>
      await _channel.invokeMethod<bool>('isInstalled', {
        'package': app.package,
      }) ??
      false;

  static Future<bool> open(ExternalApp app) async =>
      await _channel.invokeMethod<bool>('open', {'package': app.package}) ??
      false;
}
