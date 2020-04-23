import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_camera/gallery.dart';
import 'package:flutter_camera/video_timer.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:thumbnails/thumbnails.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({Key key}) : super(key: key);

  @override
  CameraScreenState createState() => CameraScreenState();
}

class CameraScreenState extends State<CameraScreen>
    with AutomaticKeepAliveClientMixin {
  CameraController _controller;
  List<CameraDescription> _cameras;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isRecordingMode = false;
  bool _isRecording = false;
  bool _isTakingPhoto = false;
  bool _isBurstModePhoto = false;
  final _timerKey = GlobalKey<VideoTimerState>();
  ResolutionPreset resolutionPreset = ResolutionPreset.medium;

  @override
  void initState() {
    _initCamera();
    super.initState();
  }

  Future<void> _initCamera() async {
    _cameras = await availableCameras();
    await _initalCamera(_cameras[0]).then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_controller != null) {
      if (!_controller.value.isInitialized) {
        return Container();
      }
    } else {
      return const Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_controller.value.isInitialized) {
      return Container();
    }
    return Scaffold(
      backgroundColor: Theme.of(context).backgroundColor,
      key: _scaffoldKey,
      extendBody: true,
      body: Stack(
        children: <Widget>[
          _buildCameraPreview(),
          Positioned(
            top: 24.0,
            left: 12.0,
            child: IconButton(
              icon: Icon(
                Icons.switch_camera,
                color: Colors.white,
              ),
              onPressed: () {
                _onCameraSwitch();
              },
            ),
          ),
          if (_isRecordingMode)
            Positioned(
              left: 0,
              right: 0,
              top: 32.0,
              child: VideoTimer(
                key: _timerKey,
              ),
            )
          else
            Positioned(
              left: 60,
              top: 24.0,
              child: PopupMenuButton<String>(
                onSelected: choiceAction,
                itemBuilder: (BuildContext context) {
                  return ResolutionPreset.values.map((ResolutionPreset r) {
                    return PopupMenuItem<String>(
                      value: serializeResolutionPreset(r),
                      child: Text(
                        serializeResolutionPreset(r),
                      ),
                    );
                  }).toList();
                },
              ),
            ),
            Positioned(
              left: 60,
              top: 54.0,
              child: Text(serializeResolutionPreset(resolutionPreset))
            )
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Future choiceAction(String choice) async {
    final r = ResolutionPreset.values.firstWhere((e) =>
        e.toString().split('.')[1].toUpperCase() == choice.toUpperCase());
    setState(() {
      resolutionPreset = r;
    });
    await _initalCamera(_controller.description);
  }

  Widget _buildCameraPreview() {
    final size = MediaQuery.of(context).size;
    return ClipRect(
      child: Container(
        child: Transform.scale(
          scale: _controller.value.aspectRatio / size.aspectRatio,
          child: Center(
            child: AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: CameraPreview(_controller),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      color: Theme.of(context).bottomAppBarColor,
      height: 100.0,
      width: double.infinity,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          FutureBuilder(
            future: getLastImage(),
            builder: (context, snapshot) {
              if (snapshot.data == null) {
                return Container(
                  width: 40.0,
                  height: 40.0,
                );
              }
              return GestureDetector(
                onTap: _isTakingPhoto
                    ? null
                    : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => Gallery(),
                          ),
                        ),
                child: Container(
                  width: 40.0,
                  height: 40.0,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4.0),
                    child: Image.file(
                      snapshot.data,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              );
            },
          ),
          CircleAvatar(
            backgroundColor: Colors.white,
            radius: 28.0,
            child: GestureDetector(
              onLongPressUp: _endBurstModePhoto2,
              onLongPress: _beginBurstModePhoto2,
              // onTapUp: _endBurstModePhoto,
              // onTapDown: _beginBurstModePhoto,
              onTap: () {
                if (!_isRecordingMode) {
                  _captureImage();
                } else {
                  if (_isRecording) {
                    stopVideoRecording();
                  } else {
                    startVideoRecording();
                  }
                }
              },
              child: Icon(
                (_isRecordingMode)
                    ? (_isRecording) ? Icons.stop : Icons.videocam
                    : Icons.camera_alt,
                size: 28.0,
                color: (_isRecording) ? Colors.red : Colors.black,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              (_isRecordingMode) ? Icons.camera_alt : Icons.videocam,
              color: Colors.white,
            ),
            onPressed: _isTakingPhoto
                ? null
                : () {
                    setState(() {
                      _isRecordingMode = !_isRecordingMode;
                    });
                  },
          ),
        ],
      ),
    );
  }

  Future<FileSystemEntity> getLastImage() async {
    final Directory extDir = await getApplicationDocumentsDirectory();
    final String dirPath = '${extDir.path}/media';
    final myDir = Directory(dirPath);
    final dirExist = await myDir.exists();
    if (!dirExist) {
      await myDir.create();
    }

    List<FileSystemEntity> _images;
    _images = myDir.listSync(recursive: true, followLinks: false);
    _images.sort((a, b) {
      return b.path.compareTo(a.path);
    });

    if (_images.length == 0) {
      return null;
    }

    var lastFile = _images[0];
    var extension = path.extension(lastFile.path);
    if (extension == '.jpeg') {
      return lastFile;
    } else {
      String thumb = await Thumbnails.getThumbnail(
          videoFile: lastFile.path, imageType: ThumbFormat.PNG, quality: 30);
      return File(thumb);
    }
  }

  Future<void> _onCameraSwitch() async {
    final CameraDescription cameraDescription =
        (_controller.description == _cameras[0]) ? _cameras[1] : _cameras[0];
    if (_controller != null) {
      await _controller.dispose();
    }
    await _initalCamera(cameraDescription);
  }

  Future<void> _initalCamera(CameraDescription cameraDescription) async {
    if (_controller != null) {
      await _controller.dispose();
    }
    _controller = CameraController(cameraDescription, resolutionPreset);
    _controller.addListener(() {
      if (mounted) setState(() {});
      if (_controller.value.hasError) {
        showInSnackBar('Camera error ${_controller.value.errorDescription}');
      }
    });

    try {
      await _controller.initialize();
    } on CameraException catch (e) {
      _showCameraException(e);
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _captureImage() async {
    print('_captureImage');
    if (_controller.value.isInitialized) {
      if (_controller.value.isTakingPicture) {
        // A capture is already pending, do nothing.
        return null;
      }
      setState(() {
        _isTakingPhoto = true;
      });
      SystemSound.play(SystemSoundType.click);
      final Directory extDir = await getApplicationDocumentsDirectory();
      final String dirPath = '${extDir.path}/media';
      await Directory(dirPath).create(recursive: true);
      final String filePath = '$dirPath/${_timestamp()}.jpeg';
      print('path: $filePath');
      try {
        await _controller.takePicture(filePath);
      } on CameraException catch (e) {
        print('Error: ${e.code}\nError Message: ${e.description}');
      } finally {
        setState(() {
          _isTakingPhoto = false;
        });
      }
    }
  }

  Future<String> startVideoRecording() async {
    print('startVideoRecording');
    if (!_controller.value.isInitialized) {
      return null;
    }
    setState(() {
      _isRecording = true;
    });
    _timerKey.currentState.startTimer();

    final Directory extDir = await getApplicationDocumentsDirectory();
    final String dirPath = '${extDir.path}/media';
    await Directory(dirPath).create(recursive: true);
    final String filePath = '$dirPath/${_timestamp()}.mp4';

    if (_controller.value.isRecordingVideo) {
      // A recording is already started, do nothing.
      return null;
    }

    try {
//      videoPath = filePath;
      await _controller.startVideoRecording(filePath);
    } on CameraException catch (e) {
      _showCameraException(e);
      return null;
    }
    return filePath;
  }

  Future<void> stopVideoRecording() async {
    if (!_controller.value.isRecordingVideo) {
      return null;
    }
    _timerKey.currentState.stopTimer();
    setState(() {
      _isRecording = false;
    });

    try {
      await _controller.stopVideoRecording();
    } on CameraException catch (e) {
      _showCameraException(e);
      return null;
    }
  }

  Future _beginBurstModePhoto(TapDownDetails d) async {
    if (!_isRecordingMode) {
      setState(() {
        _isBurstModePhoto = true;
      });
      while (_isBurstModePhoto) {
        _captureImage();
        await new Future.delayed(const Duration(milliseconds: 50));
      }
    }
  }

  void _endBurstModePhoto(dynamic d) async {
    setState(() {
      _isBurstModePhoto = false;
    });
  }

  Future _beginBurstModePhoto2() async {
    if (!_isRecordingMode) {
      setState(() {
        _isBurstModePhoto = true;
      });
      while (_isBurstModePhoto) {
        _captureImage();
        await new Future.delayed(const Duration(milliseconds: 50));
      }
    }
  }

  void _endBurstModePhoto2() async {
    setState(() {
      _isBurstModePhoto = false;
    });
  }

  String _timestamp() => DateTime.now().millisecondsSinceEpoch.toString();

  void _showCameraException(CameraException e) {
    logError(e.code, e.description);
    showInSnackBar('Error: ${e.code}\n${e.description}');
  }

  void showInSnackBar(String message) {
    _scaffoldKey.currentState.showSnackBar(SnackBar(content: Text(message)));
  }

  void logError(String code, String message) =>
      print('Error: $code\nError Message: $message');

  @override
  bool get wantKeepAlive => true;
}
