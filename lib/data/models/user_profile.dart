class UserProfile {
  final String id; // matches auth.users.id (UUID)
  final String? displayName;
  final String? avatarUrl;
  final bool leaderboardOptIn;
  final bool friendsOnlyVisibility;
  final DateTime? createdAt;

  const UserProfile({
    required this.id,
    this.displayName,
    this.avatarUrl,
    this.leaderboardOptIn = true,
    this.friendsOnlyVisibility = false,
    this.createdAt,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
        id: map['id'] as String,
        displayName: map['display_name'] as String?,
        avatarUrl: map['avatar_url'] as String?,
        leaderboardOptIn: (map['leaderboard_opt_in'] as bool?) ?? true,
        friendsOnlyVisibility: (map['friends_only_visibility'] as bool?) ?? false,
        createdAt: map['created_at'] != null
            ? DateTime.parse(map['created_at'] as String)
            : null,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'display_name': displayName,
        'avatar_url': avatarUrl,
        'leaderboard_opt_in': leaderboardOptIn,
        'friends_only_visibility': friendsOnlyVisibility,
      };

  UserProfile copyWith({
    String? displayName,
    String? avatarUrl,
    bool? leaderboardOptIn,
    bool? friendsOnlyVisibility,
  }) =>
      UserProfile(
        id: id,
        displayName: displayName ?? this.displayName,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        leaderboardOptIn: leaderboardOptIn ?? this.leaderboardOptIn,
        friendsOnlyVisibility:
            friendsOnlyVisibility ?? this.friendsOnlyVisibility,
        createdAt: createdAt,
      );
}
