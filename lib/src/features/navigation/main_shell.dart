import 'package:flutter/material.dart';

import 'package:eldercare_app/src/features/account/account_page.dart';
import 'package:eldercare_app/src/features/alerts/alerts_page.dart';
import 'package:eldercare_app/src/features/devices/device_page.dart';
import 'package:eldercare_app/src/features/history/history_page.dart';
import 'package:eldercare_app/src/features/home/home_page.dart';

enum MainTab { home, history, alerts, devices, account }

abstract interface class MainShellController {
  void goToTab(MainTab tab);
}

class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialTab = MainTab.home});

  final MainTab initialTab;

  static MainShellController? maybeOf(BuildContext context) {
    return context.findAncestorStateOfType<_MainShellState>();
  }

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> implements MainShellController {
  late MainTab _currentTab = widget.initialTab;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialTab.index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  void goToTab(MainTab tab) {
    if (_currentTab == tab) return;
    setState(() {
      _currentTab = tab;
    });
    if (_pageController.hasClients && _pageController.page?.round() != tab.index) {
      _pageController.animateToPage(
        tab.index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onPageChanged(int index) {
    final tab = MainTab.values[index];
    if (_currentTab != tab) {
      setState(() {
        _currentTab = tab;
      });
    }
  }

  int get _selectedIndex => MainTab.values.indexOf(_currentTab);

  List<Widget> get _pages => const <Widget>[
    _KeepAlivePage(child: HomePage()),
    _KeepAlivePage(child: HistoryPage()),
    _KeepAlivePage(child: AlertsPage()),
    _KeepAlivePage(child: DevicePage()),
    _KeepAlivePage(child: AccountPage()),
  ];

  @override
  void didUpdateWidget(covariant MainShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      _currentTab = widget.initialTab;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(_currentTab.index);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    const destinations = <NavigationDestination>[
      NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home_rounded),
        label: 'Trang chủ',
      ),
      NavigationDestination(
        icon: Icon(Icons.query_stats_outlined),
        selectedIcon: Icon(Icons.query_stats_rounded),
        label: 'Lịch sử',
      ),
      NavigationDestination(
        icon: Icon(Icons.notifications_none_rounded),
        selectedIcon: Icon(Icons.notifications_rounded),
        label: 'Cảnh báo',
      ),
      NavigationDestination(
        icon: Icon(Icons.watch_outlined),
        selectedIcon: Icon(Icons.watch_rounded),
        label: 'Thiết bị',
      ),
      NavigationDestination(
        icon: Icon(Icons.person_outline_rounded),
        selectedIcon: Icon(Icons.person_rounded),
        label: 'Tài khoản',
      ),
    ];

    final railDestinations = destinations
        .map(
          (destination) => NavigationRailDestination(
            icon: destination.icon,
            selectedIcon: destination.selectedIcon,
            label: Text(destination.label),
          ),
        )
        .toList(growable: false);

    return Scaffold(
      body: isWide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (index) => goToTab(MainTab.values[index]),
                  labelType: NavigationRailLabelType.all,
                  destinations: railDestinations,
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: _onPageChanged,
                    children: _pages,
                  ),
                ),
              ],
            )
          : PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              children: _pages,
            ),
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) => goToTab(MainTab.values[index]),
              destinations: destinations,
            ),
    );
  }
}

class _KeepAlivePage extends StatefulWidget {
  const _KeepAlivePage({required this.child});
  final Widget child;

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
