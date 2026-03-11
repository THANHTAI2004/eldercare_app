import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class DeviceQrScannerPage extends StatefulWidget {
  const DeviceQrScannerPage({super.key});

  @override
  State<DeviceQrScannerPage> createState() => _DeviceQrScannerPageState();
}

class _DeviceQrScannerPageState extends State<DeviceQrScannerPage> {
  bool _handled = false;

  bool get _supportsScanner {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    if (capture.barcodes.isEmpty) return;

    final code = capture.barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    _handled = true;
    Navigator.pop(context, code);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Quet ma QR thiet bi')),
      body: _supportsScanner
          ? Stack(
              children: [
                MobileScanner(onDetect: _onDetect),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.7),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Text(
                      'Dua ma QR cua thiet bi vao khung camera.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onPrimary),
                    ),
                  ),
                ),
              ],
            )
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.qr_code_scanner, size: 56),
                    const SizedBox(height: 12),
                    const Text(
                      'QR scan chua duoc ho tro tren Windows.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Hay dung "Them thiet bi" de nhap thong tin thu cong.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Quay lai'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
