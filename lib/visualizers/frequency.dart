import 'package:flutter/material.dart';
import 'package:sound/visualizers/api.dart';

class FrequencyVisualizer extends Visualizer {
  FrequencyVisualizer(VisualizerDataProvider dataProvider)
      : super(dataProvider);

  Widget build(BuildContext context, Animation<Duration> current) {
    Duration now = current.value;
    Frequencies frequencies =
        dataProvider.getFrequencies(now, now + Duration(milliseconds: 20));
    return CustomPaint(painter: FrequencyPainter(frequencies));
  }
}

class FrequencyPainter extends CustomPainter {
  // The client must not mutate |samples| after passing the list to this object.
  final Frequencies frequencies;

  FrequencyPainter(this.frequencies);

  void paint(Canvas canvas, Size size) {
    // The samples we get from FFT are mirrored around the Y axis,
    // we only need to show half of them.
    // Throw away another 90% which seem to be for super high frequencies?
    int frequencyCount = frequencies.frequencyCount ~/ 20;
    int channelCount = frequencies.channelCount;
    List<Path> paths = List<Path>.generate(channelCount, (i) => Path());
    double xStep = size.width / frequencyCount;
    double yRange = size.height;

    const double gain = 1.0;

    // Integers stored in the list are truncated to their low 16 bits,
    // interpreted as a signed 16-bit two's complement integer with values in
    // the range -32768 to +32767.
    double normalize(double sample) => sample / (120 * 32768.0);

    void addToPath(Path path, double x, double sample) {
      double y = gain * normalize(sample) * yRange;
      path.lineTo(x, yRange - y);
    }

    for (int i = 0; i < frequencyCount; ++i) {
      double x = i * xStep;
      for (int channel = 0; channel < channelCount; ++channel) {
        addToPath(paths[channel], x, frequencies.channels[channel][i].modulus);
      }
    }

    canvas.drawRect(
        Offset.zero & size, Paint()..color = Colors.lightGreen[100]);

    canvas.save();
    // canvas.translate(0, yRange);
    Paint paint = Paint();
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2.0;

    paint.color = Colors.pink[300];
    canvas.drawPath(paths[0], paint);

    paint.color = Colors.blue[300];
    canvas.drawPath(paths[1], paint);
    canvas.restore();
  }

  bool shouldRepaint(FrequencyPainter oldDelegate) {
    return frequencies != oldDelegate.frequencies;
  }
}
