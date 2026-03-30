import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/responsive.dart';
import '../../data/models/audio_track.dart';
import '../../data/repositories/app_repository.dart';
import 'play_screen.dart';

/// Full-screen track selection shown the first time the user taps the
/// Hanuman Chalisa tile. Once a track is chosen it is saved as the
/// preferred track and the user goes straight to PlayScreen in future.
class AudioTrackSelectionScreen extends StatefulWidget {
  const AudioTrackSelectionScreen({super.key});

  @override
  State<AudioTrackSelectionScreen> createState() =>
      _AudioTrackSelectionScreenState();
}

class _AudioTrackSelectionScreenState
    extends State<AudioTrackSelectionScreen> {
  String? _selectedId;
  bool _saving = false;

  Future<void> _onBegin() async {
    if (_selectedId == null || _saving) return;
    setState(() => _saving = true);
    try {
      final settings = await AppRepository.instance.getSettings();
      await AppRepository.instance.saveSettings(
        settings.copyWith(preferredTrack: _selectedId),
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        _slideUpRoute(PlayScreen(initialTrackId: _selectedId)),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF131313),
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(context),
              Expanded(child: _buildTrackList(cs)),
              _buildBottomBar(cs),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          context.sp(20), context.sp(12), context.sp(20), 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            color: Colors.white70,
            iconSize: 20,
          ),
          const SizedBox(width: 4),
          Text(
            'Choose Your Recitation',
            style: GoogleFonts.notoSerif(
              color: Colors.white,
              fontSize: context.sp(18),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackList(ColorScheme cs) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Select the audio that resonates with you.\nYou can change it anytime during playback.',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              color: Colors.white54,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          SizedBox(height: 32),
          for (final track in kAudioTracks) ...[
            _TrackCard(
              track: track,
              selected: _selectedId == track.id,
              onTap: () => setState(() => _selectedId = track.id),
            ),
            SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomBar(ColorScheme cs) {
    final ready = _selectedId != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton(
          onPressed: ready ? _onBegin : null,
          style: FilledButton.styleFrom(
            backgroundColor: cs.primary,
            disabledBackgroundColor: cs.primary.withValues(alpha: 0.25),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: _saving
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.black),
                )
              : Text(
                  'Begin',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),
        ),
      ),
    );
  }
}

class _TrackCard extends StatelessWidget {
  final AudioTrack track;
  final bool selected;
  final VoidCallback onTap;

  const _TrackCard({
    required this.track,
    required this.selected,
    required this.onTap,
  });

  static const _icons = {
    'traditional': Icons.surround_sound_rounded,
    'male': Icons.record_voice_over_rounded,
    'female': Icons.mic_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final borderColor = selected ? cs.primary : Colors.white12;
    final bgColor =
        selected ? cs.primary.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.04);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: selected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selected
                    ? cs.primary.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _icons[track.id] ?? Icons.music_note_rounded,
                color: selected ? cs.primary : Colors.white54,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.name,
                    style: GoogleFonts.notoSerif(
                      color: selected ? cs.primary : Colors.white,
                      fontSize: context.sp(15),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    track.description,
                    style: GoogleFonts.manrope(
                      color: Colors.white54,
                      fontSize: context.sp(12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? cs.primary : Colors.white30,
                  width: 1.5,
                ),
                color: selected ? cs.primary : Colors.transparent,
              ),
              child: selected
                  ? const Icon(Icons.check, color: Colors.black, size: 12)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Slide-up route (same animation as the rest of the app).
Route<T> _slideUpRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (_, __, ___) => page,
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    transitionsBuilder: (_, anim, __, child) => SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
      child: child,
    ),
  );
}
