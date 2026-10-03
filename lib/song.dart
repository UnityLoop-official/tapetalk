/// Configurazione della canzone di test.
/// Nessun testo qui: testo e traduzioni vengono scaricati a runtime.
class Song {
  final String title;
  final String artist;

  /// Video YouTube da cui viene riprodotto l'audio.
  final String youtubeId;

  /// Pagina Musixmatch con la traduzione italiana (fonte provvisoria di test).
  /// Se manca, si usa solo MyMemory.
  final String? musixmatchUrl;

  /// Durata del video in secondi: serve a scegliere la versione giusta
  /// del testo quando ne esistono diverse (album, remix, live...).
  final int? durationSeconds;

  /// Correzione del tempo tra video e testo sincronizzato, in secondi.
  /// Positivo = il testo appare più tardi.
  final double offsetSeconds;

  const Song({
    required this.title,
    required this.artist,
    required this.youtubeId,
    this.musixmatchUrl,
    this.durationSeconds,
    this.offsetSeconds = 0,
  });

  /// Identifica la canzone anche prima di conoscere il video.
  String get key => '${artist.toLowerCase()}|${title.toLowerCase()}';

  Song withVideo(String id) => Song(
    title: title,
    artist: artist,
    youtubeId: id,
    musixmatchUrl: musixmatchUrl,
    durationSeconds: durationSeconds,
    offsetSeconds: offsetSeconds,
  );

  Map<String, dynamic> toJson() => {
    'title': title,
    'artist': artist,
    'youtubeId': youtubeId,
    'musixmatchUrl': musixmatchUrl,
    'durationSeconds': durationSeconds,
    'offsetSeconds': offsetSeconds,
  };

  factory Song.fromJson(Map json) => Song(
    title: json['title'] as String,
    artist: json['artist'] as String,
    youtubeId: json['youtubeId'] as String,
    musixmatchUrl: json['musixmatchUrl'] as String?,
    durationSeconds: json['durationSeconds'] as int?,
    offsetSeconds: (json['offsetSeconds'] as num? ?? 0).toDouble(),
  );
}

const testSong = Song(
  title: 'Waiting for the Night',
  artist: 'Depeche Mode',
  youtubeId: 'RI_aU2nl8oY', // Remastered 2022, canale ufficiale Depeche Mode
  musixmatchUrl:
      'https://www.musixmatch.com/it/testo/Depeche-Mode/Waiting-for-the-Night/traduzione/italiano',
);

const englishmanInNewYork = Song(
  title: 'Englishman in New York',
  artist: 'Sting',
  youtubeId: 'd27gTrPPAyk', // video originale, canale ufficiale Sting
);

const dontMugYourself = Song(
  title: "Don't Mug Yourself",
  artist: 'The Streets',
  youtubeId: 'nHs2sQOHX-0', // video ufficiale, canale The Streets
  durationSeconds: 198,
);

const itsMyLife = Song(
  title: "It's My Life",
  artist: 'Talk Talk',
  youtubeId: 'mAOkNNSjkuU', // audio ufficiale (Talk Talk - Topic)
  durationSeconds: 233,
);

const lifesWhatYouMakeIt = Song(
  title: "Life's What You Make It",
  artist: 'Talk Talk',
  youtubeId: 'f1zxBSQEG08', // audio ufficiale (Talk Talk - Topic)
  durationSeconds: 221,
);

/// Canzoni suggerite: ognuno sceglie le sue con il cuore o ne cerca di nuove.
const catalog = [
  testSong,
  englishmanInNewYork,
  dontMugYourself,
  itsMyLife,
  lifesWhatYouMakeIt,
];
