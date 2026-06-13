import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class FcmService {
  static final FcmService _i = FcmService._();
  factory FcmService() => _i;
  FcmService._();

  final _fcm = FirebaseMessaging.instance;
  final _localNotif = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _localNotif.initialize(
      const InitializationSettings(android: androidInit),
    );

    // Guardar token en Firestore
    final token = await _fcm.getToken();
    if (token != null) await _saveToken(token);

    _fcm.onTokenRefresh.listen(_saveToken);

    // Notificaciones en foreground
    FirebaseMessaging.onMessage.listen((msg) {
      final n = msg.notification;
      if (n == null) return;
      _localNotif.show(
        msg.hashCode,
        n.title,
        n.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'quantrix_alerts',
            'Alertas Quantrix',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );
    });
  }

  Future<void> _saveToken(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'fcmToken': token,
      'tokenUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> subscribeTopic(String topic) =>
      _fcm.subscribeToTopic(topic);

  Future<void> unsubscribeTopic(String topic) =>
      _fcm.unsubscribeFromTopic(topic);
}
