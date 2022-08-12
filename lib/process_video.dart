import 'dart:io';
import 'dart:ui';

import 'package:camera_example/process_video_view_model.dart';
import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import 'package:video_player/video_player.dart';

class ProcessVideo extends StatelessWidget {
  final String path;
  const ProcessVideo({Key? key, required this.path}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder.reactive(viewModelBuilder: () {
      return ProcessVideoViewModel(path);
    }, onModelReady: ((ProcessVideoViewModel viewModel) {
      viewModel.init();
    }), builder:
        ((BuildContext context, ProcessVideoViewModel viewModel, child) {
      return WillPopScope(
        onWillPop: () async {
          viewModel.cancelProcessing(context);
          return true;
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text("Process"),
            actions: [],
          ),
          body: _body(context, viewModel),
        ),
      );
    }));
  }

  Widget _body(BuildContext context, ProcessVideoViewModel viewModel) {
    if (viewModel.videoController == null) {
      return _processing(context, viewModel);
    }

    return VideoPlayer(viewModel.videoController!);
  }

  Widget _processing(BuildContext context, ProcessVideoViewModel viewModel) {
    return Stack(
      children: [
        if (viewModel.thumbnailPath == null)
          Container(
            color: Colors.grey,
          ),
        if (viewModel.thumbnailPath != null)
          Image.file(
            File(viewModel.thumbnailPath!),
          ),
        Container(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: LinearProgressIndicator(
                    color: Colors.blue,
                    backgroundColor: Colors.grey,
                    value: viewModel.percentProcessing,
                    semanticsLabel: "${viewModel.percentProcessing}",
                    semanticsValue: "${viewModel.percentProcessing}",
                  ),
                ),
                SizedBox(
                  height: 20,
                ),
                ElevatedButton(
                  onPressed: () {
                    viewModel.cancelProcessing(context);
                  },
                  child: Text(
                    "Cancel process",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                SizedBox(
                  height: 50,
                )
              ],
            ),
          ),
        ),
      ],
    );
  }
}
