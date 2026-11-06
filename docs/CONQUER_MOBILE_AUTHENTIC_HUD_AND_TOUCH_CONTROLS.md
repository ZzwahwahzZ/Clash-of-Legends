# Conquer Mobile-faithful gameplay HUD and touch control specification

**Owner-approved requirement:** 2026-11-06  
**Target:** Android portrait/landscape phone gameplay; Redmi Note 11 baseline  
**Reference:** The actual in-game HUD of Conquer Online Mobile (Android package `com.Tq.CQ2ClientAndroid`), not a generic MMORPG HUD and not the old PC-only layout.

## Visual acceptance target

The gameplay screen must read immediately as the Conquer Mobile play screen. Use current official mobile gameplay screenshots and, where available, the legally usable UI reference material in the project's source inventory as the visual reference set. Do not substitute the PC 4:3 HUD or an unrelated fan redesign.

Match the reference's visual language, relative placement, hierarchy, proportions, icon treatment, frame shapes, colors, gradients, borders, and density:
- upper gameplay overlay and status indicators;
- character portrait/status/level and HP/MP/resource presentation;
- minimap and its expand/collapse affordance, location/coordinate and nearby marker roles;
- quest/objective and event/navigation access;
- bottom action/skill/quick-item area with class-appropriate skill icons;
- attack and special-action cluster, target feedback, cooldown/disabled states;
- inventory, character/status, equipment, skills, quests, map, settings and other function shortcuts;
- message/system feedback area, while respecting this project's explicit no-chat requirement;
- contextual NPC/interact, mount and movement controls.

The existing `MainHUD.tscn` is a functional prototype only. Its rectangular text buttons, arbitrary corner layout and missing mobile reference art are not an accepted final visual match. Replace/refine it incrementally; do not discard working signal wiring or gameplay systems.

## Control behavior (owner's explicit adaptation)

1. A visible virtual joystick is the primary continuous movement control. It must support analog direction and magnitude, smooth dead-zone handling, safe multi-touch, and release-to-stop. Walking/running is selectable through a dedicated mode control; sprint/run may also use a press/hold affordance only if it does not conflict with the reference layout.
2. Touching a valid point on the 3D world issues a pathfinding destination, using the existing navigation system and obstacle avoidance. Touching UI must never issue a world command.
3. Match the official Conquer Online Mobile behavior: a deliberate tap on a valid ground point makes the character leap/jump toward that point. The official mobile guide explicitly documents this as Jump (click the ground where you want to move). Keep auto-pathfinding as a separate command/menu, not the default result of a ground tap. Gesture recognition must distinguish a tap from a camera drag, joystick contact, and UI interaction. A dedicated jump action may be provided as an additional accessible control, but must not replace the ground-tap leap.
4. Joystick input is the continuous walk/run control, with a clear walk/run mode toggle. Ground tap is the jump-to-destination action; auto-pathfinding is separate. Attack and each skill are separate touch targets. Skill buttons show the actual class skill icon, cooldown overlay, mana/cost state, and disabled state; no text-only generic skill buttons in the final HUD.
5. Mount, auto-hunt, auto-loot, potion/quick slots and contextual interaction must be reachable by thumb and must not overlap the joystick or attack/skill cluster.
6. All touch actions must work concurrently where expected (e.g. movement joystick plus skill press), with correct pointer/touch IDs and no stuck movement state when the app loses focus or a finger leaves the screen.
7. UI must scale and reposition safely across phone aspect ratios and safe areas; target the Redmi Note 11 screen first. Preserve camera visibility and avoid covering the character/action area.

## Offline and project constraints

- Arabic-first RTL labels; iconography remains recognizable and aligned to the reference.
- No chat feed or live social channels; do not add chat merely because the reference includes it.
- Gold only; do not add VIP, premium-currency, real-money shop or payment affordances.
- Keep existing Godot scene/signal connections, save data and gameplay functions. Every visible button must perform a real action.
- Prefer original or properly licensed UI artwork and icons. Use screenshots as visual layout/behavior references; do not extract and redistribute proprietary game art without authorization.
- Do not claim visual completion until compared side-by-side against actual Conquer Mobile gameplay screenshots and verified on an Android device.

## Source references reviewed

