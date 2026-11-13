import React from 'react';
import {
  X,
  Package,
  CheckCircle2,
  Clock,
  Truck,
  MapPin,
  Phone,
  ShieldCheck,
  ChevronRight,
  ExternalLink
} from 'lucide-react';
import { Order, OrderStatus } from '../types/marketplace';
import { useMarketplace } from '../lib/marketplaceStore';

interface OrderTrackingModalProps {
  order: Order | null;
  onClose: () => void;
}

const ORDER_STEPS: { status: OrderStatus; label: string; desc: string }[] = [
  {
    status: 'placed',
    label: 'Order Placed (COD)',
    desc: 'The order record was created in the marketplace database.'
  },
  {
    status: 'confirmed',
    label: 'Verified by Seller',
    desc: 'The seller marked the order as confirmed.'
  },
  {
    status: 'packed',
    label: 'Packed for Dispatch',
    desc: 'The seller marked the order as packed.'
  },
  {
    status: 'shipped',
    label: 'Marked as Shipped',
    desc: 'The seller or authorized operator marked the order as shipped.'
  },
  {
    status: 'out_for_delivery',
    label: 'Out for Delivery',
    desc: 'The order status was marked out for delivery. Carrier integration is not connected.'
  },
  {
    status: 'delivered',
    label: 'Marked as Delivered',
    desc: 'The order status was marked delivered in the database.'
  }
];

