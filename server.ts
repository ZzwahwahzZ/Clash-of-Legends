import express from 'express';
import { createServer as createViteServer } from 'vite';
import { exec } from 'child_process';
import fs from 'fs';
import path from 'path';

import crypto from 'crypto';

async function startServer() {
  const app = express();
  const PORT = process.env.PORT ? parseInt(process.env.PORT) : 3000;

  app.use(express.json());

  // Dynamic API route returning live ZIP metadata and SHA-256
  app.get('/api/zip-info', (_req, res) => {
    const zipPath = path.resolve(process.cwd(), 'Clash-of-Legends-Full-Project.zip');
    if (!fs.existsSync(zipPath)) {
      return res.status(404).json({ error: 'Archive not found' });
    }
    const stat = fs.statSync(zipPath);
    const fileBuffer = fs.readFileSync(zipPath);
    const hash = crypto.createHash('sha256').update(fileBuffer).digest('hex');

    let totalFiles = 65;
    let uncompressedBytes = 412825;
    const invPath = path.resolve(process.cwd(), 'PROJECT_INVENTORY.json');
    if (fs.existsSync(invPath)) {
      try {
        const inv = JSON.parse(fs.readFileSync(invPath, 'utf-8'));
        totalFiles = inv.total_files || totalFiles;
        uncompressedBytes = inv.total_uncompressed_bytes || uncompressedBytes;
      } catch {
        // use fallback
      }
    }

    res.json({
      fileName: 'Clash-of-Legends-Full-Project.zip',
      sizeBytes: stat.size,
      sizeHuman: `${(stat.size / (1024 * 1024)).toFixed(2)} MB (${stat.size.toLocaleString()} bytes)`,
      sha256: hash,
      totalFiles,
      uncompressedBytes,
      uncompressedHuman: `${(uncompressedBytes / (1024 * 1024)).toFixed(3)} MB (${uncompressedBytes.toLocaleString()} bytes)`,
      compressionRatio: `${(uncompressedBytes / stat.size).toFixed(2)}:1`,
      status: 'BLOCKED'
    });
  });

  // Dedicated download endpoints for full project ZIP
  const handleZipDownload = (_req: express.Request, res: express.Response) => {
    const zipPath = path.resolve(process.cwd(), 'Clash-of-Legends-Full-Project.zip');
    if (!fs.existsSync(zipPath)) {
      return res.status(404).send('ZIP file not found.');
    }
    res.setHeader('Content-Type', 'application/zip');
    res.setHeader('Content-Disposition', 'attachment; filename="Clash-of-Legends-Full-Project.zip"');
    res.sendFile(zipPath);
  };

  app.get('/download/Clash-of-Legends-Full-Project.zip', handleZipDownload);
  app.get('/api/download-project-zip', handleZipDownload);

  // API route to get project report files
  app.get('/api/reports/:reportName', (req, res) => {
    const validReports: Record<string, string> = {
      'audit': 'PROJECT_AUDIT.md',
      'compatibility': 'GODOT_4_3_COMPATIBILITY_REPORT.md',
      'integration': 'SYSTEM_INTEGRATION_MATRIX.md',
      'devlog': 'DEVELOPMENT_LOG.md',
      'acceptance': 'TESTING_ACCEPTANCE_REPORT.md',
      'manifest': 'RESOURCE_MANIFEST',
      'research': 'REFERENCE_RESEARCH_SPECIFICATION.md',
      'reconciliation': 'RESOURCE_RECONCILIATION_REPORT.md',
      'inventory': 'PROJECT_INVENTORY.md',
      'visual': 'VISUAL_ACCEPTANCE_REPORT.md'
    };

    const fileName = validReports[req.params.reportName];
    if (!fileName) {
      return res.status(404).json({ error: 'Report not found' });
    }

    const filePath = path.resolve(process.cwd(), fileName);
    if (!fs.existsSync(filePath)) {
      return res.status(404).json({ error: 'File does not exist' });
    }

    const content = fs.readFileSync(filePath, 'utf-8');
    res.json({ name: fileName, content });
  });

  // API route to list Godot files
  app.get('/api/godot-tree', (req, res) => {
    const files = [
      'project.godot',
      'export_presets.cfg',
      'assets/shaders/weapon_glow.gdshader',
      'scripts/core/GameManager.gd',
      'scripts/core/LocalSaveEngine.gd',
      'scripts/combat/CombatEngine.gd',
      'scripts/automation/AutoHuntManager.gd',
      'scripts/automation/AutoLootManager.gd',
      'scripts/automation/QuestNavigationAgent.gd',
      'scripts/player/PlayerController.gd',
      'scripts/player/FreeCamera3D.gd',
      'scripts/player/PlayerInventory.gd',
      'scripts/enemies/MonsterBase.gd',
      'scripts/npcs/NPCBase.gd',
      'scripts/combat/LootDrop3D.gd',
      'scripts/ai/SimulatedPlayer.gd',
      'scripts/ui/MainHUDController.gd',
      'scripts/ui/VirtualJoystickController.gd',
      'scripts/ui/InventoryUI.gd',
      'scripts/ui/BlacksmithUI.gd',
      'scripts/ui/SettingsUI.gd',
      'scripts/ui/DialogueUI.gd',
      'scripts/core/TestRunner.gd',
      'scenes/characters/Player.tscn',
      'scenes/core/MainGame.tscn',
      'scenes/world/LootDrop3D.tscn',
      'scenes/enemies/MonsterBase.tscn',
      'scenes/enemies/WildWolf.tscn',
      'scenes/enemies/BossDragon.tscn',
      'scenes/npcs/NPCBase.tscn',
      'scenes/characters/SimulatedPlayer.tscn',
      'scenes/core/TestRunnerScene.tscn',
      'scenes/ui/DialogueUI.tscn',
      'scenes/ui/InventoryUI.tscn',
      'scenes/ui/BlacksmithUI.tscn',
      'scenes/ui/SettingsUI.tscn',
      'scenes/ui/MainHUD.tscn'
    ];

    const results = files.map(f => {
      const fullPath = path.resolve(process.cwd(), f);
      const exists = fs.existsSync(fullPath);
      let size = 0;
      if (exists) {
        size = fs.statSync(fullPath).size;
      }
      return { path: f, exists, size };
    });

    res.json({ files: results });
  });

  // API to read any specific Godot file content
  app.get('/api/file-content', (req, res) => {
    const relPath = req.query.path as string;
    if (!relPath) return res.status(400).json({ error: 'Missing path' });

    // Sanitize
    const cleanPath = path.normalize(relPath).replace(/^(\.\.[\/\\])+/, '');
    const fullPath = path.resolve(process.cwd(), cleanPath);
    if (!fs.existsSync(fullPath)) {
      return res.status(404).json({ error: 'File not found' });
    }

    const content = fs.readFileSync(fullPath, 'utf-8');
    res.json({ path: relPath, content });
  });

  // Mount Vite development server middleware
  const vite = await createViteServer({
    server: { middlewareMode: true },
    appType: 'spa',
  });

  app.use(vite.middlewares);

  app.listen(PORT, '0.0.0.0', () => {
    console.log(`Clash of Legends Studio Server running at http://0.0.0.0:${PORT}`);
  });
}

startServer();
