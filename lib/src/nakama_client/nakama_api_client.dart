import 'dart:convert';

import 'package:chopper/chopper.dart';
import 'package:nakama/api/api.pb.dart';
import 'package:nakama/rest/apigrpc.swagger.dart';
import 'package:nakama/src/session.dart' as model;

import 'nakama_client.dart';

const _kDefaultAppKey = 'default';

/// Base class for communicating with Nakama via gRPC.
/// [NakamaGrpcClient] abstracts the gRPC calls and handles authentication
/// for you.
class NakamaRestApiClient extends NakamaBaseClient {
  static final Map<String, NakamaRestApiClient> _clients = {};

  late final ChopperClient _chopperClient;

  /// The key used to authenticate with the server without a session.
  /// Defaults to "defaultkey".
  late final String serverKey;

  /// Temporarily holds the current valid session to use in the Chopper
  /// interceptor for JWT auth.
  model.Session? _session;

  /// Either inits and returns a new instance of [NakamaRestApiClient] or
  /// returns a already initialized one.
  factory NakamaRestApiClient.init({
    String? host,
    String? serverKey,
    String key = _kDefaultAppKey,
    int port = 7350,
    bool ssl = false,
  }) {
    if (_clients.containsKey(key)) {
      return _clients[key]!;
    }

    // Not yet initialized -> check if we've got all parameters to do so
    if (host == null || serverKey == null) {
      throw Exception(
        'Not yet initialized, need parameters [host] and [serverKey] to initialize.',
      );
    }

    // Create a new instance of this with given parameters.
    return _clients[key] = NakamaRestApiClient._(
      host: host,
      port: port,
      serverKey: serverKey,
      ssl: ssl,
    );
  }

  NakamaRestApiClient._({
    required String host,
    required String serverKey,
    required int port,
    required bool ssl,
  }) {
    _chopperClient = ChopperClient(
      converter: JsonSerializableConverter(),
      baseUrl: Uri(
        host: host,
        scheme: ssl ? 'https' : 'http',
        port: port,
      ).toString(),
      services: [Apigrpc.create()],
      interceptors: [
        // Auth Interceptor
        (Request request) async {
          // Server Key Auth
          if (_session == null) {
            return applyHeader(
              request,
              'Authorization',
              'Basic ' + base64Encode('$serverKey:'.codeUnits),
            );
          }

          // User's JWT auth
          return applyHeader(
            request,
            'Authorization',
            'Bearer ${_session!.token}',
          );
        },
      ],
    );
  }

  Apigrpc get _api => _chopperClient.getService<Apigrpc>();

  @override
  Future<model.Session> authenticateEmail({
    required String email,
    required String password,
    bool create = false,
    String? username,
  }) async {
    final res = await _api.nakamaAuthenticateEmail(
      body: ApiAccountEmail(
        email: email,
        password: password,
      ),
    );

    if (res.body == null) {
      throw Exception('Authentication failed.');
    }

    final data = res.body!;

    return model.Session(
      created: data.created ?? false,
      token: data.token!,
      refreshToken: data.refreshToken,
    );
  }

  @override
  Future<Account> getAccount(model.Session session) async {
    _session = session;
    final res = await _api.nakamaGetAccount();

    final acc = Account();
    acc.mergeFromProto3Json(res.body!.toJson());

    return acc;
  }
}

NakamaBaseClient getNakamaClient({
  String? host,
  String? serverKey,
  String key = _kDefaultAppKey,
  int httpPort = 7350,
  int grpcPort = 7349,
  bool ssl = false,
}) =>
    NakamaRestApiClient.init(
      host: host,
      key: key,
      port: httpPort,
      serverKey: serverKey,
      ssl: ssl,
    );