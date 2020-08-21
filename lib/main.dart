import 'package:flutter/material.dart';
import 'wav.dart';
import 'dart:typed_data';
import 'dart:io';
import 'dart:ui';
import 'package:sound/visualizers/api.dart';
import 'package:sound/visualizers/all.dart';
import 'dart:math';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sound Visualizer',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(),
    );
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

class SamplePlot extends AnimatedWidget {
  const SamplePlot({
    Key key,
    this.wav,
    Animation<Duration> animation,
    this.controller,
    this.visualizer,
  }) : super(key: key, listenable: animation);

  final WavFile wav;
  final AnimationController controller;
  final Visualizer visualizer;

  Animation<Duration> get _progress => listenable;

  @override
  Widget build(BuildContext context) {
    Duration now = _progress.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: visualizer.build(context, _progress)),
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
  WavPlayer({Key key, this.wav, this.visualizer}) : super(key: key);

  final WavFile wav;
  final Visualizer visualizer;

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
      visualizer: widget.visualizer,
      animation: _animation,
      controller: _controller,
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

enum VisualizerType {
  time,
  frequency,
}

class SoundSource {
  String name;
  String _path;

  SoundSource.fromFilePath(this.name, this._path);

  RandomAccessFile openForReading() {
    return File(_path).openSync();
  }
}

class _MyHomePageState extends State<MyHomePage>
    implements VisualizerDataProvider {
  Visualizer _visualizer;
  SoundSource source;
  WavFile wavFile;

  List<SoundSource> soundSources = [
    SoundSource.fromFilePath("Piano C4",
        '/Users/eseidel/Projects/rubberduck/sound/examples/third_party/freewavesamples.com/Casio-MT-45-Piano-C4.wav'),
    SoundSource.fromFilePath("Guitar",
        '/Users/eseidel/Projects/rubberduck/sound/examples/example.wav'),
  ];

  @override
  Samples getSamples(Duration start, Duration end) {
    // 20ms with an 8000 hz sample is about 160 samples.
    // Moved to the closest power of two to make package:fft happy.
    Int16List rawSamples = Int16List(pow(2, 11));
    wavFile.readSamplesAtSeekTime(start, rawSamples);
    VisualizerModel model = VisualizerModel.fromStereo(rawSamples);
    return model.samples;
  }

  @override
  Frequencies getFrequencies(Duration start, Duration end) {
    Int16List rawSamples = Int16List(pow(2, 11));
    wavFile.readSamplesAtSeekTime(start, rawSamples);
    VisualizerModel model = VisualizerModel.fromStereo(rawSamples);
    return model.frequencies;
  }

  @override
  void initState() {
    setSource(soundSources.first);
    setVisualizer(visualizers.first(this));
    super.initState();
  }

  void setSource(SoundSource newSource) {
    source = newSource;
    wavFile = WavFile(source.openForReading());
  }

  void setVisualizer(Visualizer newVisualizer) {
    _visualizer = newVisualizer;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: DropdownButton<SoundSource>(
          value: source,
          onChanged: (SoundSource result) {
            setState(() {
              setSource(result);
            });
          },
          items: soundSources.map((source) {
            return DropdownMenuItem(value: source, child: Text(source.name));
          }).toList(),
        ),
      ),
      body: SizedBox.expand(
          child: WavPlayer(wav: wavFile, visualizer: _visualizer)),
    );
  }
}
