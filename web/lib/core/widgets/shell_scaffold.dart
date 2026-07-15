import 'package:flutter/material.dart';
import 'package:fuelsense_ui/fuelsense_ui.dart';

import '../api/api_client.dart';
import '../../features/auth/auth_gate.dart';

class ShellDestination {
  const ShellDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class ShellScaffold extends StatefulWidget {
  const ShellScaffold({
    super.key,
    required this.api,
    required this.appName,
    required this.destinations,
    required this.pages,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.roleLabel,
  });

  final ApiClient api;
  final String appName;
  final List<ShellDestination> destinations;
  final List<Widget> pages;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final String? roleLabel;

  @override
  State<ShellScaffold> createState() => _ShellScaffoldState();
}

class _ShellScaffoldState extends State<ShellScaffold> {
  bool _collapsed = false;
  bool _mobileOpen = false;
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final me = await widget.api.me();
    if (mounted) setState(() => _user = me);
  }

  String get _userName {
    final first = _user?['first_name'] as String? ?? '';
    final last = _user?['last_name'] as String? ?? '';
    if (first.isNotEmpty || last.isNotEmpty) return '$first $last'.trim();
    return (_user?['email'] as String? ?? 'User').split('@').first;
  }

  String get _initials {
    final parts = _userName.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts.isNotEmpty ? parts[0][0].toUpperCase() : '?';
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need to sign in again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign out')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await widget.api.clear();
    if (!mounted) return;
    navigateToLogin(context);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final mobile = width < 860;
    final hideLabels = _collapsed && !mobile;
    final current = widget.destinations[widget.selectedIndex];

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: Stack(
        children: [
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                width: mobile ? AppSpacing.sidebarWidth : (_collapsed ? AppSpacing.sidebarCollapsed : AppSpacing.sidebarWidth),
                child: _Sidebar(
                  appName: widget.appName,
                  roleLabel: widget.roleLabel,
                  destinations: widget.destinations,
                  selectedIndex: widget.selectedIndex,
                  onSelect: (i) {
                    widget.onDestinationSelected(i);
                    if (mobile) setState(() => _mobileOpen = false);
                  },
                  hideLabels: hideLabels,
                  userName: _userName,
                  userRole: (_user?['role'] as String? ?? '').replaceAll('_', ' '),
                  initials: _initials,
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    _TopBar(
                      appName: widget.appName,
                      pageLabel: current.label,
                      initials: _initials,
                      collapsed: _collapsed,
                      mobile: mobile,
                      onToggleCollapse: () => setState(() => _collapsed = !_collapsed),
                      onOpenMobile: () => setState(() => _mobileOpen = true),
                      onLogout: _logout,
                    ),
                    Expanded(child: widget.pages[widget.selectedIndex]),
                  ],
                ),
              ),
            ],
          ),
          if (mobile && _mobileOpen) ...[
            GestureDetector(onTap: () => setState(() => _mobileOpen = false), child: Container(color: AppColors.textPrimary.withValues(alpha: 0.45))),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: AppSpacing.sidebarWidth,
              child: Material(
                elevation: 8,
                child: _Sidebar(
                  appName: widget.appName,
                  roleLabel: widget.roleLabel,
                  destinations: widget.destinations,
                  selectedIndex: widget.selectedIndex,
                  onSelect: (i) {
                    widget.onDestinationSelected(i);
                    setState(() => _mobileOpen = false);
                  },
                  hideLabels: false,
                  userName: _userName,
                  userRole: (_user?['role'] as String? ?? '').replaceAll('_', ' '),
                  initials: _initials,
                ),
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: mobile
          ? null
          : null,
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.appName,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelect,
    required this.hideLabels,
    required this.userName,
    required this.userRole,
    required this.initials,
    this.roleLabel,
  });

  final String appName;
  final String? roleLabel;
  final List<ShellDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final bool hideLabels;
  final String userName;
  final String userRole;
  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.sidebarBg,
        border: Border(right: BorderSide(color: AppColors.border)),
        boxShadow: [BoxShadow(color: Color(0x08000000), blurRadius: 2, offset: Offset(1, 0))],
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(hideLabels ? 8 : 16, 16, hideLabels ? 8 : 16, 14),
            child: Row(
              mainAxisAlignment: hideLabels ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                const FsLogo(size: 28, showText: false),
                if (!hideLabels) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(appName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                        Text(
                          (roleLabel ?? 'PORTAL').toUpperCase(),
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 0.4, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderFaint),
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: hideLabels ? 8 : 12, vertical: 8),
              children: [
                for (var i = 0; i < destinations.length; i++)
                  _NavItem(
                    icon: destinations[i].icon,
                    selectedIcon: destinations[i].selectedIcon,
                    label: destinations[i].label,
                    selected: i == selectedIndex,
                    hideLabel: hideLabels,
                    onTap: () => onSelect(i),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderFaint),
          Padding(
            padding: EdgeInsets.all(hideLabels ? 8 : 16),
            child: Row(
              mainAxisAlignment: hideLabels ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.primarySoft,
                  child: Text(initials, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
                ),
                if (!hideLabels) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(userName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        Text(userRole, style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.hideLabel,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final bool hideLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected ? AppColors.surfaceSelected : Colors.transparent,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          hoverColor: AppColors.surfaceHover,
          child: Stack(
            children: [
              if (selected)
                Positioned(
                  left: hideLabel ? 0 : -12,
                  top: 8,
                  bottom: 8,
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(3)),
                  ),
                ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: hideLabel ? 0 : 10, vertical: 9),
                child: hideLabel
                    ? Center(
                        child: Icon(
                          selected ? selectedIcon : icon,
                          size: 18,
                          color: selected ? AppColors.primary : AppColors.textMuted,
                        ),
                      )
                    : Row(
                        children: [
                          Icon(selected ? selectedIcon : icon, size: 18, color: selected ? AppColors.primary : AppColors.textMuted),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                                color: selected ? AppColors.primary : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.appName,
    required this.pageLabel,
    required this.initials,
    required this.collapsed,
    required this.mobile,
    required this.onToggleCollapse,
    required this.onOpenMobile,
    required this.onLogout,
  });

  final String appName;
  final String pageLabel;
  final String initials;
  final bool collapsed;
  final bool mobile;
  final VoidCallback onToggleCollapse;
  final VoidCallback onOpenMobile;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSpacing.topbarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        color: AppColors.surfaceCard,
        border: Border(bottom: BorderSide(color: AppColors.border)),
        boxShadow: [BoxShadow(color: Color(0x06000000), blurRadius: 2, offset: Offset(0, 1))],
      ),
      child: Row(
        children: [
          if (mobile)
            FsIconButton(icon: Icons.menu_rounded, onPressed: onOpenMobile, tooltip: 'Open menu')
          else
            FsIconButton(
              icon: Icons.view_sidebar_rounded,
              onPressed: onToggleCollapse,
              tooltip: collapsed ? 'Expand sidebar' : 'Collapse sidebar',
            ),
          const SizedBox(width: 8),
          Flexible(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    appName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, size: 14, color: AppColors.textFaint),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    pageLabel,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          FsIconButton(icon: Icons.notifications_outlined, onPressed: () {}, tooltip: 'Notifications'),
          const SizedBox(width: 4),
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.primarySoft,
            child: Text(initials, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary)),
          ),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, size: 18),
            offset: const Offset(0, 40),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
            onSelected: (v) {
              if (v == 'logout') onLogout();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Text(pageLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'logout', child: Row(children: [Icon(Icons.logout_rounded, size: 16), SizedBox(width: 8), Text('Sign out')])),
            ],
          ),
        ],
      ),
    );
  }
}

/// CEP-style page body wrapper.
class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.child,
    this.scrollable = true,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final body = Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.pageX, 0, AppSpacing.pageX, AppSpacing.pageBottom),
      child: child,
    );

    return ColoredBox(
      color: AppColors.surfaceLight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FsPageHeader(title: title, subtitle: subtitle, trailing: trailing),
          Expanded(
            child: scrollable
                ? SingleChildScrollView(child: body)
                : body,
          ),
        ],
      ),
    );
  }
}
