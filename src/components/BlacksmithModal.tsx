import React, { useState } from 'react';
import { X, Hammer, Sparkles, AlertCircle, Shield, Swords } from 'lucide-react';

interface BlacksmithModalProps {
  isOpen: boolean;
  onClose: () => void;
  language: 'ar' | 'en';
  gold: number;
  setGold: React.Dispatch<React.SetStateAction<number>>;
  onNotify: (msg: string, isAlert?: boolean) => void;
}

export const BlacksmithModal: React.FC<BlacksmithModalProps> = ({
  isOpen,
  onClose,
  language,
  gold,
  setGold,
  onNotify
}) => {
  const isAr = language === 'ar';
  const [selectedSlot, setSelectedSlot] = useState<'weapon' | 'armor' | 'helmet' | 'boots'>('weapon');
  const [refineLevels, setRefineLevels] = useState({
    weapon: 1,
    armor: 0,
    helmet: 0,
    boots: 0
  });
  const [meteorCount, setMeteorCount] = useState(8);
  const [isRefining, setIsRefining] = useState(false);

  if (!isOpen) return null;

  const currentLevel = refineLevels[selectedSlot];
  const nextLevel = currentLevel + 1;
  const goldCost = nextLevel * 300;
  const successChance = Math.max(35, 100 - (currentLevel * 10));

  const gearNames: Record<string, { ar: string; en: string }> = {
    weapon: { ar: 'فأس التروجان البرونزي', en: 'Bronze Trojan Axe' },
    armor: { ar: 'درع التنين الفولاذي', en: 'Dragon Steel Armor' },
    helmet: { ar: 'خوذة المحارب الذهبية', en: 'Golden Warrior Helm' },
    boots: { ar: 'أحذية الرياح السريعة', en: 'Boots of Swift Wind' }
  };

  const handleRefine = () => {
    if (currentLevel >= 9) {
      onNotify(isAr ? 'العتاد بلغ الحد الأقصى للصقل (+9)!' : 'Gear is already at max refinement (+9)!', true);
      return;
    }
    if (meteorCount < 1) {
      onNotify(isAr ? 'تحتاج إلى حجر نيزك للصقل!' : 'You need a Meteor Stone for refinement!', true);
      return;
    }
    if (gold < goldCost) {
      onNotify(isAr ? 'ذهب غير كافٍ لصقل هذا العتاد!' : 'Insufficient Gold for refinement!', true);
      return;
    }

    setIsRefining(true);
    setGold(g => g - goldCost);
    setMeteorCount(m => m - 1);

    setTimeout(() => {
      setIsRefining(false);
      const isSuccess = Math.random() * 100 <= successChance;
      if (isSuccess) {
        setRefineLevels(prev => ({
          ...prev,
          [selectedSlot]: prev[selectedSlot] + 1
        }));
        onNotify(isAr ? `نجح الصقل! ارتقى العتاد إلى +${nextLevel} وتوهج نصل السلاح!` : `Refinement Succeeded! Gear upgraded to +${nextLevel}!`, false);
      } else {
        onNotify(isAr ? 'فشلت محاولة الصقل! تم الحفاظ على مستوى العتاد بدون خسارة' : 'Refinement Failed! Gear level preserved safely', true);
      }
    }, 800);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/75 backdrop-blur-sm p-4" dir={isAr ? 'rtl' : 'ltr'}>
      <div className="relative w-full max-w-2xl bg-slate-900 border border-amber-600/50 rounded-3xl shadow-2xl overflow-hidden flex flex-col">
        {/* Modal Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-slate-800 bg-amber-950/30">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-amber-500 to-orange-600 flex items-center justify-center text-white shadow-lg">
              <Hammer className="w-5 h-5" />
            </div>
            <div>
              <h2 className="text-lg font-black text-white">{isAr ? 'حدادة الأساطير — صقل العتاد' : 'Legends Blacksmith — Gear Refine'}</h2>
              <p className="text-xs text-amber-300/80">{isAr ? 'استخدم أحجار النيزك والذهب لرفع قوة العتاد والتوهج' : 'Use Meteor Stones & Gold to boost stats & emission glow'}</p>
            </div>
          </div>
          <button 
            onClick={onClose}
            className="w-9 h-9 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-400 hover:text-white flex items-center justify-center transition-all cursor-pointer"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Modal Content */}
        <div className="p-6 flex flex-col gap-6">
          {/* Slot Selector */}
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
            {(['weapon', 'armor', 'helmet', 'boots'] as const).map(slot => {
              const isSelected = selectedSlot === slot;
              const lvl = refineLevels[slot];
              return (
                <button
                  key={slot}
                  onClick={() => setSelectedSlot(slot)}
                  className={`p-3.5 rounded-2xl border flex flex-col items-center gap-2 transition-all cursor-pointer ${
                    isSelected 
                      ? 'bg-amber-950/80 border-amber-400 shadow-lg scale-102' 
                      : 'bg-slate-950/60 border-slate-800 hover:border-slate-700'
                  }`}
                >
                  <span className="text-2xl">
                    {slot === 'weapon' ? '⚔️' : slot === 'armor' ? '🛡️' : slot === 'helmet' ? '🪖' : '👢'}
                  </span>
                  <span className="text-xs font-bold text-slate-200">
                    {isAr ? gearNames[slot].ar : gearNames[slot].en}
                  </span>
                  <span className="text-[11px] font-black text-amber-400 bg-slate-900 px-2 py-0.5 rounded-full border border-amber-500/30">
                    +{lvl}
                  </span>
                </button>
              );
            })}
          </div>

          {/* Refinement Forge Canvas Preview */}
          <div className="bg-slate-950 rounded-2xl border border-slate-800 p-6 flex flex-col sm:flex-row items-center justify-between gap-6">
            <div className="flex items-center gap-4">
              {/* Glowing Weapon Icon Preview (Simulating weapon_glow.gdshader) */}
              <div className="relative w-24 h-24 rounded-2xl bg-gradient-to-br from-slate-900 to-amber-950/50 border-2 border-amber-500/60 flex items-center justify-center shadow-[0_0_30px_rgba(245,158,11,0.3)]">
                <span className="text-5xl animate-pulse">
                  {selectedSlot === 'weapon' ? '⚔️' : selectedSlot === 'armor' ? '🛡️' : selectedSlot === 'helmet' ? '🪖' : '👢'}
                </span>
                <span className="absolute -top-2 -end-2 text-xs font-black bg-gradient-to-r from-amber-500 to-orange-500 text-white px-2 py-0.5 rounded-full shadow-lg">
                  +{currentLevel}
                </span>
              </div>

              <div className="flex flex-col gap-1">
                <h3 className="font-black text-white text-base">
                  {isAr ? gearNames[selectedSlot].ar : gearNames[selectedSlot].en}
                </h3>
                <div className="text-xs text-slate-300">
                  <span>{isAr ? 'المستوى الحالي:' : 'Current Level:'}</span> <span className="font-bold text-amber-400">+{currentLevel}</span>
                  <span className="mx-2">➔</span>
                  <span>{isAr ? 'المستوى القادم:' : 'Target Level:'}</span> <span className="font-bold text-emerald-400">+{nextLevel}</span>
                </div>
                <div className="text-xs text-slate-400 flex items-center gap-3 mt-1">
                  <span className="text-red-400 font-medium">+{12 * nextLevel} {isAr ? 'هجوم' : 'ATK'}</span>
                  <span className="text-blue-400 font-medium">+{6 * nextLevel} {isAr ? 'دفاع' : 'DEF'}</span>
                </div>
              </div>
            </div>

            {/* Refinement Stats Badge */}
            <div className="flex flex-col items-center sm:items-end gap-1.5 bg-slate-900/90 px-4 py-3 rounded-xl border border-slate-800">
              <span className="text-xs text-slate-400 font-medium">{isAr ? 'نسبة النجاح:' : 'Success Rate:'}</span>
              <span className="text-2xl font-black text-emerald-400">{successChance}%</span>
            </div>
          </div>

          {/* Requirements & Action */}
          <div className="flex flex-col sm:flex-row items-center justify-between gap-4 p-4 rounded-2xl bg-amber-950/20 border border-amber-600/30">
            <div className="flex items-center gap-4 text-xs font-bold text-slate-200">
              <div className="flex items-center gap-1.5">
                <span>💎</span>
                <span>{isAr ? 'حجر نيزك:' : 'Meteor:'}</span>
                <span className={`font-black ${meteorCount > 0 ? 'text-emerald-400' : 'text-red-400'}`}>1 ({isAr ? 'المتوفر:' : 'Owned:'} {meteorCount})</span>
              </div>
              <div className="flex items-center gap-1.5">
                <span>💰</span>
                <span>{isAr ? 'الذهب المطلوب:' : 'Required Gold:'}</span>
                <span className={`font-black ${gold >= goldCost ? 'text-amber-400' : 'text-red-400'}`}>{goldCost.toLocaleString()} ذهب</span>
              </div>
            </div>

            <button
              onClick={handleRefine}
              disabled={isRefining || currentLevel >= 9}
              className="w-full sm:w-auto px-8 py-3 bg-gradient-to-r from-amber-500 via-orange-500 to-amber-600 hover:from-amber-400 hover:to-orange-500 text-slate-950 font-black text-sm rounded-xl shadow-[0_0_20px_rgba(245,158,11,0.4)] transition-all cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {isRefining ? (isAr ? 'جاري الصقل والتطريق...' : 'Refining Gear...') : (isAr ? 'صقل العتاد الآن' : 'Refine Gear Now')}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};
