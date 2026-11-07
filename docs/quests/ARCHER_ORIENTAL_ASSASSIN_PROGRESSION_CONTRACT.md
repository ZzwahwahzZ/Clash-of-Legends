# Archer → Oriental Assassin — Player Character Preservation Contract

**Research date:** 2026-11-07  
**Reference client:** Conquer Online Mobile, pinned target `com.Tq.CQ2ClientAndroid` versionName `1.1.2.3`, versionCode `123`.  
**Evidence status:** Mobile-official mechanics documented; exact promotion quest script, client IDs and APK 1.1.2.3 runtime mapping remain unresolved.  
**Project rule:** The player's primary character is an Archer. Do not replace, reset, split, delete or downgrade this character when Oriental Assassin is unlocked.

## 1. Identity and progression are one character

The Archer and Oriental Assassin are two combat forms / paths of the same Archer character, not two separately created characters and not a class reroll. Preserve one character identity, save slot, level, experience, attributes, inventory, quest history, social identity and progression state.

**Level-40 evidence distinction:** Level 40 is the owner's required promotion milestone for this project. The currently located official Archer skill page independently lists Level 40 as the unlock requirement for Mortal Wound skill rank 0; it does **not** state that Path of Shadow itself unlocks at Level 40 or publish the promotion quest. A separate official **PC** Conquer class guide says an Archer becomes an Oriental Assassin after promotion at Level 40, and the PC promotion guide names Archer God/Storm Master. These are `OTHER_CLIENT_COMPARISON` evidence only; they corroborate the concept but do not prove the Mobile NPC, quest script, requirements, or rewards. Therefore, retain the owner's level-40 promotion requirement as the target behavior, but keep the exact Mobile quest gate and source mapping unresolved until verified in the pinned Mobile client. Do not import PC NPC IDs, item requirements, titles, or rewards as Mobile truth, and do not misrepresent Mortal Wound's level requirement as proof of the Mobile promotion quest.

The official Mobile skill guide documents **Path of Shadow** as the reversible form toggle: it transforms the Archer into an Oriental Assassin, allows use of the equipped Throwing Knife, disables skills requiring a Bow while transformed, and toggles back to normal Archer form when activated again.

Do not treat the word “promotion” as proof that the character permanently changes into a separate class. The Mobile skill description establishes a reversible form switch.

## 2. Weapon and skill compatibility

### Archer form
- Primary weapon family: Bow (two-handed in the official equipment type guide).
- Archer-specific equipment includes Archer Hat and Archer Coat.
- Bow-dependent skills must require a Bow to be equipped. The Mobile guide explicitly marks Fly and Scatter as Bow-required.
- Do not permit Bow-only skills while the character is in Oriental Assassin form.

### Oriental Assassin form
- Weapon used by the transformation: equipped Throwing Knife (one-handed in the official equipment type guide).
- Path of Shadow enables the Oriental Assassin form and its Throwing Knife use.
- Assassin-exclusive skills documented by the Mobile Archer skill guide:
  - **Mortal Wound** — single-target multi-knife attack; 12 Stamina. Rank 0: 420% at Level 40; rank 1: 450% at 60; rank 2: 470% at 80; rank 3: 500% at 100; rank 4: 520%.
  - **Kinetic Spark** — toggleable chi effect; 42% trigger chance at Level 50, 44% at 60, 46% at 70, 54% at 80 and 80% at 90; can affect up to six nearby enemies, with 20% less damage per additional target.
  - **Blistering Wave** — area attack, 12 Stamina; 280% at Level 70, 300% at 80 and 90, 330% at 100, 350% at 110.
  - **Spirit Focus** — 5-second channel, cannot move while charging; attack power 250% at Level 90, 260% at 95, 280% at 100, 300% at 110, 320% max.
  - **Dagger Storm** — four-second area attack, 10-second cooldown; 300% at Level 100, 350% at 105, 400% at 110, 450% at 115, 500% at 120.
  - **Blade Flurry** — Oriental Assassin XP skill; lasts 40 seconds, increases movement speed by 50%, deals 300% damage to monsters and 200% to human targets.
