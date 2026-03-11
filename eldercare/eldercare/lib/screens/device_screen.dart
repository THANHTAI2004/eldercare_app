import 'package:flutter/material.dart';
import '../config/config.dart';
import '../models/device_model.dart';
import '../services/api_service.dart';

/// Device management screen
class DeviceScreen extends StatefulWidget {
  const DeviceScreen({super.key});

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  final ApiService _apiService = ApiService();
  final List<DeviceModel> _devices = [];
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Quản lý thiết bị',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _devices.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _devices.length,
              itemBuilder: (context, index) {
                return _buildDeviceCard(_devices[index]);
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDeviceDialog,
        icon: const Icon(Icons.add),
        label: const Text('Thêm thiết bị'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.devices_other, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 20),
          Text(
            'Chưa có thiết bị nào',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Nhấn nút bên dưới để thêm thiết bị',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(DeviceModel device) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Device icon
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: device.isChestDevice
                    ? Colors.blue.shade50
                    : Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                device.isChestDevice ? Icons.monitor_heart : Icons.watch,
                size: 32,
                color: device.isChestDevice ? Colors.blue : Colors.green,
              ),
            ),
            const SizedBox(width: 16),

            // Device info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.deviceUid,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    device.isChestDevice ? 'Thiết bị ngực' : 'Thiết bị cổ tay',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Battery
                      if (device.batteryLevel != null) ...[
                        Icon(
                          Icons.battery_std,
                          size: 16,
                          color: _getBatteryColor(device.batteryLevel!),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${device.batteryLevel}%',
                          style: TextStyle(
                            fontSize: 12,
                            color: _getBatteryColor(device.batteryLevel!),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],

                      // Connection status
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: device.isOnline ? Colors.green : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        device.isOnline ? 'Đang kết nối' : 'Ngoại tuyến',
                        style: TextStyle(
                          fontSize: 12,
                          color: device.isOnline ? Colors.green : Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // More options
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () => _showDeviceOptions(device),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddDeviceDialog() {
    final deviceIdController = TextEditingController();
    String selectedType = 'chest';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thêm thiết bị mới'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: deviceIdController,
                decoration: const InputDecoration(
                  labelText: 'ID thiết bị',
                  hintText: 'Ví dụ: chest001',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Loại thiết bị:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Ngực'),
                      value: 'chest',
                      groupValue: selectedType,
                      onChanged: (value) {
                        setState(() {
                          selectedType = value!;
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Cổ tay'),
                      value: 'wrist',
                      groupValue: selectedType,
                      onChanged: (value) {
                        setState(() {
                          selectedType = value!;
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () async {
              if (deviceIdController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Vui lòng nhập ID thiết bị')),
                );
                return;
              }

              Navigator.pop(context);
              await _registerDevice(deviceIdController.text, selectedType);
            },
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
  }

  Future<void> _registerDevice(String deviceId, String deviceType) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final device = await _apiService.registerDevice(
        deviceUid: deviceId,
        deviceType: deviceType,
        userId: 'patient001', // Optional, keeping for reference
      );

      if (mounted) {
        setState(() {
          _devices.add(device);
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã thêm thiết bị $deviceId'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showDeviceOptions(DeviceModel device) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Thông tin chi tiết'),
              onTap: () {
                Navigator.pop(context);
                _showDeviceDetails(device);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text(
                'Xóa thiết bị',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                _removeDevice(device);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeviceDetails(DeviceModel device) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(device.deviceUid),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Loại', device.deviceType),
            if (device.userId != null)
              _buildDetailRow('User ID', device.userId!),
            if (device.firmwareVersion != null)
              _buildDetailRow('Firmware', device.firmwareVersion!),
            if (device.macAddress != null)
              _buildDetailRow('MAC Address', device.macAddress!),
            if (device.lastSeen != null)
              _buildDetailRow(
                'Lần cuối',
                '${device.lastSeen!.day}/${device.lastSeen!.month}/${device.lastSeen!.year}',
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$label:', style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(value),
        ],
      ),
    );
  }

  void _removeDevice(DeviceModel device) {
    setState(() {
      _devices.remove(device);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã xóa thiết bị ${device.deviceUid}')),
    );
  }

  Color _getBatteryColor(int level) {
    if (level > 50) return Colors.green;
    if (level > 20) return Colors.orange;
    return Colors.red;
  }

  @override
  void dispose() {
    _apiService.dispose();
    super.dispose();
  }
}
