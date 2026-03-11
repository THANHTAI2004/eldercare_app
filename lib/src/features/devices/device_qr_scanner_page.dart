import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class DeviceQrScannerPage extends StatefulWidget {
  const DeviceQrScannerPage({super.key});

  @override
  State<DeviceQrScannerPage> createState() => _DeviceQrScannerPageState();
}

class _DeviceQrScannerPageState extends State<DeviceQrScannerPage> {
  bool _handled = false;

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
      appBar: AppBar(
        title: const Text('Quét mã QR thiết bị'),
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: _onDetect,   // <-- chỉ giữ dòng này
          ),
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
                'Đưa mã QR của thiết bị (ESP – chứa userId) vào khung camera.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: scheme.onPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