- Bow-specific skills explicitly documented:
  - **Fly** — requires an equipped Bow; lasts 40 seconds at rank 0 or 60 seconds at rank 1; costs 100 Stamina.
  - **Scatter** — requires an equipped Bow; range 13, costs 10 Stamina; rank damage 50% at Level 32, 55% at 48, 60% at 54, 65% at 66, 68% at 72 and 72% max.
- These are separate skill eligibility rules, not cosmetic renames of Archer skills.

### Form switch invariants
- One character owns both forms after the unlock.
- Keep both weapon loadouts/items in inventory/equipment state; switching form must not destroy, sell, overwrite or silently unequip the other form's weapon.
- Entering Oriental Assassin form requires a valid equipped Throwing Knife according to the verified Mobile rule. If unavailable, fail safely and explain the missing equipment; do not auto-create or substitute a weapon.
- Returning to Archer form restores Bow-compatible skill availability. If no Bow is equipped, show the normal equipment requirement rather than granting free weapon use.
- Skill buttons, targeting, animation, attack range, weapon model, effects and skill eligibility must follow the active form.
- Preserve each form's learned skill levels and unlocks on the same character save. Never reset Archer skills when Assassin skills become available.
- Persist active form and equipment consistently across save/load; validate equipment compatibility before restoring the form.

## 3. Archer progression and questline

The Archer is the user's intended main character. Its level-up and quest progression must be complete and playable, including:
- Archer starter/tutorial and class introduction tasks;
- all source-verified Archer-specific quests and promotion tasks;
- level-40 promotion/unlock chain for Oriental Assassin;
- the promotion NPC, prerequisites, dialogue, acceptance/turn-in branches, required items, reward claims and failure/retry behavior exactly as supported by the pinned Mobile client;
- subsequent Archer/Oriental Assassin skill unlock and training milestones;
- all quest tracker, speech-bubble, NPC dialogue and world navigation connections for those steps.

**Important evidence boundary:** The official Mobile sources located so far document the Archer skill mechanics and the reversible transformation, but do not yet provide the full level-40 Archer promotion quest script, exact NPC/quest IDs, complete dialogue choices or reward payload. Do not invent these. Keep the questline at `DISCOVERED` / `SOURCE_CAPTURED` until the original Mobile guide/client records are located and mapped.

The quest UI must remain the existing Conquer Mobile-style UI already required by the project. Do not replace it with a simplified custom quest screen. The quest progression system and world HUD are connected; the quest step must drive the correct objective marker/path request while preserving original NPC dialogue and speech bubbles.

## 4. Data model requirements

Keep one character record and represent the form state explicitly. This is an engine integration proposal, not a claim about the original client's internal schema:

```json
{
  "character_identity": "single_archer_character",
  "base_class": "archer",
  "unlocked_forms": ["archer"],
  "active_form": "archer",
  "form_unlocks": {
    "oriental_assassin": {
      "required_level": 40,
      "required_promotion_quest_id": null,
      "unlock_status": "UNRESOLVED"
    }
  },
  "equipment_loadouts": {
    "archer": { "weapon_family": "bow" },
    "oriental_assassin": { "weapon_family": "throwing_knife" }
  },
  "form_skill_sets": {
    "archer": [],
    "oriental_assassin": []
  }
}
```

Do not ship null IDs as runtime values. The schema above only defines the relationship and separation. Populate IDs, requirements, rewards, skill records, animations and exact compatibility from the pinned Mobile data.

## 5. Acceptance tests — only after source mapping

