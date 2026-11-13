import React from 'react';
import { Home, Grid, Store, Package, User, ShieldCheck } from 'lucide-react';
import { useMarketplace } from '../lib/marketplaceStore';

export type NavigationTab = 'home' | 'categories' | 'sell' | 'orders' | 'account' | 'admin';

interface BottomNavProps {
  activeTab: NavigationTab;
  onTabChange: (tab: NavigationTab) => void;
  onOpenCart: () => void;
}

export const BottomNav: React.FC<BottomNavProps> = ({
  activeTab,
  onTabChange,
}) => {
  const { activeRole, orders, currentSeller } = useMarketplace();

  const pendingSellerOrders = orders.filter((o) =>
    o.status !== 'delivered' && o.status !== 'cancelled'
  ).length;

  return (
    <nav className="fixed bottom-0 left-0 right-0 z-40 bg-white border-t border-gray-200/90 shadow-[0_-2px_10px_rgba(0,0,0,0.06)] max-w-screen-md mx-auto">
      <div className="flex items-center justify-around h-14 px-1">
        {/* Tab 1: Home */}
        <button
          onClick={() => onTabChange('home')}
          className={`flex flex-col items-center justify-center flex-1 h-full py-1 transition-colors tap-effect ${
            activeTab === 'home' && activeRole === 'customer'
              ? 'text-[#1e3a8a] font-bold'
              : 'text-gray-500 hover:text-gray-900'
          }`}
        >
          <Home size={20} className={activeTab === 'home' && activeRole === 'customer' ? 'stroke-[2.5]' : ''} />
          <span className="text-[10px] mt-0.5">Home</span>
        </button>

        {/* Tab 2: Categories */}
        <button
          onClick={() => onTabChange('categories')}
          className={`flex flex-col items-center justify-center flex-1 h-full py-1 transition-colors tap-effect ${
            activeTab === 'categories'
              ? 'text-[#1e3a8a] font-bold'
              : 'text-gray-500 hover:text-gray-900'
          }`}
        >
          <Grid size={20} className={activeTab === 'categories' ? 'stroke-[2.5]' : ''} />
          <span className="text-[10px] mt-0.5">Categories</span>
        </button>

        {/* Tab 3: Sell / Seller Hub */}
        <button
          onClick={() => onTabChange('sell')}
          className={`flex flex-col items-center justify-center flex-1 h-full py-1 relative transition-colors tap-effect ${
            activeTab === 'sell' || activeRole === 'seller'
              ? 'text-[#f97316] font-bold'
              : 'text-gray-500 hover:text-gray-900'
          }`}
        >
          <div className="relative">
            <Store size={20} className={activeTab === 'sell' || activeRole === 'seller' ? 'stroke-[2.5] text-[#f97316]' : ''} />
            {currentSeller && currentSeller.status === 'pending' && (
              <span className="absolute -top-1 -right-1 w-2.5 h-2.5 bg-amber-500 rounded-full border border-white"></span>
            )}
          </div>
          <span className="text-[10px] mt-0.5">
            {activeRole === 'seller' ? 'Seller Hub' : 'Sell (₹0 fee)'}
          </span>
        </button>

        {/* Tab 4: Orders */}
        <button
          onClick={() => onTabChange('orders')}
          className={`flex flex-col items-center justify-center flex-1 h-full py-1 relative transition-colors tap-effect ${
            activeTab === 'orders'
              ? 'text-[#1e3a8a] font-bold'
              : 'text-gray-500 hover:text-gray-900'
          }`}
        >
          <div className="relative">
            <Package size={20} className={activeTab === 'orders' ? 'stroke-[2.5]' : ''} />
            {orders.length > 0 && (
              <span className="absolute -top-1 -right-1.5 w-4 h-4 bg-[#1e3a8a] text-white text-[9px] font-bold rounded-full flex items-center justify-center">
                {orders.length}
              </span>
            )}
          </div>
          <span className="text-[10px] mt-0.5">My Orders</span>
        </button>

        {/* Tab 5: Account & Admin Switch */}
        <button
          onClick={() => onTabChange(activeRole === 'admin' ? 'admin' : 'account')}
          className={`flex flex-col items-center justify-center flex-1 h-full py-1 transition-colors tap-effect ${
            activeTab === 'account' || activeTab === 'admin'
              ? 'text-[#1e3a8a] font-bold'
              : 'text-gray-500 hover:text-gray-900'
          }`}
        >
          {activeRole === 'admin' ? (
            <ShieldCheck size={20} className="text-[#f97316] stroke-[2.5]" />
          ) : (
            <User size={20} className={activeTab === 'account' ? 'stroke-[2.5]' : ''} />
          )}
          <span className="text-[10px] mt-0.5">
            {activeRole === 'admin' ? 'Admin' : 'Account'}
          </span>
        </button>
      </div>
    </nav>
  );
};
