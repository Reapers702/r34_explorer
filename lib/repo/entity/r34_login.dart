class R34LoginRequest {
  String username;
  String pass;
  String action = 'login';
  String emailLink = 'https://rule34video.com/email/';
  String format = 'json';
  String mode = 'async';

  R34LoginRequest({
    required this.username,
    required this.pass,
  });

  Map<String, String> toJson() {
    return {
      'username': username,
      'pass': pass,
      'action': action,
      'email_link': emailLink,
      'format': format,
      'mode': mode,
    };
  }
}

class R34LoginRes {
  R34LoginResData data;
  String status;
  Map<String, String> cookies;

  R34LoginRes({
    required this.data,
    required this.status,
    required this.cookies,
  });

  factory R34LoginRes.fromJson(
      Map<String, dynamic> json, Map<String, String> cookies) {
    return R34LoginRes(
      data: R34LoginResData.fromJson(json['data']),
      status: json['status'],
      cookies: cookies,
    );
  }
}

class R34LoginResData {
  String displayName;
  int favouriteVideosAmount;
  int statusId;
  int userId;
  String username;

  R34LoginResData({
    required this.displayName,
    required this.favouriteVideosAmount,
    required this.statusId,
    required this.userId,
    required this.username,
  });

  factory R34LoginResData.fromJson(Map<String, dynamic> json) {
    return R34LoginResData(
      displayName: json['display_name'],
      favouriteVideosAmount: json['favourite_videos_amount'],
      statusId: int.parse(json['status_id']),
      userId: int.parse(json['user_id']),
      username: json['username'],
    );
  }
}
