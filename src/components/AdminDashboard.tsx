import React, { useState } from 'react';
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
import { getStoredSupabaseConfig } from '../lib/supabaseClient';
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
  } = useMarketplace();

  const [orderFilter, setOrderFilter] = useState<OrderStatus | 'all'>('all');
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
            <span className="text-[9px] text-blue-200 font-medium">Recorded order totals only</span>
          </div>

          <div className="bg-blue-900/60 p-2.5 rounded-xl border border-blue-700/50">
            <span className="text-[10px] text-blue-200 uppercase font-bold block">Total Orders</span>
            <p className="text-base font-black text-white">{stats.totalOrders}</p>
            <span className="text-[9px] text-blue-200 font-medium">Across India</span>
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
            <span className="text-[9px] text-emerald-300 font-medium">In 6 Categories</span>
          </div>
        </div>
      </div>

      {/* Embedded Database Settings for Administrator */}
      <DatabaseSettingsCard />

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
            <span>No pending applications are currently visible to this admin account.</span>
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
                    onClick={() => approveSeller(seller.id)}
                    className="flex-1 py-1.5 bg-emerald-600 hover:bg-emerald-700 text-white font-bold text-xs rounded-lg shadow-xs tap-effect flex items-center justify-center gap-1"
                  >
                    <CheckCircle2 size={14} /> Approve Store
                  </button>
                  <button
                    onClick={() => rejectSeller(seller.id)}
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
                        onClick={() => updateOrderStatus(ord.id, statusOption)}
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
