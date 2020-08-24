import 'package:sound/visualizers/frequency.dart';
import 'package:sound/visualizers/time.dart';
import 'package:sound/visualizers/api.dart';

typedef VisualizerFactory = Visualizer Function(VisualizerDataProvider);

// Add your visualizer to this list.
Map<String, VisualizerFactory> visualizers = {
  'Frequency': (VisualizerDataProvider provider) =>
      FrequencyVisualizer(provider),
  'Time': (VisualizerDataProvider provider) => TimeVisualizer(provider),
};
