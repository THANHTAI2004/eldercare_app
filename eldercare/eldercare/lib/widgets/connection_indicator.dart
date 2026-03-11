import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';

/// Connection status indicator widget
class ConnectionIndicator extends StatelessWidget {
  final bool isApiConnected;
  final MqttConnectionState? mqttState;

  const ConnectionIndicator({
    super.key,
    required this.isApiConnected,
    this.mqttState,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // API indicator
          _buildIndicator(
            icon: Icons.cloud,
            label: 'API',
            isConnected: isApiConnected,
          ),
          const SizedBox(width: 12),
          Container(width: 1, height: 20, color: Colors.grey[300]),
          const SizedBox(width: 12),
          // MQTT indicator
          _buildIndicator(
            icon: Icons.wifi,
            label: 'MQTT',
            isConnected: mqttState == MqttConnectionState.connected,
          ),
        ],
      ),
    );
  }

  Widget _buildIndicator({
    required IconData icon,
    required String label,
    required bool isConnected,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Animated pulse dot
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isConnected ? Colors.green : Colors.red,
            boxShadow: isConnected
                ? [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.5),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(width: 6),
        Icon(icon, size: 16, color: isConnected ? Colors.green : Colors.grey),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isConnected ? Colors.green : Colors.grey,
          ),
        ),
      ],
    );
  }
}
