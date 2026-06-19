import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:eldercare_app/src/core/device_access_labels.dart';
import 'package:eldercare_app/src/data/api/api_client.dart';
import 'package:eldercare_app/src/data/api/device_api_service.dart';
import 'package:eldercare_app/src/domain/models/device.dart';
import 'package:eldercare_app/src/ui/app_spacing.dart';
import 'package:eldercare_app/src/ui/components/app_button.dart';
import 'package:eldercare_app/src/ui/components/app_card.dart';
import 'package:eldercare_app/src/ui/components/app_scaffold.dart';
import 'package:eldercare_app/src/ui/components/app_text_field.dart';
import 'package:eldercare_app/src/ui/components/empty_state.dart';
import 'package:eldercare_app/src/ui/components/loading_state.dart';
import 'package:eldercare_app/src/ui/components/status_badge.dart';

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
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _friendlyError(error);
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
    if (!_canManageViewers || !(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await _resolvedApi.addViewer(
        deviceId: widget.device.resolvedDeviceId,
        userId: _userIdCtrl.text.trim(),
      );
      _userIdCtrl.clear();
      await _loadUsers();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _friendlyError(error);
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
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _friendlyError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String _friendlyError(Object error) {
    if (error is ApiRequestException) {
      switch (error.statusCode) {
        case 403:
          return 'Tài khoản hiện tại không phải chủ thiết bị này.';
        case 404:
          return 'Không tìm thấy thiết bị hoặc tài khoản cần thêm.';
        case 409:
          return 'Tài khoản này đã được thêm vào thiết bị.';
        case 422:
          return 'Dữ liệu gửi lên không đúng định dạng máy chủ yêu cầu.';
      }
      return error.message;
    }
    return 'Không thể cập nhật danh sách người xem.';
  }

  @override
  Widget build(BuildContext context) {
    final viewers = _linkedUsers.where((user) => user.isViewerLink).toList();

    return AppScaffold(
      title: 'Quản lý người xem',
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      child: ListView(
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.device.name, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                Text(widget.device.resolvedDeviceId),
                const SizedBox(height: AppSpacing.md),
                StatusBadge(
                  label: deviceAccessRoleLabel(widget.device.normalizedLinkRole),
                  tone: widget.device.isOwnerLink
                      ? StatusTone.info
                      : StatusTone.neutral,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.section),
          if (!_canManageViewers)
            const EmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'Bạn không có quyền quản lý người xem',
              message:
                  'Chỉ chủ thiết bị mới có thể thêm hoặc xoá người xem cho thiết bị này.',
            )
          else ...[
            AppCard(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Thêm người xem', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Nhập User ID hoặc mã tài khoản của người cần được chia sẻ quyền xem.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: _userIdCtrl,
                            label: 'User ID / Mã tài khoản',
                            prefix: const Icon(Icons.person_add_alt_rounded),
                            enabled: !_isSubmitting,
                            validator: (value) {
                              if ((value ?? '').trim().isEmpty) {
                                return 'Nhập User ID';
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) => _addViewer(),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        SizedBox(
                          width: 112,
                          child: PrimaryButton(
                            label: 'Thêm',
                            onPressed: _addViewer,
                            isLoading: _isSubmitting,
                          ),
                        ),
                      ],
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        _errorMessage!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.section),
            if (_isLoading)
              const LoadingState(message: 'Đang tải danh sách người xem...')
            else if (viewers.isEmpty)
              const EmptyState(
                icon: Icons.group_outlined,
                title: 'Chưa có người xem nào',
                message: 'Thiết bị này chưa được chia sẻ cho tài khoản nào khác.',
              )
            else
              ...viewers.map(
                (user) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                  child: _ViewerCard(
                    user: user,
                    onRemove: _isSubmitting ? null : () => _removeViewer(user),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ViewerCard extends StatelessWidget {
  const _ViewerCard({
    required this.user,
    required this.onRemove,
  });

  final DeviceLinkedUser user;
  final FutureOr<void> Function()? onRemove;

  @override
  Widget build(BuildContext context) {
    final initials = user.displayName
        .split(RegExp(r'\s+'))
        .take(2)
        .map((part) => part.isEmpty ? '' : part[0].toUpperCase())
        .join();

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          CircleAvatar(child: Text(initials.isEmpty ? 'U' : initials)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.displayName, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  (user.phoneNumber ?? '').trim().isNotEmpty
                      ? user.phoneNumber!
                      : user.id,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          const StatusBadge(label: 'Người xem', tone: StatusTone.info),
          const SizedBox(width: AppSpacing.md),
          DangerButton(
            label: 'Xoá quyền',
            onPressed: onRemove,
            icon: const Icon(Icons.person_remove_outlined),
          ),
        ],
      ),
    );
  }
}
