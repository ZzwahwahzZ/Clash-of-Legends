import React, { useEffect, useRef, useState } from 'react';
import * as THREE from 'three';
import { 
  Shield, 
  Swords, 
  Crosshair, 
  Zap, 
  Sparkles, 
  Compass, 
  Backpack, 
  Hammer, 
  Settings as SettingsIcon, 
  RefreshCw, 
  ChevronRight, 
  Eye, 
  Volume2, 
  VolumeX, 
  Save, 
  CheckCircle2, 
  AlertTriangle,
  Play,
  RotateCcw
} from 'lucide-react';

interface GameWorldCanvasProps {
  language: 'ar' | 'en';
  playerClass: string;
  onClassChange: (cls: string) => void;
  gold: number;
  setGold: React.Dispatch<React.SetStateAction<number>>;
  level: number;
  setLevel: React.Dispatch<React.SetStateAction<number>>;
  onOpenInventory: () => void;
  onOpenBlacksmith: () => void;
  onOpenSettings: () => void;
  isAutoHunt: boolean;
  setIsAutoHunt: React.Dispatch<React.SetStateAction<boolean>>;
  isAutoLoot: boolean;
  setIsAutoLoot: React.Dispatch<React.SetStateAction<boolean>>;
  onNotify: (msg: string, isAlert?: boolean) => void;
  questProgress: number;
  setQuestProgress: React.Dispatch<React.SetStateAction<number>>;
  questGoal: number;
  onInteractNPC: (role: string, name: string) => void;
}

