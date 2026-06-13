import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class UpdateInfo {
  final String latestVersion;
  final int latestBuild;
  final String downloadUrl;
  final String changelog;
  final bool forceUpdate;

  const UpdateInfo({
    required this.latestVersion,
    required this.latestBuild,
    required this.downloadUrl,
    required this.changelog,
    required this.forceUpdate,
  });
}

class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  /// Consulta Firestore: retorna UpdateInfo si hay versión nueva, null si está al día.
  Future<UpdateInfo?> checkForUpdate() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('app_version')
          .get();

      if (!doc.exists) return null;

      final data = doc.data()!;
      final latestBuild = (data['build_number'] as num?)?.toInt() ?? 0;
      final latestVersion = data['version'] as String? ?? '1.0.0';
      final downloadUrl = data['download_url'] as String? ?? '';
      final changelog = data['changelog'] as String? ?? 'Mejoras y correcciones.';
      final forceUpdate = data['force_update'] as bool? ?? false;

      final info = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(info.buildNumber) ?? 1;

      if (latestBuild > currentBuild && downloadUrl.isNotEmpty) {
        return UpdateInfo(
          latestVersion: latestVersion,
          latestBuild: latestBuild,
          downloadUrl: downloadUrl,
          changelog: changelog,
          forceUpdate: forceUpdate,
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Descarga el APK mostrando progreso y luego lo instala.
  /// [onProgress] recibe valores de 0.0 a 1.0.
  Future<String?> downloadAndInstall(
    String url, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      // Pedir permiso de instalación en Android 8+
      if (Platform.isAndroid) {
        final status = await Permission.requestInstallPackages.request();
        if (!status.isGranted) {
          return 'Permiso de instalación denegado. Habilitalo en Ajustes > Instalar apps desconocidas.';
        }
      }

      // Directorio de descarga
      final dir = await getExternalStorageDirectory() ??
          await getApplicationCacheDirectory();
      final savePath = '${dir.path}/quantrix_update.apk';

      // Borrar APK anterior si existe
      final file = File(savePath);
      if (await file.exists()) await file.delete();

      // Descargar con Dio
      await Dio().download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total > 0 && onProgress != null) {
            onProgress(received / total);
          }
        },
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          receiveTimeout: const Duration(minutes: 5),
        ),
      );

      // Abrir el instalador
      final result = await OpenFile.open(savePath, type: 'application/vnd.android.package-archive');
      if (result.type != ResultType.done) {
        return 'No se pudo abrir el instalador: ${result.message}';
      }
      return null;
    } catch (e) {
      return 'Error al descargar: $e';
    }
  }
}
