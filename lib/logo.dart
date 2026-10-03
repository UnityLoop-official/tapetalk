import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Gli animali-musicassetta del logo. Tutti condividono la stessa base
/// (corpo della cassetta, bobine come occhi, finestrella del nastro in basso)
/// e cambiano solo orecchie, muso e dettagli.
enum LogoAnimal {
  gufo,
  gatto,
  orso,
  topo,
  coniglio,
  rana,
  volpe,
  maiale,
  pipistrello,
  cane,
  mucca,
}

class CassetteAnimalLogo extends StatelessWidget {
  final LogoAnimal animal;
  final double size;
  final Color color;
  final Color background;

  const CassetteAnimalLogo({
    super.key,
    this.animal = LogoAnimal.gufo,
    this.size = 200,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 0.8,
      child: CustomPaint(painter: _AnimalPainter(animal, color, background)),
    );
  }
}

/// Logo che cambia animale a intervalli regolari, con dissolvenza.
class RotatingLogo extends StatefulWidget {
  final double size;
  final Color color;
  final Color background;
  final Duration interval;

  const RotatingLogo({
    super.key,
    this.size = 200,
    required this.color,
    required this.background,
    this.interval = const Duration(seconds: 4),
  });

  @override
  State<RotatingLogo> createState() => _RotatingLogoState();
}

class _RotatingLogoState extends State<RotatingLogo> {
  late final Timer _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.interval, (_) {
      setState(() => _index = (_index + 1) % LogoAnimal.values.length);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animal = LogoAnimal.values[_index];
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 700),
      child: CassetteAnimalLogo(
        key: ValueKey(animal),
        animal: animal,
        size: widget.size,
        color: widget.color,
        background: widget.background,
      ),
    );
  }
}

class _AnimalPainter extends CustomPainter {
  final LogoAnimal animal;
  final Color color;
  final Color background;

  _AnimalPainter(this.animal, this.color, this.background);

  static const _eyeL = Offset(64, 76);
  static const _eyeR = Offset(136, 76);

  @override
  void paint(Canvas canvas, Size size) {
    // Disegno su una griglia 200x160, poi scalo.
    canvas.scale(size.width / 200, size.height / 160);
    final ink = Paint()..color = color;
    final hole = Paint()..color = background;

    _behind(canvas, ink, hole);

    // Corpo della cassetta
    canvas.drawRRect(
      RRect.fromLTRBR(10, 28, 190, 150, const Radius.circular(16)),
      ink,
    );

    // Occhi = bobine
    for (final c in [_eyeL, _eyeR]) {
      canvas.drawCircle(c, 27, hole);
      canvas.drawCircle(c, 11, ink);
      for (var i = 0; i < 6; i++) {
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.rotate(i * math.pi / 3);
        canvas.drawRect(const Rect.fromLTWH(-2, -15, 4, 6), ink);
        canvas.restore();
      }
    }

    // Finestrella del nastro con le due viti
    canvas.drawPath(
      Path()
        ..moveTo(52, 150)
        ..lineTo(62, 128)
        ..lineTo(138, 128)
        ..lineTo(148, 150)
        ..close(),
      hole,
    );
    canvas.drawCircle(const Offset(80, 140), 4, ink);
    canvas.drawCircle(const Offset(120, 140), 4, ink);

    _front(canvas, ink, hole);
  }

  /// Elementi dietro al corpo: orecchie, corna, ali.
  void _behind(Canvas canvas, Paint ink, Paint hole) {
    switch (animal) {
      case LogoAnimal.gufo:
        _mirror(canvas, (c) {
          c.drawPath(_tri(14, 40, 22, 4, 60, 34), ink);
        });
      case LogoAnimal.gatto:
        _mirror(canvas, (c) {
          c.drawPath(_tri(30, 34, 46, 0, 84, 30), ink);
          c.drawPath(_tri(44, 30, 50, 12, 70, 30), hole);
        });
      case LogoAnimal.orso:
        _mirror(canvas, (c) {
          c.drawCircle(const Offset(32, 28), 24, ink);
          c.drawCircle(const Offset(32, 28), 11, hole);
        });
      case LogoAnimal.topo:
        _mirror(canvas, (c) {
          c.drawCircle(const Offset(30, 26), 32, ink);
          c.drawCircle(const Offset(30, 26), 18, hole);
        });
      case LogoAnimal.coniglio:
        _mirror(canvas, (c) {
          c.drawRRect(
            RRect.fromLTRBR(44, -34, 74, 40, const Radius.circular(15)),
            ink,
          );
          c.drawRRect(
            RRect.fromLTRBR(53, -24, 65, 24, const Radius.circular(6)),
            hole,
          );
        });
      case LogoAnimal.rana:
        // Occhi sporgenti sopra la testa
        _mirror(canvas, (c) => c.drawCircle(const Offset(64, 48), 34, ink));
      case LogoAnimal.volpe:
        _mirror(canvas, (c) {
          c.drawPath(_tri(12, 44, 20, -6, 66, 30), ink);
          c.drawPath(_tri(24, 34, 28, 10, 50, 30), hole);
        });
      case LogoAnimal.maiale:
        _mirror(canvas, (c) => c.drawPath(_tri(20, 30, 14, 4, 58, 28), ink));
      case LogoAnimal.pipistrello:
        _mirror(canvas, (c) {
          // Ala con il bordo smerlato
          c.drawPath(
            Path()
              ..moveTo(12, 44)
              ..lineTo(-34, 30)
              ..quadraticBezierTo(-22, 56, -38, 74)
              ..quadraticBezierTo(-16, 76, -22, 100)
              ..quadraticBezierTo(-2, 96, 12, 122)
              ..close(),
            ink,
          );
          c.drawPath(_tri(34, 30, 40, 4, 62, 30), ink);
        });
      case LogoAnimal.cane:
        break; // le orecchie pendono davanti al corpo
      case LogoAnimal.mucca:
        _mirror(canvas, (c) {
          // Corna
          c.drawPath(
            Path()
              ..moveTo(40, 30)
              ..quadraticBezierTo(30, 6, 46, -4)
              ..quadraticBezierTo(46, 14, 62, 30)
              ..close(),
            ink,
          );
          // Orecchie orizzontali
          c.drawOval(const Rect.fromLTRB(-18, 40, 24, 62), ink);
        });
    }
  }

