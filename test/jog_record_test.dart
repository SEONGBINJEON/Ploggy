import 'dart:io';
import 'package:flogging_app/models/jog_record.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// 어댑터가 읽는 순서대로 값을 돌려주는 가짜 리더 (필드 개수 → (번호, 값) 반복)
class _FakeReader implements BinaryReader {
  _FakeReader(this._bytes, this._values);

  final List<int> _bytes;
  final List<Object?> _values;
  int _byteIndex = 0;
  int _valueIndex = 0;

  @override
  int readByte() => _bytes[_byteIndex++];

  @override
  dynamic read([int? typeId]) => _values[_valueIndex++];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  test('경로 저장 기능 이전(필드 4개)에 저장된 기록도 읽을 수 있다', () {
    final legacy = _FakeReader(
      [4, 0, 1, 2, 3],
      [DateTime(2025, 9, 1, 7), 3.2, 1200, 9.6],
    );
    final record = JogRecordAdapter().read(legacy);
    expect(record.distanceKm, 3.2);
    expect(record.durationSeconds, 1200);
    expect(record.routeLatLng, isEmpty);
    expect(record.routePoints, isEmpty);
  });

  group('Hive 저장', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ploggy_jog_test');
      Hive.init(tempDir.path);
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(JogRecordAdapter());
      }
    });

    tearDown(() async {
      await Hive.deleteFromDisk();
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {
        // Windows에서 파일 잠금이 늦게 풀리는 경우는 무시
      }
    });

    test('경로까지 저장하고 다시 열어도 그대로 읽힌다', () async {
      var box = await Hive.openBox<JogRecord>('jog_records');
      await box.add(JogRecord(
        date: DateTime(2026, 9, 1, 7),
        distanceKm: 1.5,
        durationSeconds: 600,
        speedKmph: 9,
        routeLatLng: [-37.8183, 144.9671, -37.8190, 144.9680],
      ));
      await box.close();

      box = await Hive.openBox<JogRecord>('jog_records');
      final record = box.getAt(0)!;
      expect(record.routePoints, [
        (lat: -37.8183, lng: 144.9671),
        (lat: -37.8190, lng: 144.9680),
      ]);
    });
  });

  group('toShareText', () {
    test('경로가 있으면 Google 지도 경로 링크를 넣는다', () {
      final record = JogRecord(
        date: DateTime(2026, 9, 1, 7),
        distanceKm: 1.5,
        durationSeconds: 605,
        speedKmph: 8.9,
        routeLatLng: [-37.8183, 144.9671, -37.8190, 144.9680],
      );
      final text = record.toShareText();
      expect(text, contains('10분 5초'));
      expect(text, contains('1.50 km'));
      expect(text, contains('https://www.google.com/maps/dir/'));
    });

    test('경로가 없으면 링크 줄을 넣지 않는다', () {
      final record = JogRecord(
        date: DateTime(2026, 9, 1, 7),
        distanceKm: 0,
        durationSeconds: 30,
        speedKmph: 0,
      );
      expect(record.toShareText(), isNot(contains('google.com')));
    });
  });
}
