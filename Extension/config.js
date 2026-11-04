// Lecture-Hunter 확장 설정. 서버 주소를 바꾸려면 여기만 고친다.
// (background.js 는 importScripts, frame.html · offscreen.html 은 <script> 로 불러온다)
self.LLAI_CONFIG = Object.freeze({
  // Flutter 위젯 서버 (flutter run --web-port=9998 또는 build/web 을 http.server 로)
  WIDGET_URL: 'http://127.0.0.1:9998',
  // FastAPI 백엔드
  BACKEND_HTTP: 'http://127.0.0.1:8000',
  BACKEND_WS: 'ws://127.0.0.1:8000',
});
