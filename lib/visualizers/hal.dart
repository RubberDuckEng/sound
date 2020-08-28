import 'package:flutter/material.dart';
import 'package:sound/visualizers/api.dart';
import 'dart:math';

class HalVisualizer extends Visualizer {
  HalVisualizer(VisualizerDataProvider dataProvider) : super(dataProvider);

  Widget build(BuildContext context, Animation<Duration> current) {
    Duration now = current.value;
    Frequencies frequencies =
        dataProvider.getFrequencies(now, now + Duration(milliseconds: 200));
    return CustomPaint(painter: HalPainter(frequencies));
  }
}

class HalPainter extends CustomPainter {
  final Frequencies frequencies;

  HalPainter(this.frequencies);

  void paint(Canvas canvas, Size size) {
    double normalize(double sample) => sample / (120 * 32768.0);

    void drawBackground() {
      canvas.drawRect(Offset.zero & size, Paint()..color = Colors.black);
    }

    void drawMetalRing({double radius, double rotation}) {
      final double startAngle = 0.0;
      final double endAngle = pi * 2;

      Rect rect = new Rect.fromCircle(
        center: new Offset(size.width / 2, size.height / 2),
        radius: radius,
      );

      final gradient = new SweepGradient(
        startAngle: startAngle,
        endAngle: endAngle,
        colors: const <Color>[
          Color(0xFF707070),
          Color(0xFF2B2B2B),
          Color(0xFF2B2B2B),
          Color(0xFF2B2B2B),
          Color(0xFF707070),
          Color(0xFF707070),
          Color(0xFFFFFFFF),
          Color(0xFF707070),
          Color(0xFF707070),
          Color(0xFFFFFFFF),
          Color(0xFF707070),
          Color(0xFF707070),
          Color(0xFFFFFFFF),
          Color(0xFF707070),
          Color(0xFF707070), 
        ],
        stops: const <double>[
          0.0,
          0.125,
          0.25,
          0.375,
          0.5,
          0.58375,
          0.625,
          0.66625,
          0.70875,
          0.75,
          0.79125,
          0.83375,
          0.875,
          0.91625,
          1.0
        ],
        transform: GradientRotation(rotation),
      );

      final paint = new Paint()
        ..shader = gradient.createShader(rect)
        ..strokeWidth = 10;

      canvas.drawArc(rect, startAngle, endAngle, true, paint);
    }

    void drawBlackCore({double radius}) {
      final Paint paint = new Paint()..color = Colors.black;
      canvas.drawCircle(Offset(size.width / 2, size.height / 2), radius, paint);
    }

    void drawOuterGlow({double intensity}) {
      final double startAngle = 0.0;
      final double endAngle = pi * 2;

      Rect rect = new Rect.fromCircle(
        center: new Offset(size.width / 2, size.height / 2),
        radius: intensity,
      );

      // a fancy rainbow gradient
      final Gradient gradient = new RadialGradient(
        colors: <Color>[
          Color(0xEF3300).withOpacity(1.0),
          Color(0xEF3300).withOpacity(0.7),
          Colors.transparent
        ],
        stops: [
          0.0,
          0.3,
          1.0,
        ],
      );

      final Paint paint = new Paint()..shader = gradient.createShader(rect);

      canvas.drawArc(rect, startAngle, endAngle, true, paint);
    }

    void drawInnerGlow({double intensity}) {
      final double startAngle = 0.0;
      final double endAngle = pi * 2;
      final double intensityThreshold = 20;
      final double innerGlowRadius = 25;

      Rect rect = new Rect.fromCircle(
        center: new Offset(size.width / 2, size.height / 2),
        radius: innerGlowRadius,
      );

      final Gradient gradient = new RadialGradient(
        colors: <Color>[
          Color(0xF2F72D).withOpacity(intensity > intensityThreshold ? 1.0 : 0),
          Color(0xF2F72D).withOpacity(intensity > intensityThreshold ? 0.7 : 0),
          Color(0xAE3002).withOpacity(intensity > intensityThreshold ? 0.1 : 0),
          Colors.transparent
        ],
        stops: [0.0, 0.35, 0.65, 1.0],
      );

      final Paint paint = new Paint()..shader = gradient.createShader(rect);

      canvas.drawArc(rect, startAngle, endAngle, true, paint);
    }

    void drawReflection(
        {double radius,
        double strokeWidth,
        double opacity,
        double blurAmount}) {
      final double startAngle = pi;
      final double endAngle = startAngle;

      Rect rect = new Rect.fromCircle(
        center: new Offset(size.width / 2, size.height / 2),
        radius: radius,
      );

      final gradient = new SweepGradient(
        colors: const <Color>[
          Colors.transparent,
          Colors.white,
          Colors.transparent,
          Colors.white,
          Colors.white,
          Colors.transparent,
          Colors.white,
          Colors.transparent,
        ],
        stops: const <double>[
          0.55,
          0.66625,
          0.6875,
          0.70875,
          0.79125,
          0.8125,
          0.83375,
          0.94
        ],
      );

      final paint = Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurAmount);

      canvas.drawArc(rect, startAngle, endAngle, false, paint);
    }

    int frequencyCount = frequencies.frequencyCount ~/ 20;
    int channelCount = frequencies.channelCount;

    double intensitySum = 0;
    double intensityCount = 0;

    for (int i = 0; i < frequencyCount; ++i) {
      for (int channel = 0; channel < channelCount; ++channel) {
        final double intensity =
            normalize(frequencies.channels[channel][i].modulus);
        intensitySum = intensitySum + intensity;
        intensityCount = intensityCount + 1;
      }
    }

    // Mappings
    final double inputStart = 0.0;
    final double inputEnd = 0.5;
    final double outputStart = 100;
    final double outputEnd = 300;

    double averageIntensity = intensitySum / intensityCount;

    // Map intensity to a usable range
    averageIntensity = outputStart +
        ((outputEnd - outputStart) / (inputEnd - inputStart)) *
            (averageIntensity - inputStart);

    // Restrict intensity radius
    if (averageIntensity > outputEnd) {
      averageIntensity = outputEnd;
    } else if (averageIntensity < outputStart) {
      averageIntensity = outputStart;
    }

    // Let's make the background black
    drawBackground();

    // Cast hals outer metal ring
    drawMetalRing(radius: 200, rotation: 0);

    // Cast hals inner metal ring, and rotate it
    drawMetalRing(radius: 190, rotation: pi);

    // Draw hals inner black soul
    drawBlackCore(radius: 180);

    // Draw hals outer glow
    drawOuterGlow(intensity: averageIntensity);

    // Draw hals outer glow
    drawInnerGlow(intensity: averageIntensity);

    // Draw outer reflection arcs
    drawReflection(radius: 150, strokeWidth: 6, opacity: 1.0, blurAmount: 12);

    drawReflection(radius: 155, strokeWidth: 5, opacity: 0.6, blurAmount: 3);

    // Draw middle reflection arc
    drawReflection(radius: 110, strokeWidth: 3, opacity: 0.3, blurAmount: 6);

    // Draw inner reflection arc
    drawReflection(radius: 80, strokeWidth: 1.5, opacity: 0.15, blurAmount: 9);

    // This conversation can serve no purpose anymore, goodbye.
  }

  bool shouldRepaint(HalPainter oldDelegate) {
    return frequencies != oldDelegate.frequencies;
  }
}
