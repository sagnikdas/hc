#!/usr/bin/env python3
"""
Generate synchronized lyrics JSON files for Hanuman Chalisa audio tracks.

Uses ffmpeg silencedetect to find speech segment boundaries in each MP3,
then maps them to the known SSML/lyrics structure.

Usage:
    python3 scripts/generate_lyrics.py

Outputs:
    assets/lyrics/hc_male.json
    assets/lyrics/hc_female.json
"""

import json
import re
import subprocess
import sys
from pathlib import Path

# ── Lyrics content ─────────────────────────────────────────────────────────────
# 89 entries matching the SSML structure (॥दोहा॥ + 4 verses + ॥चौपाई॥ + 80 + closing ॥दोहा॥ + 2)

LYRICS = [
    # Opening Doha
    {"text": "॥ दोहा ॥",                                                       "en": "|| Doha ||"},
    {"text": "श्रीगुरु चरन सरोज रज, निज मनु मुकुरु सुधारि।",                  "en": "Shri Guru Charan Saroj Raj, Nij Man Mukur Sudhari,"},
    {"text": "बरनउँ रघुबर बिमल जसु, जो दायकु फल चारि॥",                      "en": "Baranau Raghubar Bimal Jasu, Jo Dayaku Phal Chari."},
    {"text": "बुद्धिहीन तनु जानिके, सुमिरौं पवन-कुमार।",                      "en": "Buddhihin Tanu Jaanike, Sumiron Pawan Kumar,"},
    {"text": "बल बुद्धि बिद्या देहु मोहिं, हरहु कलेस बिकार॥",                "en": "Bal Buddhi Vidya Dehu Mohi, Harahu Kales Bikar."},
    # Chaupai header
    {"text": "॥ चौपाई ॥",                                                       "en": "|| Chaupai ||"},
    # 80 Chaupai lines
    {"text": "जय हनुमान ज्ञान गुन सागर।",                                      "en": "Jai Hanuman Gyan Gun Sagar,"},
    {"text": "जय कपीस तिहुँ लोक उजागर॥ १॥",                                   "en": "Jai Kapees Tihu Lok Ujagar. (1)"},
    {"text": "राम दूत अतुलित बल धामा।",                                        "en": "Ram Doot Atoolit Bal Dhama,"},
    {"text": "अञ्जनि-पुत्र पवनसुत नामा॥ २॥",                                  "en": "Anjani Putra Pavanasoota Nama. (2)"},
    {"text": "महाबीर बिक्रम बजरंगी।",                                          "en": "Mahabeer Bikram Bajrangi,"},
    {"text": "कुमति निवार सुमति के संगी॥ ३॥",                                  "en": "Kumati Niwar Sumati Ke Sangi. (3)"},
    {"text": "कञ्चन बरन बिराज सुबेसा।",                                        "en": "Kanchan Baran Biraj Subesa,"},
    {"text": "कानन कुण्डल कुञ्चित केसा॥ ४॥",                                  "en": "Kanan Kundal Kunchit Kesa. (4)"},
    {"text": "हाथ बज्र औ ध्वजा बिराजै।",                                      "en": "Haath Bajra Au Dhwaja Birajai,"},
    {"text": "काँधे मूँज जनेऊ साजै॥ ५॥",                                      "en": "Kaandhe Moonj Janeu Sajai. (5)"},
    {"text": "संकर सुवन केसरीनन्दन।",                                          "en": "Shankar Suvan Kesarinandan,"},
    {"text": "तेज प्रताप महा जग बन्दन॥ ६॥",                                   "en": "Tej Pratap Maha Jag Bandan. (6)"},
    {"text": "विद्यावान गुनी अति चातुर।",                                      "en": "Vidyavaan Guni Ati Chatur,"},
    {"text": "राम काज करिबे को आतुर॥ ७॥",                                     "en": "Ram Kaaj Karibe Ko Atur. (7)"},
    {"text": "प्रभु चरित्र सुनिबे को रसिया।",                                  "en": "Prabhu Charitra Sunibe Ko Rasiya,"},
    {"text": "राम लखन सीता मन बसिया॥ ८॥",                                     "en": "Ram Lakhan Sita Man Basiya. (8)"},
    {"text": "सूक्ष्म रूप धरि सियहिं दिखावा।",                                "en": "Sukshma Roop Dhari Siyahi Dikhawa,"},
    {"text": "बिकट रूप धरि लंक जरावा॥ ९॥",                                   "en": "Bikat Roop Dhari Lanka Jarawa. (9)"},
    {"text": "भीम रूप धरि असुर सँहारे।",                                      "en": "Bheem Roop Dhari Asur Sanhare,"},
    {"text": "रामचन्द्र के काज सँवारे॥ १०॥",                                  "en": "Ramchandra Ke Kaaj Sanware. (10)"},
    {"text": "लाय सञ्जीवन लखन जियाये।",                                       "en": "Laay Sanjeevan Lakhan Jiyaye,"},
    {"text": "श्री रघुबीर हरषि उर लाये॥ ११॥",                                 "en": "Shri Raghubeer Harashi Ur Laaye. (11)"},
    {"text": "रघुपति कीन्ही बहुत बड़ाई।",                                     "en": "Raghupati Kinhi Bahut Badaai,"},
    {"text": "तुम मम प्रिय भरतहि सम भाई॥ १२॥",                               "en": "Tum Mam Priya Bharatahi Sam Bhai. (12)"},
    {"text": "सहस बदन तुम्हरो जस गावैं।",                                     "en": "Sahas Badan Tumharo Jas Gavain,"},
    {"text": "अस कहि श्रीपति कण्ठ लगावैं॥ १३॥",                              "en": "As Kahi Shripati Kanth Lagavain. (13)"},
    {"text": "सनकादिक ब्रह्मादि मुनीसा।",                                     "en": "Sankaadik Brahmadi Munisa,"},
    {"text": "नारद-सारद सहित अहीसा॥ १४॥",                                    "en": "Narad Saarad Sahit Ahisa. (14)"},
    {"text": "जम कुबेर दिगपाल जहाँ ते।",                                      "en": "Jam Kuber Digpal Jahan Te,"},
    {"text": "कबि कोबिद कहि सके कहाँ ते॥ १५॥",                               "en": "Kabi Kobid Kahi Sake Kahan Te. (15)"},
    {"text": "तुम उपकार सुग्रीवहिं कीन्हा।",                                  "en": "Tum Upkar Sugreevahi Kinha,"},
    {"text": "राम मिलाय राजपद दीन्हा॥ १६॥",                                  "en": "Ram Milaay Rajpad Dinha. (16)"},
    {"text": "तुम्हरो मन्त्र बिभीषन माना।",                                   "en": "Tumharo Mantra Bibhishan Maana,"},
    {"text": "लंकेस्वर भए सब जग जाना॥ १७॥",                                  "en": "Lankeshwar Bhaye Sab Jag Jaana. (17)"},
    {"text": "जुग सहस्र जोजन पर भानू।",                                       "en": "Jug Sahastra Jojan Par Bhanu,"},
    {"text": "लील्यो ताहि मधुर फल जानू॥ १८॥",                                "en": "Lilyo Taahi Madhur Phal Jaanu. (18)"},
    {"text": "प्रभु मुद्रिका मेलि मुख माहीं।",                                "en": "Prabhu Mudrika Meli Mukh Mahi,"},
    {"text": "जलधि लाँघि गये अचरज नाहीं॥ १९॥",                               "en": "Jaladhi Laanghi Gaye Acharaj Nahi. (19)"},
    {"text": "दुर्गम काज जगत के जेते।",                                       "en": "Durgam Kaaj Jagat Ke Jete,"},
    {"text": "सुगम अनुग्रह तुम्हरे तेते॥ २०॥",                               "en": "Sugam Anugraha Tumhare Tete. (20)"},
    {"text": "राम दुआरे तुम रखवारे।",                                         "en": "Ram Duaare Tum Rakhwaare,"},
    {"text": "होत न आज्ञा बिनु पैसारे॥ २१॥",                                 "en": "Hot Na Agya Binu Paisare. (21)"},
    {"text": "सब सुख लहैं तुम्हारी सरना।",                                   "en": "Sab Sukh Lahe Tumhari Sarna,"},
    {"text": "तुम रक्षक काहू को डरना॥ २२॥",                                  "en": "Tum Rakshak Kahu Ko Darna. (22)"},
    {"text": "आपन तेज सम्हारो आपै।",                                         "en": "Aapan Tej Samharo Aapai,"},
    {"text": "तीनों लोक हाँक तें काँपै॥ २३॥",                                "en": "Teeno Lok Haank Te Kaampai. (23)"},
    {"text": "भूत पिसाच निकट नहिं आवै।",                                     "en": "Bhoot Pisaach Nikat Nahi Aavai,"},
    {"text": "महाबीर जब नाम सुनावै॥ २४॥",                                    "en": "Mahabeer Jab Naam Sunavai. (24)"},
    {"text": "नासै रोग हरै सब पीरा।",                                         "en": "Naasai Rog Harai Sab Pira,"},
    {"text": "जपत निरन्तर हनुमत बीरा॥ २५॥",                                  "en": "Japat Nirantar Hanumat Bira. (25)"},
    {"text": "संकट तें हनुमान छुड़ावै।",                                      "en": "Sankat Te Hanuman Chhuravai,"},
    {"text": "मन क्रम बचन ध्यान जो लावै॥ २६॥",                              "en": "Man Kram Bachan Dhyan Jo Lavai. (26)"},
    {"text": "सब पर राम तपस्वी राजा।",                                       "en": "Sab Par Ram Tapasvi Raja,"},
    {"text": "तिनके काज सकल तुम साजा॥ २७॥",                                  "en": "Tinke Kaaj Sakal Tum Saaja. (27)"},
    {"text": "और मनोरथ जो कोई लावै।",                                        "en": "Aur Manorath Jo Koi Lavai,"},
    {"text": "सोई अमित जीवन फल पावै॥ २८॥",                                  "en": "Soi Amit Jeevan Phal Pavai. (28)"},
    {"text": "चारों जुग परताप तुम्हारा।",                                     "en": "Charon Jug Partap Tumhara,"},
    {"text": "है परसिद्ध जगत उजियारा॥ २९॥",                                  "en": "Hai Parsiddh Jagat Ujiyara. (29)"},
    {"text": "साधु-सन्त के तुम रखवारे।",                                     "en": "Sadhu Sant Ke Tum Rakhware,"},
    {"text": "असुर निकन्दन राम दुलारे॥ ३०॥",                                 "en": "Asur Nikandan Ram Dulare. (30)"},
    {"text": "अष्टसिद्धि नव निधि के दाता।",                                  "en": "Ashta Siddhi Nava Nidhi Ke Daata,"},
    {"text": "अस बर दीन्ह जानकी माता॥ ३१॥",                                  "en": "As Bar Dinh Janaki Mata. (31)"},
    {"text": "राम रसायन तुम्हरे पासा।",                                       "en": "Ram Rasayan Tumhare Paasa,"},
    {"text": "सदा रहो रघुपति के दासा॥ ३२॥",                                  "en": "Sada Raho Raghupati Ke Dasa. (32)"},
    {"text": "तुम्हरे भजन राम को पावै।",                                      "en": "Tumhare Bhajan Ram Ko Pavai,"},
    {"text": "जनम-जनम के दुख बिसरावै॥ ३३॥",                                  "en": "Janam Janam Ke Dukh Bisravai. (33)"},
    {"text": "अन्त काल रघुबर पुर जाई।",                                      "en": "Ant Kaal Raghubar Pur Jaai,"},
    {"text": "जहाँ जन्म हरि-भक्त कहाई॥ ३४॥",                                "en": "Jahan Janam Hari Bhakt Kahai. (34)"},
    {"text": "और देवता चित्त न धरई।",                                        "en": "Aur Devata Chitt Na Dharai,"},
    {"text": "हनुमत सेई सर्ब सुख करई॥ ३५॥",                                 "en": "Hanumat Sei Sarb Sukh Karai. (35)"},
    {"text": "संकट कटै मिटै सब पीरा।",                                       "en": "Sankat Katai Mitai Sab Pira,"},
    {"text": "जो सुमिरै हनुमत बलबीरा॥ ३६॥",                                 "en": "Jo Sumirai Hanumat Balbira. (36)"},
    {"text": "जय जय जय हनुमान गोसाईं।",                                      "en": "Jai Jai Jai Hanuman Gosain,"},
    {"text": "कृपा करहु गुरुदेव की नाईं॥ ३७॥",                              "en": "Kripa Karahu Gurudev Ki Naain. (37)"},
    {"text": "जो सत बार पाठ कर कोई।",                                        "en": "Jo Sat Baar Path Kar Koi,"},
    {"text": "छूटहि बन्दि महा सुख होई॥ ३८॥",                                "en": "Chutahi Bandi Maha Sukh Hoi. (38)"},
    {"text": "जो यह पढ़ै हनुमान चालीसा।",                                    "en": "Jo Yah Padhai Hanuman Chalisa,"},
    {"text": "होय सिद्धि साखी गौरीसा॥ ३९॥",                                 "en": "Hoy Siddhi Sakhi Gaurisa. (39)"},
    {"text": "तुलसीदास सदा हरि चेरा।",                                       "en": "Tulsidas Sada Hari Chera,"},
    {"text": "कीजै नाथ हृदय मँह डेरा॥ ४०॥",                                 "en": "Kijai Nath Hriday Mah Dera. (40)"},
    # Closing Doha
    {"text": "॥ दोहा ॥",                                                       "en": "|| Doha ||"},
    {"text": "पवनतनय संकट हरन, मंगल मूरति रूप।",                             "en": "Pavanataney Sankat Haran, Mangal Moorti Roop,"},
    {"text": "राम लखन सीता सहित, हृदय बसहु सुर भूप॥",                        "en": "Ram Lakhan Sita Sahit, Hriday Basahu Sur Bhoop."},
]

