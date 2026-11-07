# World Semantics and Navigation Decision Contract

Status: adopted design rule; applied first to Jianghai Old City audit.
Branch: `stage/phase1-world-assets`

## Governing rule

Navigation, collision, NPC placement, quest triggers, and enemy placement must follow the authored gameplay meaning of a place. Tool output is evidence about implementation, not authority to decide what the player should do. Never infer a gameplay destination solely because a mesh, ramp, nav polygon, or projected point exists.

Before adding or testing a route, classify its destination and verify that the destination is supported by the reference map, source assets, and gameplay documentation. A technically traversable route can still be semantically wrong.

## Place classes

1. **Landmark / scenic reference** — identifies a location or provides scenery. It may be visible and explorable if the physical layout allows, but it does not automatically create a quest objective, interaction trigger, NPC, service, enemy spawn, or required navigation destination.
2. **Service / profession area** — shop, merchant, inn, healer, repair, crafting, storage, transport, etc. Define the actual service, interaction point, approach space, and relevant NPC only when supported by evidence.
3. **Quest area** — has a documented quest objective, NPC, trigger, sequence, prerequisite, and completion condition. Navigation targets must correspond to the actual objective step, not merely the area's center.
4. **Combat / hunting area** — has documented monster population, combat boundaries, spawn/respawn rules, and access routes. Do not label an empty terrain patch a hunting area without evidence.
5. **Hidden / gated / instance entrance** — cave, secret passage, portal, dungeon, or concealed entry. Model discovery, prerequisite, trigger, and transition separately from ordinary walking routes.
6. **Residential / coastal / public / scenic space** — city fabric and environmental space. Preserve natural pedestrian circulation and access to supported buildings; do not invent activities or force traversal to decorative elevated geometry.
7. **Connector / circulation space** — bridge, street, alley, ramp, stairs, or path. It connects meaningful destinations. It is not itself a destination unless the reference assigns it a gameplay function (e.g. crossing objective).

A location can have more than one class, but each class must be independently evidenced and represented explicitly.

## Evidence and confidence

For each semantic location record:
- stable ID and source scene/node;
- class (one or more of the classes above);
- evidence source and exact reference/version;
- intended player-facing function;
- supported destinations and adjacent areas;
- whether ordinary traversal is allowed;
- whether it is a navigation destination, merely a route segment, or a landmark only;
- interaction/quest/NPC/enemy permissions;
- confidence: verified, corroborated, candidate, or unknown.

Unknown is not permission to invent. Keep unsupported interactions and NPC/enemy spawns disabled.

## Navigation policy

- Route planning starts from a meaningful requested destination, not from arbitrary navmesh connectivity.
- Navigation polygons describe physically traversable surfaces only; they do not define the intended player journey.
- Do not add synthetic connectors or ramp links merely to make a test pass. Each connector must match a physically continuous, authored, intended route.
- Separate tests for: physical walkability, collision clearance, route connectivity, semantic destination correctness, and end-to-end player journey.
- Test the shortest sensible route to the actual service/quest/building destination, including turns and approaches. Do not substitute a straight-line opposite-edge target for a real destination.
- A landmark can be inspected or crossed where appropriate, but must not become a forced waypoint just because it has an anchor.
- A failed test whose destination or route is semantically unsupported is an invalid test, not a game defect. Correct the test before changing the world.
- Keep NPC spawning, quest triggers, and enemy spawning disabled until both semantic evidence and physical clearance are validated.

## Jianghai Old City immediate audit findings

The current `interaction_anchors.json` explicitly describes its anchors as references, not enabled gameplay triggers. It nevertheless mixes landmark, approach-route, and service-frontage records under one navigation-oriented schema and gives the bridge `visit/cross/escort` tags. Those tags are candidate task semantics, not proof that the bridge is a required destination.

The previous bridge probe forced a west-to-east traversal from X=-29 to X=+29 at Z=-126 and treated the two ramps as part of the required crossing. That test does not establish the intended post-bridge journey. Retire that route as an acceptance criterion until the canonical map topology and western coastal/shop access are established.

Immediate next route audit:
1. Trace the actual bridge deck exit and adjoining western coastal pedestrian street from the authored source geometry.
2. Identify the western shops and residential/public areas actually present and their doorways/approach spaces.
3. Define a bridge-crossing segment that ends at the real deck exit, then a separate coastal-turn route to the evidenced western destinations.
4. Treat the ramp as optional terrain until its purpose, top connection, and intended destination are evidenced.
5. Do not enable NPCs, quests, or enemies based on visual guesswork.

## Acceptance principle

A route passes only when it is physically possible, collision-safe, navigationally connected, and semantically correct for the documented gameplay destination. All four conditions matter.
