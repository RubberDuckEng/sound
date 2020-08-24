import 'package:fft/fft.dart';
import 'package:my_complex/my_complex.dart';
import 'dart:typed_data';
import 'package:flutter/widgets.dart';

abstract class VisualizerDataProvider {
  Samples getSamples(Duration start, Duration end);

  Frequencies getFrequencies(Duration start, Duration end);
}

abstract class Visualizer {
  final VisualizerDataProvider dataProvider;

  Visualizer(this.dataProvider);

  Widget build(BuildContext context, Animation<Duration> current);
}

class Frequencies {
  static final Window _sharedWindow = Window(WindowType.HANN);
  static final FFT _sharedFFT = FFT();

  List<List<Complex>> channels;

  int get frequencyCount => channels[0].length;
  int get channelCount => channels.length;

  // Assumption: Each channel in samples has a power-of-two length.
  Frequencies.fromSamples(Samples samples) {
    channels = samples.channels.map((List<num> channelData) {
      return _sharedFFT.Transform(_sharedWindow.apply(channelData));
    }).toList();
  }
}

class Samples {
  List<Int16List> channels;

  int get sampleCount => channels[0].length;
  int get channelCount => channels.length;

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
