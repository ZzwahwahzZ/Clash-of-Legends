# World Semantics and Navigation Decision Contract

Status: adopted design rule; applied first to Jianghai Old City audit.
Branch: `stage/phase1-world-assets`

## Governing rule

Navigation, collision, NPC placement, quest triggers, enemy placement, and map transitions must follow the authored gameplay meaning of a place. Tool output is evidence about implementation, not authority to decide what the player should do. Never infer a gameplay destination solely because a mesh, ramp, nav polygon, or projected point exists.

Classify the world before building routes. In particular, do not confuse a landmark with a road, a road with the open land beside it, or a city with a hunting/quest map.

## Separate world layers

The world must be interpreted in distinct but connected layers:

1. **Landmarks / scenic references** — named or visually notable objects/places intended for orientation, atmosphere, or viewing. By default they are observational only: no forced navigation destination, interaction, NPC, service, enemy spawn, quest trigger, or activity. Exception: if a documented quest or gameplay mechanic explicitly uses the landmark, attach that specific task interaction without changing the landmark's default class.
2. **Road and circulation network** — streets, roads, bridges, alleys, paths, ramps, stairs, crossings, and junctions. These define how the player travels between places. A road is a route segment, not automatically a destination or activity. Its geometry and junctions must be physically continuous and match the intended map topology.
3. **Roadside open lands / shoulders / adjoining parcels** — open ground on either side of a road, including clearings, fields, coast edges, outskirts, and undeveloped spaces. These are separate gameplay areas, not part of the road and not landmarks by default. They may contain documented monster habitats, quest objectives, hidden characters, secret entrances, resource gathering, ambushes, or other activities. Inspect and classify each parcel independently; do not fill it with enemies or interactions without source evidence.
4. **Cities, settlements, and districts** — complete navigable places with streets, buildings, residential blocks, shops, public spaces, services, NPCs, and any documented quest locations. Classify sub-areas and building functions individually. Preserve natural pedestrian access and coherent circulation; don't reduce a city to a road corridor or a few service markers.
5. **Open maps / wilderness / hunting maps** — larger playable spaces whose terrain, roads, paths, clearings, monster zones, quest locations, hidden characters, caves, and exits must be represented as distinct subareas. Open ground is not automatically a monster zone; monster presence and boundaries require evidence.
6. **Service / profession areas** — shops, merchants, inns, healers, repair, crafting, storage, transport, etc. Define the actual service, interaction point, approach space, and relevant NPC only when supported by evidence.
7. **Quest areas / objective sites** — places with documented quest objectives, NPCs, triggers, sequences, prerequisites, and completion conditions. Navigation targets correspond to the actual objective step, not merely the area's center.
8. **Combat / hunting subareas** — documented monster populations, combat boundaries, spawn/respawn rules, level/rank, and access routes. Do not label empty terrain a hunting area without evidence.
9. **Hidden / gated / instance entrances** — caves, secret passages, portals, dungeons, concealed characters, or hidden entry points. Model discovery, prerequisites, triggers, and transitions separately from ordinary walking routes.
10. **Landmark with explicit task exception** — a landmark remains observational unless a documented task explicitly requires visiting, inspecting, activating, defending, escorting through, or retrieving something there. In that case only the evidenced interaction/task is enabled; do not turn the whole landmark into a generic service or combat area.

A single geographic region can contain several of these layers. For example, a road may run between two open parcels, with monsters or hidden quest characters on one side and a city district beyond the bridge. Represent the road and both parcels separately, then connect them through real entrances and paths.

## Evidence and confidence

For every semantic area or subarea record:
- stable ID and source scene/node or map coordinates;
- world layer and functional class (multiple only when independently evidenced);
- evidence source and exact client/map/reference version;
- intended player-facing function;
- adjacent areas, entrances, exits, and supported destinations;
- whether ordinary traversal is allowed;
- whether it is a destination, route segment, optional exploration area, or observation-only landmark;
- interaction, quest, NPC, enemy, resource, and transition permissions;
- confidence: verified, corroborated, candidate, or unknown.

