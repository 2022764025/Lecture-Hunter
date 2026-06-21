import 'dart:html' as html;
import 'dart:ui_web' as ui;
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_lecture_ai/main.dart';
import '../../../caption/presentation/controllers/caption_controller.dart';
import '../widgets/lecture_result_strip.dart';

const String _lectureVideoViewType = 'lecture-shared-video-view';
bool _lectureVideoViewRegistered = false;

class OverlayPage extends ConsumerStatefulWidget {
  const OverlayPage({super.key});

  @override
  ConsumerState<OverlayPage> createState() => _OverlayPageState();
}

class _OverlayPageState extends ConsumerState<OverlayPage> {
  @override
  void initState() {
    super.initState();
    _registerLectureVideoView();

    if (globalLectureId != null && globalLectureId!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _connect();
      });
    }

    html.window.onMessage.listen((event) {
      try {
        final rawData = event.data;
        if (rawData is String) {
          final Map<String, dynamic> data = jsonDecode(rawData);

          if (data['type'] == 'SET_LECTURE_ID') {
            globalLectureId = data['lectureId'];
            _connect();
          }
        }
      } catch (e) {}
    });

    final readySignal = jsonEncode({'type': 'FLUTTER_READY'});
    html.window.parent?.postMessage(readySignal, '*');
  }

  void _registerLectureVideoView() {
    if (_lectureVideoViewRegistered) return;
    _lectureVideoViewRegistered = true;

    ui.platformViewRegistry.registerViewFactory(
      _lectureVideoViewType,
      (int viewId) {
        final video = html.VideoElement()
          ..id = 'lecture-shared-video'
          ..autoplay = true
          ..muted = true
          ..controls = false
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.objectFit = 'contain'
          ..style.backgroundColor = 'transparent';

        video.setAttribute('playsinline', 'true');
        return video;
      },
    );
  }

  void _connect() {
    final isMock = ref.read(mockModeProvider);
    final sseService = ref.read(sseServiceProvider);

    final currentParamId = globalLectureId;

    if (isMock) {
      sseService.startMock();
    } else {
      if (currentParamId != null) {
        sseService.connect(lectureId: currentParamId);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(subtitleStreamProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            _LectureBackground(),
            const LectureFloatingWidget(),
          ],
        ),
      ),
    );
  }
}

class _LectureBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const HtmlElementView(
            viewType: _lectureVideoViewType,
          ),
          IgnorePointer(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.transparent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}