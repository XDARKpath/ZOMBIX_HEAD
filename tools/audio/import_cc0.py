# Prende i suoni CC0 scaricati in audio_raw (fuori dal progetto) e li prepara per il gioco: un pezzo solo per file, silenzi tolti,
# code sfumate, volume uniforme per famiglia, musica con il loop chiuso. Scrive anche docs/AUDIO_LICENZE.md con l'origine di ogni file.
#   blender -b -P tools/audio/import_cc0.py -- <audio_raw> <progetto>
import os, sys, wave
import aud
import numpy as np

raw, project = sys.argv[sys.argv.index("--") + 1:][:2]
RATE = 44100
Z = "zombies-sound-pack"
GHOUL = "hungry-ghoul"
MOANS = "zombie-moans"
TROLL = "big-scary-troll-sounds"
SNARL = "monster-snarls"
GROWL = "16-monster-growls"
MON = "monster-sound-pack-volume-1"
CRE = "80-cc0-creature-sfx"
GUN = "the-free-firearm-sound-library"
BANG = "25-cc0-bang-firework-sfx"
HIT = "75-cc0-breaking-falling-hit-sfx"
WM = "100-cc0-metal-and-wood-sfx"
SWI = "swishes-sound-pack"
RPG = "50-rpg-sound-effects"
UI = "51-ui-sound-effects-buttons-switches-and-clicks"
SLI = "40-cc0-water-splash-slime-sfx"
STEP = "different-steps-on-wood-stone-leaves-gravel-and-mud"
RELO = "gun-reload-sounds"
SHELL = "shotgun-reload-sound-effects"
HAND = "handgun-reload-sound-effect"
PAIN = "grunts-male-death-and-pain"
BOOM = "synthesized-explosion"
MED = "medieval-sound-effects-weapon-textures"

