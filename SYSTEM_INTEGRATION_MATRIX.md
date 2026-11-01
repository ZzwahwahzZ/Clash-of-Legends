# SYSTEM INTEGRATION MATRIX
**Clash of Legends — Offline 3D MMORPG Architecture**  

---

## 1. System Interaction Grid

| Source Component | Target Component | Protocol / Signal / Method | Data Transferred | Offline Validation |
|------------------|------------------|----------------------------|------------------|--------------------|
| **PlayerController** | **GameManager** | `register_player(self)`, `sync_stats_to_hud()` | HP, MP, XP, Level, Gold | Verified |
| **PlayerController** | **FreeCamera3D** | `get_camera_yaw()` | Relative forward/right vectors | Verified |
| **PlayerController** | **PlayerInventory** | `update_equipment_bonuses()` | Attack bonus, Defense bonus | Verified |
| **PlayerController** | **CombatEngine** | `damage_dealt`, `skill_executed` | Damage amount, critical hit flag | Verified |
| **CombatEngine** | **MonsterBase** | `take_damage(dmg, player)` | HP reduction, agro trigger | Verified |
| **MonsterBase** | **QuestNavigationAgent**| `on_enemy_killed(type)` | Quest target kill count increment | Verified |
| **MonsterBase** | **LootDrop3D** | `setup_loot(info)` | Gold amount, meteor/gear drop | Verified |
| **AutoHuntManager** | **PlayerController** | `move_towards_target_position()`, `execute_basic_attack()` | Navigation vector, attack trigger | Verified |
| **AutoHuntManager** | **CombatEngine** | `can_cast_skill()`, `execute_skill()` | Class skill execution | Verified |
| **AutoLootManager** | **LootDrop3D** | `collect_by_player(player)` | Automated pickup within 8m | Verified |
| **LootDrop3D** | **GameManager** | `add_gold(amount)` | Local gold balance increase | Verified |
| **LootDrop3D** | **PlayerInventory** | `add_item(payload)` | 40-slot item insertion | Verified |
| **NPCBase (Sage)** | **DialogueUI** | `show_dialogue(speaker, text, opts)` | Quest dialogue branching | Verified |
| **NPCBase (Blacksmith)**| **BlacksmithUI** | `open_ui()` | Refinement modal trigger | Verified |
| **NPCBase (Merchant)** | **InventoryUI** | `open_ui()` | Shop selling transaction | Verified |
| **PlayerInventory** | **GameManager** | `spend_gold()`, `add_gold()` | Refinement cost, item sale revenue | Verified |
| **SettingsUI** | **GameManager** | `set_language("ar" / "en")` | Runtime locale switch, RTL update | Verified |
| **SettingsUI** | **LocalSaveEngine** | `save_game(p_data)`, `load_game()` | JSON persistence & backup | Verified |
| **MainHUDController** | **PlayerController** | `set_joystick_input()`, `perform_jump()`, `toggle_mount()` | Touch controls | Verified |
| **QuestNavigationAgent**| **MainHUDController** | `quest_updated` signal | Objective banner, kill counter | Verified |

---

## 2. Data Flow & Save State Schema
The local save file (`user://clash_save_data.json`) encapsulates:
```json
{
  "version": "1.0.0",
  "timestamp": 1793471000,
  "player": {
    "level": 1,
    "hp": 500,
    "max_hp": 500,
    "mp": 200,
    "max_mp": 200,
    "xp": 0,
    "max_xp": 1000,
    "gold": 1500,
    "class": "Trojan",
    "position": { "x": 0.0, "y": 0.1, "z": 0.0 },
    "inventory": {
      "slots": [...],
      "equipment": {
        "head": null,
        "armor": null,
        "weapon": {
          "id": "coronet_trojan_bronze",
          "name_ar": "فأس التروجان البرونزي",
          "refine_level": 1,
          "attack_bonus": 32
        },
        "shield": null,
        "boots": null,
        "necklace": null,
        "ring": null
      }
    }
  }
}
```
If the primary file is corrupted or disrupted during device sleep, `LocalSaveEngine._load_backup_fallback()` transparently recovers from `user://clash_save_data.bak`.
