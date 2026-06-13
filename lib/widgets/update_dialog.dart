import 'package:flutter/material.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';

class UpdateDialog extends StatefulWidget {
  final UpdateInfo info;

  const UpdateDialog({super.key, required this.info});

  static Future<void> showIfNeeded(BuildContext context, UpdateInfo info) {
    return showDialog(
      context: context,
      barrierDismissible: !info.forceUpdate,
      builder: (_) => UpdateDialog(info: info),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _downloading = false;
  double _progress = 0;
  String? _error;

  Future<void> _startDownload() async {
    setState(() {
      _downloading = true;
      _error = null;
      _progress = 0;
    });

    final err = await UpdateService().downloadAndInstall(
      widget.info.downloadUrl,
      onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      },
    );

    if (mounted) {
      if (err != null) {
        setState(() {
          _downloading = false;
          _error = err;
        });
      }
      // Si no hay error el instalador del sistema ya tomó control, no hacemos nada
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.info.forceUpdate && !_downloading,
      child: AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.system_update, color: AppTheme.primary, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Nueva versión disponible',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
          ),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('v${widget.info.latestVersion}',
                  style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ),
            const SizedBox(height: 14),
            const Text('Novedades:',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
            const SizedBox(height: 6),
            Text(widget.info.changelog,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),

            if (widget.info.forceUpdate) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.bearish.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.bearish.withValues(alpha: 0.3)),
                ),
                child: const Row(children: [
                  Icon(Icons.warning_amber_rounded, color: AppTheme.bearish, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Esta actualización es obligatoria.',
                        style: TextStyle(color: AppTheme.bearish, fontSize: 12)),
                  ),
                ]),
              ),
            ],

            // Barra de progreso durante descarga
            if (_downloading) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Descargando...',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  Text('${(_progress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                          color: AppTheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: AppTheme.cardBorder,
                  valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'La app se instalará automáticamente al terminar.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
              ),
            ],

            // Error
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.bearish.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_error!,
                    style: const TextStyle(color: AppTheme.bearish, fontSize: 12)),
              ),
            ],
          ],
        ),
        actions: [
          if (!widget.info.forceUpdate && !_downloading)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Ahora no',
                  style: TextStyle(color: AppTheme.textSecondary)),
            ),
          if (!_downloading)
            ElevatedButton.icon(
              onPressed: _startDownload,
              icon: const Icon(Icons.download, size: 16),
              label: Text(_error != null ? 'Reintentar' : 'Actualizar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
        ],
      ),
    );
  }
}
