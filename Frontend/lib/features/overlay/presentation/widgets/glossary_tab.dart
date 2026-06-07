import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class GlossaryTab extends ConsumerStatefulWidget {
  final bool embedded;
  const GlossaryTab({super.key, this.embedded = false});

  @override
  ConsumerState<GlossaryTab> createState() => _GlossaryTabState();
}

class _GlossaryTabState extends ConsumerState<GlossaryTab> {
  List<dynamic> glossaryList = [];
  bool isLoading = true; // 💡 로딩 화면(뱅글뱅글) 스위치
  bool isError = false;  // 💡 에러 화면(경고창) 스위치

  @override
  void initState() {
    super.initState();
    fetchGlossaryData(); // 화면이 열리면 자동으로 서버에 연결해요.
  }

  Future<void> fetchGlossaryData() async {
    const String lectureId = "test_lecture_id"; 
    // 💡 민재님이나 수지님이 알려준 백엔드 주소로 바꿔 적는 곳이에요.
    final String backendUrl = 'http://시작주소:8000/lecture/glossary/$lectureId';
    
    try {
      // ⏱️ "딱 5초만 기다린다!" 하고 타이머를 걸어둡니다.
      final response = await http.get(Uri.parse(backendUrl)).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        setState(() {
          glossaryList = json.decode(response.body); 
          isLoading = false;
          isError = false; // 성공했으니 에러 스위치를 꺼요!
        });
      } else {
        throw Exception("서버 연결 실패");
      }
    } catch (e) {
      // 💡 인터넷이 끊기거나 서버가 작동 안 하면 여기로 와요!
      setState(() {
        isLoading = false;
        isError = true; // 에러가 났으니 경고창 스위치를 켭니다!
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1단계: 로딩 중일 때
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.blueAccent),
      );
    }

    // 2단계: ⭐ 인터넷이 끊겼거나 에러가 났을 때 보여주는 안내 화면!
    if (isError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off, color: Colors.redAccent, size: 40),
            const SizedBox(height: 10),
            const Text(
              '인터넷 연결이나 서버가 아파요! 😭',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 5),
            TextButton(
              onPressed: () {
                setState(() { isLoading = true; }); // 로딩창 다시 켜고
                fetchGlossaryData(); // 다시 연결 시도!
              },
              child: const Text(
                '🔄 다시 연결해보기', 
                style: TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.bold),
              ),
            )
          ],
        ),
      );
    }

    // 3단계: 무사히 단어 데이터를 가져왔을 때
    if (glossaryList.isEmpty) {
      return const Center(
        child: Text('등록된 전공 용어가 없습니다.', style: TextStyle(color: Colors.white54)),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: glossaryList.length,
      itemBuilder: (context, index) {
        final item = glossaryList[index];
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item['word'] ?? '단어 없음', style: const TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(item['meaning'] ?? '설명이 없습니다.', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
          // 테스트용 주석 추가
        );
      },
    );
  }
}
