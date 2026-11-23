class_name StrikeLibrary
extends RefCounted

## Every strike animation, by id: the attacks (one per attacking piece, keyed by its
## art key) and the victim reactions, listed explicitly (content is never discovered
## by scanning folders; see docs/CONTENT_ARCHITECTURE.md). Also decides which
## reaction a strike plays.

const ATTACKS := {
	&"knight": preload("res://scripts/battle/strike/attacks/KnightStrike.gd"),
	&"bishop": preload("res://scripts/battle/strike/attacks/BishopStrike.gd"),
	&"rook": preload("res://scripts/battle/strike/attacks/RookStrike.gd"),
	&"pawn": preload("res://scripts/battle/strike/attacks/PawnStrike.gd"),
	&"queen": preload("res://scripts/battle/strike/attacks/QueenStrike.gd"),
	&"king": preload("res://scripts/battle/strike/attacks/KingStrike.gd"),
	&"assassin": preload("res://scripts/battle/strike/attacks/AssassinStrike.gd"),
	&"bowman": preload("res://scripts/battle/strike/attacks/BowmanStrike.gd"),
	&"catapult": preload("res://scripts/battle/strike/attacks/CatapultStrike.gd"),
	&"lancer": preload("res://scripts/battle/strike/attacks/LancerStrike.gd"),
	&"portal_mage": preload("res://scripts/battle/strike/attacks/PortalMageStrike.gd"),
	&"royal_guard": preload("res://scripts/battle/strike/attacks/RoyalGuardStrike.gd"),
	&"centaur": preload("res://scripts/battle/strike/attacks/CentaurStrike.gd"),
	&"unicorn_cavalry": preload("res://scripts/battle/strike/attacks/UnicornCavalryStrike.gd"),
	&"gryphon": preload("res://scripts/battle/strike/attacks/GryphonStrike.gd"),
	&"manticore": preload("res://scripts/battle/strike/attacks/ManticoreStrike.gd"),
	&"archmage": preload("res://scripts/battle/strike/attacks/ArchmageStrike.gd"),
	&"swift_courier": preload("res://scripts/battle/strike/attacks/SwiftCourierStrike.gd"),
	&"tide_knight": preload("res://scripts/battle/strike/attacks/TideKnightStrike.gd"),
	&"echo": preload("res://scripts/battle/strike/attacks/EchoStrike.gd"),
	&"chameleon": preload("res://scripts/battle/strike/attacks/ChameleonStrike.gd"),
	&"sentry": preload("res://scripts/battle/strike/attacks/SentryStrike.gd"),
	&"falconer": preload("res://scripts/battle/strike/attacks/FalconerStrike.gd"),
	&"vanguard": preload("res://scripts/battle/strike/attacks/VanguardStrike.gd"),
	&"squire": preload("res://scripts/battle/strike/attacks/SquireStrike.gd"),
	&"stand_in": preload("res://scripts/battle/strike/attacks/StandInStrike.gd"),
	&"powder_keg": preload("res://scripts/battle/strike/attacks/PowderKegStrike.gd"),
	&"ember_bird": preload("res://scripts/battle/strike/attacks/EmberBirdStrike.gd"),
	&"gargoyle": preload("res://scripts/battle/strike/attacks/GargoyleStrike.gd"),
	&"crystal_mage": preload("res://scripts/battle/strike/attacks/CrystalMageStrike.gd"),
	&"ranger": preload("res://scripts/battle/strike/attacks/RangerStrike.gd"),
	&"sun_moon_monk": preload("res://scripts/battle/strike/attacks/SunMoonMonkStrike.gd"),
	&"antelope": preload("res://scripts/battle/strike/attacks/AntelopeStrike.gd"),
	&"war_king": preload("res://scripts/battle/strike/attacks/WarKingStrike.gd"),
	&"shadow_king": preload("res://scripts/battle/strike/attacks/ShadowKingStrike.gd"),
	&"shield_king": preload("res://scripts/battle/strike/attacks/ShieldKingStrike.gd"),
	&"lantern_bearer": preload("res://scripts/battle/strike/attacks/LanternBearerStrike.gd"),
	&"martyr": preload("res://scripts/battle/strike/attacks/MartyrStrike.gd"),
	&"stone_giant": preload("res://scripts/battle/strike/attacks/StoneGiantStrike.gd"),
	&"blast_catapult": preload("res://scripts/battle/strike/attacks/BlastCatapultStrike.gd"),
	&"sky_archer": preload("res://scripts/battle/strike/attacks/SkyArcherStrike.gd"),
	&"flame_phoenix": preload("res://scripts/battle/strike/attacks/FlamePhoenixStrike.gd"),
	&"thousand_faces": preload("res://scripts/battle/strike/attacks/ThousandFacesStrike.gd"),
}

