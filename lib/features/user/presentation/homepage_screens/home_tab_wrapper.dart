import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'homepagescreen.dart';
// Adjust imports to match your project paths:
import 'workspace_screen.dart';

class HomeTabWrapper extends StatefulWidget {
  final Map<String, dynamic>? loginData;
  final VoidCallback onStartupFlowCompleted;
  final VoidCallback onProfileTap;

  const HomeTabWrapper({
    super.key,
    this.loginData,
    required this.onStartupFlowCompleted,
    required this.onProfileTap,
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
    }
  }

  Future<void> _handleWorkspaceSelected(String workspaceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_workspaceIdKey, workspaceId);

    if (mounted) {
      setState(() {
        _selectedWorkspaceId = workspaceId;
      });
    }
  }

  Future<void> _handleSwitchWorkspace() async {
    // Clear the saved workspace ID from storage so the user is
    // forced to re-select a workspace on the next app start.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_workspaceIdKey);

    if (mounted) {
      setState(() {
        _selectedWorkspaceId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // 1. If NO workspace is selected -> Show WorkspaceScreen at Index 0
    if (_selectedWorkspaceId == null || _selectedWorkspaceId!.isEmpty) {
      return WorkspaceScreen(
        loginData: widget.loginData,
        onWorkspaceConfirmed:
            _handleWorkspaceSelected, // Trigger switch to Home
      );
    }

    // 2. If workspace IS selected -> Show HomePageScreen at Index 0
    return HomePageScreen(
      loginData: widget.loginData,
      onStartupFlowCompleted: widget.onStartupFlowCompleted,
      onProfileTap: widget.onProfileTap,
      onSwitchWorkspace:
          _handleSwitchWorkspace, // Trigger switch back to Workspace
    );
  }
}