MUSIC = {
    "menu": ("ambient-horror-track-01", "ambient_horror_track01.wav", -21.0, False, "Musica per schermate horror, loop perfetto"),
    "explore": ("horror-atmosphere", "wastelands_loop.ogg", -23.0, False, "Post Apocalyptic Wastelands, 5:23, loop perfetto"),
    "combat": ("bio-hazard-menustage", "biohazardsv3_0.ogg", -17.0, True, "Scritta per un gioco di zombie"),
    "boss_capomacello": ("heavy-boss-battle-1", "heavy_boss_battle_1_bpm200_0.ogg", -15.0, False, "Metal pesante da boss, 200 bpm, loop"),
    "boss_carceriere": ("determined-pursuit-epic-orchestra-loop", "determined_pursuit_loop.wav", -15.0, False, "Orchestra frenetica da boss, loop"),
    "boss_mago": ("basilisk-boss-battle-loop", "basilisk_boss_battle_in_game.ogg", -15.0, False, "Boss in tono oscuro, loop"),
    "boss_teste": ("the-plague", "The Plague.Wav", -15.0, True, "Elettronica apocalittica"),
}
# chiave: lista di [raccolta, file, pezzo (None = tutto), tono, durata massima]. Ogni voce diventa una variante.
def v(pack, name, part=None, pitch=1.0, most=3.5): return [pack, name, part, pitch, most]
def many(pack, names, part=None, pitch=1.0, most=3.5): return [v(pack, n, part, pitch, most) for n in names]
SFX = {
    # Infetto comune: lamenti e versi umani andati a male.
    "zombie_walker_idle": [v(MOANS, "darsycho__zombie-moans_0.ogg", k, 1.0, 3.2) for k in (0, 2, 4, 6)],
    "zombie_walker_alert": many(Z, ["zombie-16.wav", "zombie-17.wav", "zombie-21.wav"]),
    "zombie_walker_attack": many(Z, ["zombie-4.wav", "zombie-6.wav", "zombie-7.wav", "zombie-10.wav"]),
    "zombie_walker_hurt": many(Z, ["zombie-11.wav", "zombie-13.wav", "zombie-24.wav"]),
    "zombie_walker_death": many(Z, ["zombie-18.wav", "zombie-20.wav", "zombie-15.wav"], None, 0.88),
    # Corridore: più acuto e nervoso.
    "zombie_runner_idle": [v(GHOUL, "hungry-ghoul_0.ogg", k, 1.1, 2.2) for k in (0, 1, 2)],
    "zombie_runner_alert": many(GROWL, ["monster.16.ogg", "monster.11.ogg", "monster.6.ogg"]),
    "zombie_runner_attack": many(MON, ["Monster-2.wav", "Monster-1.wav", "monster-17.wav"]),
    "zombie_runner_hurt": many(MON, ["Monster-4.wav", "Monster-7.wav", "monster-12.wav"]),
    "zombie_runner_death": many(GROWL, ["monster.7.ogg", "monster.14.ogg"], None, 0.95),
    # Bruto: voce da troll, abbassata.
    "zombie_brute_idle": [v(TROLL, "troll-idle-noises_0.ogg", k, 0.86, 3.2) for k in (0, 2, 4)],
    "zombie_brute_alert": [v(TROLL, "troll-roars_0.ogg", k, 0.84, 3.0) for k in (0, 3)],
    "zombie_brute_attack": [v(TROLL, "scrapped-troll-sounds.ogg", k, 0.86, 2.0) for k in (0, 2, 4)],
    "zombie_brute_hurt": [v(TROLL, "scrapped-troll-sounds.ogg", k, 0.95, 1.4) for k in (1, 3)],
    "zombie_brute_death": [v(TROLL, "troll-roars_0.ogg", k, 0.72, 3.5) for k in (5, 6)],
    # Urlatrice: chiama gli altri.
    "zombie_elite_idle": [v(CRE, "breath.ogg", k, 1.0, 2.5) for k in (0, 1)] + many(CRE, ["nose.ogg"]),
    "zombie_elite_alert": many(CRE, ["scream_01.ogg", "scream_02.ogg"]),
    "zombie_elite_attack": many(CRE, ["monster_01.ogg", "monster_02.ogg", "monster_03.ogg"]),
    "zombie_elite_hurt": many(CRE, ["hurt_01.ogg", "hurt_02.ogg", "hurt_03.ogg"]),
    "zombie_elite_death": [v(CRE, "howl.ogg", None, 0.9), v(CRE, "howl.ogg", None, 0.78)],
    # Sputatore: gola piena.
    "zombie_spitter_idle": many(CRE, ["burble_01.ogg", "burble_02.ogg"]),
    "zombie_spitter_alert": many(CRE, ["cough_01.ogg", "cough_02.ogg"]),
    "zombie_spitter_attack": many(CRE, ["spit_01.ogg", "spit_02.ogg", "spit_03.ogg"]),
    "zombie_spitter_hurt": many(CRE, ["grunt_01.ogg", "grunt_02.ogg"]),
    "zombie_spitter_death": many(CRE, ["cough_03.ogg", "monster_06.ogg"], None, 0.85),
    # Carceriere e boss.
    "zombie_carceriere_idle": [v(TROLL, "troll-idle-noises_0.ogg", k, 0.68, 3.5) for k in (1, 3)],
    "zombie_carceriere_alert": many(CRE, ["roar_01.ogg", "roar_02.ogg"], None, 0.7),
    "zombie_carceriere_attack": [v(TROLL, "scrapped-troll-sounds.ogg", k, 0.7, 2.0) for k in (0, 2)],
    "zombie_carceriere_hurt": [v(TROLL, "scrapped-troll-sounds.ogg", 5, 0.75, 1.5)],
    "zombie_carceriere_death": [v(TROLL, "troll-roars_0.ogg", 4, 0.6, 3.5)],
    "boss_carceriere_roar": many(CRE, ["roar_01.ogg", "roar_03.ogg"], None, 0.66),
    "boss_carceriere_attack": [v(TROLL, "scrapped-troll-sounds.ogg", 2, 0.66, 2.0)],
    "boss_carceriere_death": [v(TROLL, "troll-roars_0.ogg", 6, 0.58, 3.5)],
    "boss_capomacello_roar": [v(TROLL, "troll-roars_0.ogg", 1, 0.8, 3.0), v(TROLL, "troll-roars_0.ogg", 2, 0.76, 3.0)],
    "boss_capomacello_attack": [v(SNARL, "monster-snarl-attack.ogg", k, 0.8, 1.8) for k in (0, 3, 6)],
    "boss_capomacello_death": [v(TROLL, "troll-roars_0.ogg", 5, 0.66, 3.5)],
    "boss_mago_roar": many(CRE, ["alien_01.ogg", "alien_02.ogg"], None, 0.8),
    "boss_mago_attack": many(CRE, ["alien_03.ogg", "alien_04.ogg"], None, 0.9),
    "boss_mago_death": many(CRE, ["weird_01.ogg"], None, 0.7),
    "boss_teste_roar": [v(SNARL, "monster-snarl-5.ogg", k, 0.85, 2.5) for k in (0, 2)],
    "boss_teste_attack": [v(SNARL, "monsters-snarls-3_0.ogg", k, 0.9, 1.6) for k in (0, 4, 8)],
    "boss_teste_death": many(CRE, ["monster_05.ogg"], None, 0.7),
    "zombie_step": many(STEP, ["gravel.ogg", "leaves01.ogg", "mud02.ogg"], 0, 0.9, 0.6),
    # Colpi d'arma: uno sparo vero per arma.
    "fire_pistol": [v(GUN, "X_39P.wav", 0, 1.0, 1.1)],
    "fire_revolver": [v(GUN, "V_27P.wav", 0, 0.95, 1.3)],
    "fire_flare_gun": [v(BANG, "shot_01.ogg", None, 1.0, 1.0)],
    "fire_nailgun": [v(GUN, "R_35P.wav", 0, 1.45, 0.22)],
    "fire_smg": [v(GUN, "G_31P.wav", 0, 1.0, 0.42)],
    "fire_assault_rifle": [v(GUN, "C_28P.wav", 0, 1.0, 0.55)],
    "fire_lmg": [v(GUN, "P_30P.wav", 0, 0.82, 0.5)],
    "fire_sniper_rifle": [v(GUN, "M_21P.wav", 0, 0.92, 2.0)],
    "fire_pump_shotgun": [v(GUN, "H_21P.wav", 0, 1.0, 1.6)],
    "fire_sawn_off": [v(GUN, "O_21P.wav", 0, 0.86, 1.6)],
    "fire_lever_rifle": [v(GUN, "I_22P.wav", 0, 1.0, 1.5)],
    "fire_crossbow": [v(MED, "Crossbow Shoot.wav", 5, 1.0, 0.7)],
    "weapon_reload_bolt": [v(MED, "Crossbow Place Bolt.wav", 0, 1.0, 1.2)],
    "fire_grenade_launcher": many(BANG, ["cannon_01.ogg"], None, 1.25, 1.4),
    "weapon_fire_pistol": [v(GUN, "X_39P.wav", 0, 1.0, 1.1)],
    "weapon_fire_rifle": [v(GUN, "C_28P.wav", 0, 1.0, 0.9)],
    "weapon_reload_pistol": [v(HAND, "reload.wav", None, 1.0, 2.2)],
    "weapon_reload_rifle": [v(RELO, "assaultriflereload1_0.wav", None, 1.0, 2.4)],
    "weapon_reload_shell": [v(SHELL, "4 Shell Reload.wav", None, 1.0, 3.0)],
    "gun_rack": [v(RELO, "shotguncock_0.wav", None, 1.0, 1.0)],
    "gun_empty": many(RPG, ["metalClick.ogg"], None, 1.2, 0.3),
    # Armi bianche.
    "swing_axe": [v(MED, "Axe Swing.wav", k, 0.94, 0.7) for k in (1, 2, 5, 6)],
    "swing_blade": [v(MED, "Katana Swing.wav", k, 1.0, 0.6) for k in (6, 4, 0)] + [v(MED, "Seax Swing.wav", 3, 0.9, 0.6)],
    "swing_blunt": [v(MED, "Spear Swing.wav", k, 0.76, 0.7) for k in (0, 1, 3)] + [v(MED, "Axe Swing.wav", 5, 0.78, 0.7)],
    "swing_knife": [v(MED, "Dagger Swing.wav", k, 1.05, 0.45) for k in (2, 3, 5)] + [v(MED, "Seax Swing.wav", 3, 1.1, 0.45)],
    "swing_shovel": [v(MED, "Spear Swing.wav", k, 0.8, 0.7) for k in (2, 3)],
    "weapon_hit_flesh": many(RPG, ["knifeSlice.ogg", "knifeSlice2.ogg", "chop.ogg"], None, 0.85, 0.6),
    "weapon_hit_head": many(HIT, ["bfh1_breaking_01.ogg", "bfh1_breaking_02.ogg"], None, 0.9, 0.7),
    "weapon_hit_bone": many(WM, ["wood_cracking_01.ogg", "wood_cracking_02.ogg"], None, 1.0, 0.6),
    "weapon_hit_guard": many(WM, ["metal_hit_01.ogg", "metal_hit_02.ogg"], None, 1.0, 0.6),
    "kick": many(HIT, ["bfh1_hit_01.ogg", "bfh1_hit_02.ogg"], None, 0.75, 0.5),
    "weapon_equip": [v(MED, "Katana Draw Fast.wav", 0, 1.0, 0.6), v(MED, "Katana Draw Fast.wav", 1, 1.0, 0.6), v(MED, "Dagger Draw Fast.wav", 0, 1.0, 0.5)],
    "bow_draw": [v(MED, "English Longbow Draw.wav", 1, 1.0, 1.2)],
    "bow_release": [v(MED, "English Longbow Shoot.wav", 0, 1.0, 0.6)],
    "arrow_impact": many(WM, ["wood_hit_01.ogg", "wood_hit_02.ogg"], None, 1.2, 0.4),
    "arrow_pickup": many(RPG, ["cloth1.ogg", "cloth2.ogg"], None, 1.0, 0.4),
    "player_hurt": [v(PAIN, "death pain grunts.wav", k, 1.0, 0.8) for k in (0, 1, 2, 3)],
    "player_death": [v(PAIN, "death pain grunts.wav", k, 0.96, 2.5) for k in (4, 5)],
    "boss_defeat": many(BANG, ["cannon_03.ogg"], None, 0.55, 3.0),
    "explosion": [v(BOOM, "synthetic_explosion_1.flac", None, 1.0, 2.5), v(BOOM, "synthetic_explosion_1.flac", None, 0.82, 2.8)],
    "footstep": many(RPG, ["footstep00.ogg", "footstep01.ogg", "footstep02.ogg", "footstep03.ogg", "footstep04.ogg"], None, 1.0, 0.5),
}
ROOT_SFX = {
    "menu_hover": many(UI, ["rollover1.ogg"], None, 1.0, 0.2),
    "menu_press": many(UI, ["click1.ogg"], None, 1.0, 0.25),
    "hit": many(RPG, ["knifeSlice.ogg"], None, 0.85, 0.5),
    "heavy": many(HIT, ["bfh1_breaking_03.ogg"], None, 0.85, 0.8),
    "swing": [v(MED, "Axe Swing.wav", 6, 1.0, 0.6)],
    "footstep": many(RPG, ["footstep00.ogg"], None, 1.0, 0.5),
}
# Rumore finale per famiglia, in dB sui 100 ms più forti: conta il colpo, non la coda.
def level(key):
    if key.startswith("fire_") or key.startswith("weapon_fire"): return -4.0
    if key.startswith("swing") or key in ("swing",): return -13.0
    if key.startswith("zombie_step") or key == "footstep": return -18.0
    if key.startswith("menu"): return -18.0
    if key == "boss_defeat" or key == "explosion": return -3.0
    if key.startswith("zombie") or key.startswith("boss"): return -9.0
    if "reload" in key or key.startswith("gun_") or key in ("weapon_equip", "arrow_pickup", "bow_draw"): return -15.0
    return -9.0


