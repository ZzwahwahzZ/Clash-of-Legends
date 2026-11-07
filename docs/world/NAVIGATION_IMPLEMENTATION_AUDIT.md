# Navigation Implementation Audit — Current Branch

Branch: `stage/phase1-world-assets`
Audit basis: source inspection of `QuestNavigationAgent.gd`, `WorldTravelManager.gd`, `PlayerController.gd`, `MainHUDController.gd`, and `VirtualJoystickController.gd`.
Status: source-level audit only; no runtime acceptance is claimed.

## Intended design contract

There is one automatic world-navigation executor with two request origins:
1. World-tap requests: tap an eligible semantic target (NPC, merchant, service/object interaction, or explicitly selectable place) and route to its valid approach point.
2. Quest/dialogue requests: tap a quest/objective/dialogue action explicitly marked as navigable and route to the exact target for the current objective step.

Both request origins must use the same route planner, path follower, obstacle handling, arrival test, and interaction-range logic. Manual joystick input is separate direct control and may move over any physically walkable ground, whether or not it is an auto-navigation target.

A map transition/instant-travel action is not the same as walking navigation. It must remain a distinct, explicit world-transition feature and must not be silently invoked as a shortcut for a quest route unless the game design explicitly calls for a portal/transport transition.

## Findings from current source

### 1. World-tap automatic navigation is not present in the inspected HUD/controller path

- `MainHUDController.gd` wires the quest banner to `navigate_to_quest_target()`.
- The inspected HUD does not expose a world-tap selection path that resolves a tapped NPC/object/place into a semantic target ID and approach point.
- Therefore world-tap navigation is not proven implemented by these files. Do not write a passing world-tap runtime test until the actual world input/picking implementation is located and inspected.

### 2. Quest navigation currently uses hard-coded coordinates

- `QuestNavigationAgent.gd` builds destinations in `_get_navigation_target()` using fixed Vector3 coordinates and a small hard-coded set of travel IDs.
- These destinations are not resolved from structured per-step objective target references, validated map/area IDs, NPC interaction anchors, or objective metadata.
- The current quest chain is a starter prototype (wolves, meteor collection, blacksmith visit, level requirement, dragon, sage); its data must not be treated as canonical Conquer Mobile quest coverage.
- Consequently, the current code cannot yet prove that a quest click routes to the exact active objective target, especially for multi-step, hidden-character, entrance, or map-transition objectives.

### 3. Quest navigation can invoke instant teleport before local movement

- `QuestNavigationAgent.navigate_to_quest_target()` calls `WorldTravelManager.travel_to(travel_id, "quest")` when the manager exists, then calls the player's local `move_towards_target_position(destination, 0.0)`.
- `WorldTravelManager.travel_to()` directly assigns `player.global_position = destination.position`, updates the current destination ID, and reports instant travel.
- This is a map/area teleport, not ordinary automatic walking. It can therefore bypass the route that the quest banner is supposed to request.
- The quest route must not use this path as a default. A validated objective on the same map should use the shared walking navigation executor. A cross-map objective should resolve to a documented exit/transport/portal and use the actual transition flow, not teleport directly to the objective coordinates.

### 4. The world travel list is a separate instant-travel interface

- `MainHUDController` builds a world map/travel list and calls `travel_to(destination_id, "manual")`.
- `WorldTravelManager.travel_to()` teleports the player to a hard-coded coordinate and emits a notification saying instant travel completed.
- This should be classified as an explicit instant-travel/map-transition feature, not as the user's world-tap walking navigation. Whether this feature belongs in the final game requires a separate design/evidence decision; do not conflate it with tapping an NPC or a place in the live world.

### 5. Manual joystick input has a basic priority behavior

- `VirtualJoystickController` emits direction changes.
- `MainHUDController` forwards those changes to `PlayerController.set_joystick_input()`.
- In `PlayerController._physics_process()`, non-zero joystick input takes precedence over the active movement target and clears the auto-target flags.
- This is consistent with direct manual control interrupting auto-navigation at the source-code level. It still needs runtime verification for touch/multitouch, zero-vector release, and whether any other input source reactivates auto movement.

### 6. Local path following has a fallback that must be guarded

