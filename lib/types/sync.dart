class ReleaseInfo {
  final String stableVersion;
  final Map<String, Map<String, String>> stableDownloads;
  final String? betaVersion;
  final Map<String, Map<String, String>> betaDownloads;

  ReleaseInfo({
    required this.stableVersion,
    required this.stableDownloads,
    this.betaVersion,
    required this.betaDownloads,
  });

  factory ReleaseInfo.fromJson(Map<String, dynamic> json) {
    return ReleaseInfo(
      stableVersion: json['stableVersion'] as String? ?? '',
      stableDownloads: (json['stableDownloads'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, (v as Map<String, dynamic>).map(
          (k2, v2) => MapEntry(k2, v2 as String? ?? ''),
        )),
      ) ?? {},
      betaVersion: json['betaVersion'] as String?,
      betaDownloads: (json['betaDownloads'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, (v as Map<String, dynamic>).map(
          (k2, v2) => MapEntry(k2, v2 as String? ?? ''),
        )),
      ) ?? {},
    );
  }

  Map<String, dynamic> toJson() => {
    'stableVersion': stableVersion,
    'stableDownloads': stableDownloads,
    'betaVersion': betaVersion,
    'betaDownloads': betaDownloads,
  };
}
