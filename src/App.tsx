import React, { useState, useEffect } from 'react';
import { GameWorldCanvas } from './components/GameWorldCanvas';
import { InventoryModal } from './components/InventoryModal';
import { BlacksmithModal } from './components/BlacksmithModal';
import { SettingsModal } from './components/SettingsModal';
import { GodotSuitePanel } from './components/GodotSuitePanel';
import { 
  Gamepad2, 
  Terminal, 
  Globe, 
  Sparkles, 
  ShieldCheck, 
  CheckCircle2, 
  AlertTriangle,
  MessageSquare,
  X,
  Download,
  PackageCheck
} from 'lucide-react';

export default function App() {
  const [language, setLanguage] = useState<'ar' | 'en'>('ar');
  const [playerClass, setPlayerClass] = useState<string>('Trojan');
  const [gold, setGold] = useState<number>(1500);
  const [level, setLevel] = useState<number>(1);
  const [questProgress, setQuestProgress] = useState<number>(0);
  const questGoal = 5;

  const [activeTab, setActiveTab] = useState<'game' | 'godot'>('game');

  // Modals
  const [isInventoryOpen, setIsInventoryOpen] = useState(false);
  const [isBlacksmithOpen, setIsBlacksmithOpen] = useState(false);
  const [isSettingsOpen, setIsSettingsOpen] = useState(false);

  // NPC Dialogue Modal
  const [activeNPC, setActiveNPC] = useState<{ role: string; name: string; dialogue: string } | null>(null);

  // Automation Toggles
  const [isAutoHunt, setIsAutoHunt] = useState(false);
  const [isAutoLoot, setIsAutoLoot] = useState(true);

  // Notifications
  const [notification, setNotification] = useState<{ text: string; isAlert: boolean } | null>(null);

  const isAr = language === 'ar';

  const notificationTimeoutRef = React.useRef<NodeJS.Timeout | null>(null);

  const triggerNotification = React.useCallback((text: string, isAlert: boolean = false) => {
    setTimeout(() => {
      setNotification({ text, isAlert });
      if (notificationTimeoutRef.current) {
        clearTimeout(notificationTimeoutRef.current);
      }
      notificationTimeoutRef.current = setTimeout(() => {
        setNotification(null);
      }, 3800);
    }, 0);
  }, []);

  // Local Save / Load (matching LocalSaveEngine.gd)
  const handleSaveGame = () => {
    const saveData = {
      level,
      gold,
      playerClass,
      questProgress,
      isAutoHunt,
      isAutoLoot,
      timestamp: Date.now()
    };
    localStorage.setItem('clash_save_data', JSON.stringify(saveData));
    localStorage.setItem('clash_save_data_bak', JSON.stringify(saveData));
    triggerNotification(isAr ? 'تم حفظ بيانات اللعبة محلياً في الذاكرة بنجاح' : 'Game saved locally to offline storage', false);
  };

  const handleLoadGame = () => {
    const raw = localStorage.getItem('clash_save_data') || localStorage.getItem('clash_save_data_bak');
    if (raw) {
      try {
        const d = JSON.parse(raw);
        if (d.level) setLevel(d.level);
        if (d.gold !== undefined) setGold(d.gold);
        if (d.playerClass) setPlayerClass(d.playerClass);
        if (d.questProgress !== undefined) setQuestProgress(d.questProgress);
        triggerNotification(isAr ? 'تم استرجاع تقدمك في اللعبة بنجاح!' : 'Game progress loaded successfully!', false);
      } catch (e) {
        triggerNotification(isAr ? 'تعذر قراءة ملف الحفظ' : 'Failed to parse save data', true);
      }
    } else {
      triggerNotification(isAr ? 'لا يوجد ملف حفظ سابق' : 'No previous save file found', true);
    }
  };

  const handleInteractNPC = (role: string, name: string) => {
    let dialogue = '';
    if (role === 'sage') {
      dialogue = isAr 
        ? 'مرحباً بك يا بطل في مدينة التوأم! سهل التوأم يعج بالذئاب البرية لحماية القوافل، وتنين اللهب يرقد في القمة الجبلية. استعد جيداً!'
        : 'Welcome Hero to Twin City! The plains are teeming with wolves, and the flame dragon rests in the mountain summit. Prepare yourself!';
    } else if (role === 'blacksmith') {
      setIsBlacksmithOpen(true);
      return;
    } else if (role === 'merchant') {
      setIsInventoryOpen(true);
      return;
    } else if (role === 'warden') {
      dialogue = isAr 
        ? 'أنا حارس البوابة المؤدية إلى أراضي الأساطير الخارجية. هل أنت مستعد لخوض التحديات الكبرى؟'
        : 'I am the Dungeon Warden guarding the portals to the outer realms. Are you prepared for greater trials?';
    }
    setActiveNPC({ role, name, dialogue });
  };

  return (
    <div className={`min-h-screen bg-slate-950 text-slate-100 flex flex-col font-sans ${isAr ? 'font-arabic' : ''}`} dir={isAr ? 'rtl' : 'ltr'}>
      {/* Toast Notification */}
      {notification && (
        <div className="fixed top-20 left-1/2 transform -translate-x-1/2 z-50 animate-fade-in-down">
          <div className={`px-5 py-3 rounded-2xl shadow-2xl backdrop-blur-md border flex items-center gap-3 text-xs md:text-sm font-bold ${
            notification.isAlert 
              ? 'bg-red-950/90 text-red-200 border-red-500/60 shadow-[0_0_20px_rgba(239,68,68,0.4)]' 
              : 'bg-amber-950/90 text-amber-200 border-amber-500/60 shadow-[0_0_20px_rgba(245,158,11,0.4)]'
          }`}>
            {notification.isAlert ? <AlertTriangle className="w-4 h-4 text-red-400 shrink-0" /> : <ShieldCheck className="w-4 h-4 text-amber-400 shrink-0" />}
            <span>{notification.text}</span>
          </div>
        </div>
      )}

      {/* Main Studio Navigation Header */}
      <header className="sticky top-0 z-40 bg-slate-900/90 backdrop-blur-md border-b border-slate-800 px-4 md:px-8 py-3.5 flex flex-wrap items-center justify-between gap-4">
        {/* Brand */}
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-2xl bg-gradient-to-br from-amber-500 via-orange-500 to-red-600 flex items-center justify-center text-white shadow-[0_0_15px_rgba(245,158,11,0.5)] border border-amber-300">
            <Gamepad2 className="w-6 h-6" />
          </div>
          <div>
            <div className="flex items-center gap-2">
              <h1 className="text-base md:text-lg font-black tracking-wide text-white">
                {isAr ? 'صراع الأساطير' : 'Clash of Legends'}
              </h1>
              <span className="text-[10px] font-black uppercase bg-gradient-to-r from-amber-500 to-orange-500 text-slate-950 px-2 py-0.5 rounded-full">
                Godot 4.3
              </span>
            </div>
            <p className="text-[11px] text-slate-400 hidden sm:block">
              {isAr ? 'لعبة MMORPG ثلاثية الأبعاد مستوحاة من كونكر موبايل — أوفلاين بالكامل' : '3D MMORPG inspired by Conquer Online Mobile — 100% Offline'}
            </p>
          </div>
        </div>

        {/* View Switcher Tabs */}
        <div className="flex items-center bg-slate-950 p-1.5 rounded-2xl border border-slate-800">
          <button
            onClick={() => setActiveTab('game')}
            className={`flex items-center gap-2 px-4 py-2 rounded-xl font-bold text-xs transition-all cursor-pointer ${
              activeTab === 'game'
                ? 'bg-gradient-to-r from-amber-500 to-orange-500 text-slate-950 shadow-md'
                : 'text-slate-400 hover:text-white'
            }`}
          >
            <Gamepad2 className="w-4 h-4" />
            <span>{isAr ? 'عالم اللعبة المباشر' : 'Live 3D Realm'}</span>
          </button>

          <button
            onClick={() => setActiveTab('godot')}
            className={`flex items-center gap-2 px-4 py-2 rounded-xl font-bold text-xs transition-all cursor-pointer ${
              activeTab === 'godot'
                ? 'bg-gradient-to-r from-amber-500 to-orange-500 text-slate-950 shadow-md'
                : 'text-slate-400 hover:text-white'
            }`}
          >
            <Terminal className="w-4 h-4" />
            <span>{isAr ? 'استوديو جودو والتقارير' : 'Godot Studio & Reports'}</span>
          </button>
        </div>

        {/* Header Actions: Download Project ZIP & Quick Language Toggle */}
        <div className="flex items-center gap-2.5">
          <a
            href="/Clash-of-Legends-Full-Project.zip"
            download="Clash-of-Legends-Full-Project.zip"
            className="flex items-center gap-2 px-4 py-2 bg-gradient-to-r from-emerald-500 to-teal-600 hover:from-emerald-400 hover:to-teal-500 text-slate-950 font-black text-xs rounded-xl shadow-lg transition-all cursor-pointer hover:scale-[1.02]"
            title="Download Clash-of-Legends-Full-Project.zip (62 files, 0.13 MB)"
          >
            <Download className="w-4 h-4" />
            <span>{isAr ? 'تحميل المشروع (ZIP)' : 'Download Project ZIP'}</span>
          </a>

          <button
            onClick={() => {
              const next = language === 'ar' ? 'en' : 'ar';
              setLanguage(next);
              triggerNotification(next === 'ar' ? 'تم تفعيل واجهة اللغة العربية' : 'Switched to English interface', false);
            }}
            className="flex items-center gap-2 px-3.5 py-2 bg-slate-800/80 hover:bg-slate-700 rounded-xl border border-slate-700 text-xs font-bold text-amber-300 transition-all cursor-pointer"
          >
            <Globe className="w-4 h-4 text-amber-400" />
            <span>{isAr ? 'English' : 'العربية (افتراضي)'}</span>
          </button>
        </div>
      </header>

      {/* Main View Area */}
      <main className="flex-1 flex flex-col p-3 md:p-6 max-w-7xl mx-auto w-full gap-6">
        {activeTab === 'game' ? (
          <div className="flex flex-col gap-4">
            {/* Interactive 3D MMORPG Canvas */}
            <div className="rounded-3xl overflow-hidden border border-slate-800 shadow-2xl bg-slate-950">
              <GameWorldCanvas
                language={language}
                playerClass={playerClass}
                onClassChange={setPlayerClass}
                gold={gold}
                setGold={setGold}
                level={level}
                setLevel={setLevel}
                onOpenInventory={() => setIsInventoryOpen(true)}
                onOpenBlacksmith={() => setIsBlacksmithOpen(true)}
                onOpenSettings={() => setIsSettingsOpen(true)}
                isAutoHunt={isAutoHunt}
                setIsAutoHunt={setIsAutoHunt}
                isAutoLoot={isAutoLoot}
                setIsAutoLoot={setIsAutoLoot}
                onNotify={triggerNotification}
                questProgress={questProgress}
                setQuestProgress={setQuestProgress}
                questGoal={questGoal}
                onInteractNPC={handleInteractNPC}
              />
            </div>

            {/* Quick Feature Badges & Offline MMORPG Verification Status */}
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
              <div className="bg-slate-900/60 p-3.5 rounded-2xl border border-slate-800/80 flex items-center gap-3">
                <span className="text-2xl">⚔️</span>
                <div>
                  <h4 className="text-xs font-black text-white">{isAr ? '٧ فئات أصلية' : '7 Original Classes'}</h4>
                  <p className="text-[10px] text-slate-400">{isAr ? 'تروجان، محارب، آرتشر، تاويست...' : 'Trojan, Warrior, Archer...'}</p>
                </div>
              </div>

              <div className="bg-slate-900/60 p-3.5 rounded-2xl border border-slate-800/80 flex items-center gap-3">
                <span className="text-2xl">💰</span>
                <div>
                  <h4 className="text-xs font-black text-white">{isAr ? 'اقتصاد الذهب فقط' : 'Gold-Only Economy'}</h4>
                  <p className="text-[10px] text-slate-400">{isAr ? 'بدون نقاط CP أو مشتريات مدفوعة' : 'Zero CP or Microtransactions'}</p>
                </div>
              </div>

              <div className="bg-slate-900/60 p-3.5 rounded-2xl border border-slate-800/80 flex items-center gap-3">
                <span className="text-2xl">💎</span>
                <div>
                  <h4 className="text-xs font-black text-white">{isAr ? 'صقل الأحجار النيزكية' : 'Meteor Refinement'}</h4>
                  <p className="text-[10px] text-slate-400">{isAr ? 'ترقية العتاد وتوهج الأسلحة +9' : 'Gear Upgrades & Glowing Shaders'}</p>
                </div>
              </div>

              <div className="bg-slate-900/60 p-3.5 rounded-2xl border border-slate-800/80 flex items-center gap-3">
                <span className="text-2xl">🛡️</span>
                <div>
                  <h4 className="text-xs font-black text-white">{isAr ? 'لعب أوفلاين بالكامل' : '100% Offline World'}</h4>
                  <p className="text-[10px] text-slate-400">{isAr ? 'محاكاة كاملة للاعبين والوحوش' : 'Local simulated heroes & AI'}</p>
                </div>
              </div>
            </div>
          </div>
        ) : (
          /* Godot Engine & Specifications Suite */
          <GodotSuitePanel language={language} />
        )}
      </main>

      {/* NPC Dialogue Modal */}
      {activeNPC && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-sm p-4">
          <div className="relative w-full max-w-lg bg-slate-900 border border-slate-700 rounded-3xl p-6 shadow-2xl flex flex-col gap-4">
            <div className="flex items-center justify-between pb-3 border-b border-slate-800">
              <div className="flex items-center gap-2">
                <MessageSquare className="w-5 h-5 text-amber-400" />
                <h3 className="font-black text-base text-white">{activeNPC.name}</h3>
              </div>
              <button 
                onClick={() => setActiveNPC(null)}
                className="w-8 h-8 rounded-xl bg-slate-800 text-slate-400 hover:text-white flex items-center justify-center transition-all cursor-pointer"
              >
                <X className="w-4 h-4" />
              </button>
            </div>
            <p className="text-sm text-slate-200 leading-relaxed bg-slate-950 p-4 rounded-2xl border border-slate-800">
              {activeNPC.dialogue}
            </p>
            <div className="flex justify-end gap-2 pt-2">
              <button
                onClick={() => setActiveNPC(null)}
                className="px-6 py-2.5 bg-amber-500 hover:bg-amber-400 text-slate-950 font-black text-xs rounded-xl shadow-lg transition-all cursor-pointer"
              >
                {isAr ? 'حسناً، فهمت' : 'Understood'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Modals */}
      <InventoryModal
        isOpen={isInventoryOpen}
        onClose={() => setIsInventoryOpen(false)}
        language={language}
        gold={gold}
        setGold={setGold}
        onNotify={triggerNotification}
      />

      <BlacksmithModal
        isOpen={isBlacksmithOpen}
        onClose={() => setIsBlacksmithOpen(false)}
        language={language}
        gold={gold}
        setGold={setGold}
        onNotify={triggerNotification}
      />

      <SettingsModal
        isOpen={isSettingsOpen}
        onClose={() => setIsSettingsOpen(false)}
        language={language}
        setLanguage={setLanguage}
        playerClass={playerClass}
        setPlayerClass={setPlayerClass}
        onSaveGame={handleSaveGame}
        onLoadGame={handleLoadGame}
        onNotify={triggerNotification}
      />
    </div>
  );
}
