import 'package:flutter/material.dart';

import '../../core/web/host_bridge.dart';
import 'lecture_widget.dart';
import 'stage_page.dart';

/// 크롬 확장 iframe 안이면 위젯만(배경 투명), 직접 열었으면 시연용 화면(StagePage)을 보여준다.
class OverlayPage extends StatefulWidget {
  const OverlayPage({super.key});

  @override
  State<OverlayPage> createState() => _OverlayPageState();
}

class _OverlayPageState extends State<OverlayPage> {
  @override
  void initState() {
    super.initState();
    HostBridge.ready();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: HostBridge.embedded
          ? const Align(alignment: Alignment.topLeft, child: LectureWidget(shadow: false))
          : const StagePage(),
    );
  }
}
