import 'package:flutter/material.dart';
import 'package:sound/visualizers/api.dart';

class LandscapeVisualizer extends Visualizer {
  LandscapeVisualizer(VisualizerDataProvider dataProvider)
      : super(dataProvider);

  Widget build(BuildContext context, Animation<Duration> current) {
    return Landscape(dataProvider: dataProvider, current: current);
  }
}

class Landscape extends StatefulWidget {
  final VisualizerDataProvider dataProvider;
  final Animation<Duration> current;

  Landscape({Key key, this.dataProvider, this.current}) : super(key: key);

  @override
  _LandscapeState createState() => _LandscapeState();
}

const int _kMaxHistory = 50;
const Duration _kSampleWindow = Duration(milliseconds: 200);

class _LandscapeState extends State<Landscape> {
  final List<Frequencies> _history = List<Frequencies>();

  void _addCurrentFrequences() {
    Duration now = widget.current.value;
    Frequencies frequencies =
        widget.dataProvider.getFrequencies(now, now + _kSampleWindow);
    _history.add(frequencies);
    if (_history.length > _kMaxHistory) {
      _history.removeAt(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    _addCurrentFrequences();
    return CustomPaint(painter: LanscapePainter(history: _history));
  }
}

class LanscapePainter extends CustomPainter {
  final List<Frequencies> history;

  LanscapePainter({this.history});

  void paint(Canvas canvas, Size size) {
    // The samples we get from FFT are mirrored around the Y axis,
    // we only need to show half of them.
    // Throw away another 90% which seem to be for super high frequencies?
    int historyCount = history.length;
    int frequencyCount = history[0].frequencyCount ~/ 20;
    List<Path> paths = List<Path>.generate(history.length, (i) => Path());
    double xStep = size.width / frequencyCount;
    double yRange = size.height;

    const double gain = 1.0;

    // Integers stored in the list are truncated to their low 16 bits,
    // interpreted as a signed 16-bit two's complement integer with values in
    // the range -32768 to +32767.
    double normalize(double sample) => sample / (120 * 32768.0);

    void addToPath(Path path, double x, double sample) {
      double y = gain * normalize(sample) * yRange;
      path.lineTo(x, y);
    }

    for (int i = 0; i < frequencyCount; ++i) {
      double x = i * xStep;
      for (int historyIndex = 0; historyIndex < historyCount; ++historyIndex) {
        addToPath(paths[historyIndex], x,
            history[historyCount - historyIndex - 1].channels[0][i].modulus);
      }
    }

    canvas.drawRect(
        Offset.zero & size, Paint()..color = Colors.lightGreen[100]);

    canvas.save();
    canvas.translate(0, yRange);
    canvas.scale(1.0, -1.0);
    Paint paint = Paint();
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2.0;

    for (int i = 0; i < paths.length; ++i) {
      double fraction = i / _kMaxHistory;
      double oneMinusFraction = 1 - fraction;
      paint.color = Colors.purple[600].withOpacity(oneMinusFraction);
      canvas.save();
      canvas.translate(size.width / 2.0, fraction * yRange * 0.8);
      canvas.scale(oneMinusFraction * 0.5 + 0.5);
      canvas.translate(-size.width / 2.0, 0.0);
      canvas.drawPath(paths[i], paint);
      canvas.restore();
    }
    canvas.restore();
  }

  bool shouldRepaint(LanscapePainter oldDelegate) => true;
}
