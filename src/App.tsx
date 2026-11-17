import React, { useState } from 'react';
import {
  Header
} from './components/Header';
import { BottomNav, NavigationTab } from './components/BottomNav';
import { BannerSlider } from './components/BannerSlider';
import { CategoryChips } from './components/CategoryChips';
import { ProductCard } from './components/ProductCard';
import { ProductDetailModal } from './components/ProductDetailModal';
import { CartDrawer } from './components/CartDrawer';
import { CheckoutModal } from './components/CheckoutModal';
import { OrderTrackingModal } from './components/OrderTrackingModal';
import { WishlistModal } from './components/WishlistModal';
import { SupabaseConnectModal } from './components/SupabaseConnectModal';
import { AuthModal } from './components/AuthModal';
import { SellerPortal } from './components/SellerPortal';
import { AdminDashboard } from './components/AdminDashboard';
import { DatabaseSettingsCard } from './components/DatabaseSettingsCard';
import { useMarketplace } from './lib/marketplaceStore';
import { Product, Order } from './types/marketplace';
import {
  ShieldCheck,
  Truck,
  RotateCcw,
  Sparkles,
  Package,
  ChevronRight,
  Download,
  Database,
  Store,
  Layers,
  PhoneCall,
  CheckCircle2,
  ExternalLink
} from 'lucide-react';

