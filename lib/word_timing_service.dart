/// Una parola dei sottotitoli automatici di YouTube, con il momento in cui
/// viene detta nel video.
class TimedWord {
  final String word;
  final Duration time;

  const TimedWord(this.word, this.time);
}

/// Allinea le parole di una riga ai tempi veri dei sottotitoli automatici
/// (scaricati da VideoSync).
class WordTimingService {
  /// Allinea le parole di una riga del testo ai tempi veri di [timed].
  /// Le parole trovate prendono il loro tempo; quelle che il riconoscimento
  /// automatico ha sbagliato si collocano in mezzo alle vicine.
  /// Se nella riga non si trova nessuna parola, resta la stima [estimate].
  static List<Duration> align({
    required List<String> words,
    required Duration lineStart,
    required Duration lineEnd,
    required List<Duration> estimate,
    required List<TimedWord> timed,
  }) {
    final window = [
      for (final t in timed)
        if (t.time >= lineStart - const Duration(seconds: 1) &&
            t.time < lineEnd)
          t,
    ];
    final times = List<Duration?>.filled(words.length, null);
    var next = 0;
    for (var k = 0; k < words.length; k++) {
      final n = _norm(words[k]);
      if (n.isEmpty) continue;
      // Cerco poco più avanti: così una parola sbagliata non fa saltare
      // l'allineamento alla fine della riga.
      for (var x = next; x < window.length && x < next + 4; x++) {
        if (_norm(window[x].word) == n) {
          times[k] = window[x].time;
          next = x + 1;
          break;
        }
      }
    }
    final matched = [
      for (var k = 0; k < words.length; k++)
        if (times[k] != null) k,
    ];
    if (matched.isEmpty) return estimate;

    final first = matched.first;
    final last = matched.last;
    final result = <Duration>[];
    for (var k = 0; k < words.length; k++) {
      final Duration t;
      if (times[k] != null) {
        t = times[k]!;
      } else if (k < first) {
        // Prima della prima parola trovata: tra l'inizio riga e quella.
        t = lineStart + (times[first]! - lineStart) * (k / first);
      } else if (k > last) {
        // Dopo l'ultima trovata: stesso passo della stima.
        t = times[last]! + (estimate[k] - estimate[last]);
      } else {
        final a = matched.lastWhere((m) => m < k);
        final b = matched.firstWhere((m) => m > k);
        t = times[a]! + (times[b]! - times[a]!) * ((k - a) / (b - a));
      }
      // Mai prima della parola precedente.
      result.add(result.isNotEmpty && t < result.last ? result.last : t);
    }
    return result;
  }

  static String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}
