import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:eldercare_app/src/core/app_date_utils.dart';
import 'package:eldercare_app/src/core/validators.dart';
import 'package:eldercare_app/src/services/push_notification_service.dart';
import 'package:eldercare_app/src/state/device_provider.dart';
import 'package:eldercare_app/src/state/session_provider.dart';
import 'package:eldercare_app/src/ui/app_spacing.dart';
import 'package:eldercare_app/src/ui/components/app_button.dart';
import 'package:eldercare_app/src/ui/components/app_card.dart';
import 'package:eldercare_app/src/ui/components/app_scaffold.dart';
import 'package:eldercare_app/src/ui/components/app_text_field.dart';
import 'package:eldercare_app/src/ui/components/status_badge.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  Future<void> _logout(BuildContext context) async {
    final push = context.read<PushNotificationService?>();
    final session = context.read<SessionProvider>();
    final deviceProvider = context.read<DeviceProvider>();
    await push?.unregisterCurrentInstallation();
    await session.logout();
    await deviceProvider.clear();
  }

  Future<void> _openEditProfile(BuildContext context) async {
    final session = context.read<SessionProvider>();
    final nameCtrl = TextEditingController(text: session.currentUser?.name ?? '');
    DateTime? selectedDate = _parseDate(session.currentUser?.dateOfBirth);
    final formKey = GlobalKey<FormState>();
    String? dateError;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Thông tin cá nhân'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppTextField(
                    controller: nameCtrl,
                    label: 'Họ và tên',
                    prefix: const Icon(Icons.person_outline_rounded),
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Nhập họ và tên';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _DatePickerField(
                    date: selectedDate,
                    errorText: dateError,
                    onTap: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate ??
                            DateTime(now.year - 60, now.month, now.day),
                        firstDate: DateTime(1900),
                        lastDate: now,
                      );
                      if (picked == null) return;
                      setState(() {
                        selectedDate = DateTime(picked.year, picked.month, picked.day);
                        dateError = null;
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Huỷ'),
              ),
              FilledButton(
                onPressed: () async {
                  if (!(formKey.currentState?.validate() ?? false)) return;
                  if (selectedDate == null) {
                    setState(() {
                      dateError = 'Vui lòng chọn ngày sinh';
                    });
                    return;
                  }
                  final ok = await session.updateProfile(
                    name: nameCtrl.text.trim(),
                    dateOfBirth:
                        '${selectedDate!.year.toString().padLeft(4, '0')}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}',
                  );
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        ok
                            ? 'Đã cập nhật thông tin cá nhân.'
                            : (session.error ?? 'Không thể cập nhật hồ sơ'),
                      ),
                    ),
                  );
                },
                child: const Text('Lưu'),
              ),
            ],
          ),
        );
      },
    );

    nameCtrl.dispose();
  }

  Future<void> _openChangePassword(BuildContext context) async {
    final session = context.read<SessionProvider>();
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Đổi mật khẩu'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppTextField(
                    controller: currentCtrl,
                    label: 'Mật khẩu hiện tại',
                    obscureText: obscureCurrent,
                    prefix: const Icon(Icons.lock_outline_rounded),
                    suffix: IconButton(
                      onPressed: () {
                        setState(() {
                          obscureCurrent = !obscureCurrent;
                        });
                      },
                      icon: Icon(
                        obscureCurrent
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                    validator: (value) {
                      if ((value ?? '').isEmpty) {
                        return 'Nhập mật khẩu hiện tại';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    controller: newCtrl,
                    label: 'Mật khẩu mới',
                    obscureText: obscureNew,
                    prefix: const Icon(Icons.password_outlined),
                    suffix: IconButton(
                      onPressed: () {
                        setState(() {
                          obscureNew = !obscureNew;
                        });
                      },
                      icon: Icon(
                        obscureNew
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                    validator: AppValidators.validatePassword,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    controller: confirmCtrl,
                    label: 'Nhập lại mật khẩu mới',
                    obscureText: obscureConfirm,
                    prefix: const Icon(Icons.lock_reset_outlined),
                    suffix: IconButton(
                      onPressed: () {
                        setState(() {
                          obscureConfirm = !obscureConfirm;
                        });
                      },
                      icon: Icon(
                        obscureConfirm
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                    validator: (value) {
                      if ((value ?? '').isEmpty) {
                        return 'Nhập lại mật khẩu mới';
                      }
                      if (value != newCtrl.text) {
                        return 'Mật khẩu nhập lại không khớp';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Huỷ'),
              ),
              FilledButton(
                onPressed: () async {
                  if (!(formKey.currentState?.validate() ?? false)) return;
                  final ok = await session.changePassword(
                    currentPassword: currentCtrl.text,
                    newPassword: newCtrl.text,
                  );
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        ok
                            ? 'Đổi mật khẩu thành công.'
                            : (session.error ?? 'Không thể đổi mật khẩu'),
                      ),
                    ),
                  );
                },
                child: const Text('Cập nhật'),
              ),
            ],
          ),
        );
      },
    );

    currentCtrl.dispose();
    newCtrl.dispose();
    confirmCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final push = context.watch<PushNotificationService?>();
    final user = session.currentUser;
    final initials = (user?.name.trim().isNotEmpty ?? false)
        ? user!.name
            .trim()
            .split(RegExp(r'\s+'))
            .take(2)
            .map((part) => part[0].toUpperCase())
            .join()
        : 'EC';

    return AppScaffold(
      title: 'Tài khoản',
      subtitle: 'Quản lý hồ sơ, bảo mật và thông báo cho phiên hiện tại.',
      child: ListView(
        children: [
          AppCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 34,
                  child: Text(initials),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name.trim().isEmpty ?? true
                            ? 'Chưa cập nhật tên'
                            : user!.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.phoneNumber ?? '--',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      const StatusBadge(
                        label: 'Phiên đang hoạt động',
                        tone: StatusTone.success,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.section),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Thông tin cá nhân', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.lg),
                _InfoRow(label: 'Họ và tên', value: user?.name ?? '--'),
                const Divider(height: 24),
                _InfoRow(label: 'Ngày sinh', value: AppDateUtils.formatDateOfBirth(user?.dateOfBirth) ?? '--'),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: SecondaryButton(
                    label: 'Sửa thông tin',
                    onPressed: () => _openEditProfile(context),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.section),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Thông báo', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Quản lý trạng thái nhận push notification trong phiên hiện tại.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                SwitchListTile.adaptive(
                  value: push?.notificationsEnabled ?? false,
                  onChanged: push == null
                      ? null
                      : (value) => push.setNotificationsEnabled(value),
                  title: const Text('Nhận thông báo'),
                  subtitle: Text(
                    push == null
                        ? 'Thiết bị hiện tại chưa hỗ trợ push notification.'
                        : 'Bật/tắt đồng bộ push token mà không thay đổi API hiện có.',
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.section),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bảo mật', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: SecondaryButton(
                    label: 'Đổi mật khẩu',
                    onPressed: () => _openChangePassword(context),
                    icon: const Icon(Icons.lock_reset_outlined),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.section),
          DangerButton(
            label: 'Đăng xuất',
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        const SizedBox(width: AppSpacing.md),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
      ],
    );
  }
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.date,
    required this.errorText,
    required this.onTap,
  });

  final DateTime? date;
  final String? errorText;
  final FutureOr<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => onTap.call(),
          borderRadius: BorderRadius.circular(18),
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Ngày sinh',
              prefixIcon: Icon(Icons.calendar_month_outlined),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    date == null
                        ? 'Chọn ngày sinh'
                        : '${date!.day.toString().padLeft(2, '0')}/${date!.month.toString().padLeft(2, '0')}/${date!.year}',
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () => onTap.call(),
                  child: const Text('Chọn ngày'),
                ),
              ],
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              errorText!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

DateTime? _parseDate(String? raw) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty) return null;
  return DateTime.tryParse(value);
}
