import 'package:flutter/material.dart';
import 'package:sound/visualizers/api.dart';

class TimeVisualizer extends Visualizer {
  TimeVisualizer(VisualizerDataProvider dataProvider) : super(dataProvider);

  Widget build(BuildContext context, Animation<Duration> current) {
    Duration now = current.value;
    Samples samples =
        dataProvider.getSamples(now, now + Duration(milliseconds: 300));
    return CustomPaint(painter: TimePainter(samples));
  }
}

class TimePainter extends CustomPainter {
  // The client must not mutate |samples| after passing the list to this object.
  final Samples samples;

  TimePainter(this.samples);

  void paint(Canvas canvas, Size size) {
    int sampleCount = samples.sampleCount;
    int channelCount = samples.channelCount;
    List<Path> paths = List<Path>.generate(channelCount, (i) => Path());
    double xStep = size.width / sampleCount;
    double yRange = size.height / 2;

    const double gain = 1.0;

    // Integers stored in the list are truncated to their low 16 bits,
    // interpreted as a signed 16-bit two's complement integer with values in
    // the range -32768 to +32767.
    double normalize(int sample) => sample / 32768.0;

    void addToPath(Path path, double x, int sample) {
      double y = gain * normalize(sample) * yRange;
      path.lineTo(x, y);
    }

    for (int i = 0; i < sampleCount; ++i) {
      double x = i * xStep;
      for (int channel = 0; channel < channelCount; ++channel) {
        addToPath(paths[channel], x, samples.channels[channel][i]);
      }
    }

    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.yellow[100]);

    canvas.save();
    canvas.translate(0, yRange);
    Paint paint = Paint();
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2.0;

    paint.color = Colors.pink[300];
    canvas.drawPath(paths[0], paint);

    paint.color = Colors.blue[300];
    canvas.drawPath(paths[1], paint);
    canvas.restore();
  }

  bool shouldRepaint(TimePainter oldDelegate) {
    return samples != oldDelegate.samples;
  }
}
