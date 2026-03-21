import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:eldercare_app/src/core/app_strings.dart';
import 'package:eldercare_app/src/core/validators.dart';
import 'package:eldercare_app/src/state/session_provider.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _profileFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _currentPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  DateTime? _selectedDateOfBirth;
  bool _profileInitialized = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_profileInitialized) return;

    final user = context.read<SessionProvider>().currentUser;
    _nameCtrl.text = user?.name ?? '';
    _phoneCtrl.text = user?.phoneNumber ?? '';
    _selectedDateOfBirth = _parseDate(user?.dateOfBirth);
    _profileInitialized = true;
  }

  DateTime? _parseDate(String? raw) {
    final text = raw?.trim() ?? '';
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _selectedDateOfBirth ?? DateTime(now.year - 60, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked == null) return;

    setState(() {
      _selectedDateOfBirth = DateTime(picked.year, picked.month, picked.day);
    });
  }

  Future<void> _saveProfile() async {
    if (!(_profileFormKey.currentState?.validate() ?? false)) {
      return;
    }

    final selectedDate = _selectedDateOfBirth;
    if (selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.registerPickBirthDate)),
      );
      return;
    }

    final session = context.read<SessionProvider>();
    final ok = await session.updateProfile(
      name: _nameCtrl.text.trim(),
      dateOfBirth: DateFormat('yyyy-MM-dd').format(selectedDate),
    );

    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã cập nhật thông tin tài khoản.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          session.error ?? 'Không thể cập nhật thông tin tài khoản',
        ),
      ),
    );
  }

  Future<void> _changePassword() async {
    if (!(_passwordFormKey.currentState?.validate() ?? false)) {
      return;
    }

    final session = context.read<SessionProvider>();
    final ok = await session.changePassword(
      currentPassword: _currentPasswordCtrl.text,
      newPassword: _newPasswordCtrl.text,
    );

    if (!mounted) return;
    if (ok) {
      _currentPasswordCtrl.clear();
      _newPasswordCtrl.clear();
      _confirmPasswordCtrl.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đổi mật khẩu thành công.')));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(session.error ?? 'Không thể đổi mật khẩu')),
    );
  }

  Future<void> _copyAccountCode(String accountCode) async {
    await Clipboard.setData(ClipboardData(text: accountCode));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Đã sao chép mã tài khoản.')));
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final user = session.currentUser;
    final accountCode = user?.userId.trim() ?? '';
    final dateText = _selectedDateOfBirth == null
        ? 'Chưa cập nhật'
        : DateFormat('dd/MM/yyyy').format(_selectedDateOfBirth!);

    return Scaffold(
      appBar: AppBar(title: const Text('Tài khoản')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mã tài khoản',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          accountCode.isEmpty ? 'Chưa có dữ liệu' : accountCode,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 8),
                        if (accountCode.isNotEmpty)
                          OutlinedButton.icon(
                            onPressed: () => _copyAccountCode(accountCode),
                            icon: const Icon(Icons.copy_outlined),
                            label: const Text('Sao chép mã tài khoản'),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _profileFormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Thông tin cá nhân',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _nameCtrl,
                            enabled: !session.isUpdatingProfile,
                            decoration: const InputDecoration(
                              labelText: 'Họ và tên',
                            ),
                            validator: (value) {
                              if ((value ?? '').trim().isEmpty) {
                                return 'Nhập họ và tên';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _phoneCtrl,
                            enabled: false,
                            decoration: const InputDecoration(
                              labelText: 'Số điện thoại',
                              helperText:
                                  'Số điện thoại hiện chưa hỗ trợ chỉnh sửa trên app',
                            ),
                          ),
                          const SizedBox(height: 12),
                          InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Ngày sinh',
                            ),
                            child: Row(
                              children: [
                                Expanded(child: Text(dateText)),
                                TextButton(
                                  onPressed: session.isUpdatingProfile
                                      ? null
                                      : _pickDateOfBirth,
                                  child: const Text('Chọn ngày'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: session.isUpdatingProfile
                                ? null
                                : _saveProfile,
                            icon: session.isUpdatingProfile
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: Text(
                              session.isUpdatingProfile
                                  ? 'Đang lưu...'
                                  : 'Lưu thông tin',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _passwordFormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Đổi mật khẩu',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _currentPasswordCtrl,
                            enabled: !session.isChangingPassword,
                            obscureText: _obscureCurrentPassword,
                            decoration: InputDecoration(
                              labelText: 'Mật khẩu hiện tại',
                              suffixIcon: IconButton(
                                tooltip: _obscureCurrentPassword
                                    ? 'Hiện mật khẩu'
                                    : 'Ẩn mật khẩu',
                                onPressed: () {
                                  setState(() {
                                    _obscureCurrentPassword =
                                        !_obscureCurrentPassword;
                                  });
                                },
                                icon: Icon(
                                  _obscureCurrentPassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if ((value ?? '').isEmpty) {
                                return 'Nhập mật khẩu hiện tại';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _newPasswordCtrl,
                            enabled: !session.isChangingPassword,
                            obscureText: _obscureNewPassword,
                            decoration: InputDecoration(
                              labelText: 'Mật khẩu mới',
                              suffixIcon: IconButton(
                                tooltip: _obscureNewPassword
                                    ? 'Hiện mật khẩu'
                                    : 'Ẩn mật khẩu',
                                onPressed: () {
                                  setState(() {
                                    _obscureNewPassword = !_obscureNewPassword;
                                  });
                                },
                                icon: Icon(
                                  _obscureNewPassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                              ),
                            ),
                            validator: AppValidators.validatePassword,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _confirmPasswordCtrl,
                            enabled: !session.isChangingPassword,
                            obscureText: _obscureConfirmPassword,
                            decoration: InputDecoration(
                              labelText: 'Nhập lại mật khẩu mới',
                              suffixIcon: IconButton(
                                tooltip: _obscureConfirmPassword
                                    ? 'Hiện mật khẩu'
                                    : 'Ẩn mật khẩu',
                                onPressed: () {
                                  setState(() {
                                    _obscureConfirmPassword =
                                        !_obscureConfirmPassword;
                                  });
                                },
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if ((value ?? '').isEmpty) {
                                return 'Nhập lại mật khẩu mới';
                              }
                              if (value != _newPasswordCtrl.text) {
                                return 'Mật khẩu nhập lại không khớp';
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) => _changePassword(),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: session.isChangingPassword
                                ? null
                                : _changePassword,
                            icon: session.isChangingPassword
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.lock_reset_outlined),
                            label: Text(
                              session.isChangingPassword
                                  ? 'Đang cập nhật...'
                                  : 'Đổi mật khẩu',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
