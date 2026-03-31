/// Represents a selectable Hanuman Chalisa audio track with its paired lyrics.
class AudioTrack {
  final String id;
  final String name;
  final String description;
  final String assetPath;
  final String lyricsPath;

  /// Maps JSON cue times onto playback clock. `1.0` = no change.
  /// Values below 1 (e.g. 0.74) **delay** each line boundary on the timeline so the
  /// highlight does not run ahead of chant-style recordings where line starts in JSON
  /// pack slightly early relative to heard audio.
  final double lyricSyncCurveExponent;

  /// Shifts the clock used **only** for lyric lookup (positive = treat playback as earlier).
  final Duration lyricSyncClockLead;

  const AudioTrack({
    required this.id,
    required this.name,
    required this.description,
    required this.assetPath,
    required this.lyricsPath,
    this.lyricSyncCurveExponent = 1.0,
    this.lyricSyncClockLead = Duration.zero,
  });
}

/// All available audio tracks in display order.
const List<AudioTrack> kAudioTracks = [
  AudioTrack(
    id: 'traditional',
    name: 'Traditional Devotional',
    description: 'Classical devotional rendition',
    assetPath: 'assets/audio/hc_real.mp3',
    lyricsPath: 'assets/lyrics/hanuman_chalisa.json',
  ),
  AudioTrack(
    id: 'male',
    name: 'Male Recitation',
    description: 'Sacred chant · male voice',
    assetPath: 'assets/audio/hc_male_final.mp3',
    lyricsPath: 'assets/lyrics/hc_male.json',
    lyricSyncCurveExponent: 0.86,
    lyricSyncClockLead: Duration(milliseconds: 220),
  ),
  AudioTrack(
    id: 'female',
    name: 'Female Recitation',
    description: 'Sacred chant · female voice',
    assetPath: 'assets/audio/hc_female_final.mp3',
    lyricsPath: 'assets/lyrics/hc_female.json',
    lyricSyncCurveExponent: 0.91,
    lyricSyncClockLead: Duration(milliseconds: 175),
  ),
];

/// Look up a track by [id]. Falls back to the traditional track if not found.
AudioTrack trackById(String? id) =>
    kAudioTracks.firstWhere((t) => t.id == id, orElse: () => kAudioTracks[0]);