const REACTIONS := {
	&"slash_shatter": preload("res://scripts/battle/strike/reactions/SlashShatterReaction.gd"),
	&"slash_split": preload("res://scripts/battle/strike/reactions/SlashSplitReaction.gd"),
	&"slash_split_heavy": preload("res://scripts/battle/strike/reactions/SlashSplitHeavyReaction.gd"),
	&"blunt_fly": preload("res://scripts/battle/strike/reactions/BluntFlyReaction.gd"),
	&"low_fly": preload("res://scripts/battle/strike/reactions/LowFlyReaction.gd"),
	&"quick_tip": preload("res://scripts/battle/strike/reactions/QuickTipReaction.gd"),
	&"underdog": preload("res://scripts/battle/strike/reactions/UnderdogReaction.gd"),
	&"blunt_crack": preload("res://scripts/battle/strike/reactions/BluntCrackReaction.gd"),
	&"crush_flat": preload("res://scripts/battle/strike/reactions/CrushFlatReaction.gd"),
	&"crush_collapse": preload("res://scripts/battle/strike/reactions/CrushCollapseReaction.gd"),
	&"crush_sink": preload("res://scripts/battle/strike/reactions/CrushSinkReaction.gd"),
	&"pierce_knock": preload("res://scripts/battle/strike/reactions/PierceKnockReaction.gd"),
	&"hole": preload("res://scripts/battle/strike/reactions/HoleReaction.gd"),
	&"hole_heavy": preload("res://scripts/battle/strike/reactions/HoleHeavyReaction.gd"),
	&"vortex": preload("res://scripts/battle/strike/reactions/VortexReaction.gd"),
	&"grab": preload("res://scripts/battle/strike/reactions/GrabReaction.gd"),
	&"rake": preload("res://scripts/battle/strike/reactions/RakeReaction.gd"),
	&"venom": preload("res://scripts/battle/strike/reactions/VenomReaction.gd"),
	&"arcane": preload("res://scripts/battle/strike/reactions/ArcaneReaction.gd"),
	&"swallow": preload("res://scripts/battle/strike/reactions/SwallowReaction.gd"),
	&"radiance": preload("res://scripts/battle/strike/reactions/RadianceReaction.gd"),
	&"resonance": preload("res://scripts/battle/strike/reactions/ResonanceReaction.gd"),
	&"burn": preload("res://scripts/battle/strike/reactions/BurnReaction.gd"),
	&"erupt": preload("res://scripts/battle/strike/reactions/EruptReaction.gd"),
	&"toss": preload("res://scripts/battle/strike/reactions/TossReaction.gd"),
	&"flatten": preload("res://scripts/battle/strike/reactions/FlattenReaction.gd"),
	&"blast": preload("res://scripts/battle/strike/reactions/BlastReaction.gd"),
	&"skewer": preload("res://scripts/battle/strike/reactions/SkewerReaction.gd"),
	&"inferno": preload("res://scripts/battle/strike/reactions/InfernoReaction.gd"),
	&"mimic": preload("res://scripts/battle/strike/reactions/MimicReaction.gd"),
	&"keg": preload("res://scripts/battle/strike/reactions/KegReaction.gd"),
	&"ember": preload("res://scripts/battle/strike/reactions/EmberReaction.gd"),
	&"shell": preload("res://scripts/battle/strike/reactions/ShellReaction.gd"),
	&"glass": preload("res://scripts/battle/strike/reactions/GlassReaction.gd"),
	&"halo": preload("res://scripts/battle/strike/reactions/HaloReaction.gd"),
	&"chip": preload("res://scripts/battle/strike/reactions/ChipReaction.gd"),
	&"rebirth": preload("res://scripts/battle/strike/reactions/RebirthReaction.gd"),
}

