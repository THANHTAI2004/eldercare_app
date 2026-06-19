import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:eldercare_app/src/app/routes.dart';
import 'package:eldercare_app/src/core/app_strings.dart';
import 'package:eldercare_app/src/core/validators.dart';
import 'package:eldercare_app/src/state/session_provider.dart';
import 'package:eldercare_app/src/ui/app_colors.dart';
import 'package:eldercare_app/src/ui/app_spacing.dart';
import 'package:eldercare_app/src/ui/components/app_button.dart';
import 'package:eldercare_app/src/ui/components/app_card.dart';
import 'package:eldercare_app/src/ui/components/app_text_field.dart';
import 'package:eldercare_app/src/ui/components/status_badge.dart';
import 'package:eldercare_app/src/widgets/app_logo.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _phoneFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      if (AppValidators.validatePhoneNumber(_phoneCtrl.text) != null) {
        _phoneFocusNode.requestFocus();
      } else {
        _passwordFocusNode.requestFocus();
      }
      return;
    }

    await context.read<SessionProvider>().login(
      phoneNumber: AppValidators.normalizePhoneNumber(_phoneCtrl.text),
      password: _passwordCtrl.text,
    );
  }

  Future<void> _openRegister() async {
    final result = await Navigator.pushNamed(context, AppRoutes.register);
    if (!mounted || result is! String || result.trim().isEmpty) return;
    _phoneCtrl.text = result.trim();
    _passwordCtrl.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tạo tài khoản thành công. Vui lòng đăng nhập.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final wide = MediaQuery.sizeOf(context).width >= 980;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF6FAFF),
              Color(0xFFEAF3FF),
              Color(0xFFF7FAFC),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: wide
                    ? Row(
                        children: [
                          Expanded(child: _LoginHeroPanel()),
                          const SizedBox(width: AppSpacing.section),
                          Expanded(
                            child: _LoginFormCard(
                              formKey: _formKey,
                              phoneCtrl: _phoneCtrl,
                              passwordCtrl: _passwordCtrl,
                              phoneFocusNode: _phoneFocusNode,
                              passwordFocusNode: _passwordFocusNode,
                              obscurePassword: _obscurePassword,
                              isSubmitting: session.isAuthenticating,
                              errorMessage: session.error,
                              onTogglePassword: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                              onSubmit: _submit,
                              onOpenRegister: _openRegister,
                            ),
                          ),
                        ],
                      )
                    : SingleChildScrollView(
                        child: Column(
                          children: [
                            const _CompactBrandHeader(),
                            const SizedBox(height: AppSpacing.xxl),
                            _LoginFormCard(
                              formKey: _formKey,
                              phoneCtrl: _phoneCtrl,
                              passwordCtrl: _passwordCtrl,
                              phoneFocusNode: _phoneFocusNode,
                              passwordFocusNode: _passwordFocusNode,
                              obscurePassword: _obscurePassword,
                              isSubmitting: session.isAuthenticating,
                              errorMessage: session.error,
                              onTogglePassword: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                              onSubmit: _submit,
                              onOpenRegister: _openRegister,
                            ),
                          ],
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

class _LoginHeroPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            const AppLogo(size: 76),
            const SizedBox(width: AppSpacing.lg),
            Text(
              'Eldercare',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Chăm sóc người thân rõ ràng hơn,\ndễ dùng hơn mỗi ngày.',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.section),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: const [
            StatusBadge(
              label: 'Theo dõi realtime',
              tone: StatusTone.info,
              icon: Icons.monitor_heart_outlined,
            ),
            StatusBadge(
              label: 'Cảnh báo kịp thời',
              tone: StatusTone.warning,
              icon: Icons.notifications_active_outlined,
            ),
            StatusBadge(
              label: 'Dễ dùng cho người lớn tuổi',
              tone: StatusTone.success,
              icon: Icons.favorite_outline_rounded,
            ),
          ],
        ),
      ],
    );
  }
}

class _CompactBrandHeader extends StatelessWidget {
  const _CompactBrandHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const AppLogo(size: 72),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Eldercare',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}

class _LoginFormCard extends StatelessWidget {
  const _LoginFormCard({
    required this.formKey,
    required this.phoneCtrl,
    required this.passwordCtrl,
    required this.phoneFocusNode,
    required this.passwordFocusNode,
    required this.obscurePassword,
    required this.isSubmitting,
    required this.errorMessage,
    required this.onTogglePassword,
    required this.onSubmit,
    required this.onOpenRegister,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController phoneCtrl;
  final TextEditingController passwordCtrl;
  final FocusNode phoneFocusNode;
  final FocusNode passwordFocusNode;
  final bool obscurePassword;
  final bool isSubmitting;
  final String? errorMessage;
  final VoidCallback onTogglePassword;
  final Future<void> Function() onSubmit;
  final Future<void> Function() onOpenRegister;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: AppCard(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Chào mừng trở lại',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  AppTextField(
                    controller: phoneCtrl,
                    focusNode: phoneFocusNode,
                    label: 'Số điện thoại',
                    hint: 'Nhập số điện thoại',
                    prefix: const _PhonePrefix(),
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    validator: AppValidators.validatePhoneNumber,
                    autofillHints: const [AutofillHints.telephoneNumber],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    controller: passwordCtrl,
                    focusNode: passwordFocusNode,
                    label: 'Mật khẩu',
                    hint: 'Nhập mật khẩu',
                    obscureText: obscurePassword,
                    textInputAction: TextInputAction.done,
                    validator: (value) {
                      if ((value ?? '').isEmpty) {
                        return AppStrings.loginPasswordRequired;
                      }
                      return null;
                    },
                    autofillHints: const [AutofillHints.password],
                    prefix: const Icon(Icons.lock_outline_rounded),
                    suffix: IconButton(
                      onPressed: onTogglePassword,
                      tooltip: obscurePassword ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                    onFieldSubmitted: (_) => onSubmit(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: null,
                      child: const Text('Quên mật khẩu?'),
                    ),
                  ),
                  if (errorMessage != null && errorMessage!.trim().isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    _InlineBanner(message: errorMessage!),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  SizedBox(
                    width: double.infinity,
                    child: PrimaryButton(
                      label: isSubmitting ? 'Đang đăng nhập...' : 'Đăng nhập',
                      onPressed: onSubmit,
                      isLoading: isSubmitting,
                      icon: const Icon(Icons.login_rounded),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'hoặc',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Center(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Chưa có tài khoản? ',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        TextButton(
                          onPressed: isSubmitting ? null : onOpenRegister,
                          child: const Text('Đăng ký'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PhonePrefix extends StatelessWidget {
  const _PhonePrefix();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 18,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: const Color(0xFFDA251D),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.star, size: 10, color: Color(0xFFFFD54F)),
          ),
          const SizedBox(width: 8),
          Text('+84', style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
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
