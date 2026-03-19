import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:eldercare_app/src/data/api/api_client.dart';
import 'package:eldercare_app/src/data/api/device_api_service.dart';
import 'package:eldercare_app/src/core/device_access_labels.dart';
import 'package:eldercare_app/src/domain/models/device.dart';

class DeviceViewersPage extends StatefulWidget {
  const DeviceViewersPage({
    super.key,
    required this.device,
    DeviceApiService? api,
  }) : _api = api;

  final Device device;
  final DeviceApiService? _api;

  @override
  State<DeviceViewersPage> createState() => _DeviceViewersPageState();
}

class _DeviceViewersPageState extends State<DeviceViewersPage> {
  final _formKey = GlobalKey<FormState>();
  final _userIdCtrl = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  List<DeviceLinkedUser> _linkedUsers = const <DeviceLinkedUser>[];
  DeviceApiService? _api;

  DeviceApiService get _resolvedApi => _api!;
  bool get _canManageViewers => widget.device.isOwnerLink;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _api ??= widget._api ?? DeviceApiService(client: context.read<ApiClient>());
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_canManageViewers) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
      _loadUsers();
    });
  }

  @override
  void dispose() {
    _userIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final users = await _resolvedApi.getLinkedUsers(
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

  Future<void> _addViewer() async {
    if (!_canManageViewers || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final userId = _userIdCtrl.text.trim();

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await _resolvedApi.addViewer(
        deviceId: widget.device.resolvedDeviceId,
        userId: userId,
      );
      _userIdCtrl.clear();
      await _loadUsers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Da them nguoi xem vao thiet bi.')),
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

  Future<void> _removeViewer(DeviceLinkedUser user) async {
    if (!_canManageViewers) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await _resolvedApi.removeViewer(
        deviceId: widget.device.resolvedDeviceId,
        userId: user.id,
      );
      await _loadUsers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Da xoa nguoi xem ${user.displayName}.')),
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

  String _friendlyError(Object e) {
    if (e is ApiRequestException) {
      if (e.statusCode == 403) {
        return 'Tai khoan hien tai khong phai chu thiet bi nay.';
      }
      if (e.statusCode == 404) {
        return 'Khong tim thay thiet bi hoac user can them.';
      }
      if (e.statusCode == 409) {
        return 'Tai khoan nay da duoc them vao thiet bi.';
      }
      if (e.statusCode == 422) {
        return 'Du lieu gui len khong dung dinh dang server yeu cau.';
      }
      return e.message;
    }
    return 'Khong the cap nhat danh sach viewer.';
  }

  @override
  Widget build(BuildContext context) {
    final viewers = _linkedUsers
        .where((user) => user.isViewerLink)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Quan ly viewer')),
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
                  Text(
                    'Quyen tren thiet bi hien tai: ${deviceAccessRoleLabel(widget.device.normalizedLinkRole)}',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (!_canManageViewers)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Chi chu thiet bi moi co the quan ly nguoi xem cua thiet bi nay.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Them nguoi xem',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Nhap user_id cua tai khoan can duoc cap quyen xem thiet bi nay.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _userIdCtrl,
                        enabled: !_isSubmitting,
                        decoration: const InputDecoration(labelText: 'user_id'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Nhap user_id';
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) => _addViewer(),
                      ),
                      if (_errorMessage != null &&
                          _errorMessage!.trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _InlineError(message: _errorMessage!),
                      ],
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _isSubmitting ? null : _addViewer,
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
                          _isSubmitting ? 'Dang cap nhat...' : 'Them nguoi xem',
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
          else if (viewers.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Chua co nguoi xem nao duoc chia se voi thiet bi nay.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ...viewers.map(
              (user) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: ListTile(
                    title: Text(user.displayName),
                    subtitle: Text(_viewerSubtitle(user)),
                    trailing: !_canManageViewers
                        ? null
                        : IconButton(
                            tooltip: 'Xoa viewer',
                            onPressed: _isSubmitting
                                ? null
                                : () => _removeViewer(user),
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

  String _viewerSubtitle(DeviceLinkedUser user) {
    final segments = <String>[];
    if ((user.phoneNumber ?? '').trim().isNotEmpty) {
      segments.add(user.phoneNumber!.trim());
    }
    if ((user.normalizedLinkRole ?? '').trim().isNotEmpty) {
      segments.add(
        'Quyen tren thiet bi nay: ${deviceAccessRoleLabel(user.normalizedLinkRole)}',
      );
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
