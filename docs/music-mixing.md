# Runtime soundtrack mixing

The five original recordings are unchanged. The transport in
`scripts/soundtrack.gd` plans both automatic and manual transitions. The audio
node renders that plan; it does not run an independent fade timer.

- Manual changes wait for the next beat (under 1.1 seconds). Automatic changes
  start two bars before the source arrangement ends, before its release tail.
- Bar-wise chroma measurements choose among accompaniment-led entry points in
  the existing recordings. The previous/restart control still starts at zero.
- Track gains use measured EBU R128 integrated loudness, targeting -18 LUFS
  before the runtime effects and personal volume controls.
- Six EQ bands use complementary equal-power envelopes. Bass changes over a
  short central interval, melodic frequencies over a wider interval, and upper
  texture over the whole transition. This reduces competing rhythms and leads.
- Tempo differences within 14% use playback-rate adjustment with reciprocal
  pitch compensation. The incoming tempo matches through the first half and
  smoothly returns to its natural tempo in the second. Larger differences use
  natural tempo and the spectral handoff rather than heavy stretching.
- A dry/wet handoff near natural tempo avoids Godot's abrupt pitch-shifter
  bypass at pitch scale 1. Processing latency is compensated on the wet path.

The host sends the incoming play generation, outgoing voices, source positions,
per-band starting gains, transition elapsed time, duration, and tempo ratio.
Clients extrapolate the same plan, including on late join or reconnect. Pause
freezes the complete plan. Repeated selections retain audible outgoing voices;
inaudible pending entries are discarded. Leaving a room retains the current
transport, including its blend, so menu navigation does not restart playback.
Multiplayer protocol 11 prevents older clients from interpreting the new plan
as the previous volume-only fade.

`tools/analyze_soundtrack.py` regenerates `scripts/soundtrack_analysis.gd` using
NumPy and FFmpeg. It reads recordings and writes metadata only. The generated
GDScript resource is included in exports without a runtime analysis dependency.

The targeted checks are `music_transition_test.gd`, `music_test.gd`,
`music_network_test.gd`, `music_ui_test.gd`, and `run_music_process_test.py`.
`music_mix_capture.gd -- /tmp/mix.wav` records manual transitions through the
real Godot mixer; add `--automatic` for the last-to-first playlist transition.
These checks establish timing, continuity, and synchronization, not a guarantee
that every pair of distinct musical arrangements will sound indistinguishable.

References informing the implementation:

- [Mixxx: beatmatching, cue points, and Auto DJ](https://manual.mixxx.org/2.6/en/chapters/djing_with_mixxx)
- [Automatic DJ system: timing and EQ-controlled transitions](https://lenvdv.github.io/2018-03-20-autodj/)
- [Signalsmith: energy-preserving crossfades](https://signalsmith-audio.co.uk/writing/2021/cheap-energy-crossfade/)
- [Godot AudioEffectEQ6](https://docs.godotengine.org/en/stable/classes/class_audioeffecteq6.html)
- [Godot AudioEffectPitchShift](https://docs.godotengine.org/en/stable/classes/class_audioeffectpitchshift.html)
