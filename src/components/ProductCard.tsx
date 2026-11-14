import React, { useState } from 'react';
import { Heart, Star, ShoppingBag, Check, ShieldCheck, Truck } from 'lucide-react';
import { Product } from '../types/marketplace';
import { useMarketplace } from '../lib/marketplaceStore';

interface ProductCardProps {
  product: Product;
  onSelect: (product: Product) => void;
}

export const ProductCard: React.FC<ProductCardProps> = ({ product, onSelect }) => {
  const { wishlistIds, toggleWishlist, addToCart, cart } = useMarketplace();
  const [justAdded, setJustAdded] = useState(false);

  const isWishlisted = wishlistIds.includes(product.id);
  const discountPercent = Math.round(((product.mrp - product.price) / product.mrp) * 100);
  const cartItem = cart.find((i) => i.product.id === product.id);
  const qtyInCart = cartItem ? cartItem.quantity : 0;

  const handleAddToCart = async (e: React.MouseEvent) => {
    e.stopPropagation();
    try {
      await addToCart(product, 1);
      setJustAdded(true);
      setTimeout(() => setJustAdded(false), 1400);
    } catch (error) {
      window.alert(error instanceof Error ? error.message : 'Could not add this item to your cart.');
    }
  };

  const handleToggleWishlist = async (e: React.MouseEvent) => {
    e.stopPropagation();
    try {
      await toggleWishlist(product.id);
    } catch (error) {
      window.alert(error instanceof Error ? error.message : 'Could not update your wishlist.');
    }
  };

  return (
    <div
      onClick={() => onSelect(product)}
      className="bg-white rounded-xl border border-gray-200/90 shadow-sm hover:shadow-md transition-shadow overflow-hidden flex flex-col justify-between tap-effect cursor-pointer group"
    >
      <div>
        {/* Top Image Container */}
        <div className="relative aspect-square w-full bg-gray-50 overflow-hidden">
          {product.imageUrl ? (
            <img
              src={product.imageUrl}
              alt={product.title}
              loading="lazy"
              className="w-full h-full object-cover object-center group-hover:scale-105 transition-transform duration-300"
            />
          ) : (
            <div className="w-full h-full flex items-center justify-center text-xs text-gray-400">No product image</div>
          )}

          {/* Badge */}
          {product.badge && (
            <div className="absolute top-2 left-2 bg-[#1e3a8a] text-white text-[9px] font-bold px-2 py-0.5 rounded shadow-sm flex items-center gap-1">
              <ShieldCheck size={10} className="text-amber-400" />
              <span>{product.badge}</span>
            </div>
          )}

          {/* Discount Pill */}
          {discountPercent > 0 && (
            <div className="absolute bottom-2 left-2 bg-[#ea580c] text-white text-[10px] font-black px-1.5 py-0.5 rounded shadow">
              {discountPercent}% OFF
            </div>
          )}

          {/* Wishlist Heart */}
          <button
            onClick={handleToggleWishlist}
            className="absolute top-2 right-2 w-7 h-7 bg-white/90 backdrop-blur-sm rounded-full flex items-center justify-center shadow-sm hover:bg-white transition"
            aria-label="Wishlist"
          >
            <Heart
              size={15}
              className={isWishlisted ? 'fill-red-500 text-red-500' : 'text-gray-400 hover:text-red-500'}
            />
          </button>
        </div>

        {/* Content Info */}
        <div className="p-2.5">
          {/* Seller store name */}
          <p className="text-[10px] text-gray-400 font-medium truncate mb-0.5">
            By <span className="text-gray-600 font-semibold">{product.sellerName}</span>
          </p>

          {/* Product Title */}
          <h4 className="text-xs font-semibold text-gray-800 line-clamp-2 leading-tight min-h-[32px] mb-1.5">
            {product.title}
          </h4>

          {/* Rating */}
          <div className="flex items-center gap-1 mb-2">
            {product.ratingCount > 0 ? (
              <>
                <span className="flex items-center gap-0.5 bg-emerald-700 text-white text-[10px] font-bold px-1.5 py-0.5 rounded">
                  {product.rating.toFixed(1)} <Star size={9} className="fill-white" />
                </span>
                <span className="text-[10px] text-gray-500">({product.ratingCount})</span>
              </>
            ) : <span className="text-[10px] text-gray-400">No ratings yet</span>}
            {product.isCodAvailable && (
              <span className="ml-auto text-[9px] font-semibold text-emerald-700 bg-emerald-50 px-1 py-0.5 rounded flex items-center gap-0.5">
                <Truck size={10} /> COD
              </span>
            )}
          </div>

          {/* Price Box */}
          <div className="flex items-baseline gap-1.5">
            <span className="text-sm font-extrabold text-[#1e3a8a]">
              ₹{product.price.toLocaleString('en-IN')}
            </span>
            {product.mrp > product.price && (
              <span className="text-[11px] text-gray-400 line-through">
                ₹{product.mrp.toLocaleString('en-IN')}
              </span>
            )}
          </div>

          {/* Stock info */}
          {product.stock <= 5 && product.stock > 0 ? (
            <p className="text-[10px] text-red-600 font-medium mt-1">
              Only {product.stock} left in stock!
            </p>
          ) : product.stock === 0 ? (
            <p className="text-[10px] text-gray-400 font-medium mt-1">Out of stock</p>
          ) : null}
        </div>
      </div>

      {/* Action Button */}
      <div className="p-2.5 pt-0">
        <button
          onClick={handleAddToCart}
          disabled={product.stock === 0}
          className={`w-full py-1.5 px-2 rounded-lg text-xs font-bold flex items-center justify-center gap-1.5 transition tap-effect ${
            justAdded
              ? 'bg-emerald-600 text-white'
              : qtyInCart > 0
              ? 'bg-blue-50 text-[#1e3a8a] border border-[#1e3a8a]/30 hover:bg-blue-100'
              : 'bg-[#1e3a8a] text-white hover:bg-blue-800'
          } disabled:bg-gray-200 disabled:text-gray-400 disabled:cursor-not-allowed`}
        >
          {justAdded ? (
            <>
              <Check size={14} /> Added!
            </>
          ) : qtyInCart > 0 ? (
            <>
              <ShoppingBag size={13} /> In Cart ({qtyInCart})
            </>
          ) : (
            <>
              <ShoppingBag size={13} /> Add to Cart
            </>
          )}
        </button>
      </div>
    </div>
  );
};