- `PlayerController` uses `NavigationAgent3D` when an active navigation map exists.
- If no active navigation map exists, it moves directly toward the target in a straight line.
- Straight-line fallback can cut through obstacles or cross semantically invalid terrain. It must not be accepted as valid pathfinding in a world with collision obstacles or restricted parcels.
- For production navigation, missing/unready navigation data should produce a safe unavailable/failure state (or a separately validated local steering solution), not silently substitute straight-line movement.

## Correct next implementation sequence

1. Locate and inspect the actual world-input/picking scripts and confirm whether tapping a character, object, or selectable place currently produces any navigation request.
2. Define a semantic target registry with stable IDs, target class, map ID, valid approach point(s), interaction range, selectability, and evidence/provenance.
3. Define structured quest objective steps with target IDs and navigation eligibility. Remove hard-coded coordinate inference from quest text/quest ID.
4. Route both request origins through one navigation request API and one path executor. Keep request-origin metadata for UI/debugging.
5. Keep instant travel/map transitions separate. Cross-map quest navigation must target a real, validated exit/transport/portal and execute its documented transition.
6. Keep joystick movement independent and ensure it reliably cancels/overrides an active auto route.
7. Only then add tests: target resolution for each request origin, shared route execution, manual override, invalid-target rejection, and explicit map-transition cases.

## Tests deliberately not accepted yet

- No world-tap auto-navigation pass: the target-picking/request path has not been identified in the inspected files.
- No quest-to-exact-objective pass: current quest destinations are hard-coded coordinates.
- No quest walking pass: the current quest action may teleport through `WorldTravelManager`.
- No straight-line fallback pass: absence of a navigation map is not evidence that a direct path is safe.
- Joystick priority is source-code-supported but not runtime-validated by this audit.

## Acceptance gate

A future pass requires a runtime demonstration for both automatic request origins using the same executor, a manual joystick interruption test, correct approach/interaction arrival, and a separate verified transition test for any cross-map objective. Passing a route to an arbitrary coordinate is not sufficient.


## Follow-up implementation — quest/UI preservation boundary

Commit: `0672279236c12c77d4358aae9c3a2606b42a9d27`

The quest-navigation call path was changed without editing quest progression content or the player-facing HUD/dialogue scenes:

- Removed the quest navigation dependency on `WorldTravelManager.travel_to(..., "quest")`. Quest navigation no longer requests an instant relocation.
- Kept `WorldTravelManager`, its destination registry, and the manual travel panel wired by `MainHUDController` intact. This is the separate Travel Scroll/instant-travel feature and is not removed or repurposed.
- The active completed-quest state resolves its existing `turn_in_npc_id` against live NPC nodes. An active `talk` objective resolves its existing `objective_target` NPC ID against the same live NPC group.
- Kill/collect objectives may navigate only when the quest data explicitly supplies a `navigation_target` with `navigation_enabled`, `target_type`, `target_id`, `map_id`, and `approach_anchor_id`, and a matching live node is registered in `quest_navigation_targets`. Missing data produces a visible unavailable message; no quest-ID coordinate guesses or map-center fallback are used.
- The quest database entries, objective counts/types/IDs, titles, descriptions, reward amounts, turn-in rules, and chain links were not edited by this change.
- `MainHUDController`, `DialogueUI.gd`, and their scenes were not edited. Existing quest banner, HUD layout, dialogue panel and dialogue options remain the presentation surface; this change deliberately adds no replacement quest UI.

### Remaining acceptance limits

- The current starter quest data does not yet provide authored `navigation_target` records for its kill/collect regions. Those objectives therefore report unavailable rather than routing to invented coordinates.
- The current talk progression callback still fires from `NPCBase.interact()` before a dialogue option is selected. That progression/dialogue coupling needs a separate behavior-preserving correction after the existing quest dialogue branches are fully inventoried; this navigation commit does not alter it.
- NPC resolution currently uses the live `npcs` group and NPC IDs. A complete semantic world registry, cross-map exits/transports, world-tap picking, and arrival/interaction-range acceptance remain unimplemented/unverified.
- No runtime Godot or Android acceptance is claimed for this source change. The player movement method's second argument is currently ignored by its implementation, so interaction-range enforcement remains a separate required task.
