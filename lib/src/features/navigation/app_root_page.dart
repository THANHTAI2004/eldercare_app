import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:eldercare_app/src/features/auth/login_page.dart';
import 'package:eldercare_app/src/features/navigation/main_shell.dart';
import 'package:eldercare_app/src/state/session_provider.dart';
import 'package:eldercare_app/src/ui/components/loading_state.dart';

class AppRootPage extends StatelessWidget {
  const AppRootPage({super.key, this.initialTab = MainTab.home});

  final MainTab initialTab;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();

    if (session.isBootstrapping) {
      return const Scaffold(
        body: Center(
          child: SizedBox(
            width: 320,
            child: LoadingState(message: 'Đang khôi phục phiên làm việc...'),
          ),
        ),
      );
    }

    if (!session.isAuthenticated) {
      return const LoginPage();
    }

    return MainShell(initialTab: initialTab);
  }
}
