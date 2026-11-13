import React from 'react';
import {
  X,
  Plus,
  Minus,
  Trash2,
  ShoppingBag,
  ShieldCheck,
  Truck,
  ArrowRight
} from 'lucide-react';
import { useMarketplace } from '../lib/marketplaceStore';

interface CartDrawerProps {
  isOpen: boolean;
  onClose: () => void;
  onProceedToCheckout: () => void;
}

export const CartDrawer: React.FC<CartDrawerProps> = ({
  isOpen,
  onClose,
  onProceedToCheckout,
}) => {
  const {
    cart,
    updateCartQuantity,
    removeFromCart,
    clearCart,
    cartTotalAmount,
    cartTotalMrp,
    cartTotalSavings,
  } = useMarketplace();

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-xs flex justify-end">
      <div className="bg-white w-full max-w-md h-full flex flex-col shadow-2xl animate-in slide-in-from-right duration-200">
        {/* Header */}
        <div className="px-4 py-3 bg-[#1e3a8a] text-white flex items-center justify-between">
          <div className="flex items-center gap-2">
            <ShoppingBag size={20} className="text-orange-400" />
            <h3 className="font-bold text-base">Shopping Cart</h3>
            <span className="text-xs bg-blue-800 text-blue-200 px-2 py-0.5 rounded-full font-medium">
              {cart.reduce((s, i) => s + i.quantity, 0)} items
            </span>
          </div>
          <button
            onClick={onClose}
            className="p-1 text-blue-200 hover:text-white rounded-full hover:bg-blue-800"
            aria-label="Close"
          >
            <X size={20} />
          </button>
        </div>

        {/* Free Delivery alert banner */}
        <div className="bg-emerald-50 px-4 py-2 border-b border-emerald-100 flex items-center justify-between text-xs text-emerald-800 font-medium">
          <span className="flex items-center gap-1.5">
            <Truck size={14} className="text-emerald-600" />
            <span>Eligible for <strong>FREE Cash On Delivery</strong></span>
          </span>
          <span className="text-emerald-700 font-bold">₹0 Shipping</span>
        </div>

        {/* Cart items list or empty state */}
        <div className="flex-1 overflow-y-auto p-4 space-y-3">
          {cart.length === 0 ? (
            <div className="text-center py-12 px-4">
              <div className="w-16 h-16 bg-blue-50 text-[#1e3a8a] rounded-full flex items-center justify-center mx-auto mb-3">
                <ShoppingBag size={32} />
              </div>
              <h4 className="font-bold text-gray-800 text-base mb-1">Your Cart is Empty</h4>
              <p className="text-xs text-gray-500 mb-4 max-w-xs mx-auto">
                Discover trending ethnic wear, smart gadgets, and natural Indian products at ₹0 extra fee.
              </p>
              <button
                onClick={onClose}
                className="px-5 py-2.5 bg-[#1e3a8a] text-white font-bold text-xs rounded-xl shadow hover:bg-blue-800 transition"
              >
                Start Shopping Now
              </button>
            </div>
          ) : (
            <>
              <div className="flex justify-between items-center pb-1">
                <span className="text-xs font-bold text-gray-500 uppercase tracking-wider">
                  Items in your bag
                </span>
                <button
                  onClick={clearCart}
                  className="text-xs text-red-600 hover:underline flex items-center gap-1"
                >
                  <Trash2 size={12} /> Clear all
                </button>
              </div>

              {cart.map(({ product, quantity }) => (
                <div
                  key={product.id}
                  className="flex gap-3 p-3 bg-white border border-gray-200 rounded-xl shadow-xs"
                >
                  <img
                    src={product.imageUrl}
                    alt={product.title}
                    className="w-18 h-18 rounded-lg object-cover bg-gray-50 shrink-0"
                  />
                  <div className="flex-1 min-w-0 flex flex-col justify-between">
                    <div>
                      <h4 className="text-xs font-bold text-gray-900 truncate">
                        {product.title}
                      </h4>
                      <p className="text-[10px] text-gray-500 truncate">
                        Seller: {product.sellerName}
                      </p>
                      <div className="flex items-baseline gap-1.5 mt-1">
                        <span className="text-xs font-extrabold text-[#1e3a8a]">
                          ₹{(product.price * quantity).toLocaleString('en-IN')}
                        </span>
                        {product.mrp > product.price && (
                          <span className="text-[10px] text-gray-400 line-through">
                            ₹{(product.mrp * quantity).toLocaleString('en-IN')}
                          </span>
                        )}
                      </div>
                    </div>

                    {/* Quantity Selector */}
                    <div className="flex items-center justify-between mt-2 pt-2 border-t border-gray-100">
                      <div className="flex items-center border border-gray-300 rounded-lg overflow-hidden bg-gray-50">
                        <button
                          onClick={() => updateCartQuantity(product.id, quantity - 1)}
                          className="px-2 py-1 text-gray-600 hover:bg-gray-200 transition"
                          aria-label="Decrease quantity"
                        >
                          <Minus size={12} />
                        </button>
                        <span className="px-3 text-xs font-bold text-gray-800">
                          {quantity}
                        </span>
                        <button
                          onClick={() => updateCartQuantity(product.id, quantity + 1)}
                          disabled={quantity >= product.stock}
                          className="px-2 py-1 text-gray-600 hover:bg-gray-200 transition disabled:opacity-40"
                          aria-label="Increase quantity"
                        >
                          <Plus size={12} />
                        </button>
                      </div>

                      <button
                        onClick={() => removeFromCart(product.id)}
                        className="text-gray-400 hover:text-red-600 p-1 transition"
                        title="Remove"
                      >
                        <Trash2 size={14} />
                      </button>
                    </div>
                  </div>
                </div>
              ))}

              {/* Price Details Breakdown */}
              <div className="bg-gray-50 rounded-xl p-3.5 border border-gray-200/80 space-y-2 mt-4 text-xs">
                <h4 className="font-bold text-gray-900 uppercase text-[11px] tracking-wider border-b border-gray-200 pb-1.5">
                  Price Details (INR)
                </h4>
                <div className="flex justify-between text-gray-600">
                  <span>Price ({cart.length} items)</span>
                  <span>₹{cartTotalMrp.toLocaleString('en-IN')}</span>
                </div>
                {cartTotalSavings > 0 && (
                  <div className="flex justify-between text-emerald-700 font-medium">
                    <span>Discount on MRP</span>
                    <span>-₹{cartTotalSavings.toLocaleString('en-IN')}</span>
                  </div>
                )}
                <div className="flex justify-between text-gray-600">
                  <span>Delivery Charges</span>
                  <span className="text-emerald-700 font-semibold">FREE</span>
                </div>
                <div className="flex justify-between text-gray-600">
                  <span>Platform Fee</span>
                  <span className="text-emerald-700 font-semibold">FREE ₹0</span>
                </div>
                <div className="flex justify-between font-extrabold text-gray-900 pt-2 border-t border-gray-200 text-sm">
                  <span>Total Amount</span>
                  <span className="text-[#1e3a8a]">₹{cartTotalAmount.toLocaleString('en-IN')}</span>
                </div>
                {cartTotalSavings > 0 && (
                  <p className="text-[11px] text-emerald-800 font-semibold bg-emerald-100/70 p-2 rounded-lg text-center">
                    🎉 You will save ₹{cartTotalSavings.toLocaleString('en-IN')} on this order!
                  </p>
                )}
              </div>

              {/* COD note */}
              <div className="flex items-center gap-2 p-2.5 bg-blue-50/70 rounded-xl border border-blue-100 text-xs text-[#1e3a8a]">
                <ShieldCheck size={18} className="shrink-0 text-[#f97316]" />
                <span className="text-[11px]">
                  Pay cash at delivery. No prepayment required. Open parcel verification enabled.
                </span>
              </div>
            </>
          )}
        </div>

        {/* Footer Checkout Button */}
        {cart.length > 0 && (
          <div className="p-3 bg-white border-t border-gray-200">
            <div className="flex items-center justify-between mb-2 px-1">
              <div>
                <span className="text-[10px] text-gray-500 uppercase font-bold">Total Payable</span>
                <p className="text-lg font-black text-[#1e3a8a]">
                  ₹{cartTotalAmount.toLocaleString('en-IN')}
                </p>
              </div>
              <span className="text-[11px] text-emerald-700 font-bold bg-emerald-50 px-2 py-0.5 rounded">
                Cash On Delivery
              </span>
            </div>

            <button
              onClick={() => {
                onClose();
                onProceedToCheckout();
              }}
              className="w-full py-3 bg-[#f97316] hover:bg-orange-600 text-white font-extrabold text-sm rounded-xl shadow-lg transition tap-effect flex items-center justify-center gap-2"
            >
              <span>Proceed to Cash on Delivery Checkout</span>
              <ArrowRight size={16} />
            </button>
          </div>
        )}
      </div>
    </div>
  );
};
