import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:eldercare_app/src/core/app_strings.dart';
import 'package:eldercare_app/src/core/validators.dart';
import 'package:eldercare_app/src/state/session_provider.dart';
import 'package:eldercare_app/src/ui/app_spacing.dart';
import 'package:eldercare_app/src/ui/components/app_button.dart';
import 'package:eldercare_app/src/ui/components/app_card.dart';
import 'package:eldercare_app/src/ui/components/app_text_field.dart';
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
    if (_selectedDate == null) {
      setState(() {
        _dateErrorText = AppStrings.registerPickBirthDate;
      });
      return;
    }

    final normalizedPhone = AppValidators.normalizePhoneNumber(_phoneCtrl.text);
    final ok = await context.read<SessionProvider>().register(
      name: _nameCtrl.text.trim(),
      phoneNumber: normalizedPhone,
      dateOfBirth: DateFormat('yyyy-MM-dd').format(_selectedDate!),
      password: _passwordCtrl.text,
    );
    if (!mounted || !ok) return;
    Navigator.pop(context, normalizedPhone);
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final dateText = _selectedDate == null
        ? 'Chọn ngày sinh'
        : DateFormat('dd/MM/yyyy').format(_selectedDate!);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF6FAFF), Color(0xFFF7FAFC)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: AppCard(
                  padding: const EdgeInsets.all(28),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: session.isRegistering
                                  ? null
                                  : () => Navigator.pop(context),
                              icon: const Icon(Icons.arrow_back_rounded),
                            ),
                            const Expanded(
                              child: AppBrandLockup(
                                center: false,
                                logoSize: 48,
                                subtitle:
                                    'Tạo tài khoản mới trong vài bước để bắt đầu theo dõi người thân.',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        Text(
                          'Tạo tài khoản',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Vui lòng cung cấp thông tin để đăng ký tài khoản Eldercare.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        AppTextField(
                          controller: _nameCtrl,
                          label: 'Họ và tên',
                          hint: 'Nhập họ và tên',
                          prefix: const Icon(Icons.person_outline_rounded),
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.name],
                          enabled: !session.isRegistering,
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) {
                              return 'Nhập họ và tên';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AppTextField(
                          controller: _phoneCtrl,
                          label: 'Số điện thoại',
                          hint: 'Nhập số điện thoại',
                          prefix: const Icon(Icons.call_outlined),
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.telephoneNumber],
                          enabled: !session.isRegistering,
                          validator: AppValidators.validatePhoneNumber,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _DateField(
                          label: 'Ngày sinh',
                          dateText: dateText,
                          errorText: _dateErrorText,
                          onTap: session.isRegistering ? null : _pickDate,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AppTextField(
                          controller: _passwordCtrl,
                          label: 'Mật khẩu',
                          hint: 'Nhập mật khẩu',
                          prefix: const Icon(Icons.lock_outline_rounded),
                          suffix: IconButton(
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.newPassword],
                          enabled: !session.isRegistering,
                          validator: AppValidators.validatePassword,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AppTextField(
                          controller: _confirmPasswordCtrl,
                          label: 'Nhập lại mật khẩu',
                          hint: 'Nhập lại mật khẩu',
                          prefix: const Icon(Icons.lock_reset_outlined),
                          suffix: IconButton(
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword;
                              });
                            },
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                          obscureText: _obscureConfirmPassword,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.newPassword],
                          enabled: !session.isRegistering,
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
                          const SizedBox(height: AppSpacing.lg),
                          _InlineBanner(message: session.error!),
                        ],
                        const SizedBox(height: AppSpacing.xxl),
                        SizedBox(
                          width: double.infinity,
                          child: PrimaryButton(
                            label: session.isRegistering
                                ? 'Đang tạo tài khoản...'
                                : 'Tạo tài khoản',
                            onPressed: _submit,
                            isLoading: session.isRegistering,
                            icon: const Icon(Icons.person_add_alt_1_rounded),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Center(
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
          ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.dateText,
    required this.errorText,
    required this.onTap,
  });

  final String label;
  final String dateText;
  final String? errorText;
  final FutureOr<void> Function()? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onTap == null ? null : () => onTap!.call(),
          borderRadius: BorderRadius.circular(18),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              prefixIcon: const Icon(Icons.calendar_month_outlined),
              suffixIcon: TextButton(
                onPressed: onTap == null ? null : () => onTap!.call(),
                child: const Text('Chọn ngày'),
              ),
            ),
            child: Text(
              dateText,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              errorText!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _InlineBanner extends StatelessWidget {
  const _InlineBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
      ),
    );
  }
}
