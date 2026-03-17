import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:eldercare_app/src/state/session_provider.dart';

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
      initialDate: _selectedDate ?? DateTime(now.year - 60, now.month, now.day),
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
        _dateErrorText = 'Vui long chon ngay sinh';
      });
      return;
    }

    final session = context.read<SessionProvider>();
    final ok = await session.register(
      name: _nameCtrl.text.trim(),
      phoneNumber: _phoneCtrl.text.trim(),
      dateOfBirth: DateFormat('yyyy-MM-dd').format(selectedDate),
      password: _passwordCtrl.text,
    );
    if (!mounted || !ok) return;

    Navigator.pop(context, _phoneCtrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final dateText = _selectedDate == null
        ? 'Chon ngay sinh'
        : DateFormat('dd/MM/yyyy').format(_selectedDate!);

    return Scaffold(
      appBar: AppBar(title: const Text('Dang ky')),
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
                    child: AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tao tai khoan moi',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Nhap thong tin co ban de tao tai khoan, sau do quay lai dang nhap bang so dien thoai va mat khau vua tao.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _nameCtrl,
                            textInputAction: TextInputAction.next,
                            autofillHints: const <String>[AutofillHints.name],
                            decoration: const InputDecoration(
                              labelText: 'Ho va ten',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Nhap ho va ten';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            autofillHints: const <String>[
                              AutofillHints.telephoneNumber,
                            ],
                            decoration: const InputDecoration(
                              labelText: 'So dien thoai',
                            ),
                            validator: (value) {
                              final text = value?.trim() ?? '';
                              if (text.isEmpty) {
                                return 'Nhap so dien thoai';
                              }
                              if (text.length < 9) {
                                return 'So dien thoai khong hop le';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Ngay sinh',
                              errorText: _dateErrorText,
                            ),
                            child: Row(
                              children: [
                                Expanded(child: Text(dateText)),
                                TextButton(
                                  onPressed: _pickDate,
                                  child: const Text('Chon ngay'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _passwordCtrl,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.next,
                            autofillHints: const <String>[
                              AutofillHints.newPassword,
                            ],
                            decoration: InputDecoration(
                              labelText: 'Mat khau',
                              suffixIcon: IconButton(
                                tooltip: _obscurePassword
                                    ? 'Hien mat khau'
                                    : 'An mat khau',
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
                              final text = value ?? '';
                              if (text.isEmpty) {
                                return 'Nhap mat khau';
                              }
                              if (text.length < 8) {
                                return 'Mat khau phai tu 8 ky tu tro len';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _confirmPasswordCtrl,
                            obscureText: _obscureConfirmPassword,
                            autofillHints: const <String>[
                              AutofillHints.newPassword,
                            ],
                            decoration: InputDecoration(
                              labelText: 'Nhap lai mat khau',
                              suffixIcon: IconButton(
                                tooltip: _obscureConfirmPassword
                                    ? 'Hien mat khau'
                                    : 'An mat khau',
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
                                return 'Nhap lai mat khau';
                              }
                              if (value != _passwordCtrl.text) {
                                return 'Mat khau nhap lai khong khop';
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
                                  ? 'Dang tao tai khoan...'
                                  : 'Tao tai khoan',
                            ),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Da co tai khoan? Dang nhap'),
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
