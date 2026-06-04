enum ProfileStatus { loading, ready, error }

class ProfileState {
  const ProfileState({
    required this.status,
    this.displayName,
    this.heightCm,
    this.weightKg,
    this.goalNotificationsEnabled = false,
    this.errorMessage,
  });

  final ProfileStatus status;
  final String? displayName;
  final int? heightCm;
  final double? weightKg;
  final bool goalNotificationsEnabled;
  final String? errorMessage;

  const ProfileState.loading() : this(status: ProfileStatus.loading);

  factory ProfileState.ready({
    String? displayName,
    int? heightCm,
    double? weightKg,
    bool goalNotificationsEnabled = false,
  }) {
    return ProfileState(
      status: ProfileStatus.ready,
      displayName: displayName,
      heightCm: heightCm,
      weightKg: weightKg,
      goalNotificationsEnabled: goalNotificationsEnabled,
    );
  }

  ProfileState copyWith({
    ProfileStatus? status,
    String? displayName,
    int? heightCm,
    double? weightKg,
    bool? goalNotificationsEnabled,
    String? errorMessage,
    bool clearDisplayName = false,
    bool clearHeightCm = false,
    bool clearWeightKg = false,
  }) {
    return ProfileState(
      status: status ?? this.status,
      displayName: clearDisplayName ? null : (displayName ?? this.displayName),
      heightCm: clearHeightCm ? null : (heightCm ?? this.heightCm),
      weightKg: clearWeightKg ? null : (weightKg ?? this.weightKg),
      goalNotificationsEnabled:
          goalNotificationsEnabled ?? this.goalNotificationsEnabled,
      errorMessage: errorMessage,
    );
  }
}
