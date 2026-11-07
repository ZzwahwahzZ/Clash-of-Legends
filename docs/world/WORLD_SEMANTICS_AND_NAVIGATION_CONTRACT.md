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

## Acceptance principle

A route passes only when it is physically possible, collision-safe, navigationally connected, and semantically correct for the documented gameplay destination. All four conditions matter. A landmark remains observational unless a specific task explicitly assigns it an interaction.
