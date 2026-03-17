import 'package:flutter/material.dart';

import 'package:eldercare_app/src/data/api/api_client.dart';
import 'package:eldercare_app/src/data/api/device_api_service.dart';
import 'package:eldercare_app/src/domain/models/device.dart';

class DeviceCaregiversPage extends StatefulWidget {
  const DeviceCaregiversPage({
    super.key,
    required this.device,
    DeviceApiService? api,
  }) : _api = api;

  final Device device;
  final DeviceApiService? _api;

  @override
  State<DeviceCaregiversPage> createState() => _DeviceCaregiversPageState();
}

class _DeviceCaregiversPageState extends State<DeviceCaregiversPage> {
  final _formKey = GlobalKey<FormState>();
  final _identifierCtrl = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  List<DeviceLinkedUser> _linkedUsers = const <DeviceLinkedUser>[];

  DeviceApiService get _api => widget._api ?? DeviceApiService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUsers();
    });
  }

  @override
  void dispose() {
    _identifierCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final users = await _api.getLinkedUsers(
        deviceId: widget.device.resolvedDeviceId,
      );
      if (!mounted) return;
      setState(() {
        _linkedUsers = users;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _friendlyError(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _addCaregiver() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final identifier = _identifierCtrl.text.trim();
    final phoneNumber = _looksLikePhoneNumber(identifier) ? identifier : null;
    final userId = phoneNumber == null ? identifier : null;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await _api.addCaregiver(
        deviceId: widget.device.resolvedDeviceId,
        userId: userId,
        phoneNumber: phoneNumber,
      );
      _identifierCtrl.clear();
      await _loadUsers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Da them nguoi cham soc vao thiet bi.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _friendlyError(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _removeCaregiver(DeviceLinkedUser user) async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await _api.removeCaregiver(
        deviceId: widget.device.resolvedDeviceId,
        userId: user.id,
      );
      await _loadUsers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Da go nguoi cham soc ${user.displayName}.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _friendlyError(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  bool _looksLikePhoneNumber(String value) {
    final normalized = value.replaceAll(RegExp(r'\s+'), '');
    return RegExp(r'^(0|\+84)[0-9]{9,10}$').hasMatch(normalized);
  }

  bool _isCaregiverLink(DeviceLinkedUser user) {
    final role = user.role?.trim().toLowerCase() ?? '';
    final linkRole = user.linkRole?.trim().toLowerCase() ?? '';
    return role == 'caregiver' || linkRole == 'caregiver';
  }

  String _friendlyError(Object e) {
    if (e is ApiRequestException) {
      if (e.statusCode == 404) {
        return 'Khong tim thay tai khoan nguoi cham soc can them.';
      }
      if (e.statusCode == 409) {
        return 'Tai khoan nay da duoc them vao thiet bi.';
      }
      if (e.statusCode == 403) {
        return 'Tai khoan hien tai khong co quyen quan ly nguoi cham soc.';
      }
      return e.message;
    }
    return 'Khong the cap nhat danh sach nguoi cham soc.';
  }

  @override
  Widget build(BuildContext context) {
    final caregivers = _linkedUsers
        .where(_isCaregiverLink)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Nguoi cham soc cua thiet bi')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.device.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text('Ma thiet bi: ${widget.device.resolvedDeviceId}'),
                  if (widget.device.primaryUserId != null)
                    Text('Nguoi quan ly: ${widget.device.primaryUserId}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Them nguoi cham soc',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Nhap user_id hoac so dien thoai cua nguoi cham soc de cap quyen xem du lieu thiet bi.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _identifierCtrl,
                      enabled: !_isSubmitting,
                      decoration: const InputDecoration(
                        labelText: 'User ID hoac so dien thoai',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Nhap user_id hoac so dien thoai';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _addCaregiver(),
                    ),
                    if (_errorMessage != null &&
                        _errorMessage!.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _InlineError(message: _errorMessage!),
                    ],
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _isSubmitting ? null : _addCaregiver,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.person_add_alt_1),
                      label: Text(
                        _isSubmitting
                            ? 'Dang cap nhat...'
                            : 'Them nguoi cham soc',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (caregivers.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Chua co nguoi cham soc nao duoc them vao thiet bi nay.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ...caregivers.map(
              (user) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: ListTile(
                    title: Text(user.displayName),
                    subtitle: Text(_caregiverSubtitle(user)),
                    trailing: IconButton(
                      tooltip: 'Xoa nguoi cham soc',
                      onPressed: _isSubmitting
                          ? null
                          : () => _removeCaregiver(user),
                      icon: const Icon(Icons.person_remove_outlined),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _caregiverSubtitle(DeviceLinkedUser user) {
    final segments = <String>[];
    if ((user.phoneNumber ?? '').trim().isNotEmpty) {
      segments.add(user.phoneNumber!.trim());
    }
    if ((user.linkRole ?? '').trim().isNotEmpty) {
      segments.add('Lien ket: ${user.linkRole}');
    }
    return segments.isEmpty ? user.id : segments.join(' | ');
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: scheme.onErrorContainer),
      ),
    );
  }
}