export default function App() {
  const {
    filteredProducts,
    products,
    categories,
    selectedCategory,
    setSelectedCategory,
    orders,
    activeRole,
    setActiveRole,
    currentUser,
    searchQuery,
    setSearchQuery,
  } = useMarketplace();

  // Navigation tab state
  const [activeTab, setActiveTab] = useState<NavigationTab>('home');

  // Modals state
  const [selectedProduct, setSelectedProduct] = useState<Product | null>(null);
  const [isCartOpen, setIsCartOpen] = useState(false);
  const [isCheckoutOpen, setIsCheckoutOpen] = useState(false);
  const [isWishlistOpen, setIsWishlistOpen] = useState(false);
  const [isSupabaseModalOpen, setIsSupabaseModalOpen] = useState(false);
  const [isAuthModalOpen, setIsAuthModalOpen] = useState(false);
  const [trackedOrder, setTrackedOrder] = useState<Order | null>(null);

  // Buy Now direct trigger
  const handleBuyNow = (product: Product) => {
    setSelectedProduct(null);
    setIsCheckoutOpen(true);
  };

  const handleOrderSuccess = (order: Order) => {
    setTrackedOrder(order);
  };

  return (
    <div className="min-h-screen bg-[#f1f5f9] text-gray-900 flex justify-center selection:bg-orange-200">
      {/* Mobile Shell Frame */}
      <div className="w-full max-w-md min-h-screen bg-white flex flex-col shadow-xl relative border-x border-gray-200/80">
        {/* Android Marketplace Header */}
        <Header
          onOpenCart={() => setIsCartOpen(true)}
          onOpenWishlist={() => setIsWishlistOpen(true)}
          onOpenSupabaseModal={() => setIsSupabaseModalOpen(true)}
          onOpenAuthModal={() => setIsAuthModalOpen(true)}
        />

        {/* View Switcher based on Active Tab or Role */}
        <main className="flex-1 pb-16">
          {/* 1. SELLER PORTAL TAB */}
          {(activeTab === 'sell' || activeRole === 'seller') ? (
            <SellerPortal />
          ) : activeTab === 'admin' || activeRole === 'admin' ? (
            /* 2. ADMIN DASHBOARD TAB */
            <AdminDashboard
              onOpenSupabaseModal={() => setIsSupabaseModalOpen(true)}
              onViewOrder={(order) => setTrackedOrder(order)}
            />
          ) : activeTab === 'categories' ? (
            /* 3. CATEGORIES TAB */
            <div className="p-3 space-y-3">
              <div className="flex items-center justify-between pb-1">
                <h2 className="text-sm font-black text-gray-900 uppercase tracking-wider flex items-center gap-1.5">
                  <Layers size={16} className="text-[#1e3a8a]" /> All Marketplace Categories
                </h2>
                <span className="text-xs text-gray-500 font-semibold">{categories.length} Departments</span>
              </div>

              <div className="grid grid-cols-2 gap-2.5">
                {categories.map((cat) => (
                  <div
                    key={cat.id}
                    onClick={() => {
                      setSelectedCategory(cat.slug);
                      setActiveTab('home');
                    }}
                    className="bg-white border border-gray-200 rounded-xl overflow-hidden shadow-xs hover:shadow-md transition tap-effect cursor-pointer group"
                  >
                    <div className="aspect-4/3 w-full bg-gray-100 overflow-hidden relative">
                      <img
                        src={cat.imageUrl}
                        alt={cat.name}
                        className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
                      />
                      <div className="absolute inset-0 bg-gradient-to-t from-black/60 to-transparent flex items-end p-2.5">
                        <span className="text-[10px] text-white font-bold bg-[#f97316] px-1.5 py-0.5 rounded">
                          {products.filter((product) => product.category === cat.slug || product.category === cat.name).length} Products
                        </span>
                      </div>
                    </div>
                    <div className="p-2.5">
                      <h3 className="font-bold text-xs text-gray-900 group-hover:text-[#1e3a8a] transition">
                        {cat.name}
                      </h3>
                      <p className="text-[10px] text-gray-500 mt-0.5 flex items-center justify-between">
                        <span>Shop Now</span>
                        <ChevronRight size={12} />
                      </p>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          ) : activeTab === 'orders' ? (
            /* 4. MY ORDERS TAB */
            <div className="p-3 space-y-3">
              <div className="flex items-center justify-between pb-1">
                <h2 className="text-sm font-black text-gray-900 uppercase tracking-wider flex items-center gap-1.5">
                  <Package size={16} className="text-[#1e3a8a]" /> My Orders & Deliveries
                </h2>
                <span className="text-xs text-gray-500 font-bold">{orders.length} Orders</span>
              </div>

              {orders.length === 0 ? (
                <div className="text-center py-16 px-4 bg-white rounded-xl border border-gray-200">
                  <Package size={36} className="mx-auto text-gray-300 mb-2" />
                  <h3 className="font-bold text-sm text-gray-800">No Orders Placed Yet</h3>
                  <p className="text-xs text-gray-500 max-w-xs mx-auto mb-4">
                    Checkout is not active yet. You can browse verified listings; orders will be enabled after delivery and payment checks.
                  </p>
                  <button
                    onClick={() => setActiveTab('home')}
                    className="px-4 py-2 bg-[#1e3a8a] text-white text-xs font-bold rounded-xl shadow"
                  >
                    Start Shopping
                  </button>
                </div>
              ) : (
                <div className="space-y-3">
                  {orders.map((ord) => (
                    <div
                      key={ord.id}
                      className="bg-white border border-gray-200 rounded-xl p-3.5 space-y-2.5 shadow-xs"
                    >
                      <div className="flex items-start justify-between">
                        <div>
                          <div className="flex items-center gap-2">
                            <span className="font-mono font-bold text-xs text-[#1e3a8a]">
                              #{ord.id}
                            </span>
                            <span className="text-[10px] font-bold px-2 py-0.5 rounded-full capitalize bg-emerald-50 text-emerald-800 border border-emerald-200">
                              {ord.status.replace(/_/g, ' ')}
                            </span>
                          </div>
                          <p className="text-[10px] text-gray-400 mt-0.5">
                            Placed on {new Date(ord.createdAt).toLocaleDateString('en-IN', {
                              day: 'numeric',
                              month: 'short',
                              year: 'numeric'
                            })}
                          </p>
                        </div>
                        <div className="text-right">
                          <span className="text-xs font-black text-gray-900 block">
                            ₹{ord.totalAmount.toLocaleString('en-IN')}
                          </span>
                          <span className="text-[10px] text-emerald-700 font-bold">
                            Cash on Delivery
                          </span>
                        </div>
                      </div>

                      {/* Items Preview */}
                      <div className="flex items-center gap-2 overflow-x-auto no-scrollbar py-1">
                        {ord.items.map((it) => (
                          <div key={it.id} className="flex items-center gap-1.5 shrink-0 bg-gray-50 p-1.5 rounded-lg border border-gray-100">
                            <img
                              src={it.imageUrl}
                              alt={it.title}
                              className="w-8 h-8 rounded object-cover"
                            />
                            <div className="text-[10px] max-w-[130px] truncate">
                              <p className="font-semibold text-gray-800 truncate">{it.title}</p>
                              <p className="text-gray-500">Qty: {it.quantity}</p>
                            </div>
                          </div>
                        ))}
                      </div>

                      <div className="flex items-center justify-between pt-1 border-t border-gray-100">
                        <p className="text-[10px] text-gray-500 truncate max-w-[170px]">
                          Delivering to: {ord.city} ({ord.pincode})
                        </p>
                        <button
                          onClick={() => setTrackedOrder(ord)}
                          className="px-3 py-1.5 bg-[#1e3a8a] text-white text-xs font-bold rounded-lg shadow-xs hover:bg-blue-800 transition tap-effect flex items-center gap-1"
                        >
                          <span>Track Delivery</span>
                          <ChevronRight size={13} />
                        </button>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          ) : activeTab === 'account' ? (
            /* 5. ACCOUNT / SETTINGS TAB */
            <div className="p-3 space-y-3">
              {/* Profile Card */}
              <div className="bg-[#1e3a8a] text-white p-4 rounded-2xl shadow-md">
                <div className="flex items-center gap-3">
                  <div className="w-12 h-12 rounded-full bg-white text-[#1e3a8a] flex items-center justify-center font-black text-xl shadow">
                    {currentUser?.fullName?.[0] || 'S'}
                  </div>
                  <div className="flex-1">
                    <h3 className="font-black text-base leading-tight">
                      {currentUser?.fullName || 'Guest'}
                    </h3>
                    <p className="text-xs text-blue-200">{currentUser?.email || 'Not signed in'}</p>
                    <p className="text-xs text-blue-200 font-mono">{currentUser?.phone ? `+91 ${currentUser.phone}` : 'Phone not added'}</p>
                  </div>
                </div>

                <div className="mt-3 pt-3 border-t border-blue-800/80 flex items-center justify-between">
                  <span className="text-[11px] text-blue-200">Active App Mode:</span>
                  <span className="text-xs font-bold px-2 py-0.5 rounded bg-[#f97316] text-white capitalize">
                    {activeRole} View
                  </span>
                </div>
              </div>

              {/* Prominent Database Settings Card */}
              <DatabaseSettingsCard />

              {/* Action Menu List */}
              <div className="bg-white rounded-xl border border-gray-200 divide-y divide-gray-100 shadow-xs text-xs">

                <button
                  onClick={() => {
                    setActiveRole('seller');
                    setActiveTab('sell');
                  }}
                  className="w-full p-3.5 flex items-center justify-between hover:bg-gray-50 transition"
                >
                  <div className="flex items-center gap-2.5">
                    <div className="p-2 bg-orange-100 text-[#ea580c] rounded-lg">
                      <Store size={16} />
                    </div>
                    <div className="text-left">
                      <p className="font-bold text-gray-900">Apply to Sell on SARVEX</p>
                      <p className="text-[11px] text-gray-500">Register store or manage catalog</p>
                    </div>
                  </div>
                  <ChevronRight size={16} className="text-gray-400" />
                </button>

                {currentUser?.role === 'admin' && (
                  <button
                    onClick={() => {
                      setActiveRole('admin');
                      setActiveTab('admin');
                    }}
                    className="w-full p-3.5 flex items-center justify-between hover:bg-gray-50 transition"
                  >
                    <div className="flex items-center gap-2.5">
                      <div className="p-2 bg-blue-100 text-[#1e3a8a] rounded-lg">
                        <ShieldCheck size={16} />
                      </div>
                      <div className="text-left">
                        <p className="font-bold text-gray-900">Central Admin Console</p>
                        <p className="text-[11px] text-gray-500">Approve sellers & manage orders</p>
                      </div>
                    </div>
                    <ChevronRight size={16} className="text-gray-400" />
                  </button>
                )}

                <button
                  onClick={() => setIsAuthModalOpen(true)}
                  className="w-full p-3.5 flex items-center justify-between hover:bg-gray-50 transition"
                >
                  <div className="flex items-center gap-2.5">
                    <div className="p-2 bg-gray-100 text-gray-700 rounded-lg">
                      <PhoneCall size={16} />
                    </div>
                    <div className="text-left">
                      <p className="font-bold text-gray-900">Account Credentials</p>
                      <p className="text-[11px] text-gray-500">Change phone or sign out</p>
                    </div>
                  </div>
                  <ChevronRight size={16} className="text-gray-400" />
                </button>
              </div>

              {/* Android PWA Instructions */}
              <div className="bg-gradient-to-r from-blue-50 to-orange-50 border border-blue-200/80 rounded-xl p-3.5 space-y-2">
                <h4 className="font-bold text-xs text-[#1e3a8a] flex items-center gap-1.5">
                  <Download size={14} className="text-[#f97316]" /> How to Install on Android Phone:
                </h4>
                <p className="text-[11px] text-gray-700 leading-normal">
                  In Chrome on Android, tap the three dots <strong>⋮</strong> in the top right, then tap <strong>"Install app"</strong> or <strong>"Add to Home screen"</strong>. SARVEX India will open as a full-screen native Android app without browser bars!
                </p>
              </div>
            </div>
          ) : (
            /* 6. HOME BUYER MARKETPLACE (Default) */
            <div className="space-y-3">
              {/* Banner Carousel */}
              <BannerSlider
                onRegisterSellerClick={() => {
                  setActiveRole('seller');
                  setActiveTab('sell');
                }}
                onExploreDealsClick={() => {
                  setSelectedCategory(null);
                  setSearchQuery('');
                }}
              />

              {/* 3 Indian Trust Badges Bar */}
              <div className="mx-3 grid grid-cols-3 gap-1.5 py-2 px-1 bg-white rounded-xl border border-gray-200 shadow-xs text-center">
                <div className="flex flex-col items-center justify-center p-1">
                  <Truck size={16} className="text-[#f97316] mb-0.5" />
                  <span className="text-[10px] font-bold text-gray-900 leading-tight">Checkout Setup</span>
                  <span className="text-[9px] text-gray-500">Orders not active yet</span>
                </div>
                <div className="flex flex-col items-center justify-center p-1 border-x border-gray-100">
                  <RotateCcw size={16} className="text-[#1e3a8a] mb-0.5" />
                  <span className="text-[10px] font-bold text-gray-900 leading-tight">Return Policy</span>
                  <span className="text-[9px] text-gray-500">Shown per listing</span>
                </div>
                <div className="flex flex-col items-center justify-center p-1">
                  <ShieldCheck size={16} className="text-emerald-600 mb-0.5" />
                  <span className="text-[10px] font-bold text-gray-900 leading-tight">Seller Review</span>
                  <span className="text-[9px] text-gray-500">Approval required</span>
                </div>
              </div>

              {/* Categories Bar */}
              <CategoryChips onSelectCategory={() => {}} />

              {/* Search or Filter status notice */}
              {(searchQuery || selectedCategory) && (
                <div className="mx-3 px-3 py-2 bg-blue-50 border border-blue-200 rounded-xl flex items-center justify-between text-xs">
                  <span className="text-gray-700">
                    Showing results for:{' '}
                    <strong>{searchQuery ? `"${searchQuery}"` : ''}</strong>
                    {selectedCategory ? ` [Category: ${selectedCategory}]` : ''}
                  </span>
                  <button
                    onClick={() => {
                      setSearchQuery('');
                      setSelectedCategory(null);
                    }}
                    className="text-[#1e3a8a] font-bold underline"
                  >
                    Clear All
                  </button>
                </div>
              )}

              {/* Products Feed */}
              <div className="px-3">
                <div className="flex items-center justify-between mb-2">
                  <h3 className="text-xs font-black text-gray-900 uppercase tracking-wider flex items-center gap-1.5">
                    <span className="w-1.5 h-3.5 bg-[#1e3a8a] rounded-full"></span>
                    Products ({filteredProducts.length})
                  </h3>

                </div>

                {filteredProducts.length === 0 ? (
                  <div className="text-center py-12 px-4 bg-white rounded-xl border border-gray-200">
                    <p className="font-bold text-gray-800 text-sm mb-1">No products found</p>
                    <p className="text-xs text-gray-500 mb-3">Try searching for sarees, earbuds, kurtas, or walnuts.</p>
                    <button
                      onClick={() => {
                        setSearchQuery('');
                        setSelectedCategory(null);
                      }}
                      className="px-4 py-2 bg-[#1e3a8a] text-white text-xs font-bold rounded-lg shadow"
                    >
                      Show All Products
                    </button>
                  </div>
                ) : (
                  <div className="grid grid-cols-2 gap-2.5">
                    {filteredProducts.map((product) => (
                      <ProductCard
                        key={product.id}
                        product={product}
                        onSelect={(prod) => setSelectedProduct(prod)}
                      />
                    ))}
                  </div>
                )}
              </div>
            </div>
          )}
        </main>

        {/* Android Bottom Navigation */}
        <BottomNav
          activeTab={activeTab}
          onTabChange={(tab) => {
            setActiveTab(tab);
            if (tab === 'home') {
              setActiveRole('customer');
            } else if (tab === 'sell') {
              setActiveRole('seller');
            } else if (tab === 'admin') {
              setActiveRole('admin');
            }
          }}
          onOpenCart={() => setIsCartOpen(true)}
        />

        {/* Global Modals & Drawers */}
        <ProductDetailModal
          product={selectedProduct}
          onClose={() => setSelectedProduct(null)}
          onBuyNow={handleBuyNow}
        />

        <CartDrawer
          isOpen={isCartOpen}
          onClose={() => setIsCartOpen(false)}
          onProceedToCheckout={() => setIsCheckoutOpen(true)}
        />

        <CheckoutModal
          isOpen={isCheckoutOpen}
          onClose={() => setIsCheckoutOpen(false)}
          onOrderSuccess={handleOrderSuccess}
          onOpenAuth={() => {
            setIsCheckoutOpen(false);
            setIsAuthModalOpen(true);
          }}
        />

        <OrderTrackingModal
          order={trackedOrder}
          onClose={() => setTrackedOrder(null)}
        />

        <WishlistModal
          isOpen={isWishlistOpen}
          onClose={() => setIsWishlistOpen(false)}
          onSelectProduct={(prod) => setSelectedProduct(prod)}
        />

        <SupabaseConnectModal
          isOpen={isSupabaseModalOpen}
          onClose={() => setIsSupabaseModalOpen(false)}
        />

        <AuthModal
          isOpen={isAuthModalOpen}
          onClose={() => setIsAuthModalOpen(false)}
        />
      </div>
    </div>
  );
}
