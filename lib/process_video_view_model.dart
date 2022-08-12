import 'dart:io';

import 'package:ffmpeg_kit_flutter_video/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_video/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_video/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_video/return_code.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:stacked/stacked.dart';
import 'package:video_player/video_player.dart';

class PopVideo {
  final String path;
  PopVideo(this.path);
}

class ProcessVideoViewModel extends BaseViewModel {
  late String path;
  String? _newFile;
  ProcessVideoViewModel(this.path);
  VideoPlayerController? videoController;
  FFmpegSession? _session;

  double percentProcessing = 0;
  int totalFrames = 0;

  void init() {
    render();
  }

  String? thumbnailPath;

  Future getInfo() async {
    final probeSession = await FFprobeKit.getMediaInformation(this.path);
    final information = probeSession.getMediaInformation();
    final size = information!.getSize();

    final videoInfo = information!
        .getStreams()
        .firstWhere((element) => element.getType() == "video");

    totalFrames = int.parse(videoInfo.getProperties("nb_frames"));

    final _thumbnailPath =
        (await getTemporaryDirectory()).path + '/thumbnail.png';

    // Delete the previous thumbnail file
    _deleteFile(_thumbnailPath);

    final session = await FFmpegKit.execute(
        "-i ${this.path} -ss 00:00:01.000 -vframes 1 $_thumbnailPath");
    final returnCode = await session.getReturnCode();
    if (ReturnCode.isSuccess(returnCode)) {
      thumbnailPath = _thumbnailPath;
    } else if (ReturnCode.isCancel(returnCode)) {
    } else {
      print("error");
    }

    notifyListeners();
  }

  void render() async {
    await getInfo();

    int charPerLinePortrait = 58;

    String text =
        "If you want to center the text itself, then you can subtract the height and width of the rendered text when telling drawtext where to render the text.";

    final lines = text.length / charPerLinePortrait;

    List<String> textFinal = [];
    for (var i = 0; i < lines; i++) {
      var end = (i + 1) * charPerLinePortrait;

      if (end > text.length - 1) {
        end = text.length - 1;
      }

      textFinal.add("${text.substring(i * charPerLinePortrait, end)}".trim());
    }

    final long = textFinal.join("\n");

    try {
      _newFile = (await getTemporaryDirectory()).path +
          '/edited-${DateTime.now().toIso8601String()}.mp4';

      final fontPath = await getFont();

      String drawTextCommand =
          "drawtext=fontfile=$fontPath:text='$long':x=10:y=(h-text_h)-10:fontsize=42:fontcolor=white:box=1:boxcolor=black@0.5: boxborderw=5";

      _session = await FFmpegKit.executeAsync(
          '-i ${this.path} -vf "$drawTextCommand" -c:a aac -b:v 7M -b:a 32K $_newFile',
          (session) async {
            final returnCode = await session.getReturnCode();
            if (ReturnCode.isSuccess(returnCode)) {
              _deleteFile(this.path);
              _startVideoPlayer(_newFile!);
            } else if (ReturnCode.isCancel(returnCode)) {
              _clear();
            } else {
              print("error");
              //_deleteFile(this.path);
            }
          },
          null,
          (statistics) {
            calculatePercent(statistics.getVideoFrameNumber());
          });
    } catch (e) {
      print(e);
    }
  }

  void calculatePercent(int current) {
    if (current >= totalFrames) {
      current = totalFrames;
    }

    percentProcessing = (current / totalFrames);
    notifyListeners();
  }

  Future<void> _deleteFile(String? path) async {
    if (path == null) {
      return;
    }

    var file = File(path);
    if (file.existsSync()) {
      await file.delete();
    }
  }

  Future<String> getFont() async {
    final data = await rootBundle.load("assets/Roboto-Regular.ttf");

    final fontPath =
        (await getTemporaryDirectory()).path + '/Roboto-Regular.ttf';

    final buffer = data.buffer;
    final fontFile = File(fontPath);
    if (fontFile.existsSync()) {
      return fontFile.path;
    }

    final wrote = await fontFile.writeAsBytes(
        buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));

    print(wrote.path);

    return wrote.path;
  }

  Future<void> _startVideoPlayer(String file) async {
    final VideoPlayerController vController =
        VideoPlayerController.file(File(file));

    vController.addListener(_videoPlayerListener);
    await vController.setLooping(true);
    await vController.initialize();
    await videoController?.dispose();

    videoController = vController;

    await videoController!.play();

    notifyListeners();
  }

  void _videoPlayerListener() {
    if (videoController != null && videoController!.value.size != null) {
      // Refreshing the state to update video player with the correct ratio.
      videoController!.removeListener(_videoPlayerListener);
    }
  }

  @override
  void dispose() {
    this.videoController?.dispose();
    this.videoController = null;
    super.dispose();
  }

  void cancelProcessing(BuildContext context) {
    if (_session != null) {
      //_session!.cancel();
      FFmpegKit.cancel(_session!.getSessionId());
      _session = null;
    }

    _clear();
    Navigator.pop(context);
  }

  void _clear({bool processedFile = true}) {
    _deleteFile(path);

    if (processedFile) {
      _deleteFile(_newFile);
    }

    _deleteFile(thumbnailPath);
  }
}
