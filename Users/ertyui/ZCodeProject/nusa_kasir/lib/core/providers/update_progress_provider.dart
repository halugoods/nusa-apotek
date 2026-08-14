import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Status unduhan update APK — global, dibagikan antar layar (dashboard &
/// settings) dan ditampilkan realtime di drawer notifikasi (tanpa perlu
/// buka-tutup drawer untuk refresh progres).
class UpdateProgress {
  final bool downloading;
  final double progress; // 0.0 - 1.0
  final String? error;
  final String? fileName;

  const UpdateProgress({
    this.downloading = false,
    this.progress = 0,
    this.error,
    this.fileName,
  });

  UpdateProgress copyWith({
    bool? downloading,
    double? progress,
    String? error,
    String? fileName,
  }) =>
      UpdateProgress(
        downloading: downloading ?? this.downloading,
        progress: progress ?? this.progress,
        error: error,
        fileName: fileName ?? this.fileName,
      );

  bool get hasError => error != null;
}

class UpdateProgressNotifier extends StateNotifier<UpdateProgress> {
  UpdateProgressNotifier() : super(const UpdateProgress());

  void startDownload(String fileName) {
    state = UpdateProgress(downloading: true, fileName: fileName);
  }

  void updateProgress(double p) {
    state = state.copyWith(progress: p);
  }

  void done() {
    state = const UpdateProgress();
  }

  void fail(String message) {
    state = UpdateProgress(error: message);
  }
}

/// Global download-progress provider (satu sumber untuk dashboard, settings,
/// dan notif drawer).
final updateProgressProvider =
    StateNotifierProvider<UpdateProgressNotifier, UpdateProgress>(
        (ref) => UpdateProgressNotifier());
