import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../theme/smithmk_theme.dart';
import 'music_page.dart';

class MediaPage extends StatelessWidget {
  const MediaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0D),
      body: SafeArea(child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 0), child: Row(children: [
          Icon(PhosphorIcons.monitorPlay(PhosphorIconsStyle.light), size: 22, color: SmithMkColors.gold),
          const SizedBox(width: 10),
          const Text('Media', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        ])),
        const SizedBox(height: 12),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Row(children: [
          _pill('HA', true), const SizedBox(width: 6),
          _pill('SUPABASE', true), const SizedBox(width: 6),
          _pill('SPOTIFY', true),
        ])),
        Expanded(child: LayoutBuilder(builder: (ctx, c) {
          final isWide = c.maxWidth > 500;
          return Center(child: Padding(padding: const EdgeInsets.all(20), child: isWide
            ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _mediaTile(context, 'MUSIC', PhosphorIcons.headphones(PhosphorIconsStyle.light), 'Spotify · Echo · Sonos', true),
                const SizedBox(width: 16),
                _orDivider(true),
                const SizedBox(width: 16),
                _mediaTile(context, 'TV', PhosphorIcons.monitor(PhosphorIconsStyle.light), 'Roku · NVIDIA Shield', false),
              ])
            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                _mediaTile(context, 'MUSIC', PhosphorIcons.headphones(PhosphorIconsStyle.light), 'Spotify · Echo · Sonos', true),
                const SizedBox(height: 16),
                _orDivider(false),
                const SizedBox(height: 16),
                _mediaTile(context, 'TV', PhosphorIcons.monitor(PhosphorIconsStyle.light), 'Roku · NVIDIA Shield', false),
              ])));
        })),
      ])),
    );
  }

  Widget _mediaTile(BuildContext context, String label, IconData icon, String sub, bool isMusic) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        if (isMusic) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const MusicPage()));
        } else {
          // TV page placeholder
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('TV page coming soon'), backgroundColor: Color(0xFF1E1E26)));
        }
      },
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (_, v, child) => Transform.translate(
          offset: Offset(0, 20 * (1 - v)),
          child: Opacity(opacity: v, child: child)),
        child: Container(
          width: 200, height: 220,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(begin: Alignment(-0.5, -0.5), end: Alignment(0.5, 0.5),
              colors: [Color(0xF21E1E26), Color(0xEB16161C)]),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 24, offset: const Offset(8, 8)),
              BoxShadow(color: Colors.white.withValues(alpha: 0.02), blurRadius: 12, offset: const Offset(-4, -4)),
              BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 50, offset: const Offset(0, 20)),
            ],
          ),
          child: Stack(children: [
            // Top edge highlight
            Positioned(top: 0, left: 0, right: 0, height: 1, child: Container(
              decoration: BoxDecoration(borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                gradient: LinearGradient(colors: [Colors.transparent, Colors.white.withValues(alpha: 0.12), Colors.transparent])))),
            // Inner top glow
            Positioned(top: 0, left: 0, right: 0, height: 90, child: Container(
              decoration: BoxDecoration(borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.white.withValues(alpha: 0.04), Colors.transparent])))),
            // Content
            Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Icon orb
              Container(width: 80, height: 80, decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF222222), Color(0xFF161616)]),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 16, offset: const Offset(6, 6)),
                  BoxShadow(color: Colors.white.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(-3, -3)),
                  const BoxShadow(color: Color(0x0EFFFFFF), blurRadius: 0, offset: Offset(0, -1)),
                ]),
                child: Icon(icon, size: 32, color: SmithMkColors.gold)),
              const SizedBox(height: 14),
              Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 2, color: SmithMkColors.gold)),
              const SizedBox(height: 4),
              Text(sub, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0x4DFFFFFF))),
            ])),
          ]),
        ),
      ),
    );
  }

  Widget _orDivider(bool vertical) {
    if (vertical) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 1, height: 30, decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.white.withValues(alpha: 0.08), Colors.transparent]))),
        const Padding(padding: EdgeInsets.symmetric(vertical: 6),
          child: Text('OR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2, color: Color(0x26FFFFFF)))),
        Container(width: 1, height: 30, decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.white.withValues(alpha: 0.08), Colors.transparent]))),
      ]);
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(height: 1, width: 30, decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.transparent, Colors.white.withValues(alpha: 0.08), Colors.transparent]))),
      const Padding(padding: EdgeInsets.symmetric(horizontal: 8),
        child: Text('OR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2, color: Color(0x26FFFFFF)))),
      Container(height: 1, width: 30, decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.transparent, Colors.white.withValues(alpha: 0.08), Colors.transparent]))),
    ]);
  }

  static Widget _pill(String label, bool ok) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: const Color(0x0AFFFFFF),
      border: Border.all(color: ok ? const Color(0x4D4CAF50) : const Color(0x4DEF4444))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle,
        color: ok ? SmithMkColors.success : SmithMkColors.error,
        boxShadow: [BoxShadow(color: ok ? SmithMkColors.success : SmithMkColors.error, blurRadius: 6)])),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 1, color: Color(0x66FFFFFF))),
    ]));
}