Unknown is not permission to invent. Keep unsupported interactions, quest triggers, NPCs, and enemy spawns disabled. Preserve unknown parcels for further inspection rather than silently classifying them as empty or decorative.


## Unified navigation system: two request modes

The game has **one world-navigation and path-execution system**, with two distinct sources of automatic-movement requests. These are not two unrelated pathfinders and must not be confused with direct player movement.

### A. World-tap navigation

- The player taps a meaningful, selectable world target such as an eligible NPC, merchant, service interaction point, task object, or explicitly selectable destination/area.
- The selection layer resolves the tap to a semantic target ID and its valid approach/interaction point. It must not treat every visible mesh, arbitrary ground point, landmark, or navmesh polygon as an eligible destination.
- If the target is out of interaction range, the unified navigation system plans and executes movement to its valid approach point; interaction is attempted only when the target's actual interaction conditions are met.
- If the target is a place rather than an actor, it must be explicitly marked as a selectable destination. Merely being walkable or visible does not make it tappable for auto-navigation.
- A scenic landmark remains view-only/non-interactive by default. It may be tapped for navigation only if the game's documented interaction model explicitly makes that landmark a selectable destination, or a specific quest step supplies a target there.
- Invalid, blocked, unknown, or non-selectable taps must not create arbitrary routes or silently select a nearby unrelated destination.

### B. Quest/dialogue navigation

- Tapping a quest entry, objective, or dialogue bubble that explicitly supports navigation asks the same unified navigation system to resolve the **current objective step's intended target**.
- The quest system supplies a semantic target reference (NPC, map/area, object, entrance, or objective location), including prerequisites and any required map transition. The navigation system must not guess from quest text alone when the structured objective target is missing or ambiguous.
- A dialogue bubble is a navigation request only when that bubble/action is marked as navigable. Ordinary dialogue choices must not unexpectedly move the player.
- Multi-step tasks must route to the active step, not a later stage, a generic quest-giver, or the center of the entire map.
- If the task requires finding a hidden character, entering a cave, reaching a monster parcel, or interacting with a specific object, route to the evidenced access/approach point and preserve the discovery/entry/interaction conditions.
- If the objective is not yet available, already complete, blocked by prerequisites, or has no validated target, report the appropriate state rather than inventing a destination.

### Shared execution and direct movement

- Both automatic request modes feed one shared route planner, path follower, obstacle/collision handling, arrival detection, and interaction-range check.
- The request source remains tagged as world-tap or quest/dialogue for diagnostics, UI feedback, cancellation, and acceptance tests, but it does not fork into separate movement implementations.
- The virtual joystick/manual controls remain direct player input. They allow the user to explore any physically walkable area, including spaces that are not auto-navigation destinations, without requiring that every point be registered as a target.
- Direct movement does not imply that the destination is semantically selectable or that a quest/service interaction exists there.
- New manual input should interrupt or take priority over auto movement according to the game's input policy; auto-navigation must never fight the joystick.
- Route requests may traverse ordinary road segments and valid open-land paths to reach a target. The road is often a connector; adjacent fields/clearings can be the actual objective or hunting area. The route graph must preserve these distinct semantic areas and real access links.

## Navigation acceptance tests

Test the two request modes separately at the request/target-resolution layer, then test their shared movement execution:

1. **World-tap target resolution:** eligible NPC/service/object/place tap resolves to the correct semantic ID and approach point; view-only landmarks and arbitrary scenery do not become accidental targets.
2. **Quest/dialogue target resolution:** navigable quest/objective/bubble resolves to the active step's exact target; non-navigable dialogue does not trigger movement; missing or gated targets produce a correct unavailable/prerequisite state.
3. **Shared route execution:** both request sources use the same route planner and path follower; test route continuity, collisions, obstacle avoidance, arrival radius, interaction range, cancellation, and failure recovery.
4. **Manual control independence:** joystick movement can reach physically walkable non-target ground; it interrupts/overrides automatic movement as designed and is not constrained to registered auto-navigation points.
5. **Semantic route correctness:** verify the actual route through roads, junctions, open parcels, entrances, and map transitions against canonical map evidence. A geometrically successful route to the wrong task step is a failure.
6. **Negative cases:** tap a landmark, decorative object, blocked area, or unsupported target; test an ambiguous/missing quest target; confirm no invented destination, NPC, spawn, or route is activated.

