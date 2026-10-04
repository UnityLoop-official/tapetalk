import 'package:flutter_test/flutter_test.dart';
import 'package:saimon_musix/lyrics_service.dart';
import 'package:saimon_musix/video_sync.dart';

Duration s(double v) => Duration(milliseconds: (v * 1000).round());

final lines = [
  LyricLine(s(10), 'Is this the real life'),
  LyricLine(s(15), 'Is this just fantasy'),
  LyricLine(s(20), 'Caught in a landslide'),
  LyricLine(s(25), 'No escape from reality'),
  LyricLine(s(30), 'Open your eyes'),
  LyricLine(s(35), 'Look up to the skies and see'),
  LyricLine(s(40), 'I am just a poor boy'),
];

void main() {
  test('video con un\'intro più lunga: tutto il testo si sposta', () {
    final sync = VideoSync(300, [
      for (final l in lines) Cue(l.time + s(4.6), '♪ ${l.english} ♪'),
    ], const []);
    expect(sync.alignedTimes(lines), [for (final l in lines) l.time + s(4.6)]);
  });

  test('video montato diversamente: ogni riga prende il suo tempo', () {
    final video = [s(8), s(13), s(18), s(23), s(36), s(41), s(46)];
    final sync = VideoSync(300, [
      for (var i = 0; i < lines.length; i++) Cue(video[i], lines[i].english),
    ], const []);
    expect(sync.alignedTimes(lines), video);
  });

  test('riga non ritrovata: segue lo spostamento della precedente', () {
    final sync = VideoSync(300, [
      for (final l in lines)
        if (!l.english.startsWith('Open')) Cue(l.time + s(2), l.english),
    ], const []);
    expect(sync.alignedTimes(lines)![4], s(32));
  });

  test('troppo poche righe ritrovate: resta il testo com\'è', () {
    final sync = VideoSync(300, [Cue(s(12), 'Is this the real life')], const []);
    expect(sync.alignedTimes(lines), isNull);
  });
}