export const GameWorldCanvas: React.FC<GameWorldCanvasProps> = ({
  language,
  playerClass,
  onClassChange,
  gold,
  setGold,
  level,
  setLevel,
  onOpenInventory,
  onOpenBlacksmith,
  onOpenSettings,
  isAutoHunt,
  setIsAutoHunt,
  isAutoLoot,
  setIsAutoLoot,
  onNotify,
  questProgress,
  setQuestProgress,
  questGoal,
  onInteractNPC
}) => {
  const containerRef = useRef<HTMLDivElement>(null);
  const [hp, setHp] = useState(500);
  const [maxHp, setMaxHp] = useState(500);
  const [mp, setMp] = useState(200);
  const [maxMp, setMaxMp] = useState(200);
  const [xp, setXp] = useState(0);
  const [maxXp, setMaxXp] = useState(1000);
  const [isMounted, setIsMounted] = useState(false);
  const [targetEnemy, setTargetEnemy] = useState<string | null>(null);
  const [targetEnemyHp, setTargetEnemyHp] = useState<number>(160);
  const [damageTexts, setDamageTexts] = useState<Array<{ id: number; text: string; x: number; y: number; isCrit: boolean }>>([]);

  const isAr = language === 'ar';

  // Three.js game state references
  const stateRef = useRef({
    playerPos: new THREE.Vector3(0, 0, 0),
    playerVelocity: new THREE.Vector3(0, 0, 0),
    playerRotation: 0,
    joystickDir: new THREE.Vector2(0, 0),
    cameraYaw: 0,
    cameraPitch: 0.65,
    cameraZoom: 18,
    isMouseDown: false,
    lastMouseX: 0,
    lastMouseY: 0,
    wolves: [
      { id: 1, pos: new THREE.Vector3(14, 0, 10), hp: 160, maxHp: 160, state: 'idle', timer: 0 },
      { id: 2, pos: new THREE.Vector3(18, 0, 15), hp: 160, maxHp: 160, state: 'idle', timer: 1 },
      { id: 3, pos: new THREE.Vector3(16, 0, 22), hp: 160, maxHp: 160, state: 'idle', timer: 2 },
      { id: 4, pos: new THREE.Vector3(22, 0, 14), hp: 160, maxHp: 160, state: 'idle', timer: 0.5 },
    ],
    dragon: { pos: new THREE.Vector3(32, 0, -28), hp: 2400, maxHp: 2400, state: 'idle' },
    simPlayers: [
      { id: 1, name: 'سيد_السيوف', pos: new THREE.Vector3(-3, 0, -4), target: new THREE.Vector3(-3, 0, -4) },
      { id: 2, name: 'صائد_الكنوز', pos: new THREE.Vector3(4, 0, 6), target: new THREE.Vector3(4, 0, 6) }
    ],
    lootDrops: [] as Array<{ id: number; pos: THREE.Vector3; gold: number; isItem: boolean; mesh: THREE.Mesh }>,
    skillCooldowns: { s1: 0, s2: 0, basic: 0 }
  });

  const joystickTouchRef = useRef<{ id: number; startX: number; startY: number } | null>(null);

  // Synchronization refs to decouple Three.js render loop from React state updates
  const isMountedRef = useRef(isMounted);
  const isAutoHuntRef = useRef(isAutoHunt);
  const isAutoLootRef = useRef(isAutoLoot);
  const questProgressRef = useRef(questProgress);
  const questGoalRef = useRef(questGoal);
  const hpRef = useRef(500);
  const maxHpRef = useRef(500);
  const isArRef = useRef(isAr);
  const onNotifyRef = useRef(onNotify);
  const setGoldRef = useRef(setGold);
  const setLevelRef = useRef(setLevel);
  const setQuestProgressRef = useRef(setQuestProgress);

  useEffect(() => { isMountedRef.current = isMounted; }, [isMounted]);
  useEffect(() => { isAutoHuntRef.current = isAutoHunt; }, [isAutoHunt]);
  useEffect(() => { isAutoLootRef.current = isAutoLoot; }, [isAutoLoot]);
  useEffect(() => { questProgressRef.current = questProgress; }, [questProgress]);
  useEffect(() => { questGoalRef.current = questGoal; }, [questGoal]);
  useEffect(() => { isArRef.current = isAr; }, [isAr]);
  useEffect(() => {
    onNotifyRef.current = onNotify;
    setGoldRef.current = setGold;
    setLevelRef.current = setLevel;
    setQuestProgressRef.current = setQuestProgress;
  });

  useEffect(() => {
    if (!containerRef.current) return;
    const container = containerRef.current;
    const width = container.clientWidth;
    const height = container.clientHeight;

    // Three.js Scene Setup
    const scene = new THREE.Scene();
    scene.background = new THREE.Color(0x131a24);
    scene.fog = new THREE.FogExp2(0x131a24, 0.015);

    const camera = new THREE.PerspectiveCamera(45, width / height, 0.5, 200);

    const renderer = new THREE.WebGLRenderer({ antialias: true, powerPreference: 'high-performance' });
    renderer.setSize(width, height);
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    renderer.shadowMap.enabled = true;
    renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    container.appendChild(renderer.domElement);

    // Lighting
    const ambientLight = new THREE.AmbientLight(0xffffff, 0.85);
    scene.add(ambientLight);

    const sunLight = new THREE.DirectionalLight(0xfffaed, 1.4);
    sunLight.position.set(20, 35, 20);
    sunLight.castShadow = true;
    sunLight.shadow.mapSize.width = 1024;
    sunLight.shadow.mapSize.height = 1024;
    scene.add(sunLight);

    // Ground: Twin Plains Terrain
    const groundGeo = new THREE.PlaneGeometry(140, 140, 32, 32);
    const groundMat = new THREE.MeshStandardMaterial({
      color: 0x2d4a27,
      roughness: 0.9,
      metalness: 0.1
    });
    const ground = new THREE.Mesh(groundGeo, groundMat);
    ground.rotation.x = -Math.PI / 2;
    ground.receiveShadow = true;
    scene.add(ground);

    // Twin City Cobblestone Plaza
    const plazaGeo = new THREE.CylinderGeometry(14, 14, 0.1, 32);
    const plazaMat = new THREE.MeshStandardMaterial({
      color: 0x5a544d,
      roughness: 0.7,
      metalness: 0.2
    });
    const plaza = new THREE.Mesh(plazaGeo, plazaMat);
    plaza.position.set(0, 0.05, 0);
    plaza.receiveShadow = true;
    scene.add(plaza);

    // Town Gateway Pillars (Conquer Online Twin City Gates style)
    const pillarMat = new THREE.MeshStandardMaterial({ color: 0x8b3a2b, roughness: 0.5 });
    const p1 = new THREE.Mesh(new THREE.CylinderGeometry(0.8, 0.8, 6, 16), pillarMat);
    p1.position.set(-8, 3, 10);
    scene.add(p1);
    const p2 = new THREE.Mesh(new THREE.CylinderGeometry(0.8, 0.8, 6, 16), pillarMat);
    p2.position.set(8, 3, 10);
    scene.add(p2);
    const archMat = new THREE.MeshStandardMaterial({ color: 0xd4af37, roughness: 0.4, metalness: 0.6 });
    const arch = new THREE.Mesh(new THREE.BoxGeometry(18, 1.2, 2), archMat);
    arch.position.set(0, 6.2, 10);
    scene.add(arch);

    // Player Mesh Group
    const playerGroup = new THREE.Group();
    const bodyMat = new THREE.MeshStandardMaterial({ color: 0x2563eb, roughness: 0.4 });
    const playerBody = new THREE.Mesh(new THREE.CapsuleGeometry(0.5, 1.2, 8, 16), bodyMat);
    playerBody.position.y = 1.1;
    playerBody.castShadow = true;
    playerGroup.add(playerBody);

    // Glowing Weapon Mesh (Shader Simulation matching weapon_glow.gdshader)
    const weaponGeo = new THREE.BoxGeometry(0.2, 1.4, 0.35);
    const weaponMat = new THREE.MeshStandardMaterial({
      color: 0xffaa00,
      emissive: 0xff5500,
      emissiveIntensity: 1.8,
      roughness: 0.2,
      metalness: 0.8
    });
    const weaponMesh = new THREE.Mesh(weaponGeo, weaponMat);
    weaponMesh.position.set(0.65, 1.2, 0.3);
    weaponMesh.rotation.z = -0.4;
    weaponMesh.castShadow = true;
    playerGroup.add(weaponMesh);

    // Horse Mount
    const mountGeo = new THREE.BoxGeometry(1.2, 1.0, 2.2);
    const mountMat = new THREE.MeshStandardMaterial({ color: 0x4a2e18, roughness: 0.7 });
    const mountMesh = new THREE.Mesh(mountGeo, mountMat);
    mountMesh.position.y = 0.6;
    mountMesh.visible = false;
    playerGroup.add(mountMesh);

    scene.add(playerGroup);

    // NPC Meshes
    const npcsData = [
      { name: isAr ? 'حكيم التوأم' : 'Twin Sage', role: 'sage', color: 0x10b981, pos: [4, 1.1, 4] },
      { name: isAr ? 'حداد الأساطير' : 'Master Blacksmith', role: 'blacksmith', color: 0xf59e0b, pos: [-5, 1.1, 4] },
      { name: isAr ? 'تاجر القوافل' : 'General Merchant', role: 'merchant', color: 0x8b5cf6, pos: [6, 1.1, -4] },
      { name: isAr ? 'حارس البوابة' : 'Dungeon Warden', role: 'warden', color: 0xef4444, pos: [-7, 1.1, -5] }
    ];

    const npcMeshes: THREE.Group[] = [];
    npcsData.forEach(npc => {
      const g = new THREE.Group();
      const m = new THREE.Mesh(
        new THREE.CapsuleGeometry(0.48, 1.1, 8, 16),
        new THREE.MeshStandardMaterial({ color: npc.color, roughness: 0.5 })
      );
      m.castShadow = true;
      g.add(m);
      g.position.set(npc.pos[0], npc.pos[1], npc.pos[2]);
      g.userData = { role: npc.role, name: npc.name };
      scene.add(g);
      npcMeshes.push(g);
    });

    // Wolves Meshes
    const wolfMat = new THREE.MeshStandardMaterial({ color: 0x78716c, roughness: 0.8 });
    const wolfMeshes: THREE.Mesh[] = [];
    stateRef.current.wolves.forEach(w => {
      const wolfMesh = new THREE.Mesh(new THREE.BoxGeometry(0.8, 0.7, 1.4), wolfMat);
      wolfMesh.position.copy(w.pos);
      wolfMesh.position.y = 0.45;
      wolfMesh.castShadow = true;
      scene.add(wolfMesh);
      wolfMeshes.push(wolfMesh);
    });

    // Dragon Boss Mesh
    const dragonMat = new THREE.MeshStandardMaterial({
      color: 0x991b1b,
      emissive: 0xef4444,
      emissiveIntensity: 0.8,
      roughness: 0.3
    });
    const dragonMesh = new THREE.Mesh(new THREE.CylinderGeometry(1.6, 2.2, 4.0, 16), dragonMat);
    dragonMesh.position.copy(stateRef.current.dragon.pos);
    dragonMesh.position.y = 2.0;
    dragonMesh.castShadow = true;
    scene.add(dragonMesh);

    // Simulated Players
    const simMat = new THREE.MeshStandardMaterial({ color: 0x06b6d4, roughness: 0.5 });
    const simMeshes: THREE.Mesh[] = [];
    stateRef.current.simPlayers.forEach(sp => {
      const sm = new THREE.Mesh(new THREE.CapsuleGeometry(0.45, 1.1, 8, 16), simMat);
      sm.position.copy(sp.pos);
      sm.position.y = 1.1;
      sm.castShadow = true;
      scene.add(sm);
      simMeshes.push(sm);
    });

    // Handle Resize
    const handleResize = () => {
      if (!container) return;
      const w = container.clientWidth;
      const h = container.clientHeight;
      camera.aspect = w / h;
      camera.updateProjectionMatrix();
      renderer.setSize(w, h);
    };
    window.addEventListener('resize', handleResize);

    // Animation Loop
    let animId: number;
    let clock = new THREE.Clock();

    const animate = () => {
      animId = requestAnimationFrame(animate);
      const delta = Math.min(clock.getDelta(), 0.1);
      const time = clock.getElapsedTime();

      // Weapon pulse shader glow simulation
      const pulse = 1.0 + Math.sin(time * 3.5) * 0.45;
      weaponMat.emissiveIntensity = 1.5 * pulse;

      // Player Movement Logic
      const speed = isMountedRef.current ? 9.5 : 6.0;
      const state = stateRef.current;

      // Handle Auto-Hunt AI if enabled
      if (isAutoHuntRef.current) {
        let nearestWolf = null;
        let minDist = 30;
        state.wolves.forEach(w => {
          if (w.hp > 0) {
            const d = state.playerPos.distanceTo(w.pos);
            if (d < minDist) {
              minDist = d;
              nearestWolf = w;
            }
          }
        });

        if (nearestWolf) {
          const diff = (nearestWolf as any).pos.clone().sub(state.playerPos);
          diff.y = 0;
          if (diff.length() > 2.5) {
            diff.normalize();
            state.playerPos.add(diff.multiplyScalar(speed * delta));
            state.playerRotation = Math.atan2(diff.x, diff.z);
          } else {
            // In range: auto attack
            if (state.skillCooldowns.basic <= 0) {
              state.skillCooldowns.basic = 0.8;
              (nearestWolf as any).hp -= 48;
              setTargetEnemy(isArRef.current ? 'ذئب بري' : 'Wild Wolf');
              setTargetEnemyHp((nearestWolf as any).hp);
              showFloatingText('-48', true);
              if ((nearestWolf as any).hp <= 0) {
                handleMonsterKilled((nearestWolf as any).id, (nearestWolf as any).pos);
              }
            }
          }
        }
      } else if (state.joystickDir.lengthSq() > 0.01) {
        // Manual Joystick Movement
        const camYaw = state.cameraYaw;
        const forward = new THREE.Vector3(0, 0, -1).applyAxisAngle(new THREE.Vector3(0, 1, 0), camYaw);
        const right = new THREE.Vector3(1, 0, 0).applyAxisAngle(new THREE.Vector3(0, 1, 0), camYaw);
        const moveVec = right.multiplyScalar(state.joystickDir.x).add(forward.multiplyScalar(-state.joystickDir.y)).normalize();

        state.playerPos.add(moveVec.multiplyScalar(speed * delta));
        state.playerRotation = Math.atan2(moveVec.x, moveVec.z);
      }

      playerGroup.position.copy(state.playerPos);
      playerGroup.rotation.y = state.playerRotation;
      mountMesh.visible = isMountedRef.current;

      // Elevated MMORPG Camera Follow with Yaw & Pitch
      const camDist = state.cameraZoom;
      const pitch = state.cameraPitch;
      const yaw = state.cameraYaw;
      const camOffset = new THREE.Vector3(
        Math.sin(yaw) * Math.cos(pitch) * camDist,
        Math.sin(pitch) * camDist,
        Math.cos(yaw) * Math.cos(pitch) * camDist
      );
      camera.position.copy(state.playerPos).add(camOffset);
      camera.lookAt(state.playerPos.x, state.playerPos.y + 1.2, state.playerPos.z);

      // Update Wolves AI
      state.wolves.forEach((w, idx) => {
        const mesh = wolfMeshes[idx];
        if (w.hp <= 0) {
          mesh.visible = false;
          return;
        }
        mesh.visible = true;

        const distToPlayer = w.pos.distanceTo(state.playerPos);
        if (distToPlayer < 12.0) {
          // Chase Player
          const dir = state.playerPos.clone().sub(w.pos).normalize();
          dir.y = 0;
          if (distToPlayer > 2.0) {
            w.pos.add(dir.multiplyScalar(3.2 * delta));
          } else {
            // Attack player
            w.timer += delta;
            if (w.timer > 1.5) {
              w.timer = 0;
              const nextHp = Math.max(0, hpRef.current - 24);
              hpRef.current = nextHp;
              if (nextHp <= 0) {
                state.playerPos.set(0, 0, 0);
                hpRef.current = maxHpRef.current;
                setTimeout(() => {
                  setHp(maxHpRef.current);
                  onNotifyRef.current(isArRef.current ? 'سقط البطل! إعادة الإحياء في مدينة التوأم...' : 'You died! Respawning in Twin City...', true);
                }, 0);
              } else {
                setHp(nextHp);
              }
            }
          }
          mesh.lookAt(state.playerPos.x, mesh.position.y, state.playerPos.z);
        }
        mesh.position.copy(w.pos);
        mesh.position.y = 0.45;
      });

      // Update Simulated Players (Local Offline Roaming)
      state.simPlayers.forEach((sp, idx) => {
        const sm = simMeshes[idx];
        const dist = sp.pos.distanceTo(sp.target);
        if (dist < 0.5) {
          sp.target = sp.pos.clone().add(new THREE.Vector3((Math.random() - 0.5) * 16, 0, (Math.random() - 0.5) * 16));
        } else {
          const dir = sp.target.clone().sub(sp.pos).normalize();
          sp.pos.add(dir.multiplyScalar(2.8 * delta));
          sm.lookAt(sp.target.x, sm.position.y, sp.target.z);
        }
        sm.position.copy(sp.pos);
        sm.position.y = 1.1;
      });

      // Auto-Loot Check
      if (isAutoLootRef.current && state.lootDrops.length > 0) {
        state.lootDrops = state.lootDrops.filter(ld => {
          if (state.playerPos.distanceTo(ld.pos) < 6.0) {
            scene.remove(ld.mesh);
            const goldEarned = ld.gold;
            setTimeout(() => {
              setGoldRef.current(prev => prev + goldEarned);
              onNotifyRef.current(isArRef.current ? `جمع تلقائي: +${goldEarned} ذهب!` : `Auto-Loot: +${goldEarned} Gold!`, false);
            }, 0);
            return false;
          }
          return true;
        });
      }

      // Check Proximity to NPCs for Interaction Prompts
      npcMeshes.forEach(nm => {
        if (state.playerPos.distanceTo(nm.position) < 3.2) {
          // In range
        }
      });

      // Cooldown decrement
      if (state.skillCooldowns.basic > 0) state.skillCooldowns.basic -= delta;
      if (state.skillCooldowns.s1 > 0) state.skillCooldowns.s1 -= delta;
      if (state.skillCooldowns.s2 > 0) state.skillCooldowns.s2 -= delta;

      renderer.render(scene, camera);
    };

    animId = requestAnimationFrame(animate);

    // Monster Kill Handler inside loop closure
    const handleMonsterKilled = (id: number, pos: THREE.Vector3) => {
      const currentQ = questProgressRef.current;
      const goal = questGoalRef.current;
      const nextQ = Math.min(goal, currentQ + 1);
      questProgressRef.current = nextQ;

      setTimeout(() => {
        setQuestProgressRef.current(nextQ);
        if (nextQ >= goal && currentQ < goal) {
          setGoldRef.current(g => g + 500);
          setXp(x => {
            const nx = x + 800;
            return nx >= 1000 ? nx - 1000 : nx;
          });
          setLevelRef.current(l => l + 1);
          onNotifyRef.current(isArRef.current ? 'اكتملت المهمة! حصلت على 500 ذهب و 800 خبرة' : 'Quest Complete! +500 Gold & +800 XP', false);
        }
      }, 0);

      // Spawn 3D Loot Coin
      const coinMat = new THREE.MeshStandardMaterial({
        color: 0xffd700,
        emissive: 0xffaa00,
        emissiveIntensity: 1.5,
        metalness: 0.9,
        roughness: 0.1
      });
      const coinMesh = new THREE.Mesh(new THREE.CylinderGeometry(0.35, 0.35, 0.15, 16), coinMat);
      coinMesh.position.copy(pos);
      coinMesh.position.y = 0.3;
      scene.add(coinMesh);

      stateRef.current.lootDrops.push({
        id: Date.now(),
        pos: pos.clone(),
        gold: Math.floor(40 + Math.random() * 55),
        isItem: Math.random() > 0.6,
        mesh: coinMesh
      });

      // Respawn wolf after 6 seconds
      setTimeout(() => {
        const w = stateRef.current.wolves.find(item => item.id === id);
        if (w) {
          w.hp = w.maxHp;
          w.pos.set(16 + (Math.random() - 0.5) * 8, 0, 14 + (Math.random() - 0.5) * 8);
        }
      }, 6000);
    };

    return () => {
      cancelAnimationFrame(animId);
      window.removeEventListener('resize', handleResize);
      if (container && renderer.domElement) {
        container.removeChild(renderer.domElement);
      }
      renderer.dispose();
    };
  }, [language]);

  const showFloatingText = (text: string, isCrit: boolean) => {
    const id = Date.now() + Math.random();
    setDamageTexts(prev => [...prev, { id, text, x: window.innerWidth * 0.5 + (Math.random() - 0.5) * 120, y: window.innerHeight * 0.45 + (Math.random() - 0.5) * 60, isCrit }]);
    setTimeout(() => {
      setDamageTexts(prev => prev.filter(d => d.id !== id));
    }, 1200);
  };

  // Combat Execution
  const handleAttack = () => {
    const state = stateRef.current;
    let hit = false;
    state.wolves.forEach(w => {
      if (w.hp > 0 && state.playerPos.distanceTo(w.pos) < 3.8) {
        const isCrit = Math.random() < 0.25;
        const dmg = Math.floor((isCrit ? 75 : 45) + Math.random() * 15);
        w.hp -= dmg;
        setTargetEnemy(isArRef.current ? 'ذئب بري' : 'Wild Wolf');
        setTargetEnemyHp(Math.max(0, w.hp));
        showFloatingText(isCrit ? `حرجة! -${dmg}` : `-${dmg}`, isCrit);
        hit = true;
        if (w.hp <= 0) {
          const nextQ = Math.min(questGoalRef.current, questProgressRef.current + 1);
          questProgressRef.current = nextQ;
          setTimeout(() => {
            setQuestProgressRef.current(nextQ);
            setGoldRef.current(g => g + 65);
          }, 0);
        }
      }
    });

    if (!hit) {
      showFloatingText(isArRef.current ? 'تجنب' : 'Miss', false);
    }
  };

  // Skill Execution (Class-Specific Conquer Online mechanics)
  const handleCastSkill = (skillNum: 1 | 2) => {
    const state = stateRef.current;
    if (mp < 25) {
      setTimeout(() => {
        onNotifyRef.current(isArRef.current ? 'طاقة غير كافية!' : 'Insufficient Mana!', true);
      }, 0);
      return;
    }
    setMp(m => Math.max(0, m - 25));

    if (skillNum === 1) {
      // Primary class skill: e.g. Trojan Cyclone AoE or Archer Rapid Arrow
      let hitCount = 0;
      state.wolves.forEach(w => {
        if (w.hp > 0 && state.playerPos.distanceTo(w.pos) < 6.5) {
          const dmg = Math.floor(95 + Math.random() * 30);
          w.hp -= dmg;
          showFloatingText(`إعصار! -${dmg}`, true);
          hitCount++;
          if (w.hp <= 0) {
            const nextQ = Math.min(questGoalRef.current, questProgressRef.current + 1);
            questProgressRef.current = nextQ;
            setTimeout(() => {
              setQuestProgressRef.current(nextQ);
              setGoldRef.current(g => g + 80);
            }, 0);
          }
        }
      });
      setTimeout(() => {
        onNotifyRef.current(isArRef.current ? `تم تنفيذ المهارة الخاصة: أصابت ${hitCount} أهداف!` : `Skill Executed: Hit ${hitCount} targets!`, false);
      }, 0);
    } else {
      // Secondary Skill: Self heal or Buff
      setHp(h => Math.min(maxHp, h + 180));
      hpRef.current = Math.min(maxHp, hpRef.current + 180);
      showFloatingText(isArRef.current ? '+180 شفاء' : '+180 Heal', false);
      setTimeout(() => {
        onNotifyRef.current(isArRef.current ? 'تم استعادة 180 نقطة صحة!' : 'Restored 180 HP!', false);
      }, 0);
    }
  };

  // Touch Camera Drag Handlers
  const handleMouseDown = (e: React.MouseEvent) => {
    stateRef.current.isMouseDown = true;
    stateRef.current.lastMouseX = e.clientX;
    stateRef.current.lastMouseY = e.clientY;
  };

  const handleMouseMove = (e: React.MouseEvent) => {
    if (!stateRef.current.isMouseDown) return;
    const dx = e.clientX - stateRef.current.lastMouseX;
    const dy = e.clientY - stateRef.current.lastMouseY;
    stateRef.current.cameraYaw -= dx * 0.006;
    stateRef.current.cameraPitch = Math.max(0.2, Math.min(1.2, stateRef.current.cameraPitch + dy * 0.006));
    stateRef.current.lastMouseX = e.clientX;
    stateRef.current.lastMouseY = e.clientY;
  };

  const handleMouseUp = () => {
    stateRef.current.isMouseDown = false;
  };

  // Virtual Joystick Touch Handling
  const handleTouchStart = (e: React.TouchEvent) => {
    const touch = e.touches[0];
    const rect = e.currentTarget.getBoundingClientRect();
    const centerX = rect.left + rect.width / 2;
    const centerY = rect.top + rect.height / 2;
    joystickTouchRef.current = { id: touch.identifier, startX: centerX, startY: centerY };
    updateJoystickPos(touch.clientX, touch.clientY, centerX, centerY);
  };

  const handleTouchMove = (e: React.TouchEvent) => {
    if (!joystickTouchRef.current) return;
    for (let i = 0; i < e.touches.length; i++) {
      if (e.touches[i].identifier === joystickTouchRef.current.id) {
        updateJoystickPos(
          e.touches[i].clientX,
          e.touches[i].clientY,
          joystickTouchRef.current.startX,
          joystickTouchRef.current.startY
        );
        break;
      }
    }
  };

  const handleTouchEnd = () => {
    joystickTouchRef.current = null;
    stateRef.current.joystickDir.set(0, 0);
  };

  const updateJoystickPos = (x: number, y: number, cx: number, cy: number) => {
    const maxRadius = 45;
    const dx = x - cx;
    const dy = y - cy;
    const dist = Math.hypot(dx, dy);
    const clampedDist = Math.min(dist, maxRadius);
    const angle = Math.atan2(dy, dx);
    const nx = (Math.cos(angle) * clampedDist) / maxRadius;
    const ny = (Math.sin(angle) * clampedDist) / maxRadius;
    stateRef.current.joystickDir.set(nx, ny);
  };

  return (
    <div 
      className="relative w-full h-[620px] md:h-[720px] bg-slate-950 overflow-hidden select-none"
      onMouseDown={handleMouseDown}
      onMouseMove={handleMouseMove}
      onMouseUp={handleMouseUp}
      dir={isAr ? 'rtl' : 'ltr'}
    >
      {/* 3D WebGL Canvas Container */}
      <div ref={containerRef} className="absolute inset-0 w-full h-full cursor-grab active:cursor-grabbing" />

      {/* Floating Damage Text Overlay */}
      {damageTexts.map(d => (
        <div
          key={d.id}
          className={`absolute pointer-events-none font-black text-lg md:text-xl transform -translate-x-1/2 -translate-y-1/2 animate-bounce transition-all ${
            d.isCrit ? 'text-red-500 scale-125 drop-shadow-[0_2px_8px_rgba(239,68,68,0.8)]' : 'text-amber-300 drop-shadow-[0_2px_4px_rgba(0,0,0,0.8)]'
          }`}
          style={{ left: `${d.x}px`, top: `${d.y}px` }}
        >
          {d.text}
        </div>
      ))}

      {/* TOP LEFT: Hero Stats & Gold Bar */}
      <div className="absolute top-4 start-4 z-20 flex flex-col gap-2 max-w-[340px]">
        <div className="flex items-center gap-3 bg-slate-900/85 backdrop-blur-md p-2.5 rounded-2xl border border-slate-700/60 shadow-xl">
          {/* Level Badge */}
          <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-amber-500 to-amber-700 flex flex-col items-center justify-center font-black text-white shadow-lg shrink-0 border border-amber-400">
            <span className="text-[10px] uppercase font-bold text-amber-200">{isAr ? 'مستوى' : 'LVL'}</span>
            <span className="text-lg leading-none">{level}</span>
          </div>

          <div className="flex-1 flex flex-col gap-1.5 min-w-[150px]">
            {/* Health Bar */}
            <div className="flex flex-col">
              <div className="flex justify-between text-xs font-bold text-red-300 mb-0.5">
                <span>HP</span>
                <span>{hp} / {maxHp}</span>
              </div>
              <div className="w-full h-3 bg-slate-800 rounded-full overflow-hidden border border-red-900/50">
                <div 
                  className="h-full bg-gradient-to-r from-red-600 to-rose-400 rounded-full transition-all duration-200"
                  style={{ width: `${(hp / maxHp) * 100}%` }}
                />
              </div>
            </div>

            {/* Mana Bar */}
            <div className="flex flex-col">
              <div className="flex justify-between text-xs font-bold text-sky-300 mb-0.5">
                <span>MP</span>
                <span>{mp} / {maxMp}</span>
              </div>
              <div className="w-full h-2.5 bg-slate-800 rounded-full overflow-hidden border border-sky-900/50">
                <div 
                  className="h-full bg-gradient-to-r from-sky-600 to-cyan-400 rounded-full transition-all duration-200"
                  style={{ width: `${(mp / maxMp) * 100}%` }}
                />
              </div>
            </div>
          </div>
        </div>

        {/* Currency & Class Badge */}
        <div className="flex items-center gap-2">
          <div className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-amber-950/80 backdrop-blur-md border border-amber-600/50 shadow-md">
            <span className="text-amber-400 font-bold text-sm">💰 {isAr ? 'الذهب:' : 'Gold:'}</span>
            <span className="text-amber-200 font-black text-sm">{gold.toLocaleString()}</span>
          </div>

          <div className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-blue-950/80 backdrop-blur-md border border-blue-600/50 shadow-md">
            <span className="text-blue-300 text-xs font-bold">{isAr ? 'الفئة:' : 'Class:'}</span>
            <span className="text-blue-100 font-black text-xs">{playerClass}</span>
          </div>
        </div>
      </div>

      {/* TOP RIGHT: Quest Tracker & Quick Menu Controls */}
      <div className="absolute top-4 end-4 z-20 flex flex-col items-end gap-2.5">
        {/* Quest Tracker Banner */}
        <button 
          onClick={() => {
            stateRef.current.playerPos.set(16, 0, 14);
            onNotify(isAr ? 'الملاحة التلقائية: توجيه البطل إلى منطقة الذئاب في سهل التوأم' : 'Auto-Nav: Guiding Hero to Twin Plains wolves', false);
          }}
          className="flex items-center gap-3 px-4 py-2.5 bg-slate-900/90 hover:bg-slate-800/90 backdrop-blur-md rounded-2xl border border-amber-500/40 shadow-xl transition-all hover:scale-[1.02] text-start group cursor-pointer"
        >
          <div className="w-8 h-8 rounded-lg bg-amber-500/20 border border-amber-500/50 flex items-center justify-center text-amber-400 shrink-0">
            <Compass className="w-4 h-4 animate-spin-slow" />
          </div>
          <div>
            <div className="text-xs font-black text-amber-300 flex items-center gap-1">
              <span>{isAr ? 'تهديد الذئاب البرية' : 'Wild Wolf Threat'}</span>
              <span className="text-[10px] text-amber-400/80 font-normal">({isAr ? 'انقر للملاحة' : 'Tap to Nav'})</span>
            </div>
            <div className="text-xs text-slate-300 font-medium">
              {isAr ? `القضاء على الذئاب: ${questProgress} / ${questGoal}` : `Defeat Wolves: ${questProgress} / ${questGoal}`}
            </div>
          </div>
        </button>

        {/* Auto-Hunt & Auto-Loot Toggles */}
        <div className="flex items-center gap-2">
          <button
            onClick={() => {
              const next = !isAutoHunt;
              setIsAutoHunt(next);
              onNotify(next ? (isAr ? 'تم تفعيل الصيد التلقائي' : 'Auto-Hunt Enabled') : (isAr ? 'تم إيقاف الصيد التلقائي' : 'Auto-Hunt Disabled'), false);
            }}
            className={`flex items-center gap-1.5 px-3 py-1.5 rounded-xl font-bold text-xs transition-all cursor-pointer backdrop-blur-md border ${
              isAutoHunt 
                ? 'bg-emerald-600 text-white border-emerald-400 shadow-[0_0_15px_rgba(16,185,129,0.5)]' 
                : 'bg-slate-900/80 text-slate-300 border-slate-700/60 hover:bg-slate-800'
            }`}
          >
            <Play className={`w-3.5 h-3.5 ${isAutoHunt ? 'animate-pulse' : ''}`} />
            <span>{isAr ? 'صيد تلقائي' : 'Auto Hunt'}</span>
          </button>

          <button
            onClick={() => {
              const next = !isAutoLoot;
              setIsAutoLoot(next);
              onNotify(next ? (isAr ? 'تم تفعيل جمع الغنائم التلقائي' : 'Auto-Loot Enabled') : (isAr ? 'تم إيقاف جمع الغنائم' : 'Auto-Loot Disabled'), false);
            }}
            className={`flex items-center gap-1.5 px-3 py-1.5 rounded-xl font-bold text-xs transition-all cursor-pointer backdrop-blur-md border ${
              isAutoLoot 
                ? 'bg-amber-600 text-white border-amber-400 shadow-[0_0_15px_rgba(245,158,11,0.5)]' 
                : 'bg-slate-900/80 text-slate-300 border-slate-700/60 hover:bg-slate-800'
            }`}
          >
            <Sparkles className="w-3.5 h-3.5" />
            <span>{isAr ? 'جمع تلقائي' : 'Auto Loot'}</span>
          </button>
        </div>

        {/* Menus: Bag, Blacksmith, Settings */}
        <div className="flex items-center gap-2">
          <button
            onClick={onOpenInventory}
            className="flex items-center gap-1.5 px-3 py-1.5 bg-slate-900/80 hover:bg-slate-800 text-slate-200 font-bold text-xs rounded-xl border border-slate-700/60 backdrop-blur-md transition-all cursor-pointer"
          >
            <Backpack className="w-3.5 h-3.5 text-amber-400" />
            <span>{isAr ? 'الحقيبة (٤٠)' : 'Bag (40)'}</span>
          </button>

          <button
            onClick={onOpenBlacksmith}
            className="flex items-center gap-1.5 px-3 py-1.5 bg-slate-900/80 hover:bg-slate-800 text-slate-200 font-bold text-xs rounded-xl border border-slate-700/60 backdrop-blur-md transition-all cursor-pointer"
          >
            <Hammer className="w-3.5 h-3.5 text-orange-400" />
            <span>{isAr ? 'الحداد' : 'Forge'}</span>
          </button>

          <button
            onClick={onOpenSettings}
            className="flex items-center gap-1.5 px-3 py-1.5 bg-slate-900/80 hover:bg-slate-800 text-slate-200 font-bold text-xs rounded-xl border border-slate-700/60 backdrop-blur-md transition-all cursor-pointer"
          >
            <SettingsIcon className="w-3.5 h-3.5 text-slate-300" />
            <span>{isAr ? 'الإعدادات' : 'Settings'}</span>
          </button>
        </div>
      </div>

      {/* TARGET LOCK HUD (When engaging enemies) */}
      {targetEnemy && (
        <div className="absolute top-20 left-1/2 transform -translate-x-1/2 z-20 flex items-center gap-3 bg-red-950/80 backdrop-blur-md px-4 py-2 rounded-2xl border border-red-500/60 shadow-xl">
          <div className="w-3 h-3 rounded-full bg-red-500 animate-ping" />
          <div className="flex flex-col">
            <span className="text-xs font-black text-red-200">{targetEnemy}</span>
            <span className="text-[10px] text-red-300">HP: {targetEnemyHp}</span>
          </div>
        </div>
      )}

      {/* BOTTOM LEFT: Virtual Touch Joystick & Offline World Chat */}
      <div className="absolute bottom-6 start-6 z-20 flex flex-col gap-3">
        {/* Offline World Chat ticker */}
        <div className="bg-slate-950/80 backdrop-blur-md px-3 py-1.5 rounded-xl border border-slate-800/80 text-[11px] text-slate-300 max-w-[280px] truncate shadow-lg">
          <span className="text-cyan-400 font-bold me-1">[{isAr ? 'عالم' : 'World'}]</span>
          <span>{isAr ? 'صراع الأساطير: أهلاً بكل أبطال كونكر في مدينة التوأم!' : 'Clash of Legends: Welcome heroes to Twin City!'}</span>
        </div>

        {/* Touch Joystick Base */}
        <div 
          className="relative w-32 h-32 rounded-full bg-slate-900/60 backdrop-blur-md border-2 border-slate-600/40 flex items-center justify-center touch-none shadow-2xl cursor-pointer"
          onTouchStart={handleTouchStart}
          onTouchMove={handleTouchMove}
          onTouchEnd={handleTouchEnd}
          onMouseDown={e => {
            const rect = e.currentTarget.getBoundingClientRect();
            updateJoystickPos(e.clientX, e.clientY, rect.left + rect.width / 2, rect.top + rect.height / 2);
          }}
          onMouseUp={() => stateRef.current.joystickDir.set(0, 0)}
        >
          <div className="w-12 h-12 rounded-full bg-gradient-to-br from-amber-400 to-amber-600 border border-amber-300 shadow-md flex items-center justify-center pointer-events-none">
            <Compass className="w-5 h-5 text-white" />
          </div>
        </div>
      </div>

      {/* BOTTOM RIGHT: Classic Conquer Online Radial Combat Controls */}
      <div className="absolute bottom-6 end-6 z-20 flex items-end gap-3">
        {/* Mount & Jump Utility Buttons */}
        <div className="flex flex-col gap-2.5 mb-1">
          <button
            onClick={() => {
              setIsMounted(!isMounted);
              onNotify(!isMounted ? (isAr ? 'تم امتطاء الحصان الحربي (+60% سرعة)' : 'Mounted Warhorse (+60% Speed)') : (isAr ? 'تم الترجل عن الحصان' : 'Dismounted'), false);
            }}
            className={`w-12 h-12 rounded-2xl flex flex-col items-center justify-center font-bold text-[10px] transition-all cursor-pointer backdrop-blur-md border ${
              isMounted 
                ? 'bg-amber-600 text-white border-amber-300 shadow-[0_0_15px_rgba(245,158,11,0.5)]' 
                : 'bg-slate-900/85 text-slate-200 border-slate-700/60 hover:bg-slate-800'
            }`}
          >
            <span>🐎</span>
            <span>{isAr ? 'الحصان' : 'Mount'}</span>
          </button>

          <button
            onClick={() => {
              showFloatingText(isAr ? 'قفزة هوائية' : 'Air Jump', false);
            }}
            className="w-12 h-12 rounded-2xl bg-slate-900/85 hover:bg-slate-800 text-slate-200 border border-slate-700/60 flex flex-col items-center justify-center font-bold text-[10px] backdrop-blur-md transition-all cursor-pointer"
          >
            <span>🦘</span>
            <span>{isAr ? 'قفز' : 'Jump'}</span>
          </button>
        </div>

        {/* Radial Skill 2: Buff/Heal */}
        <button
          onClick={() => handleCastSkill(2)}
          className="w-14 h-14 rounded-2xl bg-gradient-to-br from-emerald-600 to-teal-800 hover:from-emerald-500 hover:to-teal-700 border-2 border-emerald-400 flex flex-col items-center justify-center text-white shadow-xl hover:scale-105 active:scale-95 transition-all cursor-pointer mb-2"
        >
          <Sparkles className="w-5 h-5 text-emerald-200" />
          <span className="text-[10px] font-black">{isAr ? 'شفاء' : 'Heal'}</span>
        </button>

        {/* Radial Skill 1: Class Main Skill (Trojan Cyclone / Rapid Arrow) */}
        <button
          onClick={() => handleCastSkill(1)}
          className="w-16 h-16 rounded-2xl bg-gradient-to-br from-purple-600 to-indigo-800 hover:from-purple-500 hover:to-indigo-700 border-2 border-purple-400 flex flex-col items-center justify-center text-white shadow-xl hover:scale-105 active:scale-95 transition-all cursor-pointer mb-3"
        >
          <Zap className="w-6 h-6 text-yellow-300 animate-pulse" />
          <span className="text-[10px] font-black">{isAr ? 'إعصار' : 'Cyclone'}</span>
        </button>

        {/* Oversized Main Attack Button */}
        <button
          onClick={handleAttack}
          className="w-20 h-20 rounded-full bg-gradient-to-br from-red-600 via-rose-600 to-red-800 hover:from-red-500 hover:to-rose-700 border-4 border-amber-400 flex flex-col items-center justify-center text-white shadow-[0_0_25px_rgba(239,68,68,0.6)] hover:scale-105 active:scale-90 transition-all cursor-pointer"
        >
          <Swords className="w-8 h-8 text-amber-200" />
          <span className="text-xs font-black uppercase tracking-wider">{isAr ? 'هجوم' : 'Attack'}</span>
        </button>
      </div>

      {/* BOTTOM CENTER: Full XP Progression Bar */}
      <div className="absolute bottom-0 inset-x-0 h-2 bg-slate-900 border-t border-slate-800">
        <div 
          className="h-full bg-gradient-to-r from-amber-500 via-yellow-400 to-amber-300 transition-all duration-300"
          style={{ width: `${(xp / maxXp) * 100}%` }}
        />
      </div>
    </div>
  );
};