assert len(LYRICS) == 89, f"Expected 89 lyrics entries, got {len(LYRICS)}"


def detect_silences(audio_path: str, threshold_db: float = -35, min_duration: float = 0.25) -> list[float]:
    """Run ffmpeg silencedetect and return sorted list of silence_end timestamps."""
    cmd = [
        "ffmpeg", "-i", audio_path,
        "-af", f"silencedetect=noise={threshold_db}dB:d={min_duration}",
        "-f", "null", "-",
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    ends = []
    for line in result.stderr.splitlines():
        m = re.search(r"silence_end:\s*([\d.]+)", line)
        if m:
            ends.append(float(m.group(1)))
    return sorted(ends)


def get_duration(audio_path: str) -> float:
    """Get audio file duration in seconds."""
    cmd = ["ffprobe", "-v", "quiet", "-show_entries", "format=duration",
           "-of", "default=noprint_wrappers=1", audio_path]
    result = subprocess.run(cmd, capture_output=True, text=True)
    for line in result.stdout.splitlines():
        if line.startswith("duration="):
            return float(line.split("=")[1])
    raise ValueError(f"Could not get duration for {audio_path}")


def filter_silences(silences: list[float], expected: int, min_speech_gap: float = 1.3) -> list[float]:
    """
    Filter out intra-verse silences so the count matches expected.

    Strategy:
    1. Remove silences where the gap from the previous silence is < min_speech_gap
       (these are pairs where the earlier silence is an intra-verse mid-break).
       We keep the LATER of each close pair (the real verse-end break).
    2. If still too many, remove silences with shortest durations.
    """
    if not silences:
        return silences

    # Step 1: remove silences that come too soon after the previous one
    # We mark the EARLIER silence for removal when gap to next < min_speech_gap
    to_remove = set()
    for i in range(len(silences) - 1):
        if silences[i + 1] - silences[i] < min_speech_gap and i not in to_remove:
            # The earlier silence (i) is the intra-verse pause; remove it
            # But only if removing it won't make things worse
            to_remove.add(i)

    filtered = [s for i, s in enumerate(silences) if i not in to_remove]

    # Step 2: if still too many, remove shortest-duration silences
    # We don't have duration data here, so we estimate duration as gap to NEXT silence
    # (shorter "held" position = shorter silence = more likely intra-verse)
    while len(filtered) > expected:
        # Compute pseudo-durations as gap from current to next silence
        # (heuristic: intra-verse silences tend to be followed quickly)
        if len(filtered) < 2:
            break
        gaps_to_next = []
        for i in range(len(filtered) - 1):
            gaps_to_next.append((filtered[i + 1] - filtered[i], i))
        gaps_to_next.append((float('inf'), len(filtered) - 1))  # last entry
        # Remove the entry with smallest gap_to_next (most suspicious)
        gaps_to_next.sort()
        idx_to_remove = gaps_to_next[0][1]
        filtered.pop(idx_to_remove)

    return filtered


def map_silences_to_timestamps(silences: list[float]) -> list[float]:
    """
    Map 89 silence_end timestamps to 89 lyric line start times.

    Structure:
      silence[0] → end of ॥दोहा॥ header break → JSON[0] & JSON[1] share this time
      silence[1] → end of doha verse 1 break   → JSON[2]
      silence[2] → end of doha verse 2 break   → JSON[3]
      silence[3] → end of doha verse 3 break   → JSON[4]
      silence[4] → end of doha verse 4 break   → (chaupai header starts speaking)
      silence[5] → end of chaupai header break → JSON[5] & JSON[6] share this time
      silence[6..84] → end of chaupai 2..80    → JSON[7..85]
      silence[85] → end of last chaupai break  → JSON[86] (closing ॥दोहा॥ header starts speaking)
      silence[86] → end of closing header break → JSON[87]
      silence[87] → end of closing verse 1 break → JSON[88]
      silence[88] → end of closing verse 2 break → (end of content)
    """
    assert len(silences) == 89, f"Need exactly 89 silences, got {len(silences)}"

    timestamps = [0.0] * 89

    # Opening doha
    timestamps[0] = silences[0]   # ॥ दोहा ॥ header (shares time with verse 1)
    timestamps[1] = silences[0]   # doha verse 1
    timestamps[2] = silences[1]   # doha verse 2
    timestamps[3] = silences[2]   # doha verse 3
    timestamps[4] = silences[3]   # doha verse 4

    # Chaupai header + 80 chaupai lines
    timestamps[5] = silences[5]   # ॥ चौपाई ॥ header (shares time with chaupai 1)
    timestamps[6] = silences[5]   # chaupai 1
    for k in range(1, 80):        # chaupai 2..80
        timestamps[6 + k] = silences[5 + k]

    # Closing doha
    timestamps[86] = silences[85]  # closing ॥ दोहा ॥ header (its own time)
    timestamps[87] = silences[86]  # closing verse 1
    timestamps[88] = silences[87]  # closing verse 2

    return timestamps


def generate_json(silences: list[float], duration: float, title: str) -> dict:
    """Generate the lyrics JSON dict from 89 silence_end timestamps."""
    timestamps = map_silences_to_timestamps(silences)
    lines = []
    for i, (lyric, ts) in enumerate(zip(LYRICS, timestamps)):
        lines.append({
            "startSeconds": round(ts, 2),
            "text": lyric["text"],
            "en": lyric["en"],
        })
    return {
        "title": title,
        "totalDurationSeconds": round(duration),
        "lines": lines,
    }


def process_track(audio_path: str, out_path: str, title: str,
                  silence_threshold: float, min_duration: float,
                  expected_silences: int = 89, skip_trailing: int = 0):
    """Full pipeline for one audio track."""
    print(f"\n{'='*60}")
    print(f"Processing: {audio_path}")
    print(f"Output:     {out_path}")

    duration = get_duration(audio_path)
    print(f"Duration:   {duration:.2f}s")

    raw = detect_silences(audio_path, threshold_db=silence_threshold, min_duration=min_duration)
    print(f"Raw silences detected (d={min_duration}): {len(raw)}")

    # Trim known trailing silences at the end
    silences = raw[:len(raw) - skip_trailing] if skip_trailing else raw
    print(f"After trimming {skip_trailing} trailing: {len(silences)}")

    if len(silences) != expected_silences:
        print(f"Need {expected_silences}, filtering...")
        silences = filter_silences(silences, expected_silences)
        print(f"After filtering: {len(silences)}")

    if len(silences) != expected_silences:
        print(f"WARNING: Could not get exactly {expected_silences} silences "
              f"(have {len(silences)}). Falling back to interpolation for missing entries.")
        # Pad or trim to expected
        while len(silences) < expected_silences:
            # Interpolate: add a point between the two most-spaced entries
            gaps = [(silences[i+1]-silences[i], i) for i in range(len(silences)-1)]
            gaps.sort(reverse=True)
            idx = gaps[0][1]
            mid = (silences[idx] + silences[idx+1]) / 2
            silences.insert(idx+1, mid)
        while len(silences) > expected_silences:
            silences.pop()

    data = generate_json(silences, duration, title)

    out = Path(out_path)
    out.parent.mkdir(parents=True, exist_ok=True)
    with open(out, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    print(f"Written {len(data['lines'])} lines → {out}")

    # Print first/last few entries for verification
    print("\nFirst 5 entries:")
    for e in data["lines"][:5]:
        print(f"  {e['startSeconds']:7.2f}s  {e['text'][:40]}")
    print("  ...")
    print("Last 5 entries:")
    for e in data["lines"][-5:]:
        print(f"  {e['startSeconds']:7.2f}s  {e['text'][:40]}")


def main():
    base = Path(__file__).parent.parent  # repo root

    # ── Male track ─────────────────────────────────────────────────────────────
    # d=0.25 gives 98 silences (1 initial + 89 structural + 6 intra-verse + 1 trailing + more)
    # After filtering short-gap silences and trimming 1 trailing → target 89
    process_track(
        audio_path=str(base / "assets/audio/hc_male_final.mp3"),
        out_path=str(base / "assets/lyrics/hc_male.json"),
        title="Hanuman Chalisa — Male Recitation",
        silence_threshold=-35,
        min_duration=0.25,
        expected_silences=89,
        skip_trailing=1,  # drop the last (trailing) silence
    )

    # ── Female track ───────────────────────────────────────────────────────────
    # d=0.5 gives exactly 90 silences (89 structural + 1 trailing)
    process_track(
        audio_path=str(base / "assets/audio/hc_female_final.mp3"),
        out_path=str(base / "assets/lyrics/hc_female.json"),
        title="Hanuman Chalisa — Female Recitation",
        silence_threshold=-35,
        min_duration=0.5,
        expected_silences=89,
        skip_trailing=1,  # drop the last (trailing) silence
    )


if __name__ == "__main__":
    main()
