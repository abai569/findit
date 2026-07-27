import 'package:flutter_test/flutter_test.dart';
import 'package:wuping_guanjia/models/ad_banner.dart';

void main() {
  group('AdBanner', () {
    test('builds the public PocketBase file URL', () {
      final ad = AdBanner.fromRecord(
        {
          'id': 'record123',
          'title': 'Storage offer',
          'image': 'banner image.webp',
        },
        pocketBaseUrl: 'https://pb.example.com',
      );

      expect(
        ad.imageUrl,
        'https://pb.example.com/api/files/ads/record123/banner%20image.webp',
      );
    });

    test('accepts only absolute HTTPS target URLs', () {
      const secure = AdBanner(
        id: '1',
        title: 'Secure',
        imageUrl: 'https://pb.example.com/banner.webp',
        targetUrl: 'https://example.com/offer',
      );
      const insecure = AdBanner(
        id: '2',
        title: 'Insecure',
        imageUrl: 'https://pb.example.com/banner.webp',
        targetUrl: 'http://example.com/offer',
      );
      const script = AdBanner(
        id: '3',
        title: 'Script',
        imageUrl: 'https://pb.example.com/banner.webp',
        targetUrl: 'javascript:alert(1)',
      );

      expect(secure.safeTargetUri, Uri.parse('https://example.com/offer'));
      expect(insecure.safeTargetUri, isNull);
      expect(script.safeTargetUri, isNull);
    });

    test('checks inclusive campaign boundaries', () {
      final ad = AdBanner(
        id: '1',
        title: 'Scheduled',
        imageUrl: 'https://pb.example.com/banner.webp',
        startsAt: DateTime.utc(2026, 7, 1),
        endsAt: DateTime.utc(2026, 7, 31),
      );

      expect(ad.isActiveAt(DateTime.utc(2026, 7, 1)), isTrue);
      expect(ad.isActiveAt(DateTime.utc(2026, 7, 31)), isTrue);
      expect(ad.isActiveAt(DateTime.utc(2026, 6, 30, 23, 59)), isFalse);
      expect(ad.isActiveAt(DateTime.utc(2026, 7, 31, 0, 1)), isFalse);
    });

    test('round trips cached values', () {
      final original = AdBanner(
        id: 'record123',
        title: 'Storage offer',
        subtitle: 'Organize every room',
        imageUrl: 'https://pb.example.com/banner.webp',
        targetUrl: 'https://example.com/offer',
        buttonText: 'View offer',
        backgroundColor: '#123456',
        startsAt: DateTime.utc(2026, 7, 1),
        endsAt: DateTime.utc(2026, 7, 31),
      );

      final restored = AdBanner.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.subtitle, original.subtitle);
      expect(restored.imageUrl, original.imageUrl);
      expect(restored.targetUrl, original.targetUrl);
      expect(restored.buttonText, original.buttonText);
      expect(restored.backgroundColor, original.backgroundColor);
      expect(restored.startsAt, original.startsAt);
      expect(restored.endsAt, original.endsAt);
    });
  });
}
