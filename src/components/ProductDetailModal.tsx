import React, { useState } from 'react';
import {
  X,
  Star,
  ShieldCheck,
  Truck,
  RotateCcw,
  CheckCircle2,
  Heart,
  ShoppingBag,
  Store,
  MapPin,
  Sparkles
} from 'lucide-react';
import { Product } from '../types/marketplace';
import { useMarketplace } from '../lib/marketplaceStore';
import { ProductReviews } from './ProductReviews';

interface ProductDetailModalProps {
  product: Product | null;
  onClose: () => void;
  onBuyNow: (product: Product) => void;
}

export const ProductDetailModal: React.FC<ProductDetailModalProps> = ({
  product,
  onClose,
  onBuyNow,
}) => {
  if (!product) return null;

  const { wishlistIds, toggleWishlist, addToCart, cart, products } = useMarketplace();
  // Keep live product reference so ratings update immediately on review submission
  const currentProduct = products.find((p) => p.id === product.id) || product;

    const [addedNotice, setAddedNotice] = useState(false);

  const isWishlisted = wishlistIds.includes(currentProduct.id);
  const discountPercent = Math.round(((currentProduct.mrp - currentProduct.price) / currentProduct.mrp) * 100);
  const savingsAmount = currentProduct.mrp - currentProduct.price;
  const inCart = cart.find((i) => i.product.id === currentProduct.id);

  const handleAddToCart = () => {
    addToCart(currentProduct, 1);
    setAddedNotice(true);
    setTimeout(() => setAddedNotice(false), 2000);
  };


  return (
    <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-xs flex flex-col justify-end sm:justify-center items-center">
      <div className="bg-white w-full max-w-lg max-h-[92vh] sm:max-h-[85vh] rounded-t-2xl sm:rounded-2xl flex flex-col overflow-hidden shadow-2xl animate-in slide-in-from-bottom duration-200">
        {/* Top Header */}
        <div className="flex items-center justify-between px-4 py-3 border-b border-gray-100 bg-white sticky top-0 z-10">
          <div className="flex items-center gap-1.5 text-xs text-gray-500">
            <span className="capitalize font-semibold text-[#1e3a8a]">{currentProduct.category}</span>
            <span>/</span>
            <span className="truncate max-w-[150px]">{currentProduct.title}</span>
          </div>
          <div className="flex items-center gap-2">
            <button
              onClick={() => toggleWishlist(currentProduct.id)}
              className="p-1.5 text-gray-500 hover:text-red-500 rounded-full"
              aria-label="Wishlist"
            >
              <Heart
                size={20}
                className={isWishlisted ? 'fill-red-500 text-red-500' : ''}
              />
            </button>
            <button
              onClick={onClose}
              className="p-1.5 text-gray-500 hover:text-gray-800 rounded-full bg-gray-100"
              aria-label="Close"
            >
              <X size={18} />
            </button>
          </div>
        </div>

        {/* Scrollable Content */}
        <div className="overflow-y-auto p-4 space-y-4 pb-24">
          {/* Main Image */}
          <div className="relative aspect-square w-full rounded-xl overflow-hidden bg-gray-50 border border-gray-100">
            {currentProduct.imageUrl ? (
              <img src={currentProduct.imageUrl} alt={currentProduct.title} className="w-full h-full object-cover" />
            ) : <div className="w-full h-full flex items-center justify-center text-sm text-gray-400">No product image</div>}
            {currentProduct.badge && (
              <span className="absolute top-3 left-3 bg-[#1e3a8a] text-white text-[11px] font-bold px-2.5 py-1 rounded shadow-md flex items-center gap-1">
                <ShieldCheck size={13} className="text-amber-400" />
                {currentProduct.badge}
              </span>
            )}
          </div>

          {/* Title & Seller */}
          <div>
            <div className="flex items-center justify-between mb-1">
              <div className="flex items-center gap-1.5 bg-blue-50 text-[#1e3a8a] text-xs font-semibold px-2 py-0.5 rounded">
                <Store size={12} />
                <span>Sold by: <strong>{currentProduct.sellerName}</strong></span>
              </div>
              {currentProduct.ratingCount > 0 && <span className="flex items-center gap-1 bg-emerald-700 text-white text-xs font-bold px-2 py-0.5 rounded">
                {currentProduct.rating.toFixed(1)} <Star size={11} className="fill-white" />
              </span>}
            </div>

            <h2 className="text-base sm:text-lg font-bold text-gray-900 leading-snug">
              {currentProduct.title}
            </h2>
            <p className="text-xs text-gray-500 mt-0.5">
              {currentProduct.ratingCount > 0 ? `${currentProduct.ratingCount} customer ratings and reviews` : 'No customer ratings yet'}
            </p>
          </div>

          {/* Pricing Section */}
          <div className="bg-amber-50/50 p-3 rounded-xl border border-amber-200/60">
            <div className="flex items-baseline gap-2">
              <span className="text-2xl font-black text-[#1e3a8a]">
                ₹{currentProduct.price.toLocaleString('en-IN')}
              </span>
              {currentProduct.mrp > currentProduct.price && (
                <>
                  <span className="text-sm text-gray-400 line-through">
                    ₹{currentProduct.mrp.toLocaleString('en-IN')}
                  </span>
                  <span className="text-xs font-bold text-[#ea580c] bg-orange-100 px-2 py-0.5 rounded">
                    {discountPercent}% OFF
                  </span>
                </>
              )}
            </div>
            {savingsAmount > 0 && (
              <p className="text-xs font-semibold text-emerald-700 mt-1 flex items-center gap-1">
                <Sparkles size={12} /> You save ₹{savingsAmount.toLocaleString('en-IN')} on this order!
              </p>
            )}
            <p className="text-[11px] text-gray-500 mt-1">Applicable taxes and fees will be confirmed at checkout.</p>
          </div>

          {/* Checkout and delivery readiness */}
          <div className="border border-gray-200 rounded-xl p-3.5 space-y-3">
            <div className="flex items-start gap-2.5">
              <div className="p-2 bg-emerald-100 text-emerald-800 rounded-lg">
                <Truck size={18} />
              </div>
              <div className="flex-1">
                <div className="flex items-center justify-between">
                  <h4 className="text-xs font-bold text-gray-900">Checkout status</h4>
                  <span className="text-[11px] font-bold text-gray-700 bg-gray-100 px-1.5 py-0.5 rounded">
                    Not available
                  </span>
                </div>
                <p className="text-xs text-gray-600 mt-0.5">
                  Ordering is temporarily disabled while payment collection and delivery operations are being verified.
                </p>
              </div>
            </div>

            <div className="flex items-start gap-2.5 pt-2 border-t border-gray-100">
              <div className="p-2 bg-blue-100 text-[#1e3a8a] rounded-lg">
                <RotateCcw size={18} />
              </div>
              <div>
                <h4 className="text-xs font-bold text-gray-900">Returns and refunds</h4>
                <p className="text-xs text-gray-600 mt-0.5">
                  Return eligibility, refund timing and replacement support will be published after these workflows are operational.
                </p>
              </div>
            </div>

            <div className="pt-2 border-t border-gray-100 text-[11px] text-gray-600">
              Delivery coverage and delivery dates are not verified yet. Please check back after courier integration is activated.
            </div>
          </div>

          {/* Description */}
          <div>
            <h4 className="text-xs font-bold text-gray-900 uppercase tracking-wider mb-1.5">
              Product Overview
            </h4>
            <p className="text-xs text-gray-700 leading-relaxed bg-gray-50 p-3 rounded-xl border border-gray-100">
              {currentProduct.description}
            </p>
          </div>

          {/* Stock status */}
          <div className="flex items-center justify-between text-xs p-2.5 bg-gray-50 rounded-lg">
            <span className="text-gray-600">Stock Availability:</span>
            <span className={`font-bold ${currentProduct.stock > 0 ? 'text-emerald-700' : 'text-red-600'}`}>
              {currentProduct.stock > 0 ? `${currentProduct.stock} units available` : 'Sold out'}
            </span>
          </div>

          {/* Customer Ratings & Reviews Section */}
          <ProductReviews productId={currentProduct.id} />
        </div>

        {/* Sticky Mobile Bottom Actions */}
        <div className="p-3 bg-white border-t border-gray-200 fixed bottom-0 left-0 right-0 max-w-lg mx-auto z-20 flex gap-2">
          <button
            onClick={handleAddToCart}
            disabled={currentProduct.stock === 0}
            className="flex-1 py-3 px-3 bg-white border-2 border-[#1e3a8a] text-[#1e3a8a] font-bold text-xs rounded-xl shadow-xs hover:bg-blue-50 transition tap-effect flex items-center justify-center gap-1.5 disabled:opacity-50"
          >
            <ShoppingBag size={15} />
            <span>{addedNotice ? 'Added to Cart ✓' : inCart ? `In Cart (${inCart.quantity})` : 'Add to Cart'}</span>
          </button>

          <button
            onClick={() => onBuyNow(currentProduct)}
            disabled={true}
            className="flex-1 py-3 px-3 bg-gradient-to-r from-[#f97316] to-[#ea580c] hover:from-orange-600 hover:to-orange-700 text-white font-extrabold text-xs rounded-xl shadow-md transition tap-effect flex items-center justify-center gap-1.5 disabled:opacity-50"
          >
            <span>Checkout unavailable</span>
          </button>
        </div>
      </div>
    </div>
  );
};
