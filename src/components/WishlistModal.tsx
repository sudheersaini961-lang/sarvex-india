import React from 'react';
import { X, Heart, ShoppingBag, Trash2 } from 'lucide-react';
import { useMarketplace } from '../lib/marketplaceStore';
import { Product } from '../types/marketplace';

interface WishlistModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSelectProduct: (product: Product) => void;
}

export const WishlistModal: React.FC<WishlistModalProps> = ({
  isOpen,
  onClose,
  onSelectProduct,
}) => {
  const { wishlistIds, products, toggleWishlist, addToCart } = useMarketplace();

  if (!isOpen) return null;

  const wishlistedProducts = products.filter((p) => wishlistIds.includes(p.id));

  return (
    <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-xs flex justify-end">
      <div className="bg-white w-full max-w-md h-full flex flex-col shadow-2xl animate-in slide-in-from-right duration-200">
        {/* Header */}
        <div className="px-4 py-3 bg-[#1e3a8a] text-white flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Heart size={20} className="fill-red-400 text-red-400" />
            <h3 className="font-bold text-base">My Wishlist</h3>
            <span className="text-xs bg-blue-800 text-blue-200 px-2 py-0.5 rounded-full font-medium">
              {wishlistedProducts.length} items
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

        {/* Content */}
        <div className="flex-1 overflow-y-auto p-4 space-y-3">
          {wishlistedProducts.length === 0 ? (
            <div className="text-center py-16 px-4">
              <div className="w-16 h-16 bg-red-50 text-red-400 rounded-full flex items-center justify-center mx-auto mb-3">
                <Heart size={30} />
              </div>
              <h4 className="font-bold text-gray-800 text-base mb-1">Your Wishlist is Empty</h4>
              <p className="text-xs text-gray-500 mb-4">
                Save your favorite Indian kurtas, sarees, and audio electronics here to buy later.
              </p>
              <button
                onClick={onClose}
                className="px-5 py-2.5 bg-[#1e3a8a] text-white font-bold text-xs rounded-xl shadow hover:bg-blue-800 transition"
              >
                Browse Trending Products
              </button>
            </div>
          ) : (
            wishlistedProducts.map((product) => (
              <div
                key={product.id}
                onClick={() => {
                  onClose();
                  onSelectProduct(product);
                }}
                className="flex gap-3 p-3 bg-white border border-gray-200 rounded-xl shadow-xs cursor-pointer hover:shadow-md transition tap-effect"
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
                    <p className="text-[10px] text-gray-500">
                      By {product.sellerName}
                    </p>
                    <div className="flex items-baseline gap-1.5 mt-1">
                      <span className="text-xs font-extrabold text-[#1e3a8a]">
                        ₹{product.price.toLocaleString('en-IN')}
                      </span>
                      {product.mrp > product.price && (
                        <span className="text-[10px] text-gray-400 line-through">
                          ₹{product.mrp.toLocaleString('en-IN')}
                        </span>
                      )}
                    </div>
                  </div>

                  <div className="flex items-center justify-between mt-2 pt-2 border-t border-gray-100">
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        addToCart(product, 1);
                      }}
                      className="text-xs font-bold text-[#1e3a8a] bg-blue-50 hover:bg-blue-100 px-3 py-1 rounded-lg flex items-center gap-1"
                    >
                      <ShoppingBag size={12} /> Add to Cart
                    </button>
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        toggleWishlist(product.id);
                      }}
                      className="text-gray-400 hover:text-red-600 p-1"
                      title="Remove from wishlist"
                    >
                      <Trash2 size={14} />
                    </button>
                  </div>
                </div>
              </div>
            ))
          )}
        </div>
      </div>
    </div>
  );
};
