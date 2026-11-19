import React, { useState } from 'react';
import {
  Store,
  Plus,
  Package,
  TrendingUp,
  ShieldCheck,
  CheckCircle,
  Clock,
  Trash2,
  Image as ImageIcon,
  IndianRupee,
  AlertCircle,
  Truck
} from 'lucide-react';
import { useMarketplace } from '../lib/marketplaceStore';

export const SellerPortal: React.FC = () => {
  const {
    sellers,
    products,
    orders,
    categories,
    currentUser,
    registerSeller,
    addProduct,
    deleteProduct,
    updateOrderStatus
  } = useMarketplace();

  // A seller can only see the shop owned by the authenticated Supabase user.
  const activeSeller = sellers.find((seller) => seller.userId === currentUser?.id) || null;

  // Forms state
  const [activeTab, setActiveTab] = useState<'catalog' | 'orders' | 'add_product' | 'register'>(
    activeSeller ? 'catalog' : 'register'
  );

  // New Seller Registration Form
  const [storeName, setStoreName] = useState('');
  const [ownerName, setOwnerName] = useState(currentUser?.fullName || '');
  const [sellerPhone, setSellerPhone] = useState(currentUser?.phone || '');
  const [sellerEmail, setSellerEmail] = useState(currentUser?.email || '');
  const [sellerCity, setSellerCity] = useState('');
  const [sellerState, setSellerState] = useState('Rajasthan');
  const [sellerPincode, setSellerPincode] = useState('');
  const [pickupAddress, setPickupAddress] = useState('');
  const [upiId, setUpiId] = useState('');
  const [regSuccess, setRegSuccess] = useState(false);

  // Add Product Form
  const [newTitle, setNewTitle] = useState('');
  const [newDesc, setNewDesc] = useState('');
  const [newCategory, setNewCategory] = useState(categories[0]?.slug || 'electronics');
  const [newPrice, setNewPrice] = useState<number | ''>('');
  const [newMrp, setNewMrp] = useState<number | ''>('');
  const [newStock, setNewStock] = useState<number | ''>(20);
  const [newImageUrl, setNewImageUrl] = useState('');
  const [productSuccessMsg, setProductSuccessMsg] = useState('');
  const [actionError, setActionError] = useState('');

  // Seller metrics
  const sellerProducts = products.filter((p) => p.sellerId === activeSeller?.id);
  const sellerOrders = orders.filter((o) =>
    o.items.some((item) => item.sellerId === activeSeller?.id)
  );

  const sellerRevenue = sellerOrders.reduce((acc, order) => {
    const sellerItems = order.items.filter((item) => item.sellerId === activeSeller?.id);
    return acc + sellerItems.reduce((s, i) => s + i.price * i.quantity, 0);
  }, 0);

  const handleRegisterSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setActionError('');
    if (!currentUser) {
      setActionError('Seller application ke liye pehle account se sign in karein.');
      return;
    }
    if (!storeName.trim() || !ownerName.trim() || !sellerPhone.trim() || !sellerEmail.trim() || !sellerCity.trim() || !sellerState.trim() || !sellerPincode.trim() || !pickupAddress.trim()) {
      setActionError('Shop, owner, phone, email, city, state, PIN code aur pickup address sab bharna zaroori hai.');
      return;
    }
    try {
      await registerSeller({
        userId: currentUser.id,
        storeName: storeName.trim(),
        ownerName: ownerName.trim(),
        phone: sellerPhone.trim(),
        email: sellerEmail.trim(),
        city: sellerCity.trim(),
        state: sellerState.trim(),
        pincode: sellerPincode.trim(),
        pickupAddress: pickupAddress.trim(),
        upiId: upiId.trim() || undefined
      });
      setRegSuccess(true);
      setActiveTab('catalog');
    } catch (error: any) {
      setActionError(error?.message || 'Seller application save nahi hui.');
    }
  };

  const handleAddProductSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setActionError('');
    if (!activeSeller || activeSeller.status !== 'approved') {
      setActionError('Product list karne ke liye aapki shop ka admin-approved hona zaroori hai.');
      return;
    }
    if (!newTitle.trim() || !newPrice || !newMrp || !newImageUrl.trim()) {
      setActionError('Product title, price, MRP aur image URL zaroori hain.');
      return;
    }
    try {
      await addProduct({
        sellerId: activeSeller.id,
        sellerName: activeSeller.storeName,
        title: newTitle.trim(),
        description: newDesc.trim(),
        category: newCategory,
        price: Number(newPrice),
        mrp: Number(newMrp),
        stock: Number(newStock) || 0,
        imageUrl: newImageUrl.trim(),
        isCodAvailable: false,
        isFeatured: false
      });
      setProductSuccessMsg(`"${newTitle}" database mein save ho gaya.`);
      setTimeout(() => setProductSuccessMsg(''), 3000);
      setNewTitle('');
      setNewDesc('');
      setNewPrice('');
      setNewMrp('');
      setNewImageUrl('');
      setActiveTab('catalog');
    } catch (error: any) {
      setActionError(error?.message || 'Product save nahi hua.');
    }
  };

  return (
    <div className="pb-20 max-w-screen-md mx-auto">
      {/* Top Banner */}
      <div className="bg-[#1e3a8a] text-white p-4">
        <div className="flex items-center justify-between mb-3">
          <div className="flex items-center gap-2">
            <div className="p-2 bg-[#f97316] rounded-xl text-white">
              <Store size={22} />
            </div>
            <div>
              <h1 className="text-base sm:text-lg font-black tracking-tight">
                SARVEX Seller Hub
              </h1>
              <p className="text-xs text-blue-200">
                Seller account • Admin-reviewed listings
              </p>
            </div>
          </div>


        </div>

        {/* Vendor Status Banner */}
        {activeSeller && (
          <div className="flex items-center justify-between bg-blue-900/60 rounded-xl px-3 py-2 text-xs border border-blue-700/50">
            <div className="flex items-center gap-2">
              <span className="text-gray-300">Store Status:</span>
              {activeSeller.status === 'approved' ? (
                <span className="flex items-center gap-1 text-emerald-300 font-bold bg-emerald-950/80 px-2 py-0.5 rounded-full border border-emerald-500/40">
                  <CheckCircle size={12} /> Approved & Active
                </span>
              ) : activeSeller.status === 'pending' ? (
                <span className="flex items-center gap-1 text-amber-300 font-bold bg-amber-950/80 px-2 py-0.5 rounded-full border border-amber-500/40">
                  <Clock size={12} /> Pending Admin Approval
                </span>
              ) : (
                <span className="text-red-300 font-bold">Rejected</span>
              )}
            </div>

            {activeSeller.status === 'pending' && (
              <span className="text-[11px] text-amber-200 italic font-medium">
                Under Central Review
              </span>
            )}
          </div>
        )}
      </div>

      {/* Tabs */}
      <div className="flex border-b border-gray-200 bg-white sticky top-[95px] z-20">
        {activeSeller && <button
          onClick={() => setActiveTab('catalog')}
          className={`flex-1 py-2.5 text-xs font-bold text-center border-b-2 transition ${
            activeTab === 'catalog'
              ? 'border-[#1e3a8a] text-[#1e3a8a] bg-blue-50/40'
              : 'border-transparent text-gray-500 hover:text-gray-900'
          }`}
        >
          My Products ({sellerProducts.length})
        </button>}
        {activeSeller && activeSeller.status === 'approved' && <button
          onClick={() => setActiveTab('add_product')}
          className={`flex-1 py-2.5 text-xs font-bold text-center border-b-2 transition flex items-center justify-center gap-1 ${
            activeTab === 'add_product'
              ? 'border-[#f97316] text-[#f97316] bg-orange-50/40'
              : 'border-transparent text-gray-500 hover:text-gray-900'
          }`}
        >
          <Plus size={14} /> Add Product
        </button>}
        {activeSeller && <button
          onClick={() => setActiveTab('orders')}
          className={`flex-1 py-2.5 text-xs font-bold text-center border-b-2 transition ${
            activeTab === 'orders'
              ? 'border-[#1e3a8a] text-[#1e3a8a] bg-blue-50/40'
              : 'border-transparent text-gray-500 hover:text-gray-900'
          }`}
        >
          Fulfillment ({sellerOrders.length})
        </button>}
        {!activeSeller && <button
          onClick={() => setActiveTab('register')}
          className={`flex-1 py-2.5 text-xs font-bold text-center border-b-2 transition ${
            activeTab === 'register'
              ? 'border-[#1e3a8a] text-[#1e3a8a] bg-blue-50/40'
              : 'border-transparent text-gray-500 hover:text-gray-900'
          }`}
        >
          Register New
        </button>}
      </div>

      {/* Main Body per tab */}
      <div className="p-3">
        {!currentUser && <div className="mb-3 p-4 bg-amber-50 border border-amber-200 rounded-xl text-sm text-amber-900">Seller Portal use karne ke liye pehle Supabase se sign in karein.</div>}

        {activeSeller && activeSeller.status !== 'approved' && <div className="mb-3 p-4 bg-amber-50 border border-amber-200 rounded-xl text-sm text-amber-900">Aapki shop abhi {activeSeller.status} hai. Admin approval se pehle product listing aur fulfillment band hain.</div>}
        {actionError && (
          <div className="mb-3 p-3 bg-red-50 border border-red-200 text-red-800 text-xs rounded-xl font-bold" role="alert">{actionError}</div>
        )}
        {productSuccessMsg && (
          <div className="mb-3 p-3 bg-emerald-50 border border-emerald-200 text-emerald-800 text-xs rounded-xl font-bold flex items-center gap-2">
            <CheckCircle size={16} /> {productSuccessMsg}
          </div>
        )}

        {/* Tab 1: Product Catalog */}
        {activeTab === 'catalog' && activeSeller && (
          <div className="space-y-3">
            {/* Quick Metrics */}
            <div className="grid grid-cols-3 gap-2">
              <div className="bg-white p-3 rounded-xl border border-gray-200 shadow-xs">
                <span className="text-[10px] text-gray-500 uppercase font-bold block">Gross Sales</span>
                <p className="text-base font-black text-[#1e3a8a]">
                  ₹{sellerRevenue.toLocaleString('en-IN')}
                </p>
                <span className="text-[9px] text-gray-500 font-bold">Based on recorded orders</span>
              </div>
              <div className="bg-white p-3 rounded-xl border border-gray-200 shadow-xs">
                <span className="text-[10px] text-gray-500 uppercase font-bold block">Live Products</span>
                <p className="text-base font-black text-gray-900">{sellerProducts.length}</p>
                <span className="text-[9px] text-blue-600 font-bold">Active in Catalog</span>
              </div>
              <div className="bg-white p-3 rounded-xl border border-gray-200 shadow-xs">
                <span className="text-[10px] text-gray-500 uppercase font-bold block">Commission</span>
                <p className="text-base font-black text-gray-700">—</p>
                <span className="text-[9px] text-gray-500 font-bold">Not configured</span>
              </div>
            </div>

            {/* List */}
            <div className="flex items-center justify-between pt-1">
              <h3 className="text-xs font-bold text-gray-800 uppercase tracking-wider">
                Store Inventory for {activeSeller.storeName}
              </h3>
              <button
                disabled={activeSeller.status !== 'approved'}
                onClick={() => setActiveTab('add_product')}
                className="text-xs font-bold text-[#f97316] flex items-center gap-1 hover:underline"
              >
                <Plus size={13} /> Add New Item
              </button>
            </div>

            {sellerProducts.length === 0 ? (
              <div className="text-center py-10 bg-white rounded-xl border border-gray-200 p-4">
                <Package size={32} className="mx-auto text-gray-400 mb-2" />
                <h4 className="font-bold text-gray-800 text-sm">No products listed yet</h4>
                <p className="text-xs text-gray-500 mb-3">Add your first product to start receiving orders.</p>
                <button
                  onClick={() => setActiveTab('add_product')}
                  className="px-4 py-2 bg-[#f97316] text-white text-xs font-bold rounded-lg shadow"
                >
                  List a Product
                </button>
              </div>
            ) : (
              <div className="space-y-2">
                {sellerProducts.map((prod) => (
                  <div
                    key={prod.id}
                    className="bg-white p-3 rounded-xl border border-gray-200 flex items-center justify-between gap-3 shadow-xs"
                  >
                    <img
                      src={prod.imageUrl}
                      alt={prod.title}
                      className="w-14 h-14 rounded-lg object-cover bg-gray-50 shrink-0"
                    />
                    <div className="flex-1 min-w-0">
                      <h4 className="text-xs font-bold text-gray-900 truncate">{prod.title}</h4>
                      <p className="text-[10px] text-gray-500 capitalize">{prod.category}</p>
                      <div className="flex items-center gap-2 mt-1">
                        <span className="text-xs font-extrabold text-[#1e3a8a]">
                          ₹{prod.price.toLocaleString('en-IN')}
                        </span>
                        <span className="text-[10px] text-gray-400 line-through">
                          ₹{prod.mrp.toLocaleString('en-IN')}
                        </span>
                        <span className="text-[10px] font-bold text-emerald-700 bg-emerald-50 px-1.5 py-0.2 rounded">
                          Stock: {prod.stock}
                        </span>
                      </div>
                    </div>
                    <button
                      onClick={() => deleteProduct(prod.id)}
                      className="text-gray-400 hover:text-red-600 p-1.5 rounded-lg hover:bg-gray-50 transition"
                      title="Delete Product"
                    >
                      <Trash2 size={16} />
                    </button>
                  </div>
                ))}
              </div>
            )}
          </div>
        )}

        {/* Tab 2: Add Product */}
        {activeTab === 'add_product' && activeSeller && activeSeller.status === 'approved' && (
          <form
            onSubmit={handleAddProductSubmit}
            className="bg-white rounded-xl border border-gray-200 p-4 space-y-3.5 shadow-sm"
          >
            <div className="flex justify-between items-center border-b border-gray-100 pb-2">
              <h3 className="text-sm font-bold text-gray-900 flex items-center gap-1.5">
                <Plus size={16} className="text-[#f97316]" /> Add Product to SARVEX India
              </h3>
              <span className="text-[10px] font-bold text-emerald-700 bg-emerald-50 px-2 py-0.5 rounded">
                Database listing
              </span>
            </div>

            <div>
              <label className="text-[11px] font-bold text-gray-700 block mb-1">
                Product Title *
              </label>
              <input
                type="text"
                required
                value={newTitle}
                onChange={(e) => setNewTitle(e.target.value)}
                placeholder="e.g. Handcrafted Kashmiri Pure Pashmina Shawl"
                className="w-full text-xs px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-[#1e3a8a] focus:outline-none"
              />
            </div>

            <div className="grid grid-cols-2 gap-2">
              <div>
                <label className="text-[11px] font-bold text-gray-700 block mb-1">
                  Category *
                </label>
                <select
                  value={newCategory}
                  onChange={(e) => setNewCategory(e.target.value)}
                  className="w-full text-xs px-2.5 py-2 border border-gray-300 rounded-lg bg-white focus:ring-2 focus:ring-[#1e3a8a] focus:outline-none capitalize"
                >
                  {categories.map((c) => (
                    <option key={c.id} value={c.slug}>
                      {c.name}
                    </option>
                  ))}
                </select>
              </div>

            </div>

            <div className="grid grid-cols-3 gap-2">
              <div>
                <label className="text-[11px] font-bold text-gray-700 block mb-1">
                  Price (₹) *
                </label>
                <input
                  type="number"
                  required
                  min={1}
                  value={newPrice}
                  onChange={(e) => setNewPrice(e.target.value ? Number(e.target.value) : '')}
                  placeholder="Selling Price"
                  className="w-full text-xs px-2.5 py-2 border border-gray-300 rounded-lg font-mono focus:ring-2 focus:ring-[#1e3a8a] focus:outline-none"
                />
              </div>

              <div>
                <label className="text-[11px] font-bold text-gray-700 block mb-1">
                  MRP (₹) *
                </label>
                <input
                  type="number"
                  required
                  min={1}
                  value={newMrp}
                  onChange={(e) => setNewMrp(e.target.value ? Number(e.target.value) : '')}
                  placeholder="Original MRP"
                  className="w-full text-xs px-2.5 py-2 border border-gray-300 rounded-lg font-mono focus:ring-2 focus:ring-[#1e3a8a] focus:outline-none"
                />
              </div>

              <div>
                <label className="text-[11px] font-bold text-gray-700 block mb-1">
                  Stock Qty *
                </label>
                <input
                  type="number"
                  required
                  min={1}
                  value={newStock}
                  onChange={(e) => setNewStock(e.target.value ? Number(e.target.value) : '')}
                  placeholder="Qty"
                  className="w-full text-xs px-2.5 py-2 border border-gray-300 rounded-lg font-mono focus:ring-2 focus:ring-[#1e3a8a] focus:outline-none"
                />
              </div>
            </div>

            <div>
              <label className="text-[11px] font-bold text-gray-700 block mb-1">
                Image URL *
              </label>
              <input
                type="url"
                required
                value={newImageUrl}
                onChange={(e) => setNewImageUrl(e.target.value)}
                placeholder="https://images.unsplash.com/..."
                className="w-full text-xs px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-[#1e3a8a] focus:outline-none"
              />

            </div>

            <div>
              <label className="text-[11px] font-bold text-gray-700 block mb-1">
                Product Description
              </label>
              <textarea
                rows={2}
                value={newDesc}
                onChange={(e) => setNewDesc(e.target.value)}
                placeholder="Key features, dimensions, fabric care or technical specs..."
                className="w-full text-xs px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-[#1e3a8a] focus:outline-none"
              />
            </div>

            <button
              type="submit"
              className="w-full py-3 bg-[#1e3a8a] hover:bg-blue-800 text-white font-bold text-xs rounded-xl shadow transition tap-effect"
            >
              Publish Product to Marketplace
            </button>
          </form>
        )}

        {/* Tab 3: Order Fulfillment */}
        {activeTab === 'orders' && activeSeller && (
          <div className="space-y-3">
            <h3 className="text-xs font-bold text-gray-800 uppercase tracking-wider">
              Customer Orders Containing Your Items ({sellerOrders.length})
            </h3>

            {sellerOrders.length === 0 ? (
              <div className="text-center py-10 bg-white rounded-xl border border-gray-200 p-4">
                <Truck size={32} className="mx-auto text-gray-400 mb-2" />
                <h4 className="font-bold text-gray-800 text-sm">No pending orders</h4>
                <p className="text-xs text-gray-500">Order fulfilment will appear here after secure checkout and delivery workflows are activated.</p>
              </div>
            ) : (
              <div className="space-y-3">
                {sellerOrders.map((order) => {
                  const itemsForThisSeller = order.items.filter(
                    (i) => i.sellerId === activeSeller.id
                  );
                  return (
                    <div
                      key={order.id}
                      className="bg-white rounded-xl border border-gray-200 p-3.5 space-y-2 shadow-xs"
                    >
                      <div className="flex justify-between items-start">
                        <div>
                          <div className="flex items-center gap-2">
                            <span className="font-mono font-bold text-xs text-[#1e3a8a]">
                              #{order.id}
                            </span>
                            <span className="text-[10px] font-bold px-2 py-0.5 rounded-full capitalize bg-blue-50 text-blue-800">
                              {order.status.replace(/_/g, ' ')}
                            </span>
                          </div>
                          <p className="text-[10px] text-gray-500 mt-0.5">
                            Customer: {order.customerName} ({order.city})
                          </p>
                        </div>
                        <span className="text-xs font-black text-gray-900">
                          ₹{itemsForThisSeller.reduce((s, i) => s + i.price * i.quantity, 0).toLocaleString('en-IN')}
                        </span>
                      </div>

                      {/* Items */}
                      <div className="border-t border-gray-100 pt-2 space-y-1">
                        {itemsForThisSeller.map((it) => (
                          <div key={it.id} className="text-xs text-gray-700 flex justify-between">
                            <span className="truncate max-w-[220px]">
                              {it.quantity}x {it.title}
                            </span>
                            <span className="font-semibold">₹{(it.price * it.quantity).toLocaleString('en-IN')}</span>
                          </div>
                        ))}
                      </div>

                      {/* Fulfillment update actions */}
                      <div className="flex items-center justify-between pt-2 border-t border-gray-100">
                        <span className="text-[10px] text-gray-500">Update Package:</span>
                        <div className="flex gap-1.5">
                          {order.status === 'placed' && (
                            <button
                              onClick={() => updateOrderStatus(order.id, 'confirmed')}
                              className="px-2.5 py-1 bg-blue-100 text-[#1e3a8a] text-[11px] font-bold rounded hover:bg-blue-200"
                            >
                              Confirm Item
                            </button>
                          )}
                          {order.status === 'confirmed' && (
                            <button
                              onClick={() => updateOrderStatus(order.id, 'shipped')}
                              className="px-2.5 py-1 bg-[#1e3a8a] text-white text-[11px] font-bold rounded hover:bg-blue-800"
                            >
                              Hand to Courier (Ship)
                            </button>
                          )}
                          {order.status === 'shipped' && (
                            <span className="text-[11px] text-emerald-700 font-bold">
                              In Logistics Transit ✓
                            </span>
                          )}
                        </div>
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
          </div>
        )}

        {/* Tab 4: Register as Seller */}
        {activeTab === 'register' && !activeSeller && currentUser && (
          <form
            onSubmit={handleRegisterSubmit}
            className="bg-white rounded-xl border border-gray-200 p-4 space-y-3.5 shadow-sm"
          >
            <div className="border-b border-gray-100 pb-2">
              <h3 className="text-sm font-bold text-gray-900 flex items-center gap-1.5">
                <Store size={16} className="text-[#f97316]" /> Register New Seller Store
              </h3>
              <p className="text-xs text-gray-500 mt-0.5">
                Submit your shop details for admin review. Apply using your signed-in account. Product listing stays disabled until approval. SARVEX controls assurance badges.
              </p>
            </div>

            <div>
              <label className="text-[11px] font-bold text-gray-700 block mb-1">
                Store Name *
              </label>
              <input
                type="text"
                required
                value={storeName}
                onChange={(e) => setStoreName(e.target.value)}
                placeholder="e.g. Royal Handlooms Varanasi"
                className="w-full text-xs px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-[#1e3a8a] focus:outline-none"
              />
            </div>

            <div>
              <label className="text-[11px] font-bold text-gray-700 block mb-1">
                Owner / Authorized Person Name *
              </label>
              <input
                type="text"
                required
                value={ownerName}
                onChange={(e) => setOwnerName(e.target.value)}
                placeholder="Owner full name"
                className="w-full text-xs px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-[#1e3a8a] focus:outline-none"
              />
            </div>

            <div>
              <label className="text-[11px] font-bold text-gray-700 block mb-1">Account Email *</label>
              <input
                type="email"
                required
                value={sellerEmail}
                onChange={(e) => setSellerEmail(e.target.value)}
                placeholder="you@example.com"
                className="w-full text-xs px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-[#1e3a8a] focus:outline-none"
              />
            </div>

            <div className="grid grid-cols-2 gap-2">
              <div>
                <label className="text-[11px] font-bold text-gray-700 block mb-1">
                  Contact Phone *
                </label>
                <input
                  type="tel"
                  required
                  maxLength={10}
                  pattern="[0-9]{10}"
                  value={sellerPhone}
                  onChange={(e) => setSellerPhone(e.target.value.replace(/\D/g, ''))}
                  placeholder="10-digit mobile number"
                  className="w-full text-xs px-3 py-2 border border-gray-300 rounded-lg font-mono focus:ring-2 focus:ring-[#1e3a8a] focus:outline-none"
                />
              </div>

              <div>
                <label className="text-[11px] font-bold text-gray-700 block mb-1">
                  UPI ID (optional; payouts not configured)
                </label>
                <input
                  type="text"
                  value={upiId}
                  onChange={(e) => setUpiId(e.target.value)}
                  placeholder="storename@okhdfc"
                  className="w-full text-xs px-3 py-2 border border-gray-300 rounded-lg font-mono focus:ring-2 focus:ring-[#1e3a8a] focus:outline-none"
                />
              </div>
            </div>

            <div className="grid grid-cols-3 gap-2">
              <div>
                <label className="text-[11px] font-bold text-gray-700 block mb-1">
                  City *
                </label>
                <input
                  type="text"
                  required
                  value={sellerCity}
                  onChange={(e) => setSellerCity(e.target.value)}
                  placeholder="Jaipur"
                  className="w-full text-xs px-2.5 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-[#1e3a8a] focus:outline-none"
                />
              </div>

              <div>
                <label className="text-[11px] font-bold text-gray-700 block mb-1">
                  State *
                </label>
                <input
                  type="text"
                  required
                  value={sellerState}
                  onChange={(e) => setSellerState(e.target.value)}
                  placeholder="Rajasthan"
                  className="w-full text-xs px-2.5 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-[#1e3a8a] focus:outline-none"
                />
              </div>

              <div>
                <label className="text-[11px] font-bold text-gray-700 block mb-1">
                  Pincode *
                </label>
                <input
                  type="text"
                  maxLength={6}
                  required
                  pattern="[0-9]{6}"
                  value={sellerPincode}
                  onChange={(e) => setSellerPincode(e.target.value.replace(/\D/g, ''))}
                  placeholder="302001"
                  className="w-full text-xs px-2.5 py-2 border border-gray-300 rounded-lg font-mono focus:ring-2 focus:ring-[#1e3a8a] focus:outline-none"
                />
              </div>
            </div>

            <div>
              <label className="text-[11px] font-bold text-gray-700 block mb-1">
                Warehouse / Pickup Address *
              </label>
              <textarea
                required
                rows={2}
                value={pickupAddress}
                onChange={(e) => setPickupAddress(e.target.value)}
                placeholder="Where SARVEX courier will pick packages for customer delivery"
                className="w-full text-xs px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-[#1e3a8a] focus:outline-none"
              />
            </div>

            <button
              type="submit"
              className="w-full py-3 bg-[#f97316] hover:bg-orange-600 text-white font-extrabold text-xs rounded-xl shadow-md transition tap-effect"
            >
              Submit Seller Application
            </button>
          </form>
        )}
      </div>
    </div>
  );
};