1. Create one Archer character and verify identity/save key remains constant through the entire progression.
2. Before level 40 / before the required promotion chain is complete, Oriental Assassin form is unavailable.
3. Complete the verified level-40 chain; receive exactly the source-defined unlock/rewards once.
4. Activate Path of Shadow with a valid Throwing Knife; the same character changes form and weapon presentation.
5. In Assassin form, Bow-required Fly and Scatter cannot be activated.
6. In Archer form, Assassin-only skills cannot be activated; the Archer's Bow-dependent skills work when a Bow is equipped.
7. Switch back and forth repeatedly; no item duplication, item loss, skill reset, quest reset, level change or character replacement.
8. Save and reload in each form; restore a valid form/loadout or fail safely if equipment is missing.
9. Verify each form's skill unlock levels, costs, damage, cooldowns and effects against the Mobile guide and pinned client.
10. Verify promotion dialogue, NPC bubbles, quest tracker and navigation target against the original client before approval.

A visual mock, a successful code build, or a PC guide is not sufficient evidence for Mobile acceptance.

## 6. Mobile official sources

- Archer skills / Oriental Assassin transformation (2023-02-02): https://comobile.99.com/guide/info/classes/2023-02-02/skill_-_archer.shtml
- Equipment types (2023-02-15): https://comobile.99.com/guide/info/equipment/2023-02-15/equipment_-_equipment_type.shtml
- Mobile guide index: https://comobile.99.com/guide/info/info.shtml

The skill guide is direct evidence for Path of Shadow, the reversible form change, Throwing Knife use, Bow-skill incompatibility and the named Oriental Assassin skills. The equipment guide identifies Bow as a two-handed weapon and Throwing Knife as a one-handed weapon, and lists Archer-specific headgear/armor. Neither source alone supplies the full level-40 promotion quest record.

## 7. Admission status

Current status: **MOBILE_OFFICIAL mechanics documented; client mapping and full questline unresolved.**

Do not mark this progression implemented or approved until the pinned APK's quest/promotion data, NPC and item identifiers, skill records, dialogue branches and Android runtime behavior have been verified.


## 8. Implementation progress in Clash of Legends

The following first-pass protections have now been committed to `stage/phase1-world-assets`:

- `ClassProgressionManager` no longer unlocks the Assassin path merely because the character reaches level 40. The unlock entry point requires a completed, reward-claimed, source-verified promotion result with a non-empty source quest key. This adapter is not yet connected to a real Mobile promotion quest because its exact quest record is still unresolved.
- Unlocking the alternate path does not change the active Bow form. Selecting Bow always restores the Archer form; selecting Throwing Knives selects Oriental Assassin. Save/load reconstructs the form from the saved active style, not merely from the fact that the alternate path is unlocked.
- `PlayerInventory` now retains separate Bow and Throwing Knife loadouts. A player can prepare the inactive weapon without replacing the currently equipped weapon; switching form stores the outgoing weapon and restores the incoming weapon. The inactive loadout is serialized with the inventory, and the existing SettingsUI save/load payload already carries both `class_progression` and `inventory`; load restores the progression style and then the saved inventory loadouts.
- `Path of Shadow` is registered as a source-documented form-toggle skill. It is gated behind the promotion unlock and requires a Throwing Knife in the saved Assassin loadout. Activating it swaps the active form and weapon; activating it again returns to Archer.
- The existing HUD skill slots now refresh on promotion/form changes and filter skills by the active form. The existing class-selection screen defaults to Archer while keeping every other selectable class available.
- Regression coverage was added at `tools/quality/validate_archer_progression.gd`, with a dedicated Godot 4.3 workflow at `.github/workflows/archer-progression-validation.yml`.

**Verification status:** code and workflow commits are present, but the dedicated GitHub Actions result has not yet been retrieved in this session, and no Android device/runtime test has been performed. Do not mark the form switch or weapon visuals as visually approved. The test uses isolated fixture weapons to verify loadout behavior; it does not claim the real source weapon IDs/visuals have been joined yet.

**Remaining blockers:** join Archer creation weapon ID `500239` and armor ID `133080` to their exact itemtype names/remaining fields and verified models; decode and verify the Mobile promotion quest/NPC/dialogue/reward records; map all real Archer and Oriental Assassin skill IDs/ranks/effects/animations/VFX/audio; connect the verified promotion completion to `apply_archer_promotion_result`; and visually test both forms and their weapons on Android.
