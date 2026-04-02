import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/lyrics_service.dart';
import '../../core/responsive.dart';
import '../../main.dart' show lyricsService;

class RecitationScreen extends StatefulWidget {
  /// Inject test lines without loading the asset bundle. Production code
  /// always leaves this null; tests pass a small list to stay asset-free.
  @visibleForTesting
  final List<LyricsLine>? debugLines;

  const RecitationScreen({super.key, this.debugLines});

  @override
  State<RecitationScreen> createState() => _RecitationScreenState();
}

class _RecitationScreenState extends State<RecitationScreen> {
  bool _showEnglish = false;

  List<LyricsLine> get _lines => widget.debugLines ?? lyricsService.lines;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lines = _lines;
    final hasTransliteration = lines.any((l) => l.transliteration != null);

    return Scaffold(
      backgroundColor: cs.surface,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _RecitationBackground(cs: cs),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(context, cs),
                if (hasTransliteration)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: context.sp(4)),
                    child: _LangToggle(
                      showEnglish: _showEnglish,
                      cs: cs,
                      onToggle: (v) => setState(() => _showEnglish = v),
                    ),
                  ),
                Expanded(
                  child: lines.isEmpty
                      ? Center(
                          child: Text(
                            'ॐ',
                            style: GoogleFonts.notoSerif(
                              fontSize: context.sp(64),
                              color: cs.secondary.withValues(alpha: 0.4),
                            ),
                          ),
                        )
                      : _buildLyricsList(context, cs, lines),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, ColorScheme cs) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.sp(20),
        vertical: context.sp(8),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_rounded,
                color: cs.primary, size: context.sp(22)),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Text(
              'Voice Recitation',
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSerif(
                fontSize: context.sp(19),
                color: cs.primary,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.share_outlined,
                color: cs.primary, size: context.sp(20)),
            onPressed: () => SharePlus.instance.share(
              ShareParams(
                text: "जय हनुमान! I've been doing Hanuman Chalisa paath daily. "
                    "Join me 🙏\n\nSearch 'Hanuman Chalisa' on the Play Store.",
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLyricsList(
    BuildContext context,
    ColorScheme cs,
    List<LyricsLine> lines,
  ) {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        context.sp(24),
        context.sp(8),
        context.sp(24),
        context.sp(32),
      ),
      itemCount: lines.length,
      itemBuilder: (ctx, i) {
        final line = lines[i];
        final isHeader = line.text.startsWith('॥');
        final displayText =
            (_showEnglish && line.transliteration != null)
                ? line.transliteration!
                : line.text;

        if (isHeader) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: context.sp(14)),
            child: Center(
              child: Text(
                displayText,
                textAlign: TextAlign.center,
                style: (_showEnglish
                        ? GoogleFonts.manrope
                        : GoogleFonts.notoSerif)(
                  fontSize: context.sp(13),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.2,
                  color: cs.secondary.withValues(alpha: 0.65),
                ),
              ),
            ),
          );
        }

        return Padding(
          padding: EdgeInsets.symmetric(vertical: context.sp(6)),
          child: Text(
            displayText,
            textAlign: TextAlign.center,
            style: (_showEnglish
                    ? GoogleFonts.manrope
                    : GoogleFonts.notoSerif)(
              fontSize: context.sp(17),
              fontWeight: FontWeight.w400,
              color: cs.onSurface.withValues(alpha: 0.88),
              height: 1.55,
            ),
          ),
        );
      },
    );
  }
}

// ── Background ─────────────────────────────────────────────────────────────────
// Same visual treatment as PlayScreen: desaturated hero image at 0.20 opacity,
// gradient vignette, and large ॐ watermark in the bottom-right corner.
class _RecitationBackground extends StatelessWidget {
  final ColorScheme cs;
  const _RecitationBackground({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Opacity(
          opacity: 0.20,
          child: ColorFiltered(
            colorFilter: const ColorFilter.matrix([
              0.2126, 0.7152, 0.0722, 0, 0,
              0.2126, 0.7152, 0.0722, 0, 0,
              0.2126, 0.7152, 0.0722, 0, 0,
              0,      0,      0,      1, 0,
            ]),
            child: Image.asset(
              'assets/images/hanuman_player_bg.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => const SizedBox.shrink(),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                cs.surface.withValues(alpha: 0.5),
                Colors.transparent,
                cs.surface,
              ],
              stops: const [0.0, 0.3, 1.0],
            ),
          ),
        ),
        Positioned(
          right: context.sp(22),
          bottom: context.sp(18),
          child: Text(
            'ॐ',
            style: GoogleFonts.notoSerif(
              fontSize: context.sp(220),
              color: cs.secondary.withValues(alpha: 0.10),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Language toggle pill ───────────────────────────────────────────────────────
// Matches the design in PlayScreen._LyricsPanel.
class _LangToggle extends StatelessWidget {
  final bool showEnglish;
  final ColorScheme cs;
  final ValueChanged<bool> onToggle;

  const _LangToggle({
    required this.showEnglish,
    required this.cs,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: context.sp(28),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(context.sp(14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _pill(context,
              label: 'हि', selected: !showEnglish, onTap: () => onToggle(false)),
          _pill(context,
              label: 'EN', selected: showEnglish, onTap: () => onToggle(true)),
        ],
      ),
    );
  }

  Widget _pill(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: context.sp(44),
        height: context.sp(28),
        decoration: BoxDecoration(
          color: selected ? cs.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(context.sp(14)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: context.sp(11),
            fontWeight: FontWeight.w600,
            color: selected
                ? cs.onPrimary
                : cs.onSurface.withValues(alpha: 0.45),
          ),
        ),
      ),
    );
  }
}
