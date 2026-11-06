import fs from 'node:fs/promises';
import crypto from 'node:crypto';
import { NodeIO, Node } from '@gltf-transform/core';
import { ALL_EXTENSIONS } from '@gltf-transform/extensions';
import { prune } from '@gltf-transform/functions';

const [inputPath, outputPath, reportPath] = process.argv.slice(2);
if (!inputPath || !outputPath || !reportPath) {
  throw new Error('Usage: node extract_phase1_chinese_city.mjs input.glb output.glb report.json');
}

const io = new NodeIO().registerExtensions(ALL_EXTENSIONS);
const document = await io.read(inputPath);
const root = document.getRoot();
const allNodes = root.listNodes();

const inventory = allNodes
  .map((node) => ({ node: node.getName(), mesh: node.getMesh()?.getName() ?? '' }))
  .filter((item) => /(Chinese|Jianghai|Pawnshop|Lantern|Lion|Stall|Cart|ClanHall)/i.test(item.node + ' ' + item.mesh))
  .sort((a, b) => (a.node + a.mesh).localeCompare(b.node + b.mesh));

const keepPatterns = [
  /^AuthoredStreetNetwork$/i,
  /^JianghaiValleyEnvironment$/i,
  /^JianghaiTenementDistrict$/i,
  /^RedStarElectronicsFactory$/i,
  /^GuangchangPawnshop$/i,
  /^OldCityMarketBridge$/i,
  /^JianghaiChineseTempleHall_LOD/i,
  /^JianghaiChineseArcadeShop_LOD/i,
  /^JianghaiChineseGateHouse_LOD/i,
  /^JianghaiDensity_/i,
  /^JianghaiPerimeterGroundComposite$/i,
  /^JianghaiMountainMassif/i,
  /^JianghaiEnterable_/i,
  /^JianghaiCleared_Market/i,
  /^JianghaiCleared_Pawnshop/i,
  /^JianghaiExpansion_(Market|Pawnshop)/i,
  /^Pawnshop/i,
  /^Guangchang(ClanHall|Pawnshop)/i,
  /^OldCityFoundation$/i,
  /^JianghaiClanHallDoubleGateAnchor$/i,
  /Chinese.*(Lamp|Lantern|Lion|LatticeDoor)/i,
  /Jianghai.*(Lamp|Lantern|Lion|LatticeDoor)/i
];

const selected = allNodes.filter((node) => {
  const names = [node.getName(), node.getMesh()?.getName() ?? ''];
  const combined = names.join(' ');
  if (/FactoryGatePortal|PowerDrop|SecurityCamera/i.test(combined)) return false;
  return keepPatterns.some((pattern) => names.some((name) => pattern.test(name)));
});
if (selected.length === 0) {
  await fs.writeFile(reportPath, JSON.stringify({ inventory, error: 'No approved Chinese district nodes matched.' }, null, 2));
  throw new Error('No approved Chinese district nodes matched; inspect the node inventory before changing the filter.');
}

const keep = new Set();
function keepSubtree(node) {
  if (keep.has(node)) return;
  keep.add(node);
  for (const child of node.listChildren()) keepSubtree(child);
}
function keepAncestors(node) {
  let parent = node.getParentNode();
  while (parent instanceof Node) {
    keep.add(parent);
    parent = parent.getParentNode();
  }
}
for (const node of selected) {
  keepSubtree(node);
  keepAncestors(node);
}
function depth(node) {
  let value = 0;
  let parent = node.getParentNode();
  while (parent instanceof Node) {
    value++;
    parent = parent.getParentNode();
  }
  return value;
}
for (const node of [...allNodes].sort((a, b) => depth(b) - depth(a))) {
  if (!keep.has(node)) node.dispose();
}

await document.transform(prune());
await io.write(outputPath, document);

const keptNodes = root.listNodes();
const meshNodes = keptNodes.filter((node) => node.getMesh());
const meshes = root.listMeshes();
const materials = root.listMaterials();
const textures = root.listTextures();
const images = textures.reduce((sum, texture) => sum + (texture.getImage() ? 1 : 0), 0);
let uniqueTriangles = 0;
for (const mesh of meshes) {
  for (const primitive of mesh.listPrimitives()) {
    const indices = primitive.getIndices();
    const position = primitive.getAttribute('POSITION');
    const count = indices ? indices.getCount() : (position ? position.getCount() : 0);
    const mode = primitive.getMode();
    if (mode === 4) uniqueTriangles += Math.floor(count / 3);
  }
}
let instancedTriangles = 0;
for (const node of meshNodes) {
  const mesh = node.getMesh();
  for (const primitive of mesh.listPrimitives()) {
    const indices = primitive.getIndices();
    const position = primitive.getAttribute('POSITION');
    const count = indices ? indices.getCount() : (position ? position.getCount() : 0);
    if (primitive.getMode() === 4) instancedTriangles += Math.floor(count / 3);
  }
}
const output = await fs.readFile(outputPath);
const input = await fs.readFile(inputPath);
const report = {
  source_repository: 'https://github.com/AetherRadar/operation-steel-tide',
  source_commit: 'd6a33b932e00fb9016dea407eca3f909aeaf2dcb',
  source_glb: 'assets/models/jianghai_old_city/jianghai_old_city.glb',
  source_license: 'MIT project composition; third-party source components remain under their recorded licenses in LICENSE_EVIDENCE.md',
  input_bytes: input.length,
  output_bytes: output.length,
  output_sha256: crypto.createHash('sha256').update(output).digest('hex'),
  selected_node_count: selected.length,
  selected_node_names: selected.map((node) => node.getName()).sort(),
  retained_node_count: keptNodes.length,
  mesh_node_count: meshNodes.length,
  unique_mesh_count: meshes.length,
  primitive_count: meshes.reduce((sum, mesh) => sum + mesh.listPrimitives().length, 0),
  unique_triangles: uniqueTriangles,
  instanced_triangles: instancedTriangles,
  material_count: materials.length,
  texture_count: textures.length,
  embedded_image_count: images,
  source_node_inventory: inventory
};
await fs.writeFile(reportPath, JSON.stringify(report, null, 2));
console.log(JSON.stringify(report, null, 2));
