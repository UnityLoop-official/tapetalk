import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Logo: il quadretto-bocca del quadro "Never stop dreaming" (quello blu),
/// tutto in [color], con i vuoti nel colore di sfondo, e un fumetto con una
/// frase di una canzone famosa. Senza [phrase] c'è solo il quadretto,
/// centrato in un quadrato (per l'icona dell'app).
class MouthLogo extends StatelessWidget {
  final double size;
  final Color color;
  final Color background;
  final String? phrase;

  const MouthLogo({
    super.key,
    this.size = 220,
    required this.color,
    required this.background,
    this.phrase = 'Let it be',
  });

  // Griglia di disegno, scalata a [size]: con il fumetto 220x175,
  // solo il quadretto 150x150.
  static const _w = 220.0;
  static const _h = 175.0;
  static const _iconSide = 150.0;

  @override
  Widget build(BuildContext context) {
    final phrase = this.phrase;
    if (phrase == null) {
      return SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _MouthPainter(color, background, false)),
      );
    }
    final k = size / _w;
    return SizedBox(
      width: size,
      height: _h * k,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _MouthPainter(color, background, true)),
          ),
          // Testo del fumetto (vedi _bubbleCenter nel painter).
          Positioned(
            left: (_MouthPainter._bubbleCenter.dx - 30) * k,
            top: (_MouthPainter._bubbleCenter.dy - 17) * k,
            width: 60 * k,
            height: 26 * k,
            child: Transform.rotate(
              angle: -0.12,
              child: FittedBox(
                child: Text(
                  phrase,
                  style: GoogleFonts.permanentMarker(color: color),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MouthPainter extends CustomPainter {
  final Color color;
  final Color background;
  final bool withBubble;

  _MouthPainter(this.color, this.background, this.withBubble);

  static const _boxCenter = Offset(84, 90);

  /// Centro del quadretto da solo: compensa l'inclinazione e lo spessore,
  /// così il disegno sta al centro del quadrato.
  static const _iconBoxCenter = Offset(80, 66);
  static const _bubbleCenter = Offset(166, 40);

  /// Inclinazione del cubo, come nel quadro (sale verso destra).
  static const _tilt = -0.26;

  /// Spessore del cubo, verso il basso a sinistra.
  static const _depth = Offset(-14, 14);

  @override
  void paint(Canvas canvas, Size size) {
    final w = withBubble ? MouthLogo._w : MouthLogo._iconSide;
    final h = withBubble ? MouthLogo._h : MouthLogo._iconSide;
    canvas.scale(size.width / w, size.height / h);
    final ink = Paint()..color = color;
    final hole = Paint()..color = background;
    Paint line(Color c, double w) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    if (withBubble) _bubble(canvas, ink, hole, line(color, 3));

    final center = withBubble ? _boxCenter : _iconBoxCenter;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(_tilt);

    // Fianchi del cubo (sinistra e sotto), poi la faccia davanti.
    const d = _depth;
    final sides = Path()
      ..moveTo(-50, -50)
      ..lineTo(-50 + d.dx, -50 + d.dy)
      ..lineTo(-50 + d.dx, 50 + d.dy)
      ..lineTo(50 + d.dx, 50 + d.dy)
      ..lineTo(50, 50)
      ..close();
    canvas.drawPath(sides, ink);
    const face = Rect.fromLTRB(-50, -50, 50, 50);
    canvas.drawRect(face, ink);
    // Spigoli del cubo.
    final edge = line(background, 2);
    canvas.drawPath(
      Path()
        ..moveTo(-50, -50)
        ..lineTo(-50, 50)
        ..lineTo(50, 50)
        ..moveTo(-50, 50)
        ..lineTo(-50 + d.dx, 50 + d.dy),
      edge,
    );

    // Bocca: bordo, interno scuro, lingua, denti. I denti stanno dentro a
    // un filo scuro, così non si attaccano al bordo.
    canvas.drawRect(const Rect.fromLTRB(-37, -35, 37, 37), line(background, 2));
    const mouth = Rect.fromLTRB(-36, -34, 36, 36);
    canvas.save();
    canvas.clipRect(mouth.deflate(2));
    canvas.drawRect(mouth, ink);
    canvas.drawPath(
      Path()
        ..moveTo(-36, 8)
        ..cubicTo(-22, -2, -8, 6, 4, 0)
        ..cubicTo(14, -5, 26, -6, 36, -2)
        ..lineTo(36, 36)
        ..lineTo(-36, 36)
        ..close(),
      hole,
    );
    // Piega della lingua.
    canvas.drawPath(
      Path()
        ..moveTo(0, 3)
        ..quadraticBezierTo(5, 1, 8, 4),
      line(color, 1.5),
    );
    final outline = line(color, 1.8);
    const toothW = 18.0;
    for (var i = 0; i < 4; i++) {
      final l = -36 + i * toothW;
      final top = _topTooth(l, -32, toothW, 20, chipped: i == 2);
      canvas.drawPath(top, hole);
      canvas.drawPath(top, outline);
      final bottom = _bottomTooth(l, 34, toothW, 21);
      canvas.drawPath(bottom, hole);
      canvas.drawPath(bottom, outline);
    }
    canvas.restore();
    canvas.restore();
  }

  /// Dente di sopra, arrotondato in basso; quello scheggiato ha una tacca.
  Path _topTooth(
    double l,
    double t,
    double w,
    double h, {
    bool chipped = false,
  }) {
    final p = Path()..moveTo(l, t);
    final r = w / 2;
    if (chipped) {
      p
        ..lineTo(l, t + h - r)
        ..quadraticBezierTo(l, t + h, l + r * 0.6, t + h - 1)
        ..lineTo(l + r * 1.05, t + h - 6)
        ..lineTo(l + r * 1.35, t + h - 2)
        ..quadraticBezierTo(l + w, t + h - 2, l + w, t + h - r - 2);
    } else {
      p
        ..lineTo(l, t + h - r)
        ..arcToPoint(
          Offset(l + w, t + h - r),
          radius: Radius.circular(r),
          clockwise: false,
        );
    }
    return p
      ..lineTo(l + w, t)
      ..close();
  }

  /// Dente di sotto, arrotondato in alto.
  Path _bottomTooth(double l, double b, double w, double h) {
    final r = w / 2;
    return Path()
      ..moveTo(l, b)
      ..lineTo(l, b - h + r)
      ..arcToPoint(Offset(l + w, b - h + r), radius: Radius.circular(r))
      ..lineTo(l + w, b)
      ..close();
  }

  /// Fumetto con la coda verso la bocca e la doppia sottolineatura.
  void _bubble(Canvas canvas, Paint ink, Paint hole, Paint stroke) {
    const c = _bubbleCenter;
    final shape = Path()
      ..addOval(Rect.fromCenter(center: c, width: 76, height: 50));
    final tail = Path()
      ..moveTo(c.dx - 30, c.dy + 4)
      ..quadraticBezierTo(c.dx - 40, c.dy + 22, c.dx - 56, c.dy + 30)
      ..quadraticBezierTo(c.dx - 30, c.dy + 26, c.dx - 18, c.dy + 18)
      ..close();
    final bubble = Path.combine(PathOperation.union, shape, tail);
    canvas.drawPath(bubble, hole);
    canvas.drawPath(bubble, stroke);
    final under = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(c + const Offset(-20, 8), c + const Offset(20, 3), under);
    canvas.drawLine(c + const Offset(-14, 12), c + const Offset(16, 8), under);
  }

  @override
  bool shouldRepaint(_MouthPainter old) =>
      old.color != color ||
      old.background != background ||
      old.withBubble != withBubble;
}