## Hybrid pieces that strike like a knight when they make a knight-shaped move.
const KNIGHT_HYBRIDS := [&"lancer", &"centaur", &"unicorn_cavalry"]

## Pieces whose capture always plays their own reaction, whoever captures them.
const VICTIM_REACTIONS := {
	&"powder_keg": &"keg", &"ember_bird": &"ember", &"gargoyle": &"shell", &"crystal_mage": &"glass",
	&"martyr": &"halo", &"stone_giant": &"chip", &"flame_phoenix": &"rebirth",
	&"ember_egg": &"glass", &"phoenix_egg": &"shell",
}

static func has_attack(attack_id: StringName) -> bool:
	return ATTACKS.has(attack_id)

static func make_attack(attack_id: StringName) -> StrikeAttack:
	return (ATTACKS[attack_id] as GDScript).new() as StrikeAttack

## The reaction for `reaction_id`; an unknown id gets the plain base reaction.
static func make_reaction(reaction_id: StringName) -> StrikeReaction:
	var script: GDScript = REACTIONS.get(reaction_id, StrikeReaction) as GDScript
	return script.new() as StrikeReaction

## Which attack plays for this move: [attack id, strike type]. Hybrid pieces that make a
## knight-shaped move borrow the knight's stomp; everything else keeps its own attack.
static func resolve_attack(attacker_id: StringName, strike_type: int, from: Vector2i, to: Vector2i) -> Array:
	var delta: Vector2i = (to - from).abs()
	var knight_shaped: bool = (delta.x == 1 and delta.y == 2) or (delta.x == 2 and delta.y == 1)
	if attacker_id in KNIGHT_HYBRIDS and knight_shaped:
		return [&"knight", PieceDef.StrikeType.CRUSH]
	return [attacker_id, strike_type]

## The reaction a strike of `strike_type` plays on a victim, by the two weight classes.
static func reaction_for(strike_type: int, attacker_weight: int, victim_weight: int) -> StringName:
	var weight: int = clampi(victim_weight, 0, 2)
	match strike_type:
		PieceDef.StrikeType.SLASH:
			return [&"slash_shatter", &"slash_split", &"slash_split_heavy"][weight]
		PieceDef.StrikeType.CRUSH:
			return [&"crush_flat", &"crush_collapse", &"crush_sink"][weight]
		PieceDef.StrikeType.PIERCE:
			return [&"pierce_knock", &"hole", &"hole_heavy"][weight]
		PieceDef.StrikeType.VOID:
			return &"vortex"
		PieceDef.StrikeType.GRAB:
			# Too heavy to carry off: the talons rake it in two instead.
			return &"rake" if weight == 2 else &"grab"
		PieceDef.StrikeType.VENOM:
			return &"venom"
		PieceDef.StrikeType.ARCANE:
			return &"arcane"
		PieceDef.StrikeType.DEVOUR: return &"swallow"
		PieceDef.StrikeType.HOLY: return &"radiance"
		PieceDef.StrikeType.RESONANCE: return &"resonance"
		PieceDef.StrikeType.BURN: return &"burn"
		PieceDef.StrikeType.ERUPT: return &"erupt"
		PieceDef.StrikeType.TOSS: return &"toss"
		PieceDef.StrikeType.FLATTEN: return &"flatten"
		PieceDef.StrikeType.BLAST: return &"blast"
		PieceDef.StrikeType.SKEWER: return &"skewer"
		PieceDef.StrikeType.INFERNO: return &"inferno"
		PieceDef.StrikeType.MIMIC: return &"mimic"
	if weight == 0:
		return &"blunt_fly"
	if weight == 1:
		return &"low_fly" if attacker_weight > weight else &"quick_tip"
	return &"blunt_crack" if attacker_weight >= weight else &"underdog"

## The reaction a captured piece always plays, or &"" to use the attacker's.
static func victim_reaction(victim_id: StringName) -> StringName:
	var definition: PieceDef = Content.piece(String(victim_id))
	var key: StringName = StringName(definition.art_key()) if definition != null else victim_id
	return VICTIM_REACTIONS.get(key, &"")
