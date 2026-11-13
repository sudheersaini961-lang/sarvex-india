import React, { useState, useEffect } from 'react';
import {
  Search,
  ShoppingCart,
  Heart,
  MapPin,
  X,
  SlidersHorizontal,
  Database,
  Store,
  ShieldCheck,
  User,
  LogOut
} from 'lucide-react';
import { useMarketplace } from '../lib/marketplaceStore';
import { getStoredSupabaseConfig } from '../lib/supabaseClient';

interface HeaderProps {
  onOpenCart: () => void;
  onOpenWishlist: () => void;
  onOpenSupabaseModal: () => void;
  onOpenAuthModal: () => void;
}

export const Header: React.FC<HeaderProps> = ({
  onOpenCart,
  onOpenWishlist,
  onOpenSupabaseModal,
  onOpenAuthModal,
}) => {
  const {
    cart,
    wishlistIds,
    searchQuery,
    setSearchQuery,
    activeRole,
    setActiveRole,
    currentUser,
    logoutUser,
  } = useMarketplace();

  const [deliveryPincode, setDeliveryPincode] = useState('');
  const [isChangingPin, setIsChangingPin] = useState(false);
  const [pinInput, setPinInput] = useState('');
  const [showRoleMenu, setShowRoleMenu] = useState(false);

  const cartItemsCount = cart.reduce((sum, item) => sum + item.quantity, 0);
  const [isSupabaseConnected, setIsSupabaseConnected] = useState(
    getStoredSupabaseConfig().isConfigured
  );

  useEffect(() => {
    const handleUpdate = () => {
      setIsSupabaseConnected(getStoredSupabaseConfig().isConfigured);
    };
    window.addEventListener('sarvex:supabase_config_changed', handleUpdate);
    return () => {
      window.removeEventListener('sarvex:supabase_config_changed', handleUpdate);
    };
  }, []);

  const handlePinSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (pinInput.trim().length === 6) {
      setDeliveryPincode(pinInput.trim());
      setIsChangingPin(false);
    }
  };

  return (
    <header className="sticky top-0 z-40 bg-[#1e3a8a] text-white shadow-md">
      {/* Top Android Sub-bar: Delivery Location & Role Switcher */}
      <div className="flex items-center justify-between px-3 py-1.5 bg-[#172554] text-xs border-b border-blue-900/50">
        <button
          onClick={() => setIsChangingPin(true)}
          className="flex items-center gap-1 text-blue-200 hover:text-white transition-colors"
        >
          <MapPin size={13} className="text-[#f97316]" />
          <span>Deliver to: <strong className="text-white font-medium">{deliveryPincode || 'Select PIN code'}</strong></span>
          <span className="text-[10px] text-blue-300 underline ml-0.5">Change</span>
        </button>

        <div className="flex items-center gap-2">
          {/* Supabase status badge */}
          <button
            onClick={onOpenSupabaseModal}
            className={`flex items-center gap-1 px-2.5 py-0.5 rounded-full text-[11px] font-bold border transition-all shadow-xs ${
              isSupabaseConnected
                ? 'bg-emerald-950 text-emerald-300 border-emerald-400'
                : 'bg-amber-950/90 text-amber-200 border-amber-400 hover:bg-amber-900'
            }`}
            title="Configure Supabase Cloud Database"
          >
            <Database size={12} className={isSupabaseConnected ? 'text-emerald-400' : 'text-amber-400 animate-pulse'} />
            <span>{isSupabaseConnected ? 'DB: Configured' : 'DB: Not set'}</span>
          </button>

          {/* Quick Role switcher */}
          <div className="relative">
            <button
              onClick={() => setShowRoleMenu(!showRoleMenu)}
              className="flex items-center gap-1 bg-[#1e40af] hover:bg-blue-700 text-white px-2 py-0.5 rounded text-[11px] font-medium transition"
            >
              {activeRole === 'customer' && <span className="flex items-center gap-1">👤 Buyer</span>}
              {activeRole === 'seller' && <span className="flex items-center gap-1 text-amber-300">🏪 Seller</span>}
              {activeRole === 'admin' && <span className="flex items-center gap-1 text-orange-400">🛡️ Admin</span>}
            </button>

            {showRoleMenu && (
              <div className="absolute right-0 top-full mt-1 w-44 bg-white text-gray-800 rounded-lg shadow-xl border border-gray-100 py-1.5 z-50 text-xs">
                <div className="px-3 py-1 text-[10px] font-semibold text-gray-400 uppercase tracking-wider border-b border-gray-100">
                  Switch App Mode
                </div>
                <button
                  onClick={() => {
                    setActiveRole('customer');
                    setShowRoleMenu(false);
                  }}
                  className={`w-full text-left px-3 py-2 flex items-center justify-between hover:bg-blue-50 ${
                    activeRole === 'customer' ? 'font-bold text-blue-800 bg-blue-50/60' : ''
                  }`}
                >
                  <span className="flex items-center gap-2">
                    <User size={14} className="text-blue-600" /> Buyer App
                  </span>
                  {activeRole === 'customer' && <span className="text-[10px] text-blue-600 font-semibold">Active</span>}
                </button>
                <button
                  onClick={() => {
                    setActiveRole('seller');
                    setShowRoleMenu(false);
                  }}
                  className={`w-full text-left px-3 py-2 flex items-center justify-between hover:bg-amber-50 ${
                    activeRole === 'seller' ? 'font-bold text-amber-800 bg-amber-50/60' : ''
                  }`}
                >
                  <span className="flex items-center gap-2">
                    <Store size={14} className="text-amber-600" /> Seller Portal
                  </span>
                  {activeRole === 'seller' && <span className="text-[10px] text-amber-600 font-semibold">Active</span>}
                </button>
                {currentUser?.role === 'admin' && (
                  <button
                    onClick={() => {
                      setActiveRole('admin');
                      setShowRoleMenu(false);
                    }}
                    className={`w-full text-left px-3 py-2 flex items-center justify-between hover:bg-orange-50 ${
                      activeRole === 'admin' ? 'font-bold text-orange-800 bg-orange-50/60' : ''
                    }`}
                  >
                    <span className="flex items-center gap-2">
                      <ShieldCheck size={14} className="text-orange-600" /> Admin Control
                    </span>
                    {activeRole === 'admin' && <span className="text-[10px] text-orange-600 font-semibold">Active</span>}
                  </button>
                )}
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Main Bar: Brand Logo & Actions */}
      <div className="flex items-center justify-between px-3 py-2.5">
        {/* Brand */}
        <div className="flex items-center gap-2">
          <div className="w-8 h-8 rounded-lg bg-white flex items-center justify-center shadow-sm">
            <span className="text-xl font-black text-[#1e3a8a] leading-none">S</span>
            <span className="w-2 h-2 rounded-full bg-[#f97316] -ml-1 -mt-3"></span>
          </div>
          <div>
            <div className="flex items-center gap-1">
              <span className="text-lg font-black tracking-tight text-white">SARVEX</span>
              <span className="text-[10px] font-bold px-1.5 py-0.2 bg-[#f97316] text-white rounded">INDIA</span>
            </div>
            <p className="text-[9px] text-blue-200 tracking-wide font-medium -mt-1">
              {activeRole === 'seller'
                ? '0% Commission Seller Hub'
                : activeRole === 'admin'
                ? 'Central Admin Operations'
                : 'India’s Multi-Vendor Marketplace'}
            </p>
          </div>
        </div>

        {/* Right Action Icons */}
        <div className="flex items-center gap-1.5">
          {currentUser ? (
            <button
              onClick={onOpenAuthModal}
              className="flex items-center gap-1 text-xs text-blue-100 hover:text-white px-2 py-1 rounded bg-blue-800/40"
              title={currentUser.fullName}
            >
              <User size={15} />
              <span className="hidden sm:inline max-w-[80px] truncate">{currentUser.fullName.split(' ')[0]}</span>
            </button>
          ) : (
            <button
              onClick={onOpenAuthModal}
              className="text-xs bg-[#f97316] hover:bg-orange-600 text-white font-semibold px-2.5 py-1 rounded shadow-sm"
            >
              Sign In
            </button>
          )}

          {/* Wishlist */}
          <button
            onClick={onOpenWishlist}
            className="relative p-2 text-blue-100 hover:text-white hover:bg-blue-800/60 rounded-full transition"
            aria-label="Wishlist"
          >
            <Heart size={20} className={wishlistIds.length > 0 ? 'fill-red-500 text-red-500' : ''} />
            {wishlistIds.length > 0 && (
              <span className="absolute top-0 right-0 w-4 h-4 bg-red-500 text-white text-[10px] font-bold rounded-full flex items-center justify-center">
                {wishlistIds.length}
              </span>
            )}
          </button>

          {/* Cart */}
          <button
            onClick={onOpenCart}
            className="relative p-2 text-white hover:bg-blue-800/60 rounded-full transition"
            aria-label="Shopping Cart"
          >
            <ShoppingCart size={21} />
            {cartItemsCount > 0 && (
              <span className="absolute top-0 right-0 w-4 h-4 bg-[#f97316] text-white text-[10px] font-black rounded-full flex items-center justify-center shadow">
                {cartItemsCount}
              </span>
            )}
          </button>
        </div>
      </div>

      {/* Search Input Bar (Visible in customer mode) */}
      {activeRole === 'customer' && (
        <div className="px-3 pb-2.5">
          <div className="relative flex items-center">
            <Search size={17} className="absolute left-3 text-gray-400 pointer-events-none" />
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="Search 10,000+ products, sarees, earbuds, kurtas..."
              className="w-full bg-white text-gray-900 text-sm pl-9 pr-9 py-2 rounded-lg shadow-inner focus:outline-none focus:ring-2 focus:ring-[#f97316] placeholder:text-gray-400 font-normal"
            />
            {searchQuery && (
              <button
                onClick={() => setSearchQuery('')}
                className="absolute right-3 p-0.5 text-gray-400 hover:text-gray-600"
              >
                <X size={15} />
              </button>
            )}
          </div>
        </div>
      )}

      {/* Pincode Change Modal */}
      {isChangingPin && (
        <div className="fixed inset-0 z-50 bg-black/60 flex items-center justify-center p-4">
          <div className="bg-white text-gray-900 rounded-xl p-4 max-w-sm w-full shadow-2xl">
            <div className="flex justify-between items-center mb-3">
              <h3 className="font-bold text-base text-[#1e3a8a] flex items-center gap-1.5">
                <MapPin size={18} className="text-[#f97316]" /> Choose Delivery Location
              </h3>
              <button
                onClick={() => setIsChangingPin(false)}
                className="text-gray-400 hover:text-gray-600 p-1"
              >
                <X size={18} />
              </button>
            </div>
            <p className="text-xs text-gray-600 mb-3">
              Enter your 6-digit Indian Postal PIN code to view Cash on Delivery availability and fastest courier dispatch.
            </p>
            <form onSubmit={handlePinSubmit} className="space-y-3">
              <input
                type="text"
                pattern="[0-9]{6}"
                maxLength={6}
                value={pinInput}
                onChange={(e) => setPinInput(e.target.value.replace(/\D/g, ''))}
                placeholder="e.g. 110016 or 560034"
                className="w-full border border-gray-300 rounded-lg px-3 py-2 text-center text-lg font-mono font-bold tracking-widest text-[#1e3a8a] focus:ring-2 focus:ring-[#1e3a8a] focus:outline-none"
                autoFocus
              />
              <div className="flex gap-2">
                <button
                  type="button"
                  onClick={() => setIsChangingPin(false)}
                  className="flex-1 py-2 text-xs font-semibold text-gray-600 bg-gray-100 rounded-lg hover:bg-gray-200"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={pinInput.trim().length !== 6}
                  className="flex-1 py-2 text-xs font-bold text-white bg-[#1e3a8a] rounded-lg hover:bg-blue-800 disabled:opacity-50"
                >
                  Apply Pincode
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </header>
  );
};
