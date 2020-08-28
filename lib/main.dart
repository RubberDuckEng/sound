import 'package:flutter/material.dart';
import 'wav.dart';
import 'dart:typed_data';
import 'dart:io';
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

  void _initAnimation() {
    _controller?.stop();
    _controller =
        AnimationController(duration: widget.wav.duration, vsync: this);
    _animation = _controller.drive(
        Tween<Duration>(begin: const Duration(), end: widget.wav.duration));
  }

  @override
  void initState() {
    super.initState();
    _initAnimation();
  }

  @override
  void didUpdateWidget(WavPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.wav != oldWidget.wav) {
      _initAnimation();
    }
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
  VisualizerFactory _visualizerFactory;
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
    Duration duration = end - start;
    int sampleCount = (duration.inMicroseconds * wavFile.sampleRate) ~/
        Duration.microsecondsPerSecond;
    Int16List rawSamples = Int16List(sampleCount);
    wavFile.readSamplesAtSeekTime(start, rawSamples);
    return Samples.fromStereo(rawSamples);
  }

  // TODO: Should we really adjust the start instead?
  // With this implementation frequencies will vizualize before
  // being heard.
  @override
  Frequencies getFrequencies(Duration start, Duration end) {
    Duration duration = end - start;
    int sampleCount = (duration.inMicroseconds * wavFile.sampleRate) ~/
        Duration.microsecondsPerSecond;
    // Round up to the closest power of 2:
    sampleCount = pow(2, (log(sampleCount) / log(2)).ceil());
    Int16List rawSamples = Int16List(sampleCount);
    wavFile.readSamplesAtSeekTime(start, rawSamples);
    return Frequencies.fromSamples(Samples.fromStereo(rawSamples));
  }

  @override
  void initState() {
    setSource(soundSources.first);
    setVisualizer(visualizers.values.first);
    super.initState();
  }

  void setSource(SoundSource newSource) {
    source = newSource;
    wavFile = WavFile(source.openForReading());
  }

  void setVisualizer(VisualizerFactory visualizerFactory) {
    _visualizerFactory = visualizerFactory;
    _visualizer = _visualizerFactory(this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            DropdownButton<SoundSource>(
              value: source,
              onChanged: (SoundSource result) {
                setState(() {
                  setSource(result);
                });
              },
              items: soundSources.map((source) {
                return DropdownMenuItem(
                    value: source, child: Text(source.name));
              }).toList(),
            ),
            Text(' as '),
            DropdownButton<VisualizerFactory>(
              value: _visualizerFactory,
              onChanged: (VisualizerFactory visualizerFactory) {
                setState(() {
                  setVisualizer(visualizerFactory);
                });
              },
              items: visualizers.entries.map((entry) {
                return DropdownMenuItem<VisualizerFactory>(
                  value: entry.value,
                  child: Text(entry.key),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      body: SizedBox.expand(
          child: WavPlayer(wav: wavFile, visualizer: _visualizer)),
    );
  }
}
