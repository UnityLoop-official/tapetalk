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

/// Le canzoni dell'elenco "I miei preferiti".
const favorites = [
  testSong,
  englishmanInNewYork,
  dontMugYourself,
  itsMyLife,
  lifesWhatYouMakeIt,
];
