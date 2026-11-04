import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/lecture_models.dart';

/// 실시간 연결 상태
enum SyncStatus {
  /// 강의가 정해지지 않았거나 Supabase 설정이 없음
  idle,
  connecting,

  /// Supabase Realtime 구독 중 (정상)
  live,

  /// Realtime 연결이 끊겨 1.5초마다 DB를 직접 조회하는 중 (자동 재연결 시도 중)
  polling,
  error,
}

enum ChangeKind { upsert, delete }

class RowChange<T> {
  final ChangeKind kind;
  final T? row;
  final int id;
  const RowChange.upsert(T this.row, this.id) : kind = ChangeKind.upsert;
  const RowChange.delete(this.id)
      : kind = ChangeKind.delete,
        row = null;
}

/// 강의 하나의 자막·질문·공지·용어를 Supabase Realtime으로 받는다.
///
/// - 자막(lecture_contents): 원문 INSERT와 번역 UPDATE를 모두 받아 같은 id의 자막을 갱신한다.
/// - Realtime이 끊기면 자막은 1.5초마다 직접 조회하고(폴링), 5초 뒤 다시 구독을 시도한다.
///   예전 코드처럼 조회가 겹쳐 같은 행을 두 번 받지 않도록 조회 중에는 다음 조회를 건너뛴다.
/// - 질문·공지·용어는 변경 이벤트만 흘려보내고, 목록 관리는 각 컨트롤러가 한다.
class LectureRealtime {
  LectureRealtime(this.lectureId, {SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final String lectureId;
  final SupabaseClient _client;

  static const _captionColumns =
      'id, original_text, translated_text, source_lang, target_lang, created_at, has_visual, visual_summary';
  static const _initialCaptions = 30;
  static const _maxCaptions = 100;
  static const _pollInterval = Duration(milliseconds: 1500);
  static const _resubscribeDelay = Duration(seconds: 5);

  final _captionMap = <int, Caption>{};
  final _captions = StreamController<List<Caption>>.broadcast();
  final _status = StreamController<SyncStatus>.broadcast();
  final _questions = StreamController<RowChange<LectureQuestion>>.broadcast();
  final _notices = StreamController<RowChange<LectureNotice>>.broadcast();
  final _glossary = StreamController<GlossaryEntry>.broadcast();

  RealtimeChannel? _channel;
  Timer? _pollTimer;
  Timer? _resubscribeTimer;
  bool _polling = false;
  bool _disposed = false;
  SyncStatus _current = SyncStatus.idle;

  Stream<List<Caption>> get captions => _captions.stream;
  Stream<SyncStatus> get status => _status.stream;
  Stream<RowChange<LectureQuestion>> get questionChanges => _questions.stream;
  Stream<RowChange<LectureNotice>> get noticeChanges => _notices.stream;
  Stream<GlossaryEntry> get glossaryInserts => _glossary.stream;

  SyncStatus get currentStatus => _current;
  List<Caption> get currentCaptions => _sortedCaptions();

  Future<void> start() async {
    _setStatus(SyncStatus.connecting);
    await _loadRecentCaptions();
    _subscribe();
  }

  void _setStatus(SyncStatus status) {
    if (_disposed || status == _current) return;
    _current = status;
    _status.add(status);
  }

  List<Caption> _sortedCaptions() {
    final list = _captionMap.values.toList()..sort((a, b) => a.id.compareTo(b.id));
    return list;
  }

  void _upsertCaptions(Iterable<Map<String, dynamic>> rows) {
    var changed = false;
    for (final row in rows) {
      final caption = Caption.fromRow(row);
      if (caption.id == 0 || caption.original.isEmpty) continue;
      _captionMap[caption.id] = caption;
      changed = true;
    }
    if (!changed || _disposed) return;
    if (_captionMap.length > _maxCaptions) {
      final ids = _captionMap.keys.toList()..sort();
      for (final id in ids.take(_captionMap.length - _maxCaptions)) {
        _captionMap.remove(id);
      }
    }
    _captions.add(_sortedCaptions());
  }

  Future<void> _loadRecentCaptions() async {
    try {
      final rows = await _client
          .from('lecture_contents')
          .select(_captionColumns)
          .eq('lecture_id', lectureId)
          .order('id', ascending: false)
          .limit(_initialCaptions);
      _upsertCaptions(List<Map<String, dynamic>>.from(rows));
      if (_captionMap.isEmpty && !_disposed) _captions.add(const []);
    } catch (_) {
      // 첫 조회 실패는 구독/폴링이 이어서 처리한다
    }
  }

  /// 새 자막 + 최근 3개 자막(번역이 늦게 채워짐)을 다시 읽는다
  Future<void> _pollCaptions() async {
    if (_polling || _disposed) return;
    _polling = true;
    try {
      final ids = _captionMap.keys.toList()..sort();
      final from = ids.length >= 3 ? ids[ids.length - 3] : (ids.isEmpty ? 0 : ids.first);
      final rows = await _client
          .from('lecture_contents')
          .select(_captionColumns)
          .eq('lecture_id', lectureId)
          .gte('id', from)
          .order('id')
          .limit(50);
      _upsertCaptions(List<Map<String, dynamic>>.from(rows));
    } catch (_) {
      _setStatus(SyncStatus.error);
    } finally {
      _polling = false;
    }
  }

  void _startPolling() {
    if (_pollTimer != null || _disposed) return;
    _pollTimer = Timer.periodic(_pollInterval, (_) => _pollCaptions());
    _pollCaptions();
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _subscribe() {
    if (_disposed) return;
    final filter = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'lecture_id',
      value: lectureId,
    );
    final channel = _client.channel('lecture:$lectureId:${DateTime.now().millisecondsSinceEpoch}');
    _channel = channel;

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'lecture_contents',
          filter: filter,
          callback: (p) {
            if (p.eventType != PostgresChangeEvent.delete) _upsertCaptions([p.newRecord]);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'lecture_questions',
          filter: filter,
          callback: (p) => _emitRow(_questions, p, LectureQuestion.fromRow),
        )
        .onPostgresChanges(
          // 전체 공지(lecture_id 없음)도 받아야 해서 필터 없이 구독하고 여기서 거른다
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'lecture_notices',
          callback: (p) {
            final record = p.eventType == PostgresChangeEvent.delete ? p.oldRecord : p.newRecord;
            final owner = record['lecture_id'];
            if (owner == null || owner == lectureId || p.eventType == PostgresChangeEvent.delete) {
              _emitRow(_notices, p, LectureNotice.fromRow);
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'lecture_glossary',
          filter: filter,
          callback: (p) {
            if (!_disposed) _glossary.add(GlossaryEntry.fromJson(p.newRecord));
          },
        )
        .subscribe((status, error) {
      if (_disposed || !identical(_channel, channel)) return;
      switch (status) {
        case RealtimeSubscribeStatus.subscribed:
          _stopPolling();
          _setStatus(SyncStatus.live);
          _pollCaptions(); // 구독 직전에 들어온 자막 보충
        case RealtimeSubscribeStatus.channelError:
        case RealtimeSubscribeStatus.timedOut:
        case RealtimeSubscribeStatus.closed:
          _setStatus(SyncStatus.polling);
          _startPolling();
          _scheduleResubscribe();
      }
    });
  }

  void _emitRow<T>(StreamController<RowChange<T>> sink, PostgresChangePayload p, T Function(Map<String, dynamic>) parse) {
    if (_disposed) return;
    if (p.eventType == PostgresChangeEvent.delete) {
      final id = p.oldRecord['id'];
      if (id is int) sink.add(RowChange.delete(id));
      return;
    }
    final id = p.newRecord['id'];
    if (id is int) sink.add(RowChange.upsert(parse(p.newRecord), id));
  }

  void _scheduleResubscribe() {
    if (_resubscribeTimer != null || _disposed) return;
    _resubscribeTimer = Timer(_resubscribeDelay, () async {
      _resubscribeTimer = null;
      final old = _channel;
      _channel = null;
      if (old != null) {
        try {
          await _client.removeChannel(old);
        } catch (_) {}
      }
      _subscribe();
    });
  }

  Future<void> dispose() async {
    _disposed = true;
    _stopPolling();
    _resubscribeTimer?.cancel();
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      try {
        await _client.removeChannel(channel);
      } catch (_) {}
    }
    await Future.wait([
      _captions.close(),
      _status.close(),
      _questions.close(),
      _notices.close(),
      _glossary.close(),
    ]);
  }
}
