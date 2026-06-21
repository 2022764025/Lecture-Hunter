// lib/features/overlay/presentation/pages/overlay_page.dart
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
      print("==========================================================");
      print("[플러터 엔진] 주소창 복원 ID 감지 성공 -> 즉시 연동 파이프라인 가동!");
      print("==========================================================");
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
      } catch (e) {
        print("[디버그 크래시 추적 에러] : $e");
      }
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
          // 외부 웹사이트 화면을 검은색으로 먹통 시키지 않도록 투명화 세팅 고정
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
    print("==========================================================");
    print("[플러터 디버그] 실시간 소켓 연동용 강의 ID: $currentParamId");
    print("==========================================================");

    if (isMock) {
      sseService.startMock();
    } else {
      if (currentParamId != null) {
        print("[플러터 리버팟] sseService 직접 연결 시작: $currentParamId");
        sseService.connect(lectureId: currentParamId);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 잠들어 있는 자막 스트림 프로바이더를 강제로 감시(watch)
    // 이렇게 해야 내부의 .listen() 로직이 활성화되어 수파베이스 데이터를 히스토리에 꼽기 시작
    ref.watch(subtitleStreamProvider);

    return Scaffold(
      // 위젯 오버레이가 LMS 웹 스크린을 가리지 않도록 전체 배경 투명 처리
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
      color: Colors.transparent, // 웹 브라우저 투명 레이어화
      child: Stack(
        fit: StackFit.expand,
        children: [
          const HtmlElementView(
            viewType: _lectureVideoViewType,
          ),
          IgnorePointer(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.transparent, // 불필요한 시각 방해 그라데이션 제거 및 투명 박스화 완수
              ),
            ),
          ),
        ],
      ),
    );
  }
}