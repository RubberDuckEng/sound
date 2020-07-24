import "dart:io";
import "dart:typed_data";

void main() {
  print("hello interwebs");
  var file = File('examples/example.wav');
  var openFile = file.openSync();
  WavFile wav = WavFile(openFile);
  print("chunkId: ${wav.chunkId}");
  print("chunkSize: ${wav.chunkSize}");
  print("format: ${wav.format}");
  print("subchunk1Id: ${wav.subchunk1Id}");
  print("subchunk1Size: ${wav.subchunk1Size}");
  print("audioFormat: ${wav.audioFormat}");
  print("numChannels: ${wav.numChannels}");
  print("sampleRate: ${wav.sampleRate}");
  print("byteRate: ${wav.byteRate}");
  print("blockAlign: ${wav.blockAlign}");
  print("bitsPerSample: ${wav.bitsPerSample}");

  print("subchunk2Id: ${wav.subchunk2Id}");
  print("subchunk2Size: ${wav.subchunk2Size}");

  var samples = Int16List(8);
  int sampleCount = wav.readSamples(samples);
  print("sampleCount: $sampleCount");
  print("sample[0]: ${samples[0]}");
  print("sample[1]: ${samples[1]}");
  print("sample[2]: ${samples[2]}");
  print("sample[3]: ${samples[3]}");
  print("sample[4]: ${samples[4]}");
  print("sample[5]: ${samples[5]}");
  print("sample[6]: ${samples[6]}");
  print("sample[7]: ${samples[7]}");
}

class RiffChunk {
  final int offset;

  final String id;
  final int size;

  RiffChunk({this.offset, this.id, this.size});
}

class RiffParser {
  final RandomAccessFile _bytes;
  RiffParser(this._bytes);

  /// Next read is set after id and size.
  void seekToAfter(RiffChunk chunk) {
    const headerSize = 8;
    int nextChunkOffset = chunk.offset + chunk.size + headerSize;
    _bytes.setPositionSync(nextChunkOffset);
  }

  void seekToOffset(int offset) {
    _bytes.setPositionSync(offset);
  }

  RiffChunk readChunkHeader() {
    int offset = _bytes.positionSync();
    String id = readChunkId();
    int size = readInt32();

    return RiffChunk(
      offset: offset,
      id: id,
      size: size,
    );
  }

  int get currrentOffset => _bytes.positionSync();

  int readInt16() =>
      _bytes.readSync(2).buffer.asByteData().getInt16(0, Endian.little);
  int readInt32() =>
      _bytes.readSync(4).buffer.asByteData().getInt32(0, Endian.little);
  String readChunkId() => String.fromCharCodes(_bytes.readSync(4));

  // Returns the number of samples read.
  int readInto(Int16List samples) {
    int bytesRead = _bytes.readIntoSync(samples.buffer.asUint8List());
    return bytesRead ~/ 2;
  }
}

class WavFile {
  RiffParser parser;

  String chunkId;
  int chunkSize;
  String format;

  // Format Chunk:
  String subchunk1Id;
  int subchunk1Size;
  int audioFormat;
  int numChannels;
  int sampleRate;
  int byteRate;
  int blockAlign;
  int bitsPerSample;

  // Data Chunk:
  String subchunk2Id;
  int subchunk2Size;
  int samplesStartOffset;

  WavFile(var bytes) {
    parser = RiffParser(bytes);
    RiffChunk root = parser.readChunkHeader();
    chunkId = root.id;
    chunkSize = root.size;
    format = parser.readChunkId();
    // Riff is a nested tree structure, we don't
    // seek to the end of the chunk here since
    // the remaining chunks are still "inside"
    // this "root" chunk.

    // Format Chunk:
    RiffChunk formatChunk = parser.readChunkHeader();
    subchunk1Id = formatChunk.id;
    subchunk1Size = formatChunk.size;
    audioFormat = parser.readInt16();
    numChannels = parser.readInt16();
    sampleRate = parser.readInt32();
    byteRate = parser.readInt32();
    blockAlign = parser.readInt16();
    bitsPerSample = parser.readInt16();
    assert(bitsPerSample == 16);
    parser.seekToAfter(formatChunk);

    // Data Chunk:
    RiffChunk dataChunk = parser.readChunkHeader();
    subchunk2Id = dataChunk.id;
    subchunk2Size = dataChunk.size;
    samplesStartOffset = parser.currrentOffset;
    // There may be a mystery chunk after this?
  }

  int readSamples(Int16List samples) {
    return parser.readInto(samples);
  }

  void readSamplesAtSeekTime(Duration now, Int16List samples) {
    samples.fillRange(0, samples.length, 0);
    int nowAsOffset =
        now.inMicroseconds * byteRate ~/ Duration.microsecondsPerSecond;
    // Make sure our computed offset is at a sample start.
    nowAsOffset -= nowAsOffset % blockAlign;
    parser.seekToOffset(samplesStartOffset + nowAsOffset);
    parser.readInto(samples);
  }

  Duration get duration => Duration(
      microseconds: Duration.microsecondsPerSecond * subchunk2Size ~/ byteRate);
}

// The canonical WAVE format starts with the RIFF header:

// 0         4   ChunkID          Contains the letters "RIFF" in ASCII form
//                                (0x52494646 big-endian form).
// 4         4   ChunkSize        36 + SubChunk2Size, or more precisely:
//                                4 + (8 + SubChunk1Size) + (8 + SubChunk2Size)
//                                This is the size of the rest of the chunk
//                                following this number.  This is the size of the
//                                entire file in bytes minus 8 bytes for the
//                                two fields not included in this count:
//                                ChunkID and ChunkSize.
// 8         4   Format           Contains the letters "WAVE"
//                                (0x57415645 big-endian form).

// The "WAVE" format consists of two subchunks: "fmt " and "data":
// The "fmt " subchunk describes the sound data's format:

// 12        4   Subchunk1ID      Contains the letters "fmt "
//                                (0x666d7420 big-endian form).
// 16        4   Subchunk1Size    16 for PCM.  This is the size of the
//                                rest of the Subchunk which follows this number.
// 20        2   AudioFormat      PCM = 1 (i.e. Linear quantization)
//                                Values other than 1 indicate some
//                                form of compression.
// 22        2   NumChannels      Mono = 1, Stereo = 2, etc.
// 24        4   SampleRate       8000, 44100, etc.
// 28        4   ByteRate         == SampleRate * NumChannels * BitsPerSample/8
// 32        2   BlockAlign       == NumChannels * BitsPerSample/8
//                                The number of bytes for one sample including
//                                all channels. I wonder what happens when
//                                this number isn't an integer?
// 34        2   BitsPerSample    8 bits = 8, 16 bits = 16, etc.
//           2   ExtraParamSize   if PCM, then doesn't exist
//           X   ExtraParams      space for extra parameters

// The "data" subchunk contains the size of the data and the actual sound:

// 36        4   Subchunk2ID      Contains the letters "data"
//                                (0x64617461 big-endian form).
// 40        4   Subchunk2Size    == NumSamples * NumChannels * BitsPerSample/8
//                                This is the number of bytes in the data.
//                                You can also think of this as the size
//                                of the read of the subchunk following this
//                                number.
// 44        *   Data             The actual sound data.
