import 'dart:convert';

import 'package:faker/faker.dart';
import 'package:nakama/nakama.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

import '../config.dart';

void main() {
  group('[gRPC] Test Leaderboard', () {
    late final NakamaBaseClient client;
    late final Session session;
    late final String leaderboardName;

    setUpAll(() async {
      client = getNakamaClient(
        host: kTestHost,
        ssl: false,
        serverKey: kTestServerKey,
      );

      session = await client.authenticateDevice(deviceId: faker.guid.guid());

      // Create leaderboard
      final result = await client.rpc(
        session: session,
        id: 'clientrpc.create_leaderboard',
        payload: jsonEncode({'operator': 'best'}),
      );

      final payload = jsonDecode(result!);
      leaderboardName = payload['leaderboard_id'];
    });

    test('list leaderboard records', () async {
      await client.writeLeaderboardRecord(session: session, leaderboardName: leaderboardName, score: 10);

      final result = await client.listLeaderboardRecords(
        session: session,
        leaderboardName: leaderboardName,
      );

      expect(result, isA<LeaderboardRecordList>());
      expect(result.records!.first.score, isNotNull);
      expect(result.records!.first.score, equals('10'));
    });

    test('write leaderboard record', () async {
      final result = await client.writeLeaderboardRecord(session: session, leaderboardName: leaderboardName, score: 10);

      expect(result, isA<LeaderboardRecord>());
      expect(result.score, isNotNull);
      expect(result.score, equals('10'));
    });

    test('list leaderboard records around user', () async {
      await client.writeLeaderboardRecord(session: session, leaderboardName: leaderboardName, score: 10);

      final result = await client.listLeaderboardRecordsAroundOwner(
        session: session,
        leaderboardName: leaderboardName,
        ownerId: session.userId,
      );

      expect(result, isA<LeaderboardRecordList>());
      expect(result.records!.first.score, isNotNull);
      expect(result.records!.first.score, equals('10'));
    });
  });
}