- Official Google Play listing for Conquer Online Android, package `com.Tq.CQ2ClientAndroid`, updated 2026-07-21: https://play.google.com/store/apps/details?id=com.Tq.CQ2ClientAndroid
- Official classic interface guide (PC reference only; useful for functional roles, not the mobile layout): https://conqueronline.com/guide/guides/basicint.shtml
- AppFollow screenshot index for the Android package: https://apps.appfollow.io/android/conquer-online-mmorpg-game/com.Tq.CQ2ClientAndroid?country=by

## Acceptance checklist

- [ ] Side-by-side mobile screenshot review completed against the current Conquer Mobile gameplay screen.
- [ ] Correct mobile layout, visual skin, icons and spacing; not the current generic prototype.
- [ ] Joystick analog movement and walk/run mode work.
- [ ] World tap performs a jump toward the tapped ground point; separate auto-pathfinding and obstacle avoidance work.
- [ ] Jump/hop gesture and dedicated button work without false triggers.
- [ ] Movement + attack/skill multi-touch works; no stuck inputs after touch cancellation/focus loss.
- [ ] Minimap, target, quest, quick slots and all visible function controls are functional.
- [ ] Arabic RTL, phone safe areas and multiple aspect ratios pass.
- [ ] Android runtime test on Redmi Note 11; no material FPS regression.


## Official mobile guide evidence added during review

The official Conquer Online Mobile guide page was opened and its actual linked gameplay images were inspected on 2026-11-06:

- Official guide: https://comobile.99.com/guide/info/beginners/2023-02-13/start_off_-_game_operations.shtml
- The guide explicitly describes Jump as tapping/clicking the ground destination and says all characters leap. This confirms the ground-tap leap behavior already implemented in `PlayerController.gd`.
- Official jump/pathfinding image: https://hw.99.com/uploads/allimg/230213/82-2302131430534M.png
- Official Auto-pathfinding panel image: https://hw.99.com/uploads/allimg/230213/82-23021314430C05.png. It shows a separate, full-height navigation panel with grouped destination rows (PK Tournaments, Pharmacist, Warehouse, Hunting Areas, Market/Twin City, Quest, Guild and Other Places). This supports keeping auto-pathfinding as a distinct panel/action rather than making every ground tap open pathfinding.
- The guide's kill-monsters image link was not retrievable during this review, so it is not treated as a verified full-screen HUD reference. The current visual acceptance target remains pending a directly inspectable in-game gameplay screenshot set and the original FUI/atlas resources.

These references verify control semantics and the separate pathfinding panel only. They do **not** establish that the current Godot HUD visually matches the original. The existing prototype remains unaccepted until the source UI package/art can be decoded and a side-by-side screen review is completed.


## Current Godot prototype code audit (2026-11-06)

A source review of `MainHUD.tscn`, `MainHUDController.gd`, `VirtualJoystickController.gd`, and `PlayerController.gd` confirms the following gaps; these are implementation findings, not visual guesses:

- The current HUD has HP/MP/XP bars, gold, a quest banner, auto-hunt/auto-loot, inventory/blacksmith/settings/travel buttons, two text-labelled skill buttons, attack/jump/mount buttons and a virtual joystick.
- It does not yet contain a minimap node, target/target-health presentation, quick potion/item slots, a real icon-based skill hotbar, or a dedicated walk/run mode control.
- The current skill buttons receive translated skill **names** from the skill database, not reviewed source icon textures; they remain generic text controls.
- The current joystick sets `touch_index` on every new screen-touch press. A second finger pressing inside the joystick control can therefore take ownership from the first finger. The current release/focus reset logic does not by itself solve that ownership race.
- The controller's movement speed currently has a base value and a mount multiplier, but no separate walk/run mode state or mode-change signal is present in the inspected script.
- The jump button and world-tap leap are separate triggers; retain the dedicated button only as an additional accessibility action, not as the sole way to jump.

## Required implementation order from this audit

1. Decode and legally source the original interface layout/art and icon atlases before skinning the scene. Do not invent a visual match from the current placeholder rectangles.
2. Add a single-owner touch capture rule to the joystick: only the first active finger may own it; ignore other finger presses until release/cancel; release only on the owning pointer; always reset on focus loss.
3. Add a real walk/run mode state and a visible mode control, then verify joystick speed and movement animation state in both modes.
4. Add reviewed minimap, target feedback, quick slots and icon-backed skill buttons with functional signals and cooldown/resource states.
5. Test simultaneous joystick + skill touches, cancellation, focus loss, screen rotation, safe areas and the Redmi Note 11 aspect ratio.

No code changes were made for these new audit findings in this commit. The prototype remains a prototype; these gaps must be fixed and device-tested before visual or control acceptance.
