import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Incremented when user taps Home tab. TrialsHubScreen listens and resets to hub.
final homeTabResetProvider = StateProvider<int>((ref) => 0);
