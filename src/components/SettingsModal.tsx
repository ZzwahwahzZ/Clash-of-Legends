import React from 'react';
import { X, Globe, User, Save, Download, Volume2, Shield, Swords, Sparkles } from 'lucide-react';

interface SettingsModalProps {
  isOpen: boolean;
  onClose: () => void;
  language: 'ar' | 'en';
  setLanguage: (lang: 'ar' | 'en') => void;
  playerClass: string;
  setPlayerClass: (cls: string) => void;
  onSaveGame: () => void;
  onLoadGame: () => void;
  onNotify: (msg: string, isAlert?: boolean) => void;
}

export const SettingsModal: React.FC<SettingsModalProps> = ({
  isOpen,
  onClose,
  language,
  setLanguage,
  playerClass,
  setPlayerClass,
  onSaveGame,
  onLoadGame,
  onNotify
}) => {
  const isAr = language === 'ar';

  if (!isOpen) return null;

  const classes = [
    { id: 'Trojan', name_ar: 'التروجان (Trojan)', desc_ar: 'فأس وسيف مزدوج — أعلى ضرر هجومي جسدي', desc_en: 'Dual-wielding axes — highest burst melee damage' },
    { id: 'Warrior', name_ar: 'المحارب (Warrior)', desc_ar: 'درع وسيف حربي — أعلى دفاع ومقاومة', desc_en: 'Shield & blade — supreme physical defense and block' },
    { id: 'Archer', name_ar: 'رامي السهام (Archer)', desc_ar: 'قوس مركب طويل — قنص وسرعة حركة فائقة', desc_en: 'Composite bow — long range kiting and multi-arrows' },
    { id: 'Taoist', name_ar: 'التاويست (Taoist)', desc_ar: 'صواعق سماوية وشفاء روحي — سحر متقدم', desc_en: 'Heavenly thunderbolt and holy heal arts' },
    { id: 'Ninja', name_ar: 'النينجا (Ninja)', desc_ar: 'كاتانا مزدوجة وضربات خاطفة حرجة', desc_en: 'Dual katanas and fatal critical strikes' },
    { id: 'Monk', name_ar: 'الراهب (Monk)', desc_ar: 'مسبحة مقدسة وهالات دفاعية وهجومية', desc_en: 'Holy rosary beads and protective auras' },
    { id: 'Pirate', name_ar: 'القرصان (Pirate)', desc_ar: 'مسدس بارود وقذائف مدافع بحرية', desc_en: 'Dual flintlocks and heavy cannon barrages' }
  ];

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/75 backdrop-blur-sm p-4" dir={isAr ? 'rtl' : 'ltr'}>
      <div className="relative w-full max-w-xl bg-slate-900 border border-slate-700 rounded-3xl shadow-2xl overflow-hidden flex flex-col max-h-[90vh]">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-slate-800 bg-slate-950/60">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-blue-500/20 border border-blue-500/40 flex items-center justify-center text-blue-400">
              <Globe className="w-5 h-5" />
            </div>
            <div>
              <h2 className="text-lg font-black text-white">{isAr ? 'إعدادات صراع الأساطير' : 'Clash of Legends Settings'}</h2>
              <p className="text-xs text-slate-400">{isAr ? 'إدارة اللغة، فئة البطل، والحفظ المحلي' : 'Manage language, hero class, and offline saves'}</p>
            </div>
          </div>
          <button 
            onClick={onClose}
            className="w-9 h-9 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-400 hover:text-white flex items-center justify-center transition-all cursor-pointer"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Body */}
        <div className="p-6 flex flex-col gap-6 overflow-y-auto">
          {/* Language Selector */}
          <div className="flex flex-col gap-2">
            <label className="text-xs font-bold text-slate-300 flex items-center gap-2">
              <Globe className="w-4 h-4 text-amber-400" />
              <span>{isAr ? 'لغة الواجهة (العربية افتراضية)' : 'Interface Language (Arabic Default)'}</span>
            </label>
            <div className="grid grid-cols-2 gap-3">
              <button
                onClick={() => {
                  setLanguage('ar');
                  onNotify('تم تعيين اللغة العربية كلغة رئيسية للعبة', false);
                }}
                className={`p-3 rounded-2xl border font-bold text-xs flex items-center justify-center gap-2 transition-all cursor-pointer ${
                  language === 'ar'
                    ? 'bg-amber-600 text-white border-amber-400 shadow-md'
                    : 'bg-slate-800/80 text-slate-300 border-slate-700 hover:bg-slate-700'
                }`}
              >
                <span>العربية (افتراضي / RTL)</span>
              </button>
              <button
                onClick={() => {
                  setLanguage('en');
                  onNotify('Language switched to English', false);
                }}
                className={`p-3 rounded-2xl border font-bold text-xs flex items-center justify-center gap-2 transition-all cursor-pointer ${
                  language === 'en'
                    ? 'bg-amber-600 text-white border-amber-400 shadow-md'
                    : 'bg-slate-800/80 text-slate-300 border-slate-700 hover:bg-slate-700'
                }`}
              >
                <span>English (LTR)</span>
              </button>
            </div>
          </div>

          {/* Class Selector (7 Conquer Online Classes) */}
          <div className="flex flex-col gap-2">
            <label className="text-xs font-bold text-slate-300 flex items-center gap-2">
              <User className="w-4 h-4 text-blue-400" />
              <span>{isAr ? 'فئة البطل المتوفرة (٧ فئات أصلية)' : 'Hero Class (7 Original Classes)'}</span>
            </label>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5 max-h-56 overflow-y-auto p-1">
              {classes.map(c => {
                const isSelected = playerClass === c.id;
                return (
                  <button
                    key={c.id}
                    onClick={() => {
                      setPlayerClass(c.id);
                      onNotify(isAr ? `تم تبديل الفئة إلى: ${c.name_ar}` : `Class switched to: ${c.id}`, false);
                    }}
                    className={`p-3 rounded-2xl border text-start flex flex-col gap-1 transition-all cursor-pointer ${
                      isSelected
                        ? 'bg-blue-950/80 border-blue-400 shadow-lg scale-101'
                        : 'bg-slate-800/60 border-slate-700 hover:border-slate-600'
                    }`}
                  >
                    <div className="flex items-center justify-between">
                      <span className="font-black text-xs text-white">{isAr ? c.name_ar : c.id}</span>
                      {isSelected && <span className="text-[10px] bg-blue-500 text-white px-2 py-0.5 rounded-full font-bold">Active</span>}
                    </div>
                    <span className="text-[11px] text-slate-400 leading-tight">
                      {isAr ? c.desc_ar : c.desc_en}
                    </span>
                  </button>
                );
              })}
            </div>
          </div>

          {/* Local Save / Load (Offline JSON) */}
          <div className="flex flex-col gap-2 pt-2 border-t border-slate-800">
            <label className="text-xs font-bold text-slate-300 flex items-center gap-2">
              <Save className="w-4 h-4 text-emerald-400" />
              <span>{isAr ? 'نظام الحفظ المحلي (أوفلاين بالكامل بدون خوادم)' : 'Local Offline Storage (No Network Required)'}</span>
            </label>
            <div className="grid grid-cols-2 gap-3">
              <button
                onClick={onSaveGame}
                className="py-3 px-4 bg-emerald-600 hover:bg-emerald-500 text-white font-bold text-xs rounded-2xl shadow-lg transition-all flex items-center justify-center gap-2 cursor-pointer"
              >
                <Save className="w-4 h-4" />
                <span>{isAr ? 'حفظ اللعبة محلياً' : 'Save Game Locally'}</span>
              </button>
              <button
                onClick={onLoadGame}
                className="py-3 px-4 bg-slate-800 hover:bg-slate-700 text-slate-200 border border-slate-700 font-bold text-xs rounded-2xl transition-all flex items-center justify-center gap-2 cursor-pointer"
              >
                <Download className="w-4 h-4" />
                <span>{isAr ? 'استرجاع الحفظ' : 'Load Saved Game'}</span>
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
