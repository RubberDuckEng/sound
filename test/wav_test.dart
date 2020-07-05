import 'dart:io';
import 'package:sound/wav.dart';
import 'package:test/test.dart';

void main() {
  test('Basic Wav header', () {
    // TODO(eseidel): This test should be self-contained instead of
    // depending on a file in examples.
    var file = File('examples/example.wav');
    var openFile = file.openSync();
    WavFile wav = WavFile(openFile);

    expect(wav.chunkId, equals("RIFF"));
    expect(wav.chunkSize, equals(1073210));
    expect(wav.format, equals("WAVE"));
  });
}
