# Jianghai Navigation Test Validity Review

Date: 2026-11-07
Branch: `stage/phase1-world-assets`
Related semantic contract: `docs/world/WORLD_SEMANTICS_AND_NAVIGATION_CONTRACT.md`

## Decision

The existing Jianghai navigation artifacts are retained as engineering diagnostics for this authored environment, but their route results are **not accepted as Conquer Online Mobile gameplay/navigation validation**. The Jianghai source README identifies it as a project-authored 1990s Lingnan river-industrial city composition for Operation Steel Tide. It is not the pinned Conquer Online Mobile 1.1.2.3 map source. Its geometry may be used to inspect collision, door apertures, rendering, and Godot navigation mechanics, but not to infer Conquer destinations, road topology, monster fields, quest areas, or hidden-character locations.

## Existing test review

| Existing probe | What it actually establishes | Gameplay acceptance |
|---|---|---|
| World scene load | The authored Jianghai scene loads in Godot | Not a Conquer map acceptance test |
| Pawnshop/factory doorway rays | The tested openings and adjacent wall collision behave as authored | Geometry-only |
| Bridge guardrail ray | The named guardrail collision is active at the sampled ray | Geometry-only |
| Navmesh bake / polygon count | Selected authored meshes can produce a Godot navmesh | Engineering-only |
| Seven anchor projections / route connectivity | Selected coordinates project/connect on the authored Jianghai navmesh | Rejected as gameplay semantics until source identity and function are established |
| Five route path/movement checks | Player can traverse between selected Jianghai coordinates under current collision/navmesh | Geometry/pathfinding diagnostics only; not proof these are valid Conquer destinations |
| Full bridge crossing from X=-29 to X=+29 at Z=-126 | A test forced traversal across both ramp extensions and bridge deck | **Retired as an acceptance criterion**: the endpoint and ramp traversal were not established from canonical map evidence |
| NPC spawn projection checks | Four candidate positions project onto the Jianghai navmesh | Not permission to spawn; all collision-clearance checks remain false and spawning remains disabled |

## Specific implementation risk

`tools/quality/Phase1NavigationBakeAudit.gd` currently adds `MarketBridgeNavigationSeamConnectors`, two generated navigation-only strips extending the ramp profiles from the authored deck edges toward X=±29. These strips are not physical collision or rendered geometry. They were introduced to overcome Recast erosion and make the previous bridge route connect.

Because the canonical purpose and topological continuation of those ramps have not been established, the generated strips must not be treated as authored player routes. They are excluded from gameplay acceptance. Do not extend, widen, or connect them further based on the old test.

## Current verified results, correctly scoped

- The last checked integrated report records 27/27 engineering checks passing for its then-current suite.
- The last checked runtime probe records 5/5 selected Jianghai route movements reaching their chosen projected coordinates with floor contact.
- The same runtime report records the bridge crossing failure at the west-side seam; that failure diagnoses the constructed test/geometry combination, not a proven Conquer gameplay defect.
- The bake report records 92 polygons, 7/7 anchor projections, and 7/7 coordinate connectivity checks on this authored scene. These are not evidence of canonical Conquer map semantics.
- Four NPC candidate projections were reported, but collision clearance was false for all four and NPC spawning remained disabled.
- Android-device performance was not validated.

## Required next evidence before new gameplay routes

1. Match each candidate map/scene to the pinned Android package `com.Tq.CQ2ClientAndroid`, version `1.1.2.3`, or record why it is only an adaptation.
2. Inspect the actual mobile map resource and its neighboring map/region identifiers, exits, doors, bridges, road lines, open parcels, and minimap.
3. Classify each area separately as road/circulation, roadside open land, city/district, hunting/combat area, quest/objective area, hidden/gated entrance, service, or observation-only landmark.
4. For open parcels on both sides of roads, record monster/quest/hidden-character/resource evidence independently. Do not infer content from empty ground or proximity to a road.
5. Only after those records exist, define test start/end bounds and expected route segments. Test physical traversal and semantic correctness separately.
6. Keep unsupported NPCs, quests, monsters, and interactions disabled.

## Acceptance rule

No gameplay route test is accepted unless its start, destination, allowed path, and destination function are all supported by the canonical mobile reference or an explicitly approved project adaptation. Coordinate reachability alone is not semantic validation.
