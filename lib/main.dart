import 'package:flutter/material.dart';
import 'wav.dart';
import 'dart:typed_data';
import 'dart:io';
import 'dart:ui';
import 'package:fft/fft.dart';
import 'package:my_complex/my_complex.dart';

WavFile gWav;

void main() {
  var file =
      File('/Users/eseidel/Projects/rubberduck/sound/examples/example.wav');
  var openFile = file.openSync();
  gWav = WavFile(openFile);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class Samples {
  List<Int16List> channels;

  Samples.fromStereo(Int16List samples) {
    int count = samples.length ~/ 2;
    channels = <Int16List>[
      Int16List(count),
      Int16List(count),
    ];

    for (int i = 0; i < count; ++i) {
      channels[0][i] = samples[i * 2];
      channels[1][i] = samples[i * 2 + 1];
    }
  }
}

class Frequencies {
  List<List<Complex>> channels;

  // Assumption: Each channel in samples has a power-of-two length.
  Frequencies.fromSamples(Samples samples) {
    channels = samples.channels.map(FFT().Transform).toList();
  }
}

class VisualizerModel {
  Samples samples;
  Frequencies frequencies;

  int get sampleCount => samples.channels[0].length;
  int get channelCount => samples.channels.length;

  VisualizerModel.fromStereo(Int16List stereo) {
    samples = Samples.fromStereo(stereo);
    frequencies = Frequencies.fromSamples(samples);
  }
}

class TimePainter extends CustomPainter {
  // The client must not mutate |samples| after passing the list to this object.
  final VisualizerModel model;

  TimePainter(this.model);

  void paint(Canvas canvas, Size size) {
    int sampleCount = model.sampleCount;
    int channelCount = model.channelCount;
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
        addToPath(paths[channel], x, model.samples.channels[channel][i]);
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
    return model != oldDelegate.model;
  }
}

class FrequencyPainter extends CustomPainter {
  // The client must not mutate |samples| after passing the list to this object.
  final VisualizerModel model;

  FrequencyPainter(this.model) {
    print(model.frequencies.channels[0].map((c) => c.modulus));
  }

  void paint(Canvas canvas, Size size) {
    int sampleCount = model.sampleCount;
    int channelCount = model.channelCount;
    List<Path> paths = List<Path>.generate(channelCount, (i) => Path());
    double xStep = size.width / sampleCount;
    double yRange = size.height / 2;

    const double gain = 1.0;

    // Integers stored in the list are truncated to their low 16 bits,
    // interpreted as a signed 16-bit two's complement integer with values in
    // the range -32768 to +32767.
    double normalize(double sample) => sample / 32768.0;

    void addToPath(Path path, double x, double sample) {
      double y = gain * normalize(sample) * yRange;
      path.lineTo(x, y);
    }

    for (int i = 0; i < sampleCount; ++i) {
      double x = i * xStep;
      for (int channel = 0; channel < channelCount; ++channel) {
        addToPath(
            paths[channel], x, model.frequencies.channels[channel][i].modulus);
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
    return model != oldDelegate.model;
  }
}

class SamplePlot extends AnimatedWidget {
  const SamplePlot(
      {Key key, this.wav, Animation<Duration> animation, this.controller})
      : super(key: key, listenable: animation);

  final WavFile wav;
  final AnimationController controller;

  Animation<Duration> get _progress => listenable;

  @override
  Widget build(BuildContext context) {
    Duration now = _progress.value;
    Int16List rawSamples = Int16List(8192); // Power of two to make FFT happy.
    wav.readSamplesAtSeekTime(now, rawSamples);
    VisualizerModel model = VisualizerModel.fromStereo(rawSamples);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
            child: CustomPaint(
          painter: FrequencyPainter(model), // TimePainter(model),
        )),
        Row(children: [
          IconButton(
              icon:
                  Icon(controller.isAnimating ? Icons.pause : Icons.play_arrow),
              onPressed: () {
                if (controller.isAnimating) {
                  controller.stop();
                } else {
                  controller.repeat();
                }
              }),
          Expanded(
            child: Slider(
              value: controller.value,
              onChanged: (value) {
                controller.value = value;
              },
            ),
          ),
          Text("Offset: $now"),
        ])
      ],
    );
  }
}

class WavPlayer extends StatefulWidget {
  WavPlayer({Key key, this.wav}) : super(key: key);

  final WavFile wav;

  @override
  _WavPlayerState createState() => _WavPlayerState();
}

class _WavPlayerState extends State<WavPlayer> with TickerProviderStateMixin {
  AnimationController _controller;
  Animation<Duration> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.wav.duration,
      vsync: this,
    );
    _animation = _controller.drive(
        Tween<Duration>(begin: const Duration(), end: widget.wav.duration));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SamplePlot(
      wav: widget.wav,
      animation: _animation,
      controller: _controller,
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: SizedBox.expand(child: WavPlayer(wav: gWav)),
    );
  }
}
