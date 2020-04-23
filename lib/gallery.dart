import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:esys_flutter_share/esys_flutter_share.dart';
import 'package:flutter/material.dart';
import 'package:flutter_camera/video_preview.dart';
import 'package:flutter_camera/constants.dart';
import 'package:path/path.dart' as path;

class Gallery extends StatefulWidget {
  @override
  _GalleryState createState() => _GalleryState();
}

class _GalleryState extends State<Gallery> {
  String currentFilePath;
  String appBarStr;
  bool _isDeleting = false;
  PageController _pageController;
  int _totalPhotos = -1;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: _getAllImages(),
        builder: (context, AsyncSnapshot<List<FileSystemEntity>> snapshot) {
          int lastIndex = snapshot.data.length;
          if (appBarStr == null) {
            appBarStr = "1/$lastIndex";
          }
          if (snapshot.data.isEmpty) {
            appBarStr = "";
          }
          _pageController = new PageController(initialPage: 0);
          return Scaffold(
            backgroundColor: Theme.of(context).backgroundColor,
            appBar: AppBar(
              title: appBarStr != null ? Text(appBarStr) : null,
            ),
            body: _buildBody(snapshot),
            bottomNavigationBar: BottomAppBar(
              child: Container(
                height: 56.0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    IconButton(
                      icon: Icon(Icons.share),
                      onPressed: () => _shareFile(),
                    ),
                    GestureDetector(
                      onLongPressUp: _endDeleteFile2,
                      onLongPress: _beginDeleteFile2,
                      // onTapUp: _endDeleteFile,
                      // onTapDown: _beginDeleteFile,
                      onTap: _deleteFile,
                      child: Icon(Icons.delete),
                    )
                  ],
                ),
              ),
            ),
          );
        });
  }

  _buildBody(AsyncSnapshot<List<FileSystemEntity>> snapshot) {
    if (!snapshot.hasData || snapshot.data.isEmpty) {
      return Center(
        child: Text('No images found.'),
      );
    }
    _totalPhotos = snapshot.data.length;
    print('${snapshot.data.length} ${snapshot.data}');
    return PageView.builder(
      controller: _pageController,
      onPageChanged: (int page) => {
        setState(() {
          appBarStr = "${page + 1}/${snapshot.data.length}";
        })
      },
      itemCount: snapshot.data.length,
      itemBuilder: (context, index) {
        currentFilePath = snapshot.data[index].path;
        var extension = path.extension(snapshot.data[index].path);
        if (extension == '.jpeg') {
          final imgFile = Image.file(
            File(snapshot.data[index].path),
          );
          Completer<ui.Image> imgCompleter = new Completer<ui.Image>();

          imgFile.image.resolve(new ImageConfiguration()).addListener(
              ImageStreamListener((ImageInfo info, bool _) =>
                  imgCompleter.complete(info.image)));
          return Container(
            //height: 300,
            padding: const EdgeInsets.only(bottom: 8.0),
            child: FutureBuilder(
                future: imgCompleter.future,
                builder: (context, AsyncSnapshot<ui.Image> snapshot) {
                  if (snapshot.data == null) {
                    return const Center(
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  return Column(
                    children: <Widget>[
                      new ConstrainedBox(
                        constraints: new BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height - 150,
                        ),
                        child: FittedBox(child: imgFile, fit: BoxFit.contain),
                      ),
                      Text(snapshot.data.width.toString() +
                          "x" +
                          snapshot.data.height.toString())
                    ],
                  );
                }),
          );
        } else {
          return VideoPreview(
            videoPath: snapshot.data[index].path,
          );
        }
      },
    );
    //  pageView.controller.jumpToPage(snapshot.data.length - 1);
  }

  _shareFile() async {
    var extension = path.extension(currentFilePath);
    await Share.file(
      'image',
      (extension == '.jpeg') ? 'image.jpeg' : '	video.mp4',
      File(currentFilePath).readAsBytesSync(),
      (extension == '.jpeg') ? 'image/jpeg' : '	video/mp4',
    );
  }

  Future _deleteFile() async {
    final dir = Directory(currentFilePath);
    try {
      await dir.delete(recursive: true);
      print('deleted');
      setState(() {
        appBarStr = "${_pageController.page.toInt() + 1}/$_totalPhotos";
      });
    } on FileSystemException catch (e) {
      print('Error: ${e.osError}\nError Message: ${e.message}');
    } finally {}
    setState(() {});
  }

  Future _beginDeleteFile(TapDownDetails d) async {
    setState(() {
      _isDeleting = true;
    });
    while (_isDeleting) {
      _deleteFile();
      await new Future.delayed(const Duration(milliseconds: 100));
    }
  }

  void _endDeleteFile(TapUpDetails d) async {
    setState(() {
      _isDeleting = false;
    });
  }

  Future _beginDeleteFile2() async {
    setState(() {
      _isDeleting = true;
    });
    while (_isDeleting) {
      _deleteFile();
      await new Future.delayed(const Duration(milliseconds: 100));
    }
  }

  void _endDeleteFile2() async {
    setState(() {
      _isDeleting = false;
    });
  }

  Future<List<FileSystemEntity>> _getAllImages() async {
    final String dirPath = await Constants.getMediaStorage();
    final myDir = Directory(dirPath);
    List<FileSystemEntity> _images;
    _images = await myDir.list(recursive: true, followLinks: false).toList();
    _images.sort((a, b) {
      return b.path.compareTo(a.path);
    });
    return _images;
  }
}
