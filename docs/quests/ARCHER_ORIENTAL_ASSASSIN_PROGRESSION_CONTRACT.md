# Archer → Oriental Assassin — Player Character Preservation Contract

**Research date:** 2026-11-07  
**Reference client:** Conquer Online Mobile, pinned target `com.Tq.CQ2ClientAndroid` versionName `1.1.2.3`, versionCode `123`.  
**Evidence status:** Mobile-official mechanics documented; exact promotion quest script, client IDs and APK 1.1.2.3 runtime mapping remain unresolved.  
**Project rule:** The player's primary character is an Archer. Do not replace, reset, split, delete or downgrade this character when Oriental Assassin is unlocked.

## 1. Identity and progression are one character

The Archer and Oriental Assassin are two combat forms / paths of the same Archer character, not two separately created characters and not a class reroll. Preserve one character identity, save slot, level, experience, attributes, inventory, quest history, social identity and progression state.

At the documented level-40 threshold, the character must complete the verified Archer advancement/promotion requirements and unlock the Oriental Assassin transformation. The official Mobile skill guide documents the transformation skill as **Path of Shadow**: it transforms the Archer into an Oriental Assassin, allows use of the equipped Throwing Knife, disables skills requiring a Bow while transformed, and toggles back to the normal Archer form when activated again.

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
- Assassin-exclusive skills documented by the Mobile Archer skill guide include:
  - **Mortal Wound** — multi-knife attack against one target; first listed skill level unlocks at character level 40.
  - **Kinetic Spark** — toggleable chi effect with level-based upgrades.
  - **Blistering Wave** — area attack with level-based upgrades.
  - **Spirit Focus** — channelled attack-power boost; cannot move while charging.
  - **Dagger Storm** — timed area attack with cooldown and level-based upgrades.
  - **Blade Flurry** — Oriental Assassin XP skill with movement-speed increase and spinning-blade area damage.
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