  /// Elementi davanti al corpo: muso, naso, baffi.
  void _front(Canvas canvas, Paint ink, Paint hole) {
    final line = Paint()
      ..color = background
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    switch (animal) {
      case LogoAnimal.gufo:
        canvas.drawPath(_tri(91, 98, 109, 98, 100, 112), hole);
      case LogoAnimal.gatto:
        canvas.drawPath(_tri(93, 102, 107, 102, 100, 111), hole);
        _mirror(canvas, (c) {
          c.drawLine(const Offset(20, 104), const Offset(54, 108), line);
          c.drawLine(const Offset(22, 118), const Offset(54, 114), line);
        });
      case LogoAnimal.orso:
        canvas.drawOval(const Rect.fromLTRB(88, 100, 112, 114), hole);
      case LogoAnimal.topo:
        canvas.drawCircle(const Offset(100, 108), 6, hole);
        _mirror(canvas, (c) {
          c.drawLine(const Offset(30, 102), const Offset(60, 108), line);
          c.drawLine(const Offset(30, 116), const Offset(60, 112), line);
        });
      case LogoAnimal.coniglio:
        canvas.drawPath(_tri(94, 102, 106, 102, 100, 109), hole);
        canvas.drawLine(const Offset(100, 109), const Offset(100, 116), line);
        canvas.drawRect(const Rect.fromLTRB(94, 117, 106, 125), hole);
      case LogoAnimal.rana:
        canvas.drawPath(
          Path()
            ..moveTo(50, 110)
            ..quadraticBezierTo(100, 126, 150, 110),
          line..strokeWidth = 4,
        );
      case LogoAnimal.volpe:
        canvas.drawPath(_tri(76, 98, 124, 98, 100, 124), hole);
        canvas.drawCircle(const Offset(100, 118), 5, ink);
      case LogoAnimal.maiale:
        canvas.drawOval(const Rect.fromLTRB(80, 98, 120, 122), hole);
        canvas.drawOval(const Rect.fromLTRB(89, 105, 96, 115), ink);
        canvas.drawOval(const Rect.fromLTRB(104, 105, 111, 115), ink);
      case LogoAnimal.pipistrello:
        _mirror(
          canvas,
          (c) => c.drawPath(_tri(90, 104, 96, 104, 93, 114), hole),
        );
      case LogoAnimal.cane:
        // Orecchie pendenti ai lati, staccate dal corpo da una sottile fessura
        _mirror(canvas, (c) {
          c.drawRRect(
            RRect.fromLTRBAndCorners(
              -24,
              24,
              4,
              112,
              topLeft: const Radius.circular(10),
              bottomLeft: const Radius.circular(14),
              bottomRight: const Radius.circular(14),
            ),
            ink,
          );
          c.drawRect(const Rect.fromLTRB(0, 28, 20, 42), ink);
        });
        canvas.drawOval(const Rect.fromLTRB(88, 100, 112, 114), hole);
        canvas.drawRRect(
          RRect.fromLTRBR(94, 116, 106, 126, const Radius.circular(6)),
          hole,
        );
      case LogoAnimal.mucca:
        canvas.drawRRect(
          RRect.fromLTRBR(74, 100, 126, 122, const Radius.circular(11)),
          hole,
        );
        canvas.drawCircle(const Offset(88, 111), 4, ink);
        canvas.drawCircle(const Offset(112, 111), 4, ink);
    }
  }

  /// Disegna un elemento sul lato sinistro e lo specchia a destra.
  void _mirror(Canvas canvas, void Function(Canvas) draw) {
    draw(canvas);
    canvas.save();
    canvas.translate(200, 0);
    canvas.scale(-1, 1);
    draw(canvas);
    canvas.restore();
  }

  Path _tri(double x1, double y1, double x2, double y2, double x3, double y3) =>
      Path()
        ..moveTo(x1, y1)
        ..lineTo(x2, y2)
        ..lineTo(x3, y3)
        ..close();

  @override
  bool shouldRepaint(_AnimalPainter old) =>
      old.animal != animal ||
      old.color != color ||
      old.background != background;
}