## Navigation policy

- Route planning starts from a meaningful requested destination, not from arbitrary navmesh connectivity.
- Navigation polygons describe physically traversable surfaces only; they do not define intended gameplay or player journeys.
- Keep road navigation separate from movement inside adjoining open lands. Add connectors only where a real path, entrance, or traversable opening exists.
- Do not add synthetic connectors or ramp links merely to make a test pass. Each connector must match a physically continuous, authored, intended route.
- Separate tests for physical walkability, collision clearance, route connectivity, semantic destination correctness, and end-to-end player journey.
- Test actual player journeys: follow the road, turn at the correct junction, enter the relevant city/open parcel through its real access, and approach the actual service/quest/hidden objective.
- A landmark can be viewed, passed, or used as orientation where appropriate, but must not become a forced waypoint just because it has an anchor.
- A failed test whose destination or route is semantically unsupported is an invalid test, not a game defect. Correct the test before changing the world.
- Keep NPC spawning, quest triggers, and enemy spawning disabled until both semantic evidence and physical clearance are validated.

## Jianghai Old City immediate audit findings

The current `interaction_anchors.json` explicitly describes its anchors as references, not enabled gameplay triggers. It nevertheless mixes landmark, approach-route, and service-frontage records under one navigation-oriented schema and gives the bridge `visit/cross/escort` tags. Those tags are candidate task semantics, not proof that the bridge is a required destination.

The previous bridge probe forced a west-to-east traversal from X=-29 to X=+29 at Z=-126 and treated the two ramps as part of the required crossing. That test does not establish the intended post-bridge journey. Retire that route as an acceptance criterion until the canonical map topology and western coastal/shop access are established.

Immediate next route audit:
1. Trace the actual bridge deck exit and adjoining western coastal pedestrian route from the authored source geometry.
2. Identify the western shops, residential/public spaces, and any adjoining open parcels that are actually present.
3. Separate bridge crossing, road-following, coastal turn, city entry, and approaches to evidenced destinations into distinct test segments.
4. Treat the ramp as optional terrain until its purpose, top connection, and intended destination are evidenced.
5. Inspect the land on both sides of roads independently for documented hunting, quest, hidden-character, cave, or resource functions.
6. Do not enable NPCs, quests, or enemies based on visual guesswork.


## Source-identity gate (Jianghai)

The current Jianghai district README identifies the scene as a project-authored 1990s Lingnan river-industrial city composition for Operation Steel Tide, with Godot gameplay collision, navigation, loot, spawning, doors, and mission state authored separately. Its source provenance points to that separate project, not to the pinned Conquer Online Mobile client/map. Therefore this scene is valid evidence for its own geometry and authored building layout only; it is not canonical evidence for Conquer map topology, named destinations, monster fields, hidden characters, or quest placement.

Before using any scene as gameplay-semantic authority, record its identity and provenance and match it to the pinned Conquer Mobile reference. If it is a visual environment adaptation or unrelated authored scene, use it only for visual/physical construction. Do not derive Conquer routes, map zones, NPC roles, or activities from its appearance. Canonical map evidence must come from the pinned client, verified map resources, or matching official mobile documentation/screenshots.

For Jianghai specifically, current evidence is insufficient to certify the western coastal route, western shops/residences as Conquer destinations, or any roadside combat/quest parcels. Those remain unclassified pending canonical reference matching. Physical collision and scene topology may still be audited as construction issues, but no gameplay route acceptance test may target an unverified destination.

## Acceptance principle

A route passes only when it is physically possible, collision-safe, navigationally connected, and semantically correct for the documented gameplay destination. All four conditions matter. A landmark remains observational unless a specific task explicitly assigns it an interaction.
