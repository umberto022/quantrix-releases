import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectionService {
  static final ConnectionService _instance = ConnectionService._internal();
  factory ConnectionService() => _instance;
  ConnectionService._internal();

  final _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  final _statusController = StreamController<bool>.broadcast();
  Stream<bool> get onStatusChange => _statusController.stream;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  void init() {
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online != _isOnline) {
        _isOnline = online;
        _statusController.add(_isOnline);
      }
    });
    // Check initial state
    _connectivity.checkConnectivity().then((results) {
      _isOnline = results.any((r) => r != ConnectivityResult.none);
    });
  }

  void dispose() {
    _subscription?.cancel();
    _statusController.close();
  }
}
