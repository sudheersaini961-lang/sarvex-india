import React, { useEffect, useState } from 'react';
import {
  ShieldCheck,
  Users,
  Store,
  Package,
  CheckCircle2,
  XCircle,
  Clock,
  Database,
  Filter,
  Eye,
  RefreshCw
} from 'lucide-react';
import { useMarketplace } from '../lib/marketplaceStore';
import { OrderStatus, Order } from '../types/marketplace';
import { getStoredSupabaseConfig, getSupabase } from '../lib/supabaseClient';
import { DatabaseSettingsCard } from './DatabaseSettingsCard';

interface AdminDashboardProps {
  onOpenSupabaseModal: () => void;
  onViewOrder: (order: Order) => void;
}

export const AdminDashboard: React.FC<AdminDashboardProps> = ({
  onOpenSupabaseModal,
  onViewOrder,
}) => {
  const {
    sellers,
    orders,
    products,
    stats,
    approveSeller,
    rejectSeller,
    updateOrderStatus,
    currentUser,
  } = useMarketplace();

  const [orderFilter, setOrderFilter] = useState<OrderStatus | 'all'>('all');
  const [actionError, setActionError] = useState('');
  const [supplierQueue, setSupplierQueue] = useState<any>({ suppliers: [], offers: [], listings: [] });
  const [supplierQueueError, setSupplierQueueError] = useState('');
  const [supplierQueueLoading, setSupplierQueueLoading] = useState(false);
  const runAdminAction = async (action: () => Promise<void>) => {
    setActionError('');
    try {
      await action();
    } catch (error) {
      setActionError(error instanceof Error ? error.message : 'Admin action could not be completed.');
    }
  };
  const refreshSupplierQueue = async () => {
    const supabase = getSupabase();
    if (!supabase) {
      setSupplierQueueError('Supabase database configure nahi hai.');
      return;
    }
    setSupplierQueueLoading(true);
    const { data, error } = await supabase.rpc('admin_list_supplier_review_queue');
    if (error) setSupplierQueueError(error.message);
    else {
      setSupplierQueue(data || { suppliers: [], offers: [], listings: [] });
      setSupplierQueueError('');
    }
    setSupplierQueueLoading(false);
  };

  useEffect(() => {
    if (currentUser?.id) void refreshSupplierQueue();
  }, [currentUser?.id]);

  const reviewSupplierItem = async (rpcName: string, id: string, status: string) => {
    const supabase = getSupabase();
    if (!supabase) throw new Error('Supabase database configure nahi hai.');
    const idParam = rpcName === 'admin_review_supplier' ? 'p_supplier_id'
      : rpcName === 'admin_review_supplier_offer' ? 'p_offer_id' : 'p_listing_id';
    const { error } = await supabase.rpc(rpcName, { [idParam]: id, [rpcName === 'admin_review_supplier' ? 'p_approval_status' : rpcName === 'admin_review_supplier_offer' ? 'p_offer_status' : 'p_listing_status']: status });
    if (error) throw error;
    await refreshSupplierQueue();
  };

  const { isConfigured: isSupabaseConnected, url: supabaseUrl } = getStoredSupabaseConfig();

  const pendingSellers = sellers.filter((s) => s.status === 'pending');
  const approvedSellers = sellers.filter((s) => s.status === 'approved');

  const filteredOrders = orders.filter((o) =>
    orderFilter === 'all' ? true : o.status === orderFilter
  );

  return (
    <div className="pb-24 max-w-screen-md mx-auto p-3 space-y-4">
      {/* Header */}
      <div className="bg-[#1e3a8a] text-white p-4 rounded-2xl shadow-md">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <div className="p-2 bg-[#f97316] rounded-xl text-white">
              <ShieldCheck size={24} />
            </div>
            <div>
              <h1 className="text-base sm:text-lg font-black tracking-tight">
                SARVEX Central Admin
              </h1>
              <p className="text-xs text-blue-200">
                Marketplace Governance • Seller Verification • Orders Supervision
              </p>
            </div>
          </div>

          <button
            onClick={onOpenSupabaseModal}
            className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold border transition ${
              isSupabaseConnected
                ? 'bg-emerald-900/80 text-emerald-300 border-emerald-400/50'
                : 'bg-amber-900/80 text-amber-300 border-amber-400/50'
            }`}
          >
            <Database size={13} />
            <span>{isSupabaseConnected ? 'DB Configured (test needed)' : 'DB Not Configured'}</span>
          </button>
        </div>

        {/* 4 KPI Cards */}
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-2.5 mt-4">
          <div className="bg-blue-900/60 p-2.5 rounded-xl border border-blue-700/50">
            <span className="text-[10px] text-blue-200 uppercase font-bold block">Gross GMV</span>
            <p className="text-base font-black text-white">₹{stats.gmv.toLocaleString('en-IN')}</p>
            <span className="text-[9px] text-emerald-300 font-medium">Cash On Delivery</span>
          </div>

          <div className="bg-blue-900/60 p-2.5 rounded-xl border border-blue-700/50">
            <span className="text-[10px] text-blue-200 uppercase font-bold block">Total Orders</span>
            <p className="text-base font-black text-white">{stats.totalOrders}</p>
            <span className="text-[9px] text-blue-200 font-medium">Recorded in this account</span>
          </div>

          <div className="bg-blue-900/60 p-2.5 rounded-xl border border-blue-700/50">
            <span className="text-[10px] text-blue-200 uppercase font-bold block">Indian Sellers</span>
            <p className="text-base font-black text-white">{stats.totalSellers}</p>
            <span className="text-[9px] text-amber-300 font-medium">
              {pendingSellers.length} Pending Approval
            </span>
          </div>

          <div className="bg-blue-900/60 p-2.5 rounded-xl border border-blue-700/50">
            <span className="text-[10px] text-blue-200 uppercase font-bold block">Products Live</span>
            <p className="text-base font-black text-white">{stats.activeProducts}</p>
            <span className="text-[9px] text-emerald-300 font-medium">Current catalog</span>
          </div>
        </div>
      </div>

      {/* Embedded Database Settings for Administrator */}
      <DatabaseSettingsCard />

      {actionError && <div role="alert" className="rounded-lg border border-red-200 bg-red-50 p-3 text-xs font-semibold text-red-800">{actionError}</div>}

      {/* Seller Approval Queue */}
      <div className="bg-white rounded-xl border border-gray-200 p-4 space-y-3 shadow-xs">
        <div className="flex items-center justify-between">
          <h3 className="text-xs font-bold text-gray-900 uppercase tracking-wider flex items-center gap-1.5">
            <Clock size={15} className="text-[#f97316]" /> Seller Approval Queue ({pendingSellers.length})
          </h3>
          <span className="text-[11px] text-gray-500 font-medium">
            {approvedSellers.length} Approved Sellers
          </span>
        </div>

        {pendingSellers.length === 0 ? (
          <div className="p-4 bg-emerald-50 rounded-lg text-emerald-800 text-xs font-medium flex items-center gap-2">
            <CheckCircle2 size={16} className="text-emerald-600 shrink-0" />
            <span>All seller onboarding applications have been reviewed. No pending queues!</span>
          </div>
        ) : (
          <div className="space-y-2.5">
            {pendingSellers.map((seller) => (
              <div
                key={seller.id}
                className="p-3 bg-amber-50/60 border border-amber-200 rounded-xl space-y-2"
              >
                <div className="flex justify-between items-start">
                  <div>
                    <h4 className="font-bold text-xs text-gray-900">{seller.storeName}</h4>
                    <p className="text-[11px] text-gray-600">
                      Owner: {seller.ownerName} • Ph: +91 {seller.phone}
                    </p>
                    <p className="text-[10px] text-gray-500">
                      Location: {seller.city}, {seller.state} ({seller.pincode})
                    </p>
                    <p className="text-[10px] text-gray-500 font-mono">UPI: {seller.upiId}</p>
                  </div>
                  <span className="text-[10px] font-bold bg-amber-200 text-amber-900 px-2 py-0.5 rounded-full">
                    Needs Verification
                  </span>
                </div>

                <div className="flex gap-2 pt-1">
                  <button
                    onClick={() => void runAdminAction(() => approveSeller(seller.id))}
                    className="flex-1 py-1.5 bg-emerald-600 hover:bg-emerald-700 text-white font-bold text-xs rounded-lg shadow-xs tap-effect flex items-center justify-center gap-1"
                  >
                    <CheckCircle2 size={14} /> Approve Store
                  </button>
                  <button
                    onClick={() => void runAdminAction(() => rejectSeller(seller.id))}
                    className="py-1.5 px-3 bg-red-100 hover:bg-red-200 text-red-700 font-bold text-xs rounded-lg tap-effect flex items-center justify-center gap-1"
                  >
                    <XCircle size={14} /> Reject
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>


      {/* Supplier, wholesale offer and reseller listing review */}
      <div className="rounded-xl border border-gray-200 bg-white p-4 space-y-3">
        <div className="flex items-center justify-between gap-2">
          <h3 className="text-xs font-bold uppercase tracking-wider text-gray-900">Supplier & Dropship Review Queue</h3>
          <button onClick={() => void refreshSupplierQueue()} className="flex items-center gap-1 text-[11px] font-bold text-[#1e3a8a]"><RefreshCw size={13}/> Refresh</button>
        </div>
        {supplierQueueError && <p role="alert" className="rounded-lg border border-red-200 bg-red-50 p-2 text-xs text-red-800">{supplierQueueError}</p>}
        {supplierQueueLoading && <p className="text-xs text-gray-500">Review queue loading…</p>}
        {!supplierQueueLoading && !supplierQueueError && (
          <>
            <div className="space-y-2">
              <p className="text-xs font-bold">Supplier applications ({supplierQueue.suppliers?.length || 0})</p>
              {(supplierQueue.suppliers || []).map((item:any) => <div key={item.id} className="rounded-lg border border-amber-200 bg-amber-50 p-3 space-y-1">
                <p className="text-xs font-bold">{item.business_name}</p>
                <p className="text-[11px] text-gray-700">{item.dispatch_contact_name} · {item.dispatch_phone}</p>
                <p className="text-[11px] text-gray-600">{item.dispatch_address}, {item.dispatch_city}, {item.dispatch_state} {item.dispatch_pincode}</p>
                <div className="flex gap-2 pt-1">
                  <button onClick={() => void runAdminAction(() => reviewSupplierItem('admin_review_supplier', item.id, 'approved'))} className="flex-1 rounded-lg bg-emerald-600 p-2 text-[11px] font-bold text-white">Approve Supplier</button>
                  <button onClick={() => void runAdminAction(() => reviewSupplierItem('admin_review_supplier', item.id, 'rejected'))} className="rounded-lg bg-red-100 px-3 text-[11px] font-bold text-red-700">Reject</button>
                </div>
              </div>)}
              {(!supplierQueue.suppliers || supplierQueue.suppliers.length===0) && <p className="text-[11px] text-gray-500">No pending supplier applications.</p>}
            </div>
            <div className="space-y-2 border-t pt-3">
              <p className="text-xs font-bold">Wholesale offers ({supplierQueue.offers?.length || 0})</p>
              {(supplierQueue.offers || []).map((item:any) => <div key={item.id} className="flex items-center justify-between gap-2 rounded-lg border p-2">
                <div className="min-w-0"><p className="text-xs font-semibold">{item.product_name}</p><p className="text-[11px] text-gray-500">Wholesale ₹{Number(item.wholesale_price_inr).toLocaleString('en-IN')} · MOQ {item.minimum_order_quantity}</p></div>
                <div className="flex gap-1"><button onClick={() => void runAdminAction(() => reviewSupplierItem('admin_review_supplier_offer', item.id, 'active'))} className="rounded bg-emerald-600 px-2 py-1 text-[10px] font-bold text-white">Approve</button><button onClick={() => void runAdminAction(() => reviewSupplierItem('admin_review_supplier_offer', item.id, 'rejected'))} className="rounded bg-red-100 px-2 py-1 text-[10px] font-bold text-red-700">Reject</button></div>
              </div>)}
              {(!supplierQueue.offers || supplierQueue.offers.length===0) && <p className="text-[11px] text-gray-500">No pending wholesale offers.</p>}
            </div>
            <div className="space-y-2 border-t pt-3">
              <p className="text-xs font-bold">Reseller listings ({supplierQueue.listings?.length || 0})</p>
              {(supplierQueue.listings || []).map((item:any) => <div key={item.id} className="flex items-center justify-between gap-2 rounded-lg border p-2">
                <div className="min-w-0"><p className="text-xs font-semibold">{item.public_title}</p><p className="text-[11px] text-gray-500">Retail ₹{Number(item.retail_price_inr).toLocaleString('en-IN')}</p></div>
                <div className="flex gap-1"><button onClick={() => void runAdminAction(() => reviewSupplierItem('admin_review_reseller_listing', item.id, 'active'))} className="rounded bg-emerald-600 px-2 py-1 text-[10px] font-bold text-white">Approve</button><button onClick={() => void runAdminAction(() => reviewSupplierItem('admin_review_reseller_listing', item.id, 'rejected'))} className="rounded bg-red-100 px-2 py-1 text-[10px] font-bold text-red-700">Reject</button></div>
              </div>)}
              {(!supplierQueue.listings || supplierQueue.listings.length===0) && <p className="text-[11px] text-gray-500">No pending reseller listings.</p>}
            </div>
          </>
        )}
      </div>

      {/* All Orders Governance */}
      <div className="bg-white rounded-xl border border-gray-200 p-4 space-y-3 shadow-xs">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2">
          <h3 className="text-xs font-bold text-gray-900 uppercase tracking-wider flex items-center gap-1.5">
            <Package size={15} className="text-[#1e3a8a]" /> Central Order Management ({orders.length})
          </h3>

          {/* Filter Pills */}
          <div className="flex items-center gap-1 overflow-x-auto no-scrollbar pb-1 text-[11px]">
            {(['all', 'placed', 'confirmed', 'packed', 'shipped', 'out_for_delivery', 'delivered'] as const).map(
              (st) => (
                <button
                  key={st}
                  onClick={() => setOrderFilter(st)}
                  className={`px-2 py-0.5 rounded-md font-semibold whitespace-nowrap transition ${
                    orderFilter === st
                      ? 'bg-[#1e3a8a] text-white'
                      : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
                  }`}
                >
                  {st === 'all' ? 'All' : st.replace(/_/g, ' ')}
                </button>
              )
            )}
          </div>
        </div>

        {filteredOrders.length === 0 ? (
          <p className="text-xs text-gray-500 py-6 text-center">No orders matching filter.</p>
        ) : (
          <div className="divide-y divide-gray-100 space-y-2">
            {filteredOrders.map((ord) => (
              <div key={ord.id} className="pt-2.5 space-y-2">
                <div className="flex justify-between items-start text-xs">
                  <div>
                    <div className="flex items-center gap-2">
                      <span className="font-mono font-bold text-[#1e3a8a]">#{ord.id}</span>
                      <span className="text-[10px] font-bold px-1.5 py-0.2 rounded-full uppercase bg-blue-100 text-blue-800">
                        {ord.status.replace(/_/g, ' ')}
                      </span>
                    </div>
                    <p className="text-[11px] text-gray-700 mt-0.5">
                      <strong>{ord.customerName}</strong> ({ord.city}, {ord.pincode})
                    </p>
                  </div>
                  <div className="text-right">
                    <span className="font-black text-gray-900 block">
                      ₹{ord.totalAmount.toLocaleString('en-IN')}
                    </span>
                    <button
                      onClick={() => onViewOrder(ord)}
                      className="text-[11px] text-[#1e3a8a] hover:underline font-bold flex items-center gap-0.5 ml-auto"
                    >
                      <Eye size={12} /> Track Details
                    </button>
                  </div>
                </div>

                {/* Status modifier buttons */}
                <div className="flex items-center gap-1.5 overflow-x-auto no-scrollbar pb-1">
                  <span className="text-[10px] text-gray-400">Set:</span>
                  {(['placed', 'confirmed', 'packed', 'shipped', 'out_for_delivery', 'delivered'] as OrderStatus[]).map(
                    (statusOption) => (
                      <button
                        key={statusOption}
                        onClick={() => void runAdminAction(() => updateOrderStatus(ord.id, statusOption))}
                        className={`text-[10px] px-2 py-0.5 rounded border ${
                          ord.status === statusOption
                            ? 'bg-blue-600 text-white font-bold border-blue-600'
                            : 'bg-gray-50 text-gray-600 border-gray-200 hover:bg-gray-100'
                        }`}
                      >
                        {statusOption.replace(/_/g, ' ')}
                      </button>
                    )
                  )}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
};
