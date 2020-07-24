import 'package:flutter/material.dart';
import 'wav.dart';
import 'dart:typed_data';
import 'dart:io';
import 'dart:ui';

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

class SamplePainter extends CustomPainter {
  // The client must not mutate |samples| after passing the list to this object.
  final Int16List samples;

  SamplePainter(this.samples);

  void paint(Canvas canvas, Size size) {
    var leftPath = Path();
    var rightPath = Path();
    int sampleCount = samples.length ~/ 2;
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
      addToPath(leftPath, x, samples[2 * i]);
      addToPath(rightPath, x, samples[2 * i + 1]);
    }

    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.yellow[100]);

    canvas.save();
    canvas.translate(0, yRange);
    Paint paint = Paint();
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2.0;

    paint.color = Colors.pink[300];
    canvas.drawPath(leftPath, paint);

    paint.color = Colors.blue[300];
    canvas.drawPath(rightPath, paint);
    canvas.restore();
  }

  bool shouldRepaint(SamplePainter oldDelegate) {
    return samples != oldDelegate.samples;
  }
}

class SamplePlot extends AnimatedWidget {
  const SamplePlot({Key key, this.wav, Animation<Duration> animation})
      : super(key: key, listenable: animation);

  final WavFile wav;

  Animation<Duration> get _progress => listenable;

  @override
  Widget build(BuildContext context) {
    Duration now = _progress.value;
    Int16List samples = Int16List(8000);
    wav.readSamplesAtSeekTime(now, samples);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
            child: CustomPaint(
          painter: SamplePainter(samples),
        )),
        Text("Offset: $now"),
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
    )..repeat();
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
    return SamplePlot(wav: widget.wav, animation: _animation);
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
