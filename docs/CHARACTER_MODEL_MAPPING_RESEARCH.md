# Mobile character source mapping research
**Source build:** Conquer Online Mobile 1.1.2.3  
**Audit workflow:** https://github.com/ZzwahwahzZ/Clash-of-Legends/actions/runs/41993772525  
**Mapping report artifact:** Character-Source-Mapping-Audit (metadata and extracted mapping values only)  
**Status:** PARTIALLY SOURCE-MAPPED — DO NOT TREAT C3 BODY PAIRS AS RUNTIME-ACCEPTED YET

## 1. Exact class-selection options in the mobile client

The APK's readable `rolechoose.ini` defines 18 role-selection slots. `proAni` gives the displayed role identity; `proIndex` maps each slot to the corresponding `selectcharacter.ini` vocation entry.

| Slot | Role animation/name | Vocation entry | Vocation label |
|---:|---|---:|---|
| 0 | Role_FemaleTaoist | 1 | Female Taoist |
| 1 | Role_MaleTaoist | 0 | Male Taoist |
| 2 | Role_FemaleWarrior | 7 | Female Warrior |
| 3 | Role_MaleWarrior | 6 | Male Warrior |
| 4 | Role_MalePirate | 12 | Male Pirate |
| 5 | Role_FemalePirate | 13 | Female Pirate |
| 6 | Role_FemaleArcher | 5 | Female Archer |
| 7 | Role_MaleArcher | 4 | Male Archer |
| 8 | Role_MaleLiXiaoong | 14 | Dragon-Warrior |
| 9 | Role_FemaleLiXiaoong | 15 | Dragon-Warrior |
| 10 | Role_Monk | 10 | Monk |
| 11 | Role_Saint | 11 | Saint |
| 12 | Role_MaleNinja | 8 | Male Ninja |
| 13 | Role_FemaleNinja | 9 | Female Ninja |
| 14 | Role_MaleTrojan | 2 | Male Trojan |
| 15 | Role_FemaleTrojan | 3 | Female Trojan |
| 16 | Role_View_17 | 17 | Windwalker |
| 17 | Role_View_18 | 16 | Windwalker |

This proves the source client has nine named class families in this selection screen: Taoist, Warrior, Pirate, Archer, Dragon-Warrior, Monk/Saint, Ninja, Trojan, and Windwalker. It does not contain a Thunderstriker selection in this 1.1.2.3 configuration.

## 2. Starter armor records and Look values

The readable `itemtype13.ini` records are `@@`-delimited, not INI sections. The field at zero-based index 59 contains the Look value for these starter armor records:

| Source item ID | Source item name | Description label | Look |
|---:|---|---|---:|
| 130000 | LeatherArmor | Trojan's Armor | 3000 |
| 131230 | KylinArmor | WarriorArmor | 3010 |
| 133080 | EagleCoat | Archer's Coat | 3060 |
| 134080 | RoyalGown | Taoist's Robe | 3050 |
| 135000 | LowerNinjaVest | Ninja's Vest | 3020 |
| 136000 | BurlapFrock | MonkFrock | 3030 |
| 139000 | RecruitCoat | PirateArmor | 3040 |

The source archive contains corresponding C3 body files in male/female ID families. The following pairs correlate with the Look values and are **candidate mappings** pending runtime verification:

| Look | Candidate male C3 body | Candidate female C3 body |
|---:|---|---|
| 3000 | `c3/body/7130000.c3` | `c3/body/8130000.c3` |
| 3010 | `c3/body/7131020.c3` | `c3/body/8131020.c3` |
| 3020 | `c3/body/7132000.c3` | `c3/body/8132000.c3` |
| 3030 | `c3/body/7133010.c3` | `c3/body/8133010.c3` |
| 3040 | `c3/body/7134010.c3` | `c3/body/8134010.c3` |
| 3050 | `c3/body/7135000.c3` | `c3/body/8135000.c3` |
| 3060 | `c3/body/7136000.c3` | `c3/body/8136000.c3` |

