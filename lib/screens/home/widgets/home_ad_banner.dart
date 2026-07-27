import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/ad_banner.dart';
import '../../../services/ad_service.dart';

class HomeAdBanner extends StatefulWidget {
  const HomeAdBanner({super.key, this.placement = 'home_top'});

  final String placement;

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
    _adFuture = _adService.getAd(widget.placement);
  }

  Future<void> refresh() async {
    final future = _adService.getAd(widget.placement, forceRefresh: true);
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
          child: AspectRatio(
            aspectRatio: 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  ad.imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && _failedImageUrl != ad.imageUrl) {
                        setState(() => _failedImageUrl = ad.imageUrl);
                      }
                    });
                    return const SizedBox.shrink();
                  },
                ),
                Positioned(
                  top: 6,
                  left: 6,
                  child: _buildAdLabel(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdLabel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0x99000000),
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