export const OrderTrackingModal: React.FC<OrderTrackingModalProps> = ({
  order,
  onClose,
}) => {
  const { updateOrderStatus, activeRole } = useMarketplace();

  if (!order) return null;

  const currentStepIndex = ORDER_STEPS.findIndex((s) => s.status === order.status);
  const isCancelled = order.status === 'cancelled';

  return (
    <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-xs flex justify-center items-end sm:items-center p-0 sm:p-4">
      <div className="bg-white w-full max-w-lg max-h-[92vh] rounded-t-2xl sm:rounded-2xl flex flex-col overflow-hidden shadow-2xl animate-in slide-in-from-bottom duration-200">
        {/* Header */}
        <div className="px-4 py-3 bg-[#1e3a8a] text-white flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Package size={20} className="text-orange-400" />
            <div>
              <h3 className="font-bold text-sm sm:text-base">Order #{order.id}</h3>
              <p className="text-[11px] text-blue-200">
                Placed on {new Date(order.createdAt).toLocaleDateString('en-IN', {
                  day: 'numeric',
                  month: 'short',
                  year: 'numeric'
                })}
              </p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-1 text-blue-200 hover:text-white rounded-full"
            aria-label="Close"
          >
            <X size={20} />
          </button>
        </div>

        {/* Scrollable Body */}
        <div className="flex-1 overflow-y-auto p-4 space-y-4">
          {/* Status highlight banner */}
          <div className="p-3 bg-emerald-50 border border-emerald-200 rounded-xl flex items-center justify-between">
            <div>
              <span className="text-[10px] font-bold uppercase tracking-wider text-emerald-800">
                Current Status
              </span>
              <h4 className="text-sm font-extrabold text-emerald-950 capitalize">
                {order.status.replace(/_/g, ' ')}
              </h4>
            </div>
            <div className="text-right">
              <span className="text-[10px] font-bold text-gray-500 uppercase">Payment</span>
              <p className="text-xs font-black text-[#1e3a8a]">
                ₹{order.totalAmount.toLocaleString('en-IN')} (COD)
              </p>
            </div>
          </div>

          {/* Flipkart / Meesho Vertical Stepper */}
          <div className="bg-gray-50 rounded-xl p-4 border border-gray-200">
            <h4 className="text-xs font-bold text-gray-800 uppercase tracking-wider mb-3">
              Delivery Progress
            </h4>

            <div className="space-y-4 relative">
              {ORDER_STEPS.map((step, idx) => {
                const isPassed = !isCancelled && idx <= currentStepIndex;
                const isCurrent = !isCancelled && idx === currentStepIndex;

                return (
                  <div key={step.status} className="flex items-start gap-3 relative">
                    {/* Vertical connecting line */}
                    {idx < ORDER_STEPS.length - 1 && (
                      <div
                        className={`absolute left-3.5 top-7 bottom-0 w-0.5 -ml-[1px] ${
                          isPassed && idx < currentStepIndex ? 'bg-emerald-600' : 'bg-gray-300'
                        }`}
                        style={{ height: 'calc(100% + 4px)' }}
                      />
                    )}

                    {/* Step Icon */}
                    <div
                      className={`w-7 h-7 rounded-full flex items-center justify-center shrink-0 z-10 ${
                        isCurrent
                          ? 'bg-[#1e3a8a] text-white ring-4 ring-blue-100 shadow'
                          : isPassed
                          ? 'bg-emerald-600 text-white'
                          : 'bg-gray-200 text-gray-400'
                      }`}
                    >
                      {isPassed ? (
                        <CheckCircle2 size={16} />
                      ) : (
                        <span className="text-[10px] font-bold">{idx + 1}</span>
                      )}
                    </div>

                    {/* Step Text */}
                    <div className="flex-1 pb-1">
                      <p
                        className={`text-xs font-bold ${
                          isCurrent
                            ? 'text-[#1e3a8a]'
                            : isPassed
                            ? 'text-gray-900'
                            : 'text-gray-400'
                        }`}
                      >
                        {step.label}
                      </p>
                      <p className="text-[11px] text-gray-500 leading-tight mt-0.5">
                        {step.desc}
                      </p>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>

          {/* Admin / Seller Quick Status Action (Only visible in Seller/Admin modes) */}
          {(activeRole === 'seller' || activeRole === 'admin') && (
            <div className="p-3 bg-amber-50 border border-amber-200 rounded-xl space-y-2">
              <span className="text-[11px] font-bold text-amber-900 block">
                Manage Order Fulfillment ({activeRole === 'seller' ? 'Seller Hub' : 'Admin'}):
              </span>
              <div className="flex flex-wrap gap-1.5">
                {(['confirmed', 'packed', 'shipped', 'out_for_delivery', 'delivered'] as OrderStatus[]).map(
                  (s) => (
                    <button
                      key={s}
                      onClick={() => updateOrderStatus(order.id, s)}
                      className={`px-2.5 py-1 text-[11px] font-bold rounded-lg border transition ${
                        order.status === s
                          ? 'bg-[#1e3a8a] text-white border-[#1e3a8a]'
                          : 'bg-white text-gray-700 border-gray-300 hover:bg-gray-100'
                      }`}
                    >
                      Set: {s.replace(/_/g, ' ')}
                    </button>
                  )
                )}
              </div>
            </div>
          )}

          {/* Items Summary */}
          <div className="bg-white rounded-xl border border-gray-200 p-3 space-y-2">
            <h4 className="text-xs font-bold text-gray-800 uppercase tracking-wider">
              Package Contents ({order.items.length})
            </h4>
            <div className="divide-y divide-gray-100">
              {order.items.map((item) => (
                <div key={item.id} className="py-2 flex items-center justify-between text-xs">
                  <div className="flex items-center gap-2.5 min-w-0">
                    <img
                      src={item.imageUrl}
                      alt={item.title}
                      className="w-10 h-10 rounded-md object-cover bg-gray-50 shrink-0"
                    />
                    <div className="min-w-0">
                      <p className="font-semibold text-gray-900 truncate max-w-[200px]">
                        {item.title}
                      </p>
                      <p className="text-[10px] text-gray-500">Qty: {item.quantity}</p>
                    </div>
                  </div>
                  <span className="font-bold text-[#1e3a8a] shrink-0">
                    ₹{(item.price * item.quantity).toLocaleString('en-IN')}
                  </span>
                </div>
              ))}
            </div>
          </div>

          {/* Delivery Address */}
          <div className="bg-white rounded-xl border border-gray-200 p-3 text-xs space-y-1">
            <h4 className="font-bold text-gray-800 uppercase tracking-wider flex items-center gap-1.5">
              <MapPin size={14} className="text-[#f97316]" /> Delivery Destination
            </h4>
            <p className="font-semibold text-gray-900">{order.customerName}</p>
            <p className="text-gray-600 leading-snug">{order.shippingAddress}</p>
            <p className="text-gray-600">
              {order.city}, {order.state} - <strong className="text-gray-900 font-mono">{order.pincode}</strong>
            </p>
            <p className="text-gray-600 flex items-center gap-1 pt-1 font-mono">
              <Phone size={12} className="text-gray-400" /> +91 {order.customerPhone}
            </p>
          </div>
        </div>

        {/* Footer */}
        <div className="p-3 bg-white border-t border-gray-200">
          <button
            onClick={onClose}
            className="w-full py-2.5 bg-gray-100 hover:bg-gray-200 text-gray-800 font-bold text-xs rounded-xl transition tap-effect"
          >
            Close Tracking
          </button>
        </div>
      </div>
    </div>
  );
};
