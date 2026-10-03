import 'package:flutter_test/flutter_test.dart';
import 'package:saimon_musix/word_timing_service.dart';

Duration ms(int v) => Duration(milliseconds: v);

void main() {
  final estimate = [ms(1000), ms(1500), ms(2000), ms(2500)];

  test('parole trovate prendono il tempo vero', () {
    final r = WordTimingService.align(
      words: ['All', 'I', 'ever', 'wanted'],
      lineStart: ms(1000),
      lineEnd: ms(6000),
      estimate: estimate,
      timed: [
        TimedWord('all', ms(1200)),
        TimedWord('i', ms(1900)),
        TimedWord('ever', ms(2600)),
        TimedWord('wanted', ms(3400)),
      ],
    );
    expect(r, [ms(1200), ms(1900), ms(2600), ms(3400)]);
  });

  test('una parola sbagliata dal riconoscimento sta in mezzo alle vicine', () {
    final r = WordTimingService.align(
      words: ['All', 'I', 'ever', 'wanted'],
      lineStart: ms(1000),
      lineEnd: ms(6000),
      estimate: estimate,
      timed: [
        TimedWord('all', ms(1200)),
        TimedWord('eye', ms(1900)),
        TimedWord('ever', ms(2600)),
        TimedWord('wanted', ms(3400)),
      ],
    );
    expect(r, [ms(1200), ms(1900), ms(2600), ms(3400)]);
  });

  test('senza parole trovate resta la stima', () {
    final r = WordTimingService.align(
      words: ['All', 'I', 'ever', 'wanted'],
      lineStart: ms(1000),
      lineEnd: ms(6000),
      estimate: estimate,
      timed: [TimedWord('hello', ms(9000))],
    );
    expect(r, estimate);
  });

  test('ignora le parole fuori dalla riga e la punteggiatura', () {
    final r = WordTimingService.align(
      words: ["Don't", 'stop'],
      lineStart: ms(5000),
      lineEnd: ms(8000),
      estimate: [ms(5000), ms(6000)],
      timed: [
        TimedWord('stop', ms(1000)),
        TimedWord('dont', ms(5300)),
        TimedWord('stop', ms(5800)),
      ],
    );
    expect(r, [ms(5300), ms(5800)]);
  });
}
