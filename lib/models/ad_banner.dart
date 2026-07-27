class AdBanner {
  const AdBanner({
    required this.id,
    required this.title,
    required this.imageUrl,
    this.subtitle = '',
    this.targetUrl = '',
    this.buttonText = '',
    this.backgroundColor = '',
    this.startsAt,
    this.endsAt,
  });

  final String id;
  final String title;
  final String subtitle;
  final String imageUrl;
  final String targetUrl;
  final String buttonText;
  final String backgroundColor;
  final DateTime? startsAt;
  final DateTime? endsAt;

  bool isActiveAt(DateTime time) {
    final instant = time.toUtc();
    return (startsAt == null || !instant.isBefore(startsAt!.toUtc())) &&
        (endsAt == null || !instant.isAfter(endsAt!.toUtc()));
  }

  Uri? get safeTargetUri {
    final uri = Uri.tryParse(targetUrl);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
    return uri;
  }

  factory AdBanner.fromRecord(
    Map<String, dynamic> record, {
    required String pocketBaseUrl,
  }) {
    final id = record['id'] as String? ?? '';
    final image = record['image'] as String? ?? '';
    return AdBanner(
      id: id,
      title: record['title'] as String? ?? '',
      subtitle: record['subtitle'] as String? ?? '',
      imageUrl: image.isEmpty || id.isEmpty
          ? ''
          : '$pocketBaseUrl/api/files/ads/$id/${Uri.encodeComponent(image)}',
      targetUrl: record['target_url'] as String? ?? '',
      buttonText: record['button_text'] as String? ?? '',
      backgroundColor: record['background_color'] as String? ?? '',
      startsAt: _parseDate(record['starts_at']),
      endsAt: _parseDate(record['ends_at']),
    );
  }

  factory AdBanner.fromJson(Map<String, dynamic> json) {
    return AdBanner(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      targetUrl: json['target_url'] as String? ?? '',
      buttonText: json['button_text'] as String? ?? '',
      backgroundColor: json['background_color'] as String? ?? '',
      startsAt: _parseDate(json['starts_at']),
      endsAt: _parseDate(json['ends_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'image_url': imageUrl,
      'target_url': targetUrl,
      'button_text': buttonText,
      'background_color': backgroundColor,
      'starts_at': startsAt?.toUtc().toIso8601String(),
      'ends_at': endsAt?.toUtc().toIso8601String(),
    };
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is! String || value.trim().isEmpty) return null;
    return DateTime.tryParse(value)?.toUtc();
  }
}
