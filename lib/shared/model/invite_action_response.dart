import 'package:flutter_worksmart_app/shared/model/invite_model.dart';

class InviteActionResponse {
  final String message;
  final Invite? invite;

  InviteActionResponse({required this.message, this.invite});

  factory InviteActionResponse.fromJson(Map<String, dynamic> json) {
    return InviteActionResponse(
      message: json['message']?.toString() ?? '',
      invite: json['invite'] != null
          ? Invite.fromJson(json['invite'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'message': message,
    'invite': invite?.toJson(),
  };
}
