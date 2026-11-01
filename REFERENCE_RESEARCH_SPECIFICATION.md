# REFERENCE RESEARCH SPECIFICATION: CONQUER ONLINE MOBILE
**Source of Inspiration**: Conquer Online Mobile (Classic Mobile Edition, NetDragon / TQ Digital)  
**Research Depth**: Comprehensive Mobile System Architecture & Cross-System Mapping  
**Implementation Target**: Clash of Legends (صراع الأساطير)  

---

## 1. Reference Identification & Gameplay Philosophy
Conquer Online Mobile stands out as a quintessential isometric/elevated 3D action MMORPG defined by fast-paced combat, distinct class identities, dynamic weapon glow visuals based on item quality/refinement, and deep progression centered around gear refinement (Meteors & Dragon Balls).

### Crucial Mobile Distinctions
- **Camera Perspective**: Classic elevated wide-angle view (~38° - 45° downward pitch), allowing players to scan large mob fields and navigate without disorienting first-person claustrophobia.
- **Controls**: Smooth responsive virtual floating joystick, oversized primary attack button surrounded by radial class skill triggers, instant jump button, and quick-mount toggle.
- **Auto-Automation**: Built-in Auto-Hunt (autonomous monster targeting, navigation, and skill rotation) and Auto-Loot (priority pickup of gold and rare materials).
- **Single-Player Offline Translation**: All multi-player dynamics are adapted into local NPC AI, simulated local player entities roaming the world, offline merchant transactions, and local JSON save persistence.

---

## 2. Playable Classes & Skill Architectures

### 1. Trojan (التروجان)
- **Identity**: Relentless dual-wielding berserker. Highest physical burst damage, moderate armor.
- **Signature Weapon**: Dual Axes / Broadswords.
- **Key Skills**:
  - `Cyclone (إعصار التروجان)`: Spins in a whirlwind, dealing AoE physical damage to all adjacent foes.
  - `Fast Blade (السيف الخاطف)`: High-velocity lunging slash against single targets.

### 2. Warrior (المحارب)
- **Identity**: Bastion of defense and frontline leadership. Highest physical defense and block rate.
- **Signature Weapon**: One-handed Sword & Heavy Shield / Polearm.
- **Key Skills**:
  - `Flying Dragon (التنين الطائر)`: Upward leaping strike that crushes enemy armor.
  - `Shield Block (درع الصمود)`: Temporary defensive buff granting +25 Defense for 12 seconds.

### 3. Archer (رامي السهام)
- **Identity**: Long-range sniper with supreme kiting speed and crowd-control capabilities.
- **Signature Weapon**: Composite Longbow.
- **Key Skills**:
  - `Rapid Arrow (السهم السريع)`: Rapid-fire piercing shot from up to 16 meters away.
  - `Scatter Arrows (السهام المتناثرة)`: Fan of arrows striking all enemies within a conical front arc.

### 4. Taoist (التاويست)
- **Identity**: Master of elements and mystical arts. Splintered into Water (Healer) and Fire (Destruction).
- **Signature Weapon**: Taoist Backsword / Divine Talisman.
- **Key Skills**:
  - `Thunderbolt (الصاعقة السماوية)`: Devastating lightning strike invoked from the heavens.
  - `Holy Heal (الشفاء المقدس)`: Restores substantial HP to self and friendly entities.

### 5. Ninja (النينجا)
- **Identity**: Shadow assassin utilizing speed, critical strikes, and elusive positioning.
- **Signature Weapon**: Dual Katanas.
- **Key Skills**:
  - `Fatal Strike (الضربة القاضية)`: High-critical surprise execution.

### 6. Monk (الراهب)
- **Identity**: Martial artist combining physical melee combat with holy chants and defensive auras.
- **Signature Weapon**: Holy Rosary & Prayer Beads.
- **Key Skills**:
  - `Monk Whirlwind (إعصار الراهب)`: Sweeping area martial strike.

### 7. Pirate (القرصان)
- **Identity**: Swashbuckling sea commander utilizing dual sabers and heavy blackpowder ordnance.
- **Signature Weapon**: Rapier & Flintlock Pistol.
- **Key Skills**:
  - `Cannon Blast (قذيفة المدفع)`: Heavy explosive artillery blast.

---

## 3. World Layout & Environment Mapping
1. **Twin City (مدينة التوأم)**: Central peaceful sanctuary featuring the Ancient Sage, Master Blacksmith, General Merchant, and Portal Warden.
2. **Twin Plains (سهل التوأم)**: Level 1–25 hunting grounds populated by Wild Wolves.
3. **Mountain Summit (قمة الجبل)**: Volcanic arena harboring the Great Flame Dragon world boss.

---

## 4. Refinement & Item Economy
- **Refinement System**: Equipment starts at +0 and can be upgraded at the Blacksmith up to +9. Each level costs Gold and 1 Meteor Stone (`meteor_stone`), scaling item attack and defense attributes with dynamic visual emission shaders.
- **Currency Rule**: Strictly single-currency Gold (`current_gold`). Zero premium currencies or real-money shops.
