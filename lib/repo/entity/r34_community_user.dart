class R34CommunityUser {
  final String nickName;
  final String avatarUrl;
  final String subscriberCount;
  final int favoriteVideoCount;
  final int uploadVideoCount;

  R34CommunityUser({
    required this.nickName,
    String? avatarUrl,
    String? subscriberCount,
    String? favoriteVideoCount,
    String? uploadVideoCount,
  })  : avatarUrl = avatarUrl ??
            'https://pic.ibaotu.com/21/05/25/paixin/pki80515.jpg!ww7002',
        subscriberCount = subscriberCount ?? 'Error',
        favoriteVideoCount =
            int.parse(favoriteVideoCount?.replaceAll(',', '') ?? '0'),
        uploadVideoCount =
            int.parse(uploadVideoCount?.replaceAll(',', '') ?? '0');

  Map<String, dynamic> toJson() => {
        'nickName': nickName,
        'avatarUrl': avatarUrl,
        'subscriberCount': subscriberCount,
        'favoriteVideoCount': favoriteVideoCount,
        'uploadVideoCount': uploadVideoCount,
      };
}
