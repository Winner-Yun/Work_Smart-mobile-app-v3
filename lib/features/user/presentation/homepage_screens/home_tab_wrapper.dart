import 'package:flutter/material.dart';
import 'package:flutter_worksmart_app/core/util/database/attendance_data.dart';
import 'package:flutter_worksmart_app/core/util/database/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'homepagescreen.dart';
import 'workspace_screen.dart';

class HomeTabWrapper extends StatefulWidget {
  final Map<String, dynamic>? loginData;
  final VoidCallback onStartupFlowCompleted;
  final VoidCallback onProfileTap;
  final ValueChanged<bool>? onWorkspaceStatusChanged;

  const HomeTabWrapper({
    super.key,
    this.loginData,
    required this.onStartupFlowCompleted,
    required this.onProfileTap,
    this.onWorkspaceStatusChanged,
  });

  @override
  State<HomeTabWrapper> createState() => _HomeTabWrapperState();
}

class _HomeTabWrapperState extends State<HomeTabWrapper> {
  static const String _workspaceIdKey = 'selected_workspace_id';
  bool _isLoading = true;
  String? _selectedWorkspaceId;

  @override
  void initState() {
    super.initState();
    _checkSavedWorkspace();
  }

  Future<void> _checkSavedWorkspace() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString(_workspaceIdKey);

    if (mounted) {
      setState(() {
        _selectedWorkspaceId = savedId;
        _isLoading = false;
      });
      _notifyWorkspaceStatus();
    }
  }

  Future<void> _handleWorkspaceSelected(String workspaceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_workspaceIdKey, workspaceId);

    if (mounted) {
      setState(() {
        _selectedWorkspaceId = workspaceId;
      });
      _notifyWorkspaceStatus();
    }
  }

  Future<void> _handleSwitchWorkspace() async {
    // Clear the saved workspace so the user must re-select one on next app start.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_workspaceIdKey);
    await prefs.remove('cached_selected_workspace');

    // Sweep every screen's per-workspace cache so none show stale data from the last workspace.
    await DatabaseHelper().clearWorkspaceScopedCaches();

    // Global in-memory cache that survives HomePageScreen's rebuild — reset it so the
    // next workspace doesn't briefly show the previous one's check-in/check-out status.
    setAttendanceRecords(const <Map<String, dynamic>>[]);

    if (mounted) {
      setState(() {
        _selectedWorkspaceId = null;
      });
      _notifyWorkspaceStatus();
    }
  }

  void _notifyWorkspaceStatus() {
    final bool hasWorkspace =
        _selectedWorkspaceId != null && _selectedWorkspaceId!.isNotEmpty;
    widget.onWorkspaceStatusChanged?.call(hasWorkspace);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // No workspace selected -> show WorkspaceScreen.
    if (_selectedWorkspaceId == null || _selectedWorkspaceId!.isEmpty) {
      return WorkspaceScreen(
        loginData: widget.loginData,
        onWorkspaceConfirmed:
            _handleWorkspaceSelected, // Trigger switch to Home
        onProfileTap: widget.onProfileTap,
      );
    }

    // Workspace selected -> show HomePageScreen.
    return HomePageScreen(
      loginData: widget.loginData,
      onStartupFlowCompleted: widget.onStartupFlowCompleted,
      onProfileTap: widget.onProfileTap,
      onSwitchWorkspace:
          _handleSwitchWorkspace, // Trigger switch back to Workspace
    );
  }
}