index = {}
for base, _, files in os.walk(raw):
    pack = os.path.relpath(base, raw).split(os.sep)[0]
    for f in files:
        if not f.startswith("._") and "__MACOSX" not in base:
            index.setdefault((pack, f), os.path.join(base, f))
missing, credits = [], {}


def load(pack, name):
    path = index.get((pack, name))
    if path is None:
        # Le estensioni variano da raccolta a raccolta.
        stem = os.path.splitext(name)[0]
        for (p, f), full in index.items():
            if p == pack and os.path.splitext(f)[0].lower() == stem.lower():
                path = full
                break
    if path is None:
        missing.append(pack + "/" + name)
        return None, 0
    s = aud.Sound(path)
    return s.data().astype(np.float32), int(s.specs[0])


def mono(d):
    return d.mean(axis=1) if d.ndim > 1 else d


def resample(x, ratio):
    if abs(ratio - 1.0) < 1e-3: return x
    if ratio > 1.2:
        # Prima di scendere di frequenza si tolgono gli ultrasuoni, che altrimenti tornano come fruscio.
        k = np.ones(int(round(ratio))) / int(round(ratio))
        x = np.convolve(np.convolve(x, k, "same"), k, "same")
    n = int(x.size / ratio)
    return np.interp(np.arange(n) * ratio, np.arange(x.size), x)


