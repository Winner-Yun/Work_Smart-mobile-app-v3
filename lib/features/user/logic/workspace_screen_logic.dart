import 'package:flutter/material.dart';
import 'package:flutter_worksmart_app/features/user/auth/repository/user_repository.dart';
import 'package:flutter_worksmart_app/features/user/auth/repository/workspace_repository.dart';
import 'package:flutter_worksmart_app/features/user/auth/service/user_service.dart';
import 'package:flutter_worksmart_app/features/user/auth/service/workspace_service.dart';
import 'package:flutter_worksmart_app/features/user/presentation/homepage_screens/workspace_screen.dart';
import 'package:flutter_worksmart_app/shared/model/user_model.dart';
import 'package:flutter_worksmart_app/shared/model/workspace_model.dart';

abstract class WorkspaceScreenLogic extends State<WorkspaceScreen> {
  late final WorkspaceRepository _workspaceRepo;
  late final UserRepository _userRepo;

  bool isLoading = true;
  String? errorMessage;

  List<Workspace> workspaces = [];
  UserModel? currentUser; // <--- Store fetched user here
  String? selectedWorkspaceId;

  @override
  void initState() {
    super.initState();
    _workspaceRepo = WorkspaceRepository(WorkspaceService());
    _userRepo = UserRepository(UserService());
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Run both API requests at the same time to save loading time!
      final results = await Future.wait([
        _workspaceRepo.getWorkspaces(),
        _userRepo.getUserProfile(),
      ]);

      if (mounted) {
        setState(() {
          workspaces = results[0] as List<Workspace>;
          currentUser = results[1] as UserModel;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('⛔ [WorkspaceScreenLogic] Error loading data: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = 'Failed to load data. Please try again.';
        });
      }
    }
  }

  void onWorkspaceSelected(String id) {
    setState(() {
      selectedWorkspaceId = id;
    });
  }

  void onConfirmSelection() {
    if (selectedWorkspaceId == null) return;
    widget.onWorkspaceConfirmed(selectedWorkspaceId!);
  }

  void onRetry() {
    _fetchInitialData();
  }
}
