#!/usr/bin/env node
import fs from 'node:fs/promises';
import path from 'node:path';
import { NodeIO } from '@openfairygui/core/node';

const [inventoryPath, outputDir] = process.argv.slice(2);
if (!inventoryPath || !outputDir) {
  console.error('Usage: node parse_fui_packages.mjs <fui-header-inventory.json> <output-dir>');
  process.exit(2);
}
const inventory = JSON.parse(await fs.readFile(inventoryPath, 'utf8'));
const candidates = (inventory.records ?? []).filter((row) => row.status === 'V7_CANDIDATE');
await fs.mkdir(outputDir, { recursive: true });
const io = new NodeIO();
const results = [];
const call = (object, method, fallback = null) => {
  try { return typeof object?.[method] === 'function' ? object[method]() : fallback; }
  catch { return fallback; }
};
const named = (items) => (items ?? []).map((item) => ({ id: call(item, 'getId', ''), name: call(item, 'getName', '') }));

for (const candidate of candidates) {
  const filePath = candidate.path;
  try {
    const doc = await io.readBinary(filePath);
    const packages = doc.getRoot().listPackages();
    const packageRows = packages.map((pkg) => {
      const resources = pkg.listResources();
      const components = pkg.listComponents();
      const counts = {};
      for (const resource of resources) counts[resource.propertyType] = (counts[resource.propertyType] ?? 0) + 1;
      return {
        id: pkg.getId(), name: pkg.getName(),
        dependencies: named(pkg.listDependencies()),
        resourceCounts: counts,
        atlasCount: pkg.listAtlases().length,
        components: components.map((component) => ({
          id: component.getId(), name: component.getName(),
          width: component.getWidth(), height: component.getHeight(),
          pivot: { x: component.getPivotX(), y: component.getPivotY(), asAnchor: component.getPivotAsAnchor() },
          overflow: component.getOverflow(), margin: component.getMargin(),
          relations: component.getRelations().length,
          children: component.listChildren().map((child) => ({
            id: call(child, 'getId', ''), name: call(child, 'getName', ''),
            type: child.propertyType,
            x: call(child, 'getX'), y: call(child, 'getY'),
            width: call(child, 'getSourceWidth'), height: call(child, 'getSourceHeight'),
            scaleX: call(child, 'getScaleX'), scaleY: call(child, 'getScaleY'),
            rotation: call(child, 'getRotation'), visible: call(child, 'getVisible'),
            gearCount: call(child, 'listGears', [])?.length ?? 0,
          })),
          controllers: component.listControllers().map((controller) => ({
            name: controller.getName(), selectedIndex: controller.getSelectedIndex(),
            homePageType: controller.getHomePageType(),
            pages: controller.listPages().map((page) => ({ id: page.getId(), name: page.getName() })),
            actions: controller.listActions().length,
          })),
          transitions: component.listTransitions().map((transition) => ({
            name: transition.getName(), fps: transition.getFps(),
            autoPlay: transition.getAutoPlay(), autoPlayTimes: transition.getAutoPlayTimes(),
            itemCount: transition.listItems().length,
          })),
        })),
        imageResources: pkg.listImageResources().map((image) => ({
          id: image.getId(), name: image.getName(), path: image.getPath(),
          width: image.getWidth(), height: image.getHeight(),
          fileName: call(image, 'getFileName', null),
        })),
      };
    });
    results.push({ path: filePath, status: 'PARSED', packageCount: packageRows.length, packages: packageRows });
  } catch (error) {
    results.push({ path: filePath, status: 'PARSE_ERROR', error: String(error?.stack ?? error).slice(0, 4000) });
  }
}
const report = {
  schemaVersion: '1.0.0',
  parser: '@openfairygui/core 0.7.0 (MIT)',
  protocolScope: 'FairyGUI published binary package V7 only',
  candidates: candidates.length,
  parsed: results.filter((row) => row.status === 'PARSED').length,
  failed: results.filter((row) => row.status === 'PARSE_ERROR').length,
  skippedNonV7: (inventory.records ?? []).length - candidates.length,
  results,
};
await fs.writeFile(path.join(outputDir, 'fui-package-analysis.json'), JSON.stringify(report, null, 2) + '\n');
console.log(JSON.stringify({ candidates: report.candidates, parsed: report.parsed, failed: report.failed, skippedNonV7: report.skippedNonV7 }, null, 2));
