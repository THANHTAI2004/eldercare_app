import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:eldercare_app/src/core/app_strings.dart';
import 'package:eldercare_app/src/core/validators.dart';
import 'package:eldercare_app/src/state/session_provider.dart';
import 'package:eldercare_app/src/widgets/app_logo.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  DateTime? _selectedDate;
  String? _dateErrorText;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _selectedDate ?? DateTime(now.year - 60, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() {
      _selectedDate = DateTime(picked.year, picked.month, picked.day);
      _dateErrorText = null;
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final selectedDate = _selectedDate;
    if (selectedDate == null) {
      setState(() {
        _dateErrorText = AppStrings.registerPickBirthDate;
      });
      return;
    }

    final session = context.read<SessionProvider>();
    final normalizedPhoneNumber = AppValidators.normalizePhoneNumber(
      _phoneCtrl.text,
    );
    final ok = await session.register(
      name: _nameCtrl.text.trim(),
      phoneNumber: normalizedPhoneNumber,
      dateOfBirth: DateFormat('yyyy-MM-dd').format(selectedDate),
      password: _passwordCtrl.text,
    );
    if (!mounted || !ok) return;

    Navigator.pop(context, normalizedPhoneNumber);
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final dateText = _selectedDate == null
        ? 'Chọn ngày sinh'
        : DateFormat('dd/MM/yyyy').format(_selectedDate!);

    return Scaffold(
      appBar: AppBar(title: const Text('Đăng ký')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Center(
                            child: AppBrandLockup(
                              logoSize: 76,
                              subtitle:
                                  'Tạo tài khoản để bắt đầu liên kết thiết bị và theo dõi sức khỏe từ xa.',
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Tạo tài khoản mới',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Nhập thông tin cơ bản để tạo tài khoản, sau đó quay lại đăng nhập bằng số điện thoại và mật khẩu vừa tạo.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _nameCtrl,
                            enabled: !session.isRegistering,
                            textInputAction: TextInputAction.next,
                            autofillHints: const <String>[AutofillHints.name],
                            decoration: const InputDecoration(
                              labelText: 'Họ và tên',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Nhập họ và tên';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _phoneCtrl,
                            enabled: !session.isRegistering,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            autofillHints: const <String>[
                              AutofillHints.telephoneNumber,
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Số điện thoại',
                            ),
                            validator: AppValidators.validatePhoneNumber,
                          ),
                          const SizedBox(height: 12),
                          InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Ngày sinh',
                              errorText: _dateErrorText,
                            ),
                            child: Row(
                              children: [
                                Expanded(child: Text(dateText)),
                                TextButton(
                                  onPressed: session.isRegistering
                                      ? null
                                      : _pickDate,
                                  child: const Text('Chọn ngày'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _passwordCtrl,
                            enabled: !session.isRegistering,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.next,
                            autofillHints: const <String>[
                              AutofillHints.newPassword,
                            ],
                            decoration: InputDecoration(
                              labelText: 'Mật khẩu',
                              suffixIcon: IconButton(
                                tooltip: _obscurePassword
                                    ? 'Hiện mật khẩu'
                                    : 'Ẩn mật khẩu',
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                              ),
                            ),
                            validator: (value) {
                              return AppValidators.validatePassword(value);
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _confirmPasswordCtrl,
                            enabled: !session.isRegistering,
                            obscureText: _obscureConfirmPassword,
                            autofillHints: const <String>[
                              AutofillHints.newPassword,
                            ],
                            decoration: InputDecoration(
                              labelText: 'Nhập lại mật khẩu',
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
                                return 'Nhập lại mật khẩu';
                              }
                              if (value != _passwordCtrl.text) {
                                return 'Mật khẩu nhập lại không khớp';
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) => _submit(),
                          ),
                          if (session.error != null &&
                              session.error!.trim().isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _InlineBanner(message: session.error!),
                          ],
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed: session.isRegistering ? null : _submit,
                            icon: session.isRegistering
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.person_add_alt_1),
                            label: Text(
                              session.isRegistering
                                  ? 'Đang tạo tài khoản...'
                                  : 'Tạo tài khoản',
                            ),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: session.isRegistering
                                  ? null
                                  : () => Navigator.pop(context),
                              child: const Text('Đã có tài khoản? Đăng nhập'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineBanner extends StatelessWidget {
  const _InlineBanner({required this.message});

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
