import React, { useState } from 'react';
import { X, Sparkles, Shield, Swords, DollarSign, Package } from 'lucide-react';

interface Item {
  id: string;
  name_ar: string;
  name_en: string;
  type: 'equipment' | 'consumable' | 'material';
  quantity: number;
  sellPrice: number;
  refineLevel?: number;
  attackBonus?: number;
  defenseBonus?: number;
  slot?: string;
  description_ar?: string;
  description_en?: string;
}

interface InventoryModalProps {
  isOpen: boolean;
  onClose: () => void;
  language: 'ar' | 'en';
  gold: number;
  setGold: React.Dispatch<React.SetStateAction<number>>;
  onNotify: (msg: string, isAlert?: boolean) => void;
}

export const InventoryModal: React.FC<InventoryModalProps> = ({
  isOpen,
  onClose,
  language,
  gold,
  setGold,
  onNotify
}) => {
  const isAr = language === 'ar';

  const [items, setItems] = useState<Array<Item | null>>([
    {
      id: 'coronet_trojan_bronze',
      name_ar: 'فأس التروجان البرونزي',
      name_en: 'Bronze Trojan Axe',
      type: 'equipment',
      slot: 'weapon',
      quantity: 1,
      sellPrice: 320,
      refineLevel: 1,
      attackBonus: 32,
      defenseBonus: 4,
      description_ar: 'سلاح تروجان كلاسيكي ذو فأسين مزدوجين وقوة هجومية ساحقة',
      description_en: 'Classic dual-wielding Trojan weapon with crushing power'
    },
    {
      id: 'meteor_stone',
      name_ar: 'حجر النيزك المقدس',
      name_en: 'Sacred Meteor',
      type: 'material',
      quantity: 8,
      sellPrice: 150,
      description_ar: 'حجر نيزكي سماوي يُستخدم لصقل العتاد عند الحداد',
      description_en: 'Celestial stone required for blacksmith equipment refinement'
    },
    {
      id: 'hp_potion',
      name_ar: 'جرعة شفاء كبرى',
      name_en: 'Major Healing Potion',
      type: 'consumable',
      quantity: 20,
      sellPrice: 25,
      description_ar: 'تستعيد 250 نقطة صحة فوراً',
      description_en: 'Instantly restores 250 Health points'
    },
    {
      id: 'mp_potion',
      name_ar: 'جرعة مانا سحرية',
      name_en: 'Magic Mana Potion',
      type: 'consumable',
      quantity: 15,
      sellPrice: 25,
      description_ar: 'تستعيد 150 نقطة طاقة فوراً',
      description_en: 'Instantly restores 150 Mana points'
    },
    {
      id: 'dragon_scale',
      name_ar: 'حرشفة تنين نادرة',
      name_en: 'Rare Dragon Scale',
      type: 'material',
      quantity: 3,
      sellPrice: 450,
      description_ar: 'مادة ثمينة سقطت من تنين اللهب في قمة الجبل',
      description_en: 'Precious drop from the Great Flame Dragon'
    },
    ...Array(35).fill(null)
  ]);

  const [selectedIndex, setSelectedIndex] = useState<number>(0);

  if (!isOpen) return null;

  const selectedItem = items[selectedIndex];

  const handleSell = () => {
    if (!selectedItem) return;
    const saleRevenue = selectedItem.sellPrice * selectedItem.quantity;
    setGold(g => g + saleRevenue);
    onNotify(isAr ? `تم بيع ${selectedItem.name_ar} مقابل ${saleRevenue} ذهب!` : `Sold ${selectedItem.name_en} for ${saleRevenue} Gold!`, false);
    
    setItems(prev => {
      const next = [...prev];
      next[selectedIndex] = null;
      return next;
    });
  };

  const handleUse = () => {
    if (!selectedItem) return;
    if (selectedItem.type === 'consumable') {
      onNotify(isAr ? `تم استخدام ${selectedItem.name_ar} بنجاح!` : `Used ${selectedItem.name_en}!`, false);
      setItems(prev => {
        const next = [...prev];
        const it = next[selectedIndex];
        if (it) {
          if (it.quantity > 1) {
            it.quantity -= 1;
          } else {
            next[selectedIndex] = null;
          }
        }
        return next;
      });
    } else if (selectedItem.type === 'equipment') {
      onNotify(isAr ? `تم تجهيز ${selectedItem.name_ar} بنجاح!` : `Equipped ${selectedItem.name_en}!`, false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/75 backdrop-blur-sm p-4" dir={isAr ? 'rtl' : 'ltr'}>
      <div className="relative w-full max-w-4xl bg-slate-900 border border-slate-700/80 rounded-3xl shadow-2xl overflow-hidden flex flex-col max-h-[90vh]">
        {/* Modal Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-slate-800 bg-slate-950/60">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-amber-500/20 border border-amber-500/40 flex items-center justify-center text-amber-400">
              <Package className="w-5 h-5" />
            </div>
            <div>
              <h2 className="text-lg font-black text-white">{isAr ? 'حقيبة البطل [٤٠ خانة]' : 'Hero Inventory [40 Slots]'}</h2>
              <p className="text-xs text-slate-400">{isAr ? 'الذهب المتاح:' : 'Available Gold:'} <span className="text-amber-400 font-bold">{gold.toLocaleString()} ذهب</span></p>
            </div>
          </div>
          <button 
            onClick={onClose}
            className="w-9 h-9 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-400 hover:text-white flex items-center justify-center transition-all cursor-pointer"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Modal Body: 40-Slot Grid & Details Inspector */}
        <div className="flex-1 overflow-y-auto p-6 grid grid-cols-1 lg:grid-cols-12 gap-6">
          {/* 40 Slot Grid */}
          <div className="lg:col-span-8 grid grid-cols-5 sm:grid-cols-8 gap-2.5">
            {items.map((item, idx) => {
              const isSelected = selectedIndex === idx;
              return (
                <button
                  key={idx}
                  onClick={() => setSelectedIndex(idx)}
                  className={`aspect-square rounded-xl border flex flex-col items-center justify-center p-1.5 transition-all cursor-pointer relative group ${
                    isSelected 
                      ? 'bg-amber-950/60 border-amber-400 shadow-[0_0_15px_rgba(245,158,11,0.3)] scale-105' 
                      : item 
                        ? 'bg-slate-800/80 hover:bg-slate-700/80 border-slate-700' 
                        : 'bg-slate-950/40 border-slate-800/80 hover:border-slate-700/60'
                  }`}
                >
                  {item ? (
                    <>
                      <div className="text-xl">
                        {item.type === 'equipment' ? '⚔️' : item.type === 'consumable' ? '🧪' : '💎'}
                      </div>
                      <span className="text-[10px] font-bold text-slate-200 truncate w-full text-center">
                        {isAr ? item.name_ar : item.name_en}
                      </span>
                      {item.quantity > 1 && (
                        <span className="absolute bottom-1 end-1 text-[9px] font-black bg-slate-900/90 text-amber-300 px-1 rounded">
                          x{item.quantity}
                        </span>
                      )}
                      {item.refineLevel && item.refineLevel > 0 && (
                        <span className="absolute top-1 start-1 text-[9px] font-black text-yellow-400">
                          +{item.refineLevel}
                        </span>
                      )}
                    </>
                  ) : (
                    <span className="text-xs text-slate-600 font-mono">{idx + 1}</span>
                  )}
                </button>
              );
            })}
          </div>

          {/* Details Inspector Panel */}
          <div className="lg:col-span-4 bg-slate-950/60 rounded-2xl border border-slate-800 p-5 flex flex-col justify-between">
            {selectedItem ? (
              <div className="flex flex-col gap-4">
                <div className="flex items-center gap-3">
                  <div className="w-14 h-14 rounded-2xl bg-amber-500/10 border border-amber-500/30 flex items-center justify-center text-3xl">
                    {selectedItem.type === 'equipment' ? '⚔️' : selectedItem.type === 'consumable' ? '🧪' : '💎'}
                  </div>
                  <div>
                    <h3 className="font-black text-white text-base">
                      {isAr ? selectedItem.name_ar : selectedItem.name_en}
                      {selectedItem.refineLevel ? ` (+${selectedItem.refineLevel})` : ''}
                    </h3>
                    <span className="text-xs text-amber-400 font-medium">
                      {selectedItem.type === 'equipment' ? (isAr ? 'عتاد حربي' : 'Battle Gear') : selectedItem.type === 'consumable' ? (isAr ? 'جرعة قابلة للاستهلاك' : 'Consumable Potion') : (isAr ? 'مادة صقل نادرة' : 'Refinement Material')}
                    </span>
                  </div>
                </div>

                <p className="text-xs text-slate-300 leading-relaxed bg-slate-900/80 p-3 rounded-xl border border-slate-800">
                  {isAr ? selectedItem.description_ar : selectedItem.description_en}
                </p>

                <div className="flex flex-col gap-2 text-xs">
                  {selectedItem.attackBonus && (
                    <div className="flex justify-between py-1 border-b border-slate-800 text-red-400 font-bold">
                      <span>{isAr ? 'قوة الهجوم:' : 'Attack Power:'}</span>
                      <span>+{selectedItem.attackBonus}</span>
                    </div>
                  )}
                  {selectedItem.defenseBonus && (
                    <div className="flex justify-between py-1 border-b border-slate-800 text-blue-400 font-bold">
                      <span>{isAr ? 'الدفاع الجسدي:' : 'Physical Defense:'}</span>
                      <span>+{selectedItem.defenseBonus}</span>
                    </div>
                  )}
                  <div className="flex justify-between py-1 border-b border-slate-800 text-slate-300">
                    <span>{isAr ? 'الكمية المحمولة:' : 'Carried Quantity:'}</span>
                    <span className="font-bold">{selectedItem.quantity}</span>
                  </div>
                  <div className="flex justify-between py-1 text-amber-400 font-bold">
                    <span>{isAr ? 'سعر البيع لدى التاجر:' : 'Merchant Sell Value:'}</span>
                    <span>{selectedItem.sellPrice * selectedItem.quantity} ذهب</span>
                  </div>
                </div>
              </div>
            ) : (
              <div className="h-full flex flex-col items-center justify-center text-center text-slate-500 py-12">
                <Package className="w-10 h-10 mb-2 opacity-40" />
                <p className="text-xs">{isAr ? 'اختر خانة من الحقيبة لمعاينة تفاصيل العنصر' : 'Select an inventory slot to view details'}</p>
              </div>
            )}

            {/* Actions: Equip, Use, Sell */}
            {selectedItem && (
              <div className="flex flex-col gap-2 mt-4 pt-4 border-t border-slate-800">
                <button
                  onClick={handleUse}
                  className="w-full py-2.5 bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-500 hover:to-indigo-500 text-white font-bold text-xs rounded-xl transition-all cursor-pointer shadow-lg"
                >
                  {selectedItem.type === 'equipment' ? (isAr ? 'ارتداء العتاد' : 'Equip Gear') : (isAr ? 'استخدام الجرعة' : 'Use Item')}
                </button>
                <button
                  onClick={handleSell}
                  className="w-full py-2.5 bg-amber-600/20 hover:bg-amber-600/30 text-amber-300 border border-amber-600/40 font-bold text-xs rounded-xl transition-all cursor-pointer"
                >
                  {isAr ? 'بيع للتاجر مقابل الذهب' : 'Sell to Merchant for Gold'}
                </button>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};
