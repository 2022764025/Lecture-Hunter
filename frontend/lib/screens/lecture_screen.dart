import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/audio_service.dart'; // 아까 만든 오디오 서비스 연결

class LectureScreen extends StatefulWidget {
    const LectureScreen({super.key});

    @override
    State<LectureScreen> createState() => _LectureScreenState();
}

class _LectureScreenState extends State<LectureScreen> {
    final _audioService = AudioService();
    final supabase = Supabase.instance.client;
    String _caption = "강의를 시작하면 자막이 여기에 표시됩니다.";
    bool _isRecording = false;

    @override
    void initState() {
        super.initState();
        setupRealtime();
    }

    // 실시간 자막 수신 설정 수정
    void setupRealtime() {
        supabase.channel('lecture_room_1').onBroadcast(
            event: 'new_caption',
            callback: (payload) {
                // 백엔드에서 보낸 'original'(원문)을 화면에 표시합니다.
                // 나중에 번역본을 보고 싶다면 payload['translated']를 쓰면 됩니다.
                setState(() => _caption = payload['original']); 
            },
        ).subscribe();
    }

    // 녹음 시작/중지 버튼 로직
    void _toggleRecording() async {
        if (_isRecording) {
            await _audioService.stopStreaming();
        } else {
            // 'lecture_room_1'은 임시 ID임
            await _audioService.startStreaming('lecture_room_1');
        }
        setState(() => _isRecording = !_isRecording);
    }

    @override
    Widget build(BuildContext context) {
        return Scaffold(
            appBar: AppBar(title: const Text('실시간 강의 자막')),
            body: Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                        Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Text(
                                _caption,
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                            ),
                        ),
                        const SizedBox(height: 50),
                        ElevatedButton(
                            onPressed: _toggleRecording,
                            style: ElevatedButton.styleFrom(
                                backgroundColor: _isRecording ? Colors.red : Colors.blue,
                            ),
                            child: Text(_isRecording ? '강의 종료' : '강의 시작'),
                        ),
                    ],
                ),
            ),
        );
    }
}