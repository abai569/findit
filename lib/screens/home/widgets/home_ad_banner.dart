import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/ad_banner.dart';
import '../../../services/ad_service.dart';

class HomeAdBanner extends StatefulWidget {
  const HomeAdBanner({super.key});

  @override
  State<HomeAdBanner> createState() => HomeAdBannerState();
}

class HomeAdBannerState extends State<HomeAdBanner> {
  final AdService _adService = AdService();
  late Future<AdBanner?> _adFuture;
  String? _failedImageUrl;

  @override
  void initState() {
    super.initState();
    _adFuture = _adService.getHomeAd();
  }

  Future<void> refresh() async {
    final future = _adService.getHomeAd(forceRefresh: true);
    if (mounted) {
      setState(() {
        _failedImageUrl = null;
        _adFuture = future;
      });
    }
    await future;
  }

  @override
  void dispose() {
    _adService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AdBanner?>(
      future: _adFuture,
      builder: (context, snapshot) {
        final ad = snapshot.data;
        if (ad == null || ad.imageUrl == _failedImageUrl) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: _buildBanner(context, ad),
        );
      },
    );
  }

  Widget _buildBanner(BuildContext context, AdBanner ad) {
    final targetUri = ad.safeTargetUri;
    return Semantics(
      label: ['广告', ad.title, ad.subtitle]
          .where((value) => value.isNotEmpty)
          .join('，'),
      button: targetUri != null,
      child: Material(
        color: _parseColor(ad.backgroundColor),
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: targetUri == null ? null : () => _openTarget(targetUri),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bannerHeight =
                  (constraints.maxWidth / 3).clamp(104.0, 180.0).toDouble();
              final compact = bannerHeight < 130;
              return SizedBox(
                height: bannerHeight,
                child: MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1.4,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        ad.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted && _failedImageUrl != ad.imageUrl) {
                              setState(() => _failedImageUrl = ad.imageUrl);
                            }
                          });
                          return const SizedBox.shrink();
                        },
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [Color(0xB3000000), Color(0x12000000)],
                            stops: [0, 0.8],
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(compact ? 10 : 14),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildAdLabel(),
                                  SizedBox(height: compact ? 3 : 5),
                                  Text(
                                    ad.title,
                                    maxLines: compact ? 1 : 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (!compact && ad.subtitle.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      ad.subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xE6FFFFFF),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (targetUri != null &&
                                !compact &&
                                ad.buttonText.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0x29FFFFFF),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  ad.buttonText,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                            else if (targetUri != null)
                              Tooltip(
                                message: ad.buttonText.isEmpty
                                    ? '打开广告链接'
                                    : ad.buttonText,
                                child: const Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Colors.white,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAdLabel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xB3FFFFFF)),
        borderRadius: BorderRadius.circular(3),
      ),
      child: const Text(
        '广告',
        style: TextStyle(color: Colors.white, fontSize: 10),
      ),
    );
  }

  Future<void> _openTarget(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // The banner remains usable even when the device has no browser handler.
    }
  }

  Color _parseColor(String value) {
    final hex = value.trim().replaceFirst('#', '');
    if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(hex)) {
      return const Color(0xFFE8EEF3);
    }
    return Color(int.parse('FF$hex', radix: 16));
  }
}
