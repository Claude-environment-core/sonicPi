# ============================================================================
# "SKYLINE" -- an EDM song skeleton for Sonic Pi
# ============================================================================
# A ~3 minute progressive/big-room house arrangement:
#   Intro -> Build 1 -> Drop 1 -> Breakdown -> Build 2 -> Drop 2 -> Outro
#
# Press Run to hear the whole track -- it arranges and stops itself
# automatically after the outro. Everything is driven off a single
# `:section` flag set by the :arranger loop, so it's easy to live-code:
# tweak a synth/sample/fx in any loop below and re-run.
# ============================================================================

use_bpm 128
use_random_seed 42

# --- Song map (bars; 4 beats per bar @ 128 bpm => 1 bar = 1.875s) ---------
INTRO_BARS     = 8
BUILD1_BARS    = 8
DROP1_BARS     = 20
BREAKDOWN_BARS = 16
BUILD2_BARS    = 8
DROP2_BARS     = 24
OUTRO_BARS     = 12
# total = 96 bars = 180s = exactly 3:00

# --- Harmony: Am - F - C - G, one chord per bar, cycling every 4 bars ----
PROGRESSION = [
  {root: :a3, chord: :minor},
  {root: :f3, chord: :major},
  {root: :c3, chord: :major},
  {root: :g3, chord: :major}
]

set :section, :intro

# --- One-shot "fills" the arranger triggers at section transitions -------
define :riser_sweep do |beats|
  with_fx :reverb, room: 0.7, mix: 0.4 do
    with_fx :hpf, cutoff: 60 do |hpf|
      n = synth :noise, sustain: beats - 0.25, release: 0.25, amp: 0.001
      steps = 24
      steps.times do |i|
        ratio = (i + 1) / steps.to_f
        control n, amp: 0.001 + (ratio ** 2) * 0.6
        control hpf, cutoff: 60 + ratio * 70
        sleep beats / steps.to_f
      end
    end
  end
end

define :drop_impact do
  sample :bd_boom, amp: 2, rate: 0.8
  sample :perc_bell, amp: 1.2, rate: 0.6
end

# --- Arranger: drives the timeline via the :section flag ------------------
live_loop :arranger do
  set :section, :intro
  sleep INTRO_BARS * 4

  set :section, :build1
  in_thread(name: :riser1) { riser_sweep(BUILD1_BARS * 4) }
  sleep BUILD1_BARS * 4

  in_thread(name: :impact1) { drop_impact }
  set :section, :drop1
  sleep DROP1_BARS * 4

  set :section, :breakdown
  sleep BREAKDOWN_BARS * 4

  set :section, :build2
  in_thread(name: :riser2) { riser_sweep(BUILD2_BARS * 4) }
  sleep BUILD2_BARS * 4

  in_thread(name: :impact2) { drop_impact }
  set :section, :drop2
  sleep DROP2_BARS * 4

  set :section, :outro
  sleep OUTRO_BARS * 4

  set :section, :finished
  stop
end

# --- Kick: four-on-the-floor once the energy kicks in ---------------------
live_loop :kick do
  s = get(:section)
  if [:build1, :drop1, :build2, :drop2].include?(s)
    amp = [:drop1, :drop2].include?(s) ? 1.4 : 0.9
    sample :bd_haus, amp: amp
  end
  sleep 1
end

# --- Clap/snare on the backbeat, drops only --------------------------------
live_loop :snare do
  beat = tick
  s = get(:section)
  if [:drop1, :drop2].include?(s) && (beat % 4 == 1 || beat % 4 == 3)
    sample :sn_dolf, amp: 1.1
  end
  sleep 1
end

# --- Hats: driving 8ths everywhere except the breakdown --------------------
live_loop :hats do
  s = get(:section)
  unless s == :breakdown
    amp = [:drop1, :drop2].include?(s) ? 0.6 : 0.3
    sample :drum_cymbal_closed, amp: amp
  end
  sleep 0.5
end

# --- Bass: follows the chord roots, filtered up for the drops --------------
live_loop :bass do
  bar = tick
  s = get(:section)
  chord_data = PROGRESSION[bar % 4]
  if [:build1, :drop1, :build2, :drop2].include?(s)
    cutoff = [:drop1, :drop2].include?(s) ? 110 : 80
    with_fx :lpf, cutoff: cutoff do
      use_synth :tb303
      4.times do
        play chord_data[:root], release: 0.22, cutoff: 100, amp: 0.9, res: 0.3
        sleep 1
      end
    end
  else
    sleep 4
  end
end

# --- Pad: sustained chords for glue and atmosphere -------------------------
live_loop :pad do
  bar = tick
  s = get(:section)
  chord_data = PROGRESSION[bar % 4]
  amp = [:drop1, :drop2].include?(s) ? 0.25 : 0.5
  with_fx :reverb, room: 0.8, mix: 0.35 do
    use_synth :hollow
    play chord(chord_data[:root], chord_data[:chord]), sustain: 3.5, release: 0.5, amp: amp
  end
  sleep 4
end

# --- Lead/pluck arpeggio: drops only -----------------------------------
live_loop :lead do
  bar = tick
  s = get(:section)
  chord_data = PROGRESSION[bar % 4]
  if [:drop1, :drop2].include?(s)
    notes = chord(chord_data[:root], chord_data[:chord], num_octaves: 2)
    use_synth :pluck
    with_fx :echo, phase: 0.1875, decay: 1.5, mix: 0.25 do
      8.times do
        play notes.choose, amp: 0.5, release: 0.3, cutoff: 110
        sleep 0.5
      end
    end
  else
    sleep 4
  end
end
