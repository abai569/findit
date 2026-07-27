import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/ad_banner.dart';
import '../../../services/ad_service.dart';

class HomeAdBanner extends StatefulWidget {
  const HomeAdBanner({super.key, this.placement = 'home_top', this.carousel = false});

  final String placement;
  final bool carousel;

  @override
  State<HomeAdBanner> createState() => HomeAdBannerState();
}

class HomeAdBannerState extends State<HomeAdBanner> {
  final AdService _adService = AdService();
  final PageController _pageController = PageController();
  Timer? _carouselTimer;
  late Future<dynamic> _adFuture;
  int _currentPage = 0;
  bool _isUserInteracting = false;

  @override
  void initState() {
    super.initState();
    _adFuture = widget.carousel
        ? _adService.getAds(widget.placement)
        : _adService.getAd(widget.placement);
  }

  Future<void> refresh() async {
    final future = widget.carousel
        ? _adService.getAds(widget.placement, forceRefresh: true)
        : _adService.getAd(widget.placement, forceRefresh: true);
    if (mounted) {
      setState(() {
        _failedImageUrls.clear();
        _adFuture = future;
      });
    }
    await future;
  }

  @override
  void dispose() {
    _stopCarouselTimer();
    _pageController.dispose();
    _adService.dispose();
    super.dispose();
  }

  void _startCarouselTimer(int itemCount) {
    _stopCarouselTimer();
    if (itemCount <= 1) return;
    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted || _isUserInteracting) return;
      final next = (_currentPage + 1) % itemCount;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  void _stopCarouselTimer() {
    _carouselTimer?.cancel();
    _carouselTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<dynamic>(
      future: _adFuture,
      builder: (context, snapshot) {
        if (!widget.carousel) {
          final ad = snapshot.data as AdBanner?;
          if (ad == null || _failedImageUrls.contains(ad.imageUrl)) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: _buildBanner(ad),
          );
        }

        final ads =
            (snapshot.data as List<AdBanner>?)?.where((ad) => ad.isActiveAt(DateTime.now().toUtc())).toList() ?? [];
        final validAds =
            ads.where((ad) => !_failedImageUrls.contains(ad.imageUrl)).toList();
        if (validAds.isEmpty) return const SizedBox.shrink();
        if (validAds.length == 1) {
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: _buildBanner(validAds.first),
          );
        }

        _startCarouselTimer(validAds.length);
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: _bannerHeight(context),
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification is ScrollStartNotification &&
                        notification.dragDetails != null) {
                      setState(() => _isUserInteracting = true);
                    } else if (notification is ScrollEndNotification) {
                      setState(() => _isUserInteracting = false);
                    }
                    return false;
                  },
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (page) {
                      setState(() => _currentPage = page);
                    },
                    itemCount: validAds.length,
                    itemBuilder: (context, index) =>
                        _buildBanner(validAds[index]),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              _buildDotIndicator(validAds.length),
            ],
          ),
        );
      },
    );
  }

  double _bannerHeight(BuildContext context) {
    final width = MediaQuery.of(context).size.width - 32;
    return width / 3;
  }

  Widget _buildDotIndicator(int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isActive = index == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 16 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive
                ? Theme.of(context).colorScheme.primary
                : Colors.grey[300],
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }

  Widget _buildBanner(AdBanner ad) {
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
                      if (mounted && !_failedImageUrls.contains(ad.imageUrl)) {
                        setState(
                            () => _failedImageUrls.add(ad.imageUrl));
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

  final Set<String> _failedImageUrls = {};

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
