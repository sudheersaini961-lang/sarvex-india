import React, { useEffect, useState } from 'react';
import {
  X,
  Truck,
  ShieldCheck,
  CheckCircle,
  MapPin,
  Phone,
  User,
  Building
} from 'lucide-react';
import { useMarketplace } from '../lib/marketplaceStore';
import { Order } from '../types/marketplace';

const INDIAN_STATES = [
  'Andhra Pradesh',
  'Assam',
  'Bihar',
  'Delhi',
  'Gujarat',
  'Haryana',
  'Himachal Pradesh',
  'Jammu and Kashmir',
  'Jharkhand',
  'Karnataka',
  'Kerala',
  'Madhya Pradesh',
  'Maharashtra',
  'Odisha',
  'Punjab',
  'Rajasthan',
  'Tamil Nadu',
  'Telangana',
  'Uttar Pradesh',
  'Uttarakhand',
  'West Bengal'
];

interface CheckoutModalProps {
  isOpen: boolean;
  onClose: () => void;
  onOrderSuccess: (order: Order) => void;
  onOpenAuth?: () => void;
}

export const CheckoutModal: React.FC<CheckoutModalProps> = ({
  isOpen,
  onClose,
  onOrderSuccess,
  onOpenAuth,
}) => {
  const { cart, cartTotalAmount, placeOrder, currentUser } = useMarketplace();

  const [fullName, setFullName] = useState(currentUser?.fullName || '');
  const [phone, setPhone] = useState(currentUser?.phone || '');
  const [address, setAddress] = useState('');
  const [city, setCity] = useState('');
  const [state, setState] = useState('');
  const [pincode, setPincode] = useState('');

  useEffect(() => {
    if (!isOpen) return;
    try {
      const savedPin = localStorage.getItem('sarvex_delivery_pincode') || '';
      if (/^[1-9][0-9]{5}$/.test(savedPin)) setPincode(savedPin);
    } catch { /* local storage may be unavailable */ }
  }, [isOpen]);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [errorMsg, setErrorMsg] = useState('');

  if (!isOpen) return null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setErrorMsg('');

    if (!currentUser) {
      setErrorMsg('Authentication required: Please log in or create an account to place a Cash on Delivery order.');
      if (onOpenAuth) {
        onOpenAuth();
      }
      return;
    }

    if (!fullName.trim() || !phone.trim() || !address.trim() || !city.trim() || !pincode.trim()) {
      setErrorMsg('Please fill in all delivery details.');
      return;
    }

    if (!/^[6-9][0-9]{9}$/.test(phone)) {
      setErrorMsg('Please enter a valid 10-digit Indian mobile number starting with 6, 7, 8 or 9.');
      return;
    }

    if (!/^[1-9][0-9]{5}$/.test(pincode.trim())) {
      setErrorMsg('Please enter a valid 6-digit Indian postal PIN code.');
      return;
    }

    if (!state) {
      setErrorMsg('Please select your delivery state.');
      return;
    }

    if (cart.length === 0) {
      setErrorMsg('Your cart is empty.');
      return;
    }

    setIsSubmitting(true);
    try {
      const order = await placeOrder({
        customerName: fullName.trim(),
        customerPhone: phone.trim(),
        customerEmail: currentUser?.email,
        shippingAddress: address.trim(),
        city: city.trim(),
        state,
        pincode: pincode.trim()
      });

      setIsSubmitting(false);
      onClose();
      onOrderSuccess(order);
    } catch (err: any) {
      setIsSubmitting(false);
      setErrorMsg(err?.message || 'Could not place order. Please try again.');
    }
  };

  return (
    <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-xs flex justify-center items-end sm:items-center p-0 sm:p-4">
      <div className="bg-white w-full max-w-lg max-h-[94vh] rounded-t-2xl sm:rounded-2xl flex flex-col overflow-hidden shadow-2xl animate-in slide-in-from-bottom duration-200">
        {/* Header */}
        <div className="px-4 py-3 bg-[#1e3a8a] text-white flex items-center justify-between">
          <div>
            <h3 className="font-bold text-base flex items-center gap-1.5">
              <Truck size={18} className="text-orange-400" />
              Cash on Delivery Checkout
            </h3>
            <p className="text-[11px] text-blue-200">COD setup in progress — checkout is not active</p>
          </div>
          <button
            onClick={onClose}
            className="p-1 text-blue-200 hover:text-white rounded-full"
            aria-label="Close"
          >
            <X size={20} />
          </button>
        </div>

        {/* Scrollable Form Body */}
        <form onSubmit={handleSubmit} className="flex-1 overflow-y-auto p-4 space-y-4">
          {errorMsg && (
            <div className="p-3 bg-red-50 border border-red-200 text-red-700 text-xs rounded-xl font-medium">
              {errorMsg}
            </div>
          )}

          {!currentUser && (
            <div className="p-3 bg-amber-50 border border-amber-200 rounded-xl text-xs space-y-2">
              <div className="flex items-center justify-between">
                <span className="font-semibold text-amber-900 flex items-center gap-1.5">
                  <ShieldCheck size={16} className="text-[#f97316]" /> Login Required for COD
                </span>
                {onOpenAuth && (
                  <button
                    type="button"
                    onClick={onOpenAuth}
                    className="px-2.5 py-1 bg-[#1e3a8a] text-white text-[11px] font-bold rounded-lg hover:bg-blue-900"
                  >
                    Log In / Register
                  </button>
                )}
              </div>
              <p className="text-[11px] text-amber-800 leading-tight">
                To prevent fraudulent dispatches, Cash on Delivery orders require verified customer authentication.
              </p>
            </div>
          )}

          {/* Delivery Address Section */}
          <div className="space-y-3">
            <h4 className="text-xs font-bold text-gray-900 uppercase tracking-wider flex items-center gap-1.5">
              <MapPin size={14} className="text-[#f97316]" /> Delivery Address (India)
            </h4>

            <div>
              <label className="text-[11px] font-semibold text-gray-700 block mb-1">
                Full Name *
              </label>
              <div className="relative">
                <User size={15} className="absolute left-3 top-2.5 text-gray-400" />
                <input
                  type="text"
                  required
                  value={fullName}
                  onChange={(e) => setFullName(e.target.value)}
                  placeholder="Your full name"
                  className="w-full text-xs pl-9 pr-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-[#1e3a8a] focus:outline-none"
                />
              </div>
            </div>

            <div>
              <label className="text-[11px] font-semibold text-gray-700 block mb-1">
                10-Digit Mobile Number (For Delivery OTP) *
              </label>
              <div className="relative flex">
                <span className="inline-flex items-center px-2.5 text-xs font-bold bg-gray-100 border border-r-0 border-gray-300 rounded-l-lg text-gray-700">
                  +91
                </span>
                <input
                  type="tel"
                  required
                  maxLength={10}
                  value={phone}
                  onChange={(e) => setPhone(e.target.value.replace(/\D/g, ''))}
                  placeholder="10-digit mobile number"
                  className="w-full text-xs px-3 py-2 border border-gray-300 rounded-r-lg font-mono focus:ring-2 focus:ring-[#1e3a8a] focus:outline-none"
                />
              </div>
            </div>

            <div>
              <label className="text-[11px] font-semibold text-gray-700 block mb-1">
                House / Flat No., Building & Street Address *
              </label>
              <textarea
                required
                rows={2}
                value={address}
                onChange={(e) => setAddress(e.target.value)}
                placeholder="House No., Street Name, Colony / Landmark"
                className="w-full text-xs px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-[#1e3a8a] focus:outline-none"
              />
            </div>

            <div className="grid grid-cols-2 gap-2">
              <div>
                <label className="text-[11px] font-semibold text-gray-700 block mb-1">
                  City / District *
                </label>
                <input
                  type="text"
                  required
                  value={city}
                  onChange={(e) => setCity(e.target.value)}
                  placeholder="e.g. New Delhi"
                  className="w-full text-xs px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-[#1e3a8a] focus:outline-none"
                />
              </div>

              <div>
                <label className="text-[11px] font-semibold text-gray-700 block mb-1">
                  State *
                </label>
                <select
                  required
                  value={state}
                  onChange={(e) => setState(e.target.value)}
                  className="w-full text-xs px-2.5 py-2 border border-gray-300 rounded-lg bg-white focus:ring-2 focus:ring-[#1e3a8a] focus:outline-none"
                >
                  <option value="" disabled>Select State</option>
                  {INDIAN_STATES.map((s) => (
                    <option key={s} value={s}>
                      {s}
                    </option>
                  ))}
                </select>
              </div>
            </div>

            <div>
              <label className="text-[11px] font-semibold text-gray-700 block mb-1">
                Postal PIN Code (6 digits) *
              </label>
              <input
                type="text"
                pattern="[1-9][0-9]{5}"
                inputMode="numeric"
                autoComplete="postal-code"
                maxLength={6}
                required
                value={pincode}
                onChange={(e) => setPincode(e.target.value.replace(/\D/g, ''))}
                placeholder="110016"
                className="w-full text-xs px-3 py-2 border border-gray-300 rounded-lg font-mono focus:ring-2 focus:ring-[#1e3a8a] focus:outline-none"
              />
            </div>
          </div>

          <div role="status" className="border border-amber-300 bg-amber-50 rounded-xl p-3.5 space-y-1.5">
            <div className="text-xs font-bold text-amber-950 flex items-center gap-1.5">
              <ShieldCheck size={16} /> Cash on Delivery is not active yet
            </div>
            <p className="text-[11px] text-amber-900 leading-normal">
              Courier PIN availability, COD cash collection and seller payment reconciliation are not connected. Your order will not be submitted or charged.
            </p>
          </div>

          {/* Order Summary Mini-List */}
          <div className="bg-gray-50 rounded-xl p-3 border border-gray-200">
            <h5 className="text-[11px] font-bold text-gray-700 uppercase tracking-wider mb-2">
              Order Items ({cart.length})
            </h5>
            <div className="space-y-1.5 max-h-28 overflow-y-auto">
              {cart.map((item) => (
                <div key={item.product.id} className="flex justify-between text-xs text-gray-600">
                  <span className="truncate max-w-[220px]">
                    {item.quantity}x {item.product.title}
                  </span>
                  <span className="font-semibold text-gray-900 shrink-0">
                    ₹{(item.product.price * item.quantity).toLocaleString('en-IN')}
                  </span>
                </div>
              ))}
            </div>
            <div className="border-t border-gray-200 mt-2 pt-2 flex justify-between text-xs font-extrabold text-gray-900">
              <span>Total Payable Amount</span>
              <span className="text-base text-[#1e3a8a]">
                ₹{cartTotalAmount.toLocaleString('en-IN')}
              </span>
            </div>
          </div>

          {/* Sticky Place Order Button */}
          <div className="pt-2">
            <button
              type="submit"
              disabled={true}
              className="w-full py-3.5 bg-gradient-to-r from-[#ea580c] to-[#f97316] hover:from-orange-600 hover:to-orange-700 text-white font-black text-sm rounded-xl shadow-lg transition tap-effect flex items-center justify-center gap-2 disabled:opacity-50"
            >
              {isSubmitting ? (
                <span>Confirming Order...</span>
              ) : (
                <>
                  <CheckCircle size={18} />
                  <span>COD Checkout Not Available Yet</span>
                </>
              )}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
