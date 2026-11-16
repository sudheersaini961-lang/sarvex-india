import React, { useEffect, useState } from 'react';
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
import { getSupabase } from '../lib/supabaseClient';

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
  const [activeTab, setActiveTab] = useState<'catalog' | 'orders' | 'add_product' | 'register' | 'supplier'>(
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
  const [supplierWorkspace, setSupplierWorkspace] = useState<any>(null);
  const [supplierOffers, setSupplierOffers] = useState<any[]>([]);
  const [supplierFulfilments, setSupplierFulfilments] = useState<any[]>([]);
  const [fulfilmentCourierById, setFulfilmentCourierById] = useState<Record<string, string>>({});
  const [fulfilmentTrackingById, setFulfilmentTrackingById] = useState<Record<string, string>>({});
  const [supplierLoading, setSupplierLoading] = useState(false);
  const [supplierError, setSupplierError] = useState('');
  const [supplierNotice, setSupplierNotice] = useState('');
  const [supplierBusinessName, setSupplierBusinessName] = useState('');
  const [dispatchContactName, setDispatchContactName] = useState(currentUser?.fullName || '');
  const [dispatchPhone, setDispatchPhone] = useState(currentUser?.phone || '');
  const [dispatchAddress, setDispatchAddress] = useState('');
  const [dispatchCity, setDispatchCity] = useState('');
  const [dispatchState, setDispatchState] = useState('');
  const [dispatchPincode, setDispatchPincode] = useState('');
  const [stockName, setStockName] = useState('');
  const [stockSku, setStockSku] = useState('');
  const [stockCategory, setStockCategory] = useState(categories[0]?.slug || 'electronics');
  const [stockDescription, setStockDescription] = useState('');
  const [stockImageUrl, setStockImageUrl] = useState('');
  const [stockQuantity, setStockQuantity] = useState(1);
  const [stockIdForOffer, setStockIdForOffer] = useState('');
  const [wholesalePrice, setWholesalePrice] = useState<number | ''>('');
  const [retailOfferId, setRetailOfferId] = useState('');
  const [retailPrice, setRetailPrice] = useState<number | ''>('');
  const [retailTitle, setRetailTitle] = useState('');

  useEffect(() => {
    if (activeTab !== 'supplier' || !currentUser) return;
    let alive = true;
    const loadWorkspace = async () => {
      setSupplierLoading(true);
      setSupplierError('');
      const supabase = getSupabase();
      if (!supabase) {
        if (alive) {
          setSupplierError('Supabase database configure nahi hai. Supplier workspace abhi available nahi hai.');
          setSupplierLoading(false);
        }
        return;
      }
      const [workspaceResult, offersResult, fulfilmentsResult] = await Promise.all([
        supabase.rpc('get_my_supplier_workspace'),
        supabase.rpc('browse_supplier_offers'),
        supabase.rpc('get_my_supplier_fulfilments')
      ]);
      if (!alive) return;
      if (workspaceResult.error) setSupplierError(workspaceResult.error.message);
      else setSupplierWorkspace(workspaceResult.data || null);
      if (offersResult.error) {
        // Browsing offers requires an approved seller shop; show the error only
        // when the user tries the reseller flow, not as a supplier application blocker.
        setSupplierOffers([]);
      } else {
        setSupplierOffers(Array.isArray(offersResult.data) ? offersResult.data : []);
      }
      if (fulfilmentsResult.error) setSupplierError((current) => current || fulfilmentsResult.error.message);
      else setSupplierFulfilments(Array.isArray(fulfilmentsResult.data) ? fulfilmentsResult.data : []);
      setSupplierLoading(false);
    };
    void loadWorkspace();
    return () => { alive = false; };
  }, [activeTab, currentUser?.id]);

  const callSupplierRpc = async (name: string, args: Record<string, unknown>) => {
    const supabase = getSupabase();
    if (!supabase) throw new Error('Supabase database configure nahi hai.');
    const { data, error } = await supabase.rpc(name, args);
    if (error) throw error;
    return data;
  };

  const refreshSupplierWorkspace = async () => {
    const supabase = getSupabase();
    if (!supabase) return;
    const [workspaceResult, offersResult, fulfilmentsResult] = await Promise.all([
      supabase.rpc('get_my_supplier_workspace'),
      supabase.rpc('browse_supplier_offers'),
      supabase.rpc('get_my_supplier_fulfilments')
    ]);
    if (workspaceResult.error) throw workspaceResult.error;
    if (fulfilmentsResult.error) throw fulfilmentsResult.error;
    setSupplierWorkspace(workspaceResult.data || null);
    setSupplierOffers(offersResult.error || !Array.isArray(offersResult.data) ? [] : offersResult.data);
    setSupplierFulfilments(Array.isArray(fulfilmentsResult.data) ? fulfilmentsResult.data : []);
  };

  const handleSupplierFulfilmentAction = async (
    allocationId: string,
    action: 'accept' | 'reject' | 'packed' | 'shipped'
  ) => {
    setSupplierError('');
    setSupplierNotice('');
    try {
      const result = await callSupplierRpc('supplier_update_fulfilment', {
        p_allocation_id: allocationId,
        p_action: action,
        p_courier_provider: action === 'shipped' ? (fulfilmentCourierById[allocationId] || '').trim() : null,
        p_tracking_reference: action === 'shipped' ? (fulfilmentTrackingById[allocationId] || '').trim() : null,
        p_event_note: null
      });
      const labels: Record<string, string> = {
        accept: 'Supplier ne order accept kar diya.',
        reject: 'Order reject hua; admin resolution abhi zaroori hai.',
        packed: 'Order packed mark hua.',
        shipped: 'Supplier ne dispatch details submit ki. Tracking courier se verify nahi hui hai.'
      };
      setSupplierNotice(labels[action]);
      await refreshSupplierWorkspace();
      if (action === 'shipped' && result?.tracking_reference) {
        setFulfilmentTrackingById((current) => ({ ...current, [allocationId]: result.tracking_reference }));
      }
    } catch (error) {
      setSupplierError(error instanceof Error ? error.message : 'Supplier fulfilment update nahi hua.');
    }
  };

  const handleSupplierApplication = async (e: React.FormEvent) => {
    e.preventDefault();
    setSupplierError('');
    setSupplierNotice('');
    try {
      await callSupplierRpc('supplier_apply', {
        p_business_name: supplierBusinessName.trim(),
        p_dispatch_contact_name: dispatchContactName.trim(),
        p_dispatch_phone: dispatchPhone.replace(/\D/g, ''),
        p_dispatch_address: dispatchAddress.trim(),
        p_dispatch_city: dispatchCity.trim(),
        p_dispatch_state: dispatchState.trim(),
        p_dispatch_pincode: dispatchPincode.replace(/\D/g, '')
      });
      setSupplierNotice('Supplier application admin review ke liye submit ho gayi hai.');
      await refreshSupplierWorkspace();
    } catch (error) {
      setSupplierError(error instanceof Error ? error.message : 'Supplier application submit nahi hui.');
    }
  };

  const handleSupplierStockSave = async (e: React.FormEvent) => {
    e.preventDefault();
    setSupplierError('');
    setSupplierNotice('');
    try {
      await callSupplierRpc('supplier_save_stock', {
        p_stock_id: null,
        p_supplier_sku: stockSku.trim() || null,
        p_product_name: stockName.trim(),
        p_description: stockDescription.trim() || null,
        p_category: stockCategory,
        p_image_url: stockImageUrl.trim() || null,
        p_available_quantity: stockQuantity,
        p_active: true
      });
      setSupplierNotice('Supplier stock private database mein save ho gaya.');
      setStockName(''); setStockSku(''); setStockDescription(''); setStockImageUrl('');
      setStockQuantity(1);
      await refreshSupplierWorkspace();
    } catch (error) {
      setSupplierError(error instanceof Error ? error.message : 'Supplier stock save nahi hua.');
    }
  };

  const handleSupplierOfferCreate = async (e: React.FormEvent) => {
    e.preventDefault();
    setSupplierError('');
    setSupplierNotice('');
    try {
      await callSupplierRpc('supplier_create_offer', {
        p_supplier_stock_id: stockIdForOffer,
        p_wholesale_price_inr: Number(wholesalePrice),
        p_minimum_order_quantity: 1,
        p_direct_to_customer_dispatch: true
      });
      setSupplierNotice('Wholesale offer admin approval ke liye submit ho gaya.');
      setWholesalePrice('');
      await refreshSupplierWorkspace();
    } catch (error) {
      setSupplierError(error instanceof Error ? error.message : 'Wholesale offer create nahi hua.');
    }
  };

  const handleResellerListingCreate = async (e: React.FormEvent) => {
    e.preventDefault();
    setSupplierError('');
    setSupplierNotice('');
    try {
      await callSupplierRpc('reseller_create_listing', {
        p_supplier_offer_id: retailOfferId,
        p_retail_price_inr: Number(retailPrice),
        p_public_title: retailTitle.trim(),
        p_public_description: null,
        p_public_image_url: null
      });
      setSupplierNotice('Reseller listing admin approval ke liye submit ho gayi.');
      setRetailPrice(''); setRetailTitle('');
      await refreshSupplierWorkspace();
    } catch (error) {
      setSupplierError(error instanceof Error ? error.message : 'Reseller listing submit nahi hui.');
    }
  };

  // Seller metrics
  const sellerProducts = products.filter((p) => p.sellerId === activeSeller?.id);
  const sellerOrders = orders.filter((o) =>
    o.items.some((item) => item.sellerId === activeSeller?.id)
  );

  const sellerRevenue = sellerOrders.reduce((acc, order) => {
    const sellerItems = order.items.filter((item) => item.sellerId === activeSeller?.id);
    return acc + sellerItems.reduce((s, i) => s + i.price * i.quantity, 0);
  }, 0);

  const handleOrderStatusUpdate = async (orderId: string, status: 'confirmed' | 'shipped') => {
    setActionError('');
    try {
      await updateOrderStatus(orderId, status);
    } catch (error) {
      setActionError(error instanceof Error ? error.message : 'Order status could not be updated.');
    }
  };

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
        isCodAvailable: true,
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
          onClick={() => setActiveTab('supplier')}
          className={`flex-1 py-2.5 text-xs font-bold text-center border-b-2 transition ${
            activeTab === 'supplier' ? 'border-[#f97316] text-[#f97316] bg-orange-50/40' : 'border-transparent text-gray-500 hover:text-gray-900'
          }`}
        >
          Supplier & Dropship
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
                <p className="text-base font-black text-gray-700">{activeSeller?.commissionRate ?? 0}%</p>
                <span className="text-[9px] text-gray-500 font-bold">Current platform rate</span>
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
              Orders containing your products ({sellerOrders.length})
            </h3>

            {sellerOrders.length === 0 ? (
              <div className="text-center py-10 bg-white rounded-xl border border-gray-200 p-4">
                <Truck size={32} className="mx-auto text-gray-400 mb-2" />
                <h4 className="font-bold text-gray-800 text-sm">No pending orders</h4>
                <p className="text-xs text-gray-500">Customer orders will appear here. Arrange delivery with your own courier service.</p>
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
                              onClick={() => void handleOrderStatusUpdate(order.id, 'confirmed')}
                              className="px-2.5 py-1 bg-blue-100 text-[#1e3a8a] text-[11px] font-bold rounded hover:bg-blue-200"
                            >
                              Confirm Item
                            </button>
                          )}
                          {order.status === 'confirmed' && (
                            <button
                              onClick={() => void handleOrderStatusUpdate(order.id, 'shipped')}
                              className="px-2.5 py-1 bg-[#1e3a8a] text-white text-[11px] font-bold rounded hover:bg-blue-800"
                            >
                              Mark as shipped
                            </button>
                          )}
                          {order.status === 'shipped' && (
                            <span className="text-[11px] text-emerald-700 font-bold">
                              Seller marked shipped (courier arranged by seller)
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


        {activeTab === 'supplier' && activeSeller && activeSeller.status === 'approved' && (
          <div className="space-y-4">
            <div className="rounded-xl border border-blue-100 bg-blue-50 p-3 text-xs text-blue-900">
              Supplier aur reseller tools abhi private review workflow hain. Public customer catalogue, dropship checkout, COD aur courier booking abhi enable nahi hain.
            </div>
            {supplierError && <div role="alert" className="rounded-lg border border-red-200 bg-red-50 p-3 text-xs text-red-800">{supplierError}</div>}
            {supplierNotice && <div role="status" className="rounded-lg border border-emerald-200 bg-emerald-50 p-3 text-xs text-emerald-800">{supplierNotice}</div>}
            {supplierLoading && <p className="text-xs text-gray-500">Supplier workspace load ho raha hai…</p>}
            {!supplierLoading && !supplierWorkspace?.supplier_profile && (
              <form onSubmit={handleSupplierApplication} className="rounded-xl border border-gray-200 bg-white p-4 space-y-3">
                <h3 className="text-sm font-bold text-gray-900">Apply as Supplier</h3>
                <p className="text-xs text-gray-500">Sirf approved SARVEX sellers supplier banne ke liye apply kar sakte hain. Dispatch details private rahengi.</p>
                <input required minLength={2} maxLength={120} value={supplierBusinessName} onChange={e=>setSupplierBusinessName(e.target.value)} placeholder="Business name" className="w-full rounded-lg border p-2 text-xs" />
                <input required minLength={2} maxLength={100} value={dispatchContactName} onChange={e=>setDispatchContactName(e.target.value)} placeholder="Dispatch contact name" className="w-full rounded-lg border p-2 text-xs" />
                <input required inputMode="numeric" maxLength={10} pattern="[6-9][0-9]{9}" value={dispatchPhone} onChange={e=>setDispatchPhone(e.target.value.replace(/\D/g,'').slice(0,10))} placeholder="10-digit Indian mobile" className="w-full rounded-lg border p-2 text-xs" />
                <textarea required minLength={8} maxLength={300} value={dispatchAddress} onChange={e=>setDispatchAddress(e.target.value)} placeholder="Supplier dispatch address" className="w-full rounded-lg border p-2 text-xs" />
                <div className="grid grid-cols-3 gap-2">
                  <input required minLength={2} value={dispatchCity} onChange={e=>setDispatchCity(e.target.value)} placeholder="City" className="min-w-0 rounded-lg border p-2 text-xs" />
                  <input required minLength={2} value={dispatchState} onChange={e=>setDispatchState(e.target.value)} placeholder="State" className="min-w-0 rounded-lg border p-2 text-xs" />
                  <input required inputMode="numeric" maxLength={6} pattern="[1-9][0-9]{5}" value={dispatchPincode} onChange={e=>setDispatchPincode(e.target.value.replace(/\D/g,'').slice(0,6))} placeholder="PIN" className="min-w-0 rounded-lg border p-2 text-xs" />
                </div>
                <button disabled={supplierLoading} className="w-full rounded-lg bg-[#1e3a8a] p-3 text-xs font-bold text-white">Submit Supplier Application</button>
              </form>
            )}
            {supplierWorkspace?.supplier_profile?.approval_status === 'approved' && (
              <section className="rounded-xl border border-gray-200 bg-white p-4 space-y-3">
                <div>
                  <h3 className="text-sm font-bold text-gray-900">Supplier Orders & Dispatch</h3>
                  <p className="mt-1 text-[11px] text-gray-500">Sirf aapke supplier account ko assigned orders yahan dikhenge. Courier/tracking supplier-entered hai; courier provider se verify nahi hota.</p>
                </div>
                {supplierFulfilments.length === 0 ? (
                  <p className="rounded-lg bg-gray-50 p-3 text-xs text-gray-500">Abhi koi supplier order allocation nahi hai. Dropship checkout aur order allocation abhi enable nahi hain.</p>
                ) : supplierFulfilments.map((item: any) => (
                  <article key={item.allocation_id} className="rounded-lg border border-gray-200 p-3 space-y-2">
                    <div className="flex items-start justify-between gap-2">
                      <div className="min-w-0">
                        <p className="text-xs font-bold text-gray-900">{item.product_name}</p>
                        <p className="text-[10px] text-gray-500">Order {item.order_code} · Qty {item.quantity}</p>
                      </div>
                      <span className="shrink-0 rounded-full bg-blue-50 px-2 py-1 text-[10px] font-semibold text-blue-800">{String(item.allocation_status).replace(/_/g, ' ')}</span>
                    </div>
                    <p className="text-[11px] text-gray-600">Delivery area: {item.city}, {item.state} · PIN {item.pincode}</p>
                    {item.shipping_address && (
                      <div className="rounded-md bg-gray-50 p-2 text-[11px] text-gray-700">
                        <p>{item.customer_name} · {item.customer_phone}</p>
                        <p>{item.shipping_address}</p>
                      </div>
                    )}
                    {item.allocation_status === 'awaiting_supplier' && (
                      <div className="flex gap-2">
                        <button type="button" onClick={() => void handleSupplierFulfilmentAction(item.allocation_id, 'accept')} className="flex-1 rounded-lg bg-[#1e3a8a] p-2 text-xs font-bold text-white">Accept Order</button>
                        <button type="button" onClick={() => void handleSupplierFulfilmentAction(item.allocation_id, 'reject')} className="rounded-lg border border-red-200 px-3 py-2 text-xs font-bold text-red-700">Reject</button>
                      </div>
                    )}
                    {item.allocation_status === 'accepted' && (
                      <button type="button" onClick={() => void handleSupplierFulfilmentAction(item.allocation_id, 'packed')} className="w-full rounded-lg bg-[#1e3a8a] p-2 text-xs font-bold text-white">Mark Packed</button>
                    )}
                    {['accepted', 'dispatch_pending'].includes(item.allocation_status) && (
                      <div className="space-y-2 rounded-md bg-gray-50 p-2">
                        <input value={fulfilmentCourierById[item.allocation_id] || ''} onChange={(e) => setFulfilmentCourierById((current) => ({ ...current, [item.allocation_id]: e.target.value }))} maxLength={80} placeholder="Courier name (supplier-entered)" className="w-full rounded-md border bg-white p-2 text-xs" />
                        <input value={fulfilmentTrackingById[item.allocation_id] || ''} onChange={(e) => setFulfilmentTrackingById((current) => ({ ...current, [item.allocation_id]: e.target.value }))} maxLength={120} placeholder="Tracking / AWB reference" className="w-full rounded-md border bg-white p-2 text-xs" />
                        <button type="button" onClick={() => void handleSupplierFulfilmentAction(item.allocation_id, 'shipped')} className="w-full rounded-lg bg-[#f97316] p-2 text-xs font-bold text-white">Mark Shipped</button>
                      </div>
                    )}
                    {item.latest_fulfilment_event?.tracking_reference && (
                      <p className="text-[10px] text-gray-500">Tracking: {item.latest_fulfilment_event.tracking_reference} · Supplier reported, not courier verified</p>
                    )}
                  </article>
                ))}
              </section>
            )}
            {supplierWorkspace?.supplier_profile && (
              <div className="rounded-xl border border-gray-200 bg-white p-3">
                <div className="flex items-center justify-between gap-2">
                  <div><h3 className="text-sm font-bold">Supplier Account</h3><p className="text-xs text-gray-500">{supplierWorkspace.supplier_profile.business_name}</p></div>
                  <span className="rounded-full bg-amber-50 px-2 py-1 text-[10px] font-bold text-amber-800">{supplierWorkspace.supplier_profile.approval_status}</span>
                </div>
                {supplierWorkspace.supplier_profile.approval_status !== 'approved' && <p className="mt-2 text-xs text-gray-600">Admin approval ke baad hi supplier stock aur offers add kar sakenge.</p>}
              </div>
            )}
            {supplierWorkspace?.supplier_profile?.approval_status === 'approved' && (
              <>
                <form onSubmit={handleSupplierStockSave} className="rounded-xl border border-gray-200 bg-white p-4 space-y-2">
                  <h3 className="text-sm font-bold">Add Supplier Stock</h3>
                  <input required minLength={2} maxLength={180} value={stockName} onChange={e=>setStockName(e.target.value)} placeholder="Product name" className="w-full rounded-lg border p-2 text-xs" />
                  <input maxLength={80} value={stockSku} onChange={e=>setStockSku(e.target.value)} placeholder="Supplier SKU (optional)" className="w-full rounded-lg border p-2 text-xs" />
                  <select value={stockCategory} onChange={e=>setStockCategory(e.target.value)} className="w-full rounded-lg border p-2 text-xs">{categories.map(cat=><option key={cat.id} value={cat.slug}>{cat.name}</option>)}</select>
                  <input type="number" min={0} max={1000000} required value={stockQuantity} onChange={e=>setStockQuantity(Number(e.target.value))} className="w-full rounded-lg border p-2 text-xs" aria-label="Available quantity" />
                  <input type="url" value={stockImageUrl} onChange={e=>setStockImageUrl(e.target.value)} placeholder="HTTPS image URL (authorized image only)" className="w-full rounded-lg border p-2 text-xs" />
                  <textarea maxLength={5000} value={stockDescription} onChange={e=>setStockDescription(e.target.value)} placeholder="Product description" className="w-full rounded-lg border p-2 text-xs" />
                  <button className="w-full rounded-lg bg-[#1e3a8a] p-3 text-xs font-bold text-white">Save Private Stock</button>
                </form>
                <form onSubmit={handleSupplierOfferCreate} className="rounded-xl border border-gray-200 bg-white p-4 space-y-2">
                  <h3 className="text-sm font-bold">Create Wholesale Offer</h3>
                  <select required value={stockIdForOffer} onChange={e=>setStockIdForOffer(e.target.value)} className="w-full rounded-lg border p-2 text-xs"><option value="">Select your stock item</option>{(supplierWorkspace.stock || []).filter((item:any)=>item.active).map((item:any)=><option key={item.id} value={item.id}>{item.product_name} · Qty {item.available_quantity}</option>)}</select>
                  <input type="number" required min={0.01} step="0.01" value={wholesalePrice} onChange={e=>setWholesalePrice(e.target.value ? Number(e.target.value) : '')} placeholder="Wholesale price ₹" className="w-full rounded-lg border p-2 text-xs" />
                  <button className="w-full rounded-lg bg-[#f97316] p-3 text-xs font-bold text-white">Submit Offer for Admin Review</button>
                </form>
              </>
            )}
            <div className="rounded-xl border border-gray-200 bg-white p-4 space-y-2">
              <h3 className="text-sm font-bold">Wholesale Offers from SARVEX Suppliers</h3>
              {supplierOffers.length === 0 ? <p className="text-xs text-gray-500">Abhi koi approved active supplier offer available nahi hai.</p> : supplierOffers.map((offer:any)=><div key={offer.offer_id} className="flex items-center justify-between border-b py-2 text-xs"><div className="min-w-0"><p className="font-semibold">{offer.product_name}</p><p className="text-gray-500">Stock {offer.available_quantity} · MOQ {offer.minimum_order_quantity}</p></div><p className="font-bold">₹{Number(offer.wholesale_price_inr).toLocaleString('en-IN')}</p></div>)}
            </div>
            <form onSubmit={handleResellerListingCreate} className="rounded-xl border border-gray-200 bg-white p-4 space-y-2">
              <h3 className="text-sm font-bold">Create Reseller Listing</h3>
              <select required value={retailOfferId} onChange={e=>setRetailOfferId(e.target.value)} className="w-full rounded-lg border p-2 text-xs"><option value="">Choose approved supplier offer</option>{supplierOffers.map((offer:any)=><option key={offer.offer_id} value={offer.offer_id}>{offer.product_name} · Wholesale ₹{offer.wholesale_price_inr}</option>)}</select>
              <input required minLength={2} maxLength={180} value={retailTitle} onChange={e=>setRetailTitle(e.target.value)} placeholder="Your public product title" className="w-full rounded-lg border p-2 text-xs" />
              <input type="number" required min={0.01} step="0.01" value={retailPrice} onChange={e=>setRetailPrice(e.target.value ? Number(e.target.value) : '')} placeholder="Your retail price ₹" className="w-full rounded-lg border p-2 text-xs" />
              <button disabled={supplierOffers.length===0} className="w-full rounded-lg bg-[#f97316] p-3 text-xs font-bold text-white">Submit Reseller Listing for Review</button>
            </form>
            <p className="text-[11px] text-gray-500">Wholesale prices are visible only to approved sellers. Listings remain private and pending until admin approval; customers cannot order them yet.</p>
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
                Seller Dispatch / Pickup Address *
              </label>
              <textarea
                required
                rows={2}
                value={pickupAddress}
                onChange={(e) => setPickupAddress(e.target.value)}
                placeholder="Address for your own courier pickup or parcel drop-off"
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
