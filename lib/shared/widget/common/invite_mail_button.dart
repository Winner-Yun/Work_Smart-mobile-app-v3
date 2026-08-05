import 'package:flutter/material.dart';
import 'package:flutter_worksmart_app/app/routes/app_route.dart';
import 'package:flutter_worksmart_app/features/user/repository/invite_repository.dart';
import 'package:flutter_worksmart_app/features/user/service/invite_service.dart';

/// Mail icon opening "My Invites", with a badge for how many are pending.
/// Self-contained: fetches its own count via REST.
class InviteMailButton extends StatefulWidget {
  final Map<String, dynamic>? loginData;
  final Color? iconColor;

  const InviteMailButton({super.key, this.loginData, this.iconColor});

  @override
  State<InviteMailButton> createState() => _InviteMailButtonState();
}

class _InviteMailButtonState extends State<InviteMailButton> {
  final InviteRepository _inviteRepo = InviteRepository(InviteService());
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadPendingCount();
  }

  Future<void> _loadPendingCount() async {
    try {
      final response = await _inviteRepo.getMyInvites(limit: 50);
      final int count = response.data
          .where((invite) => invite.status.toLowerCase() == 'pending')
          .length;
      if (mounted) setState(() => _pendingCount = count);
    } catch (_) {
      // Best-effort badge only — a failed count fetch shouldn't be noisy.
    }
  }

  Future<void> _openInvites() async {
    await Navigator.pushNamed(
      context,
      AppRoute.invitesScreen,
      arguments: widget.loginData,
    );
    if (mounted) _loadPendingCount();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          onPressed: _openInvites,
          icon: Icon(
            Icons.mail_outline_rounded,
            color: widget.iconColor ?? Theme.of(context).iconTheme.color,
          ),
        ),
        if (_pendingCount > 0)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: Text(
                _pendingCount > 9 ? '9+' : '$_pendingCount',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
