import React from 'react';
import {
  Smartphone,
  Shirt,
  Headphones,
  Home,
  ShoppingBag,
  Sparkles,
  LayoutGrid
} from 'lucide-react';
import { useMarketplace } from '../lib/marketplaceStore';

interface CategoryChipsProps {
  onSelectCategory?: (slug: string | null) => void;
}

export const CategoryChips: React.FC<CategoryChipsProps> = ({ onSelectCategory }) => {
  const { categories, selectedCategory, setSelectedCategory } = useMarketplace();

  const getIcon = (iconName: string) => {
    switch (iconName) {
      case 'Smartphone':
        return <Smartphone size={16} />;
      case 'Shirt':
        return <Shirt size={16} />;
      case 'Headphones':
        return <Headphones size={16} />;
      case 'Home':
        return <Home size={16} />;
      case 'ShoppingBag':
        return <ShoppingBag size={16} />;
      case 'Sparkles':
        return <Sparkles size={16} />;
      default:
        return <LayoutGrid size={16} />;
    }
  };

  const handleCategoryClick = (slug: string | null) => {
    setSelectedCategory(slug);
    if (onSelectCategory) {
      onSelectCategory(slug);
    }
  };

  return (
    <div className="py-2.5 px-3">
      <div className="flex items-center justify-between mb-2">
        <h3 className="text-xs font-bold text-gray-800 uppercase tracking-wider flex items-center gap-1.5">
          <span className="w-1.5 h-3.5 bg-[#f97316] rounded-full"></span>
          Explore Categories
        </h3>
        {selectedCategory && (
          <button
            onClick={() => handleCategoryClick(null)}
            className="text-[11px] font-semibold text-[#1e3a8a] hover:underline"
          >
            Clear Filter (Show All)
          </button>
        )}
      </div>

      <div className="flex items-center gap-2 overflow-x-auto no-scrollbar pb-1">
        {/* All Products pill */}
        <button
          onClick={() => handleCategoryClick(null)}
          className={`flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-medium whitespace-nowrap transition tap-effect border ${
            selectedCategory === null
              ? 'bg-[#1e3a8a] text-white border-[#1e3a8a] shadow-sm'
              : 'bg-white text-gray-700 border-gray-200 hover:bg-gray-50'
          }`}
        >
          <LayoutGrid size={14} />
          <span>All Items</span>
        </button>

        {/* Dynamic Categories */}
        {categories.map((cat) => {
          const isSelected = selectedCategory === cat.slug;
          return (
            <button
              key={cat.id}
              onClick={() => handleCategoryClick(isSelected ? null : cat.slug)}
              className={`flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-medium whitespace-nowrap transition tap-effect border ${
                isSelected
                  ? 'bg-[#1e3a8a] text-white border-[#1e3a8a] shadow-sm'
                  : 'bg-white text-gray-700 border-gray-200 hover:bg-gray-50'
              }`}
            >
              <span className={isSelected ? 'text-orange-300' : 'text-[#f97316]'}>
                {getIcon(cat.iconName)}
              </span>
              <span>{cat.name}</span>
            </button>
          );
        })}
      </div>
    </div>
  );
};