def parts_of(x, rate):
    win = int(rate * 0.02)
    n = x.size // win
    env = np.sqrt((x[: n * win].reshape(n, win) ** 2).mean(axis=1))
    gate = max(env.max() * 0.07, 1e-3)
    runs, start, quiet = [], None, 0
    for i, e in enumerate(env):
        if e > gate:
            if start is None: start = i
            quiet = 0
        elif start is not None:
            quiet += 1
            if quiet * 0.02 > 0.16:
                if (i - quiet - start) * 0.02 >= 0.02: runs.append((start * win, (i - quiet + 3) * win))
                start, quiet = None, 0
    if start is not None: runs.append((start * win, x.size))
    return runs or [(0, x.size)]


def prepare(row, key):
    pack, name, part, pitch, most = row
    d, rate = load(pack, name)
    if d is None: return None
    credits.setdefault(pack, set()).add(os.path.basename(name))
    x = mono(d)
    runs = parts_of(x, rate)
    a, b = runs[part % len(runs)] if part is not None else (runs[0][0], runs[-1][1])
    if name.startswith("swish"):
        # Un fendente cresce e si spegne piano: va tenuto intero, tagliando solo il silenzio vero.
        loud = np.nonzero(np.abs(x) > np.abs(x).max() * 0.012)[0]
        a, b = int(loud[0]), int(loud[-1]) + 1
    if "Swing" in name or "Draw Fast" in name:
        # Il fendente vero è più lungo del suo picco: si tiene tutto il soffio attorno al colpo.
        top = a + int(np.abs(x[a:b]).argmax())
        low = np.abs(x[a:b]).max() * 0.02
        around = np.convolve(np.abs(x[max(0, top - int(rate * 0.35)) : top + int(rate * 0.55)]), np.ones(int(rate * 0.005)) / int(rate * 0.005), "same")
        keep = np.nonzero(around > low)[0]
        a, b = max(0, top - int(rate * 0.35)) + int(keep[0]), max(0, top - int(rate * 0.35)) + int(keep[-1]) + 1
    shot = key.startswith("fire_") or key.startswith("weapon_fire") or key == "bow_release"
    if shot:
        # Lo sparo parte sul colpo più forte del file: niente ritardo fra il grilletto e il suono.
        top = int(np.abs(x).argmax())
        back = np.nonzero(np.abs(x[max(0, top - int(rate * 0.04)) : top + 1]) > np.abs(x[top]) * 0.1)[0]
        a = max(0, top - int(rate * 0.04)) + int(back[0])
        b = x.size
    x = x[max(0, a - int(rate * 0.004)) : b]
    x = resample(x, rate / RATE * pitch)
    x = x[: int(most * RATE)]
    fade = min(int(0.14 * RATE), x.size // 3)
    x[-fade:] *= np.linspace(1, 0, fade) ** 1.5
    lead = min(int(0.003 * RATE), x.size // 4)
    x[:lead] *= np.linspace(0, 1, lead)
    x = x - x.mean()
    win = max(1, int(0.1 * RATE))
    env = np.array([np.sqrt((x[i:i + win] ** 2).mean()) for i in range(0, max(1, x.size - win // 2), win // 2)])
    x = x * 10 ** (level(key) / 20) / max(float(env.max()), 1e-4)
    # Limitatore morbido: i colpi restano pieni senza distorcere.
    x = np.tanh(x * 1.05) / np.tanh(1.05) if np.abs(x).max() > 1.0 else x
    return np.clip(x, -0.98, 0.98)


def save_wav(path, x):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes((x * 32767).astype(np.int16).tobytes())


# --- Rumore sintetico per le due armi senza un equivalente reale.
def noise_tail(seconds, seed):
    rng = np.random.default_rng(seed)
    return rng.standard_normal(int(seconds * RATE))


def tesla():
    t = np.arange(int(0.42 * RATE)) / RATE
    buzz = np.sign(np.sin(2 * np.pi * 118 * t)) * 0.35 + np.sin(2 * np.pi * 1860 * t + 7 * np.sin(2 * np.pi * 37 * t)) * 0.3
    crack = noise_tail(0.42, 3) * (np.random.default_rng(4).random(t.size) > 0.992)
    x = (buzz + crack * 1.6) * np.exp(-t * 6.5)
    return np.clip(x * 1.5, -0.98, 0.98)


def blower():
    t = np.arange(int(0.5 * RATE)) / RATE
    air = np.convolve(noise_tail(0.5, 5), np.ones(14) / 14, "same") * 1.5
    x = (air + np.sin(2 * np.pi * 142 * t) * 0.16) * np.minimum(t / 0.02, 1) * np.minimum((t[-1] - t) / 0.08, 1)
    return np.clip(x * 0.55, -0.9, 0.9)


made = 0
folder = os.path.join(project, "audio", "sfx")
for key, rows in SFX.items():
    for i, row in enumerate(rows):
        x = prepare(row, key)
        if x is None: continue
        save_wav(os.path.join(folder, key + ("" if i == 0 else "_%d" % (i + 1)) + ".wav"), x)
        made += 1
for key, rows in ROOT_SFX.items():
    x = prepare(rows[0], key)
    if x is not None:
        save_wav(os.path.join(project, "audio", key + ".wav"), x)
        made += 1
save_wav(os.path.join(folder, "fire_tesla_rifle.wav"), tesla())
save_wav(os.path.join(folder, "fire_leaf_blower.wav"), blower())

# --- Suoni continui: mono, in ogg, con il giro chiuso da una dissolvenza.
def loop_ogg(path, x, over):
    over = min(int(over * RATE), x.size // 3)
    ramp = np.linspace(0, 1, over)
    x = x.copy()
    x[:over] = x[:over] * np.sqrt(ramp) + x[-over:] * np.sqrt(1 - ramp)
    x = x[:-over]
    aud.Sound.buffer(x[:, None].astype(np.float32), RATE).write(path, RATE, aud.CHANNELS_MONO, aud.FORMAT_FLOAT32, aud.CONTAINER_OGG, aud.CODEC_VORBIS, 96000, 128)


def clip_of(pack, name, start, seconds, target):
    d, rate = load(pack, name)
    credits.setdefault(pack, set()).add(name)
    x = mono(d)
    x = x[int(start * rate) : int((start + seconds) * rate)]
    x = resample(x, rate / RATE)
    x = x - x.mean()
    return x * 10 ** (target / 20) / max(float(np.sqrt((x ** 2).mean())), 1e-4)


wind = clip_of("park-ambiences", "park_ambience_wind.wav", 20, 94, -24.0)
crick = clip_of("cricket-sounds", "cricketsounds090613.wav", 2, 30, -40.0)
wind[:crick.size * 3] += np.tile(crick, 3)[:wind.size]
loop_ogg(os.path.join(project, "audio", "forest.ogg"), np.clip(wind, -0.95, 0.95), 4.0)
loop_ogg(os.path.join(project, "audio", "fire.ogg"), np.clip(clip_of("fireplace-sound-loop", "fire.wav", 3, 40, -20.0), -0.95, 0.95), 1.5)
loop_ogg(os.path.join(project, "audio", "vehicle_engine.ogg"), np.clip(clip_of("racing-car-engine-sound-loops", "loop_0.wav", 0, 30, -18.0), -0.95, 0.95), 0.1)
print("PEZZI dolore", len(parts_of(mono(load(PAIN, "death pain grunts.wav")[0]), load(PAIN, "death pain grunts.wav")[1])))

# --- Musica: stereo, volume per scena, loop chiuso con una dissolvenza incrociata se l'autore non l'ha già chiuso.
for key, (pack, name, target, close_loop, why) in MUSIC.items():
    d, rate = load(pack, name)
    if d is None: continue
    credits.setdefault(pack, set()).add(os.path.basename(name))
    if d.ndim == 1: d = np.stack([d, d], axis=1)
    if rate != RATE:
        d = np.stack([np.interp(np.arange(int(d.shape[0] * RATE / rate)) * rate / RATE, np.arange(d.shape[0]), d[:, c]) for c in range(2)], axis=1).astype(np.float32)
    if close_loop:
        over = int(2.5 * RATE)
        ramp = np.linspace(0, 1, over)[:, None]
        d[:over] = d[:over] * np.sqrt(ramp) + d[-over:] * np.sqrt(1 - ramp)
        d = d[:-over]
    rms = float(np.sqrt((d ** 2).mean()))
    gain = 10 ** (target / 20) / max(rms, 1e-4)
    gain = min(gain, 0.97 / float(np.abs(d).max()))
    d = d * gain
    path = os.path.join(project, "audio", "music", key + ".ogg")
    aud.Sound.buffer(d.astype(np.float32), RATE).write(path, RATE, aud.CHANNELS_STEREO, aud.FORMAT_FLOAT32, aud.CONTAINER_OGG, aud.CODEC_VORBIS, 160000, 128)
    print("MUSICA", key, round(d.shape[0] / RATE, 1), "s guadagno", round(gain, 2), why)
    made += 1

print("FILE", made)
print("MANCANO", missing)
lines = ["# Licenze dell'audio", "", "Tutti i suoni qui sotto sono CC0 (nessun obbligo, uso commerciale permesso), controllati sulla pagina di origine il 7 novembre 2026. `fire_tesla_rifle` e `fire_leaf_blower` sono generati da `tools/audio/import_cc0.py`. I file scaricati stanno in `audio_raw`, fuori dal progetto, ognuno con il suo LICENZA.txt.", "", "| Raccolta | Pagina | File usati |", "|---|---|---|"]
for pack in sorted(credits):
    lines.append("| %s | https://opengameart.org/content/%s | %s |" % (pack, pack, ", ".join(sorted(credits[pack]))))
lines += ["", "## Musica", "", "| Scena | Brano | Perché |", "|---|---|---|"]
for key, row in MUSIC.items(): lines.append("| %s | %s (%s) | %s |" % (key, row[1], row[0], row[4]))
open(os.path.join(project, "docs", "AUDIO_LICENZE.md"), "w", encoding="utf-8").write("\n".join(lines) + "\n")
print("FINE")
