import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/lecture_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://fcaoqlsjrkroiwzdfhwr.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZjYW9xbHNqcmtyb2l3emRmaHdyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI4NzUzNDIsImV4cCI6MjA4ODQ1MTM0Mn0.cR-BPOYvyATtpR1-FjtgktYer5PCyjYc-8DA_tYhmWQ',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Live Lecture AI',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const LectureScreen(), // 아까 만든 화면을 첫 화면으로 설정
    );
  }
}