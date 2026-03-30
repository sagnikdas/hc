/// Represents a selectable Hanuman Chalisa audio track with its paired lyrics.
class AudioTrack {
  final String id;
  final String name;
  final String description;
  final String assetPath;
  final String lyricsPath;

  const AudioTrack({
    required this.id,
    required this.name,
    required this.description,
    required this.assetPath,
    required this.lyricsPath,
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
  ),
  AudioTrack(
    id: 'female',
    name: 'Female Recitation',
    description: 'Sacred chant · female voice',
    assetPath: 'assets/audio/hc_female_final.mp3',
    lyricsPath: 'assets/lyrics/hc_female.json',
  ),
];

/// Look up a track by [id]. Falls back to the traditional track if not found.
AudioTrack trackById(String? id) =>
    kAudioTracks.firstWhere((t) => t.id == id, orElse: () => kAudioTracks[0]);