The C3 source inventory contains these body IDs, but the Look-to-file relationship has not yet been confirmed by observing the mobile client's runtime model resolver. Do not silently turn these candidates into accepted class assignments. Other body files also exist, including 7135020/8135020, 7138020/8138020, 7139000/8139000, and additional armor-specific variants.

## 3. C3 body-part and motion structure

The C3 parser audit found 2,189 parsed model files. In 1,631 files, the number of PHY meshes equals the number of MOTI chunks, supporting a per-mesh motion association. For example, some 18-mesh body models contain 18 MOTI chunks; the main body mesh can have a 66-bone static bind pose while accessory/body-part meshes have one-bone multi-key motion data.

The previous GLB exporter incorrectly reused `document.motions.first()` for every mesh. This froze or mis-transformed many parts and could suppress animation when the first MOTI chunk had only one key. The exporter is being changed to use the MOTI chunk matching each PHY mesh and to emit morph-weight animation channels. A Rust regression test and a stricter Godot import test now check that morph meshes and animation tracks survive import. This fix is not accepted until both CI tests pass on real source models.

The C3 body assets are not necessarily complete character models. The inspected `c3/body/7000000.c3` is a separate head-like mesh; the 713xxxx body models contain multiple body/equipment submeshes but may not include the head. Head, helmet, weapon, cape, mount, and other parts must be assembled using the source part order and verified transforms. A successful GLB import alone does not complete the character.

## 4. Additional role presentation and equipment data

- `3dsimplerole.ini` has Role0–Role7 selection-preview records with 3DSimpleObjID values 20001–20008, standby/blaze motion IDs, role sounds, and role-selection effects.
- Role100–Role115 contains 16 default appearance records with Look values 1–4 and Armor/Hair IDs. These are not yet reliably linked to the 18 rolechoose slots.
- `rolepartsort.xml` parses as 5 rules and 157 part nodes. Part names include `body`, `mix_body`, `armet`, `mix_armet`, `mix2_armet`, `r_weapon`, `l_weapon`, `cape`, `pelvis`, `spirit`, and `mount`. This is valuable source evidence for equipment layering order.
- `i3drole.dat` has a promising seed-9527 candidate Lua decode exposing helper names for weapon motion/effects, cloak look, hair lookup, and head-armor hiding. The cipher has not been verified against the Android client's reader.
- `cqm_createrole.dat` has a candidate Lua decode with default armor IDs including 134080, 131230, 139000, 133080, 138230, 136000, 135000, 130000, 101230, 102000, and 103990. The latter four are not yet cross-linked to itemtype Look values.

## 5. Mapping to the game's 11 target classes

The project's class roster intentionally differs from the 1.1.2.3 source roster:
- Trojan, Warrior, Archer, Ninja, Monk, Pirate, Dragon Warrior, and Windwalker can use the corresponding source class family as the starting reference.
- Water Taoist and Fire Taoist are two project branches built from the source Taoist family; separate skills, weapons, colors, and effects must not be confused with separate base skeletons.
- Thunderstriker is a project class not present in this 1.1.2.3 role-selection list; it needs an explicitly designed original model/rig or a separately verified later-version source.

The source selection labels Monk and Saint separately. The project's Monk class needs a deliberate mapping decision rather than assuming that both labels are interchangeable.

## 6. Runtime acceptance blockers

1. Confirm the Look-to-C3 body resolver using the Android client's model-loading code or a controlled rendered test.
2. Confirm male/female model pairing, skeleton names, animation compatibility, and attachment transforms.
3. Resolve Dragon-Warrior and Windwalker body paths from their role/default-armor records.
4. Decide how the source Monk/Saint pair maps to the project's Monk.
5. Create a custom, rigged Thunderstriker asset; do not borrow an unrelated class mesh.
6. Replace the current index-based model selection in `PlayerController.gd` only after the source mapping is verified. Never use arbitrary catalog array positions as class identity.

**Current implementation rule:** the source mappings in this report are research evidence. They are not yet authorized for runtime class assignment until the remaining checks above pass.
