import { useState, useEffect } from 'react';
import {
  UserProfile,
  Seller,
  Product,
  Category,
  CartItem,
  Order,
  OrderItem,
  OrderStatus,
  UserRole,
  Review,
} from '../types/marketplace';
import { getSupabase, generateUuid, isUuid } from './supabaseClient';

// Standard Categories
export const INITIAL_CATEGORIES: Category[] = [
  {
    id: 'cat-mobiles',
    name: 'Mobiles & Tech',
    slug: 'mobiles',
    iconName: 'Smartphone',
    imageUrl: 'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=300&auto=format&fit=crop&q=80',
    itemCount: 0
  },
  {
    id: 'cat-fashion',
    name: 'Ethnic & Fashion',
    slug: 'fashion',
    iconName: 'Shirt',
    imageUrl: 'https://images.unsplash.com/photo-1610030469983-98e550d6193c?w=300&auto=format&fit=crop&q=80',
    itemCount: 0
  },
  {
    id: 'cat-electronics',
    name: 'Audio & Gadgets',
    slug: 'electronics',
    iconName: 'Headphones',
    imageUrl: 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=300&auto=format&fit=crop&q=80',
    itemCount: 0
  },
  {
    id: 'cat-home',
    name: 'Home & Living',
    slug: 'home-kitchen',
    iconName: 'Home',
    imageUrl: 'https://images.unsplash.com/photo-1583847268964-b28dc8f51f92?w=300&auto=format&fit=crop&q=80',
    itemCount: 0
  },
  {
    id: 'cat-grocery',
    name: 'Grocery & Naturals',
    slug: 'grocery',
    iconName: 'ShoppingBag',
    imageUrl: 'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=300&auto=format&fit=crop&q=80',
    itemCount: 0
  },
  {
    id: 'cat-beauty',
    name: 'Beauty & Wellness',
    slug: 'beauty',
    iconName: 'Sparkles',
    imageUrl: 'https://images.unsplash.com/photo-1522337360788-8b13dee7a37e?w=300&auto=format&fit=crop&q=80',
    itemCount: 0
  }
];

// No seller, product, review, order, cart, or wishlist demo records are seeded.
export const INITIAL_SELLERS: Seller[] = [];
export const INITIAL_PRODUCTS: Product[] = [];
export const INITIAL_REVIEWS: Review[] = [];
export const INITIAL_ORDERS: Order[] = [];


function getCheckoutIdempotencyKey(payload: Record<string, unknown>): string {
  const storageKey = 'sarvex_pending_checkout_v1';
  // Persist only a non-reversible fingerprint. Never write customer name, phone,
  // email, or delivery address to browser storage.
  const source = JSON.stringify(payload);
  let hashA = 0x811c9dc5;
  let hashB = 0x9e3779b9;
  for (let i = 0; i < source.length; i += 1) {
    const code = source.charCodeAt(i);
    hashA = Math.imul(hashA ^ code, 0x01000193);
    hashB = Math.imul(hashB ^ (code + i), 0x85ebca6b);
  }
  const fingerprint = `${(hashA >>> 0).toString(16)}${(hashB >>> 0).toString(16)}`;
  if (typeof window !== 'undefined') {
    try {
      const existing = localStorage.getItem(storageKey);
      if (existing) {
        const parsed = JSON.parse(existing) as { fingerprint?: string; key?: string };
        if (parsed.fingerprint === fingerprint && parsed.key) return parsed.key;
      }
      const key = generateUuid();
      localStorage.setItem(storageKey, JSON.stringify({ fingerprint, key }));
      return key;
    } catch {
      // If browser storage is unavailable, this attempt still gets a unique key.
    }
  }
  return generateUuid();
}

function clearCheckoutIdempotencyKey(): void {
  if (typeof window !== 'undefined') {
    try { localStorage.removeItem('sarvex_pending_checkout_v1'); } catch { /* storage may be disabled */ }
  }
}

export interface MarketplaceState {
  currentUser: UserProfile | null;
  activeRole: UserRole;
  categories: Category[];
  sellers: Seller[];
  products: Product[];
  orders: Order[];
  reviews: Review[];
  cart: CartItem[];
  wishlistIds: string[];
  searchQuery: string;
  selectedCategory: string | null;
}

function loadInitialState(): MarketplaceState {
  // No marketplace or personal records are restored from localStorage.
  // Supabase Auth and database records are the source of truth.
  return {
    currentUser: null,
    activeRole: 'customer',
    categories: INITIAL_CATEGORIES,
    sellers: [],
    products: [],
    orders: [],
    reviews: [],
    cart: [],
    wishlistIds: [],
    searchQuery: '',
    selectedCategory: null
  };
}

let globalState = loadInitialState();
const listeners = new Set<() => void>();

function notify() {
  // Never persist profiles, seller KYC/payout details, cart, or order data in browser storage.
  listeners.forEach((listener) => listener());
}

export function useMarketplace() {
  const [state, setState] = useState<MarketplaceState>(globalState);

  useEffect(() => {
    const listener = () => setState({ ...globalState });
    listeners.add(listener);
    return () => {
      listeners.delete(listener);
    };
  }, []);

  // Sync with Supabase on mount and listen to Auth state changes
  useEffect(() => {
    let publicSellerSnapshot: Seller[] = [];

    async function syncSupabase() {
      const supabase = getSupabase();
      if (!supabase) return;

      try {
        // 1. Fetch only the approved public seller fields. Never expose private
        // seller_shops columns (phone, pickup address, bank, IFSC, or UPI) publicly.
        const { data: publicSellers, error: publicSellersError } = await supabase
          .from('sellers')
          .select('id, user_id, store_name, owner_name, city, state, pincode, status, rating, created_at');
        if (publicSellersError) throw publicSellersError;

        const shopNameMap: Record<string, string> = {};
        globalState.sellers = (publicSellers || []).map((s: any): Seller => {
          const storeName = s.store_name || '';
          shopNameMap[s.id] = storeName;
          return {
            id: s.id,
            userId: s.user_id || '',
            storeName,
            ownerName: s.owner_name || '',
            phone: '',
            email: '',
            city: s.city || '',
            state: s.state || '',
            pincode: s.pincode || '',
            pickupAddress: '',
            status: s.status as any,
            commissionRate: 0,
            rating: Number(s.rating ?? 0),
            createdAt: s.created_at || ''
          };
        });
        publicSellerSnapshot = [...globalState.sellers];
        notify();

        // 2. Fetch Products (from existing products table: id UUID, seller_shop_id, product_name, price_inr, etc.)
        const { data: dbProducts, error: productsError } = await supabase.from('products').select('*');
        if (productsError) throw productsError;
        if (dbProducts) {
          globalState.products = dbProducts.map((p: any) => {
            const priceInr = Number(p.price_inr ?? p.price ?? 0);
            const discount = Number(p.discount_percent ?? 0);
            const calculatedMrp = discount > 0
              ? Math.round(priceInr / (1 - discount / 100))
              : Number(p.mrp ?? priceInr);

            return {
              id: p.id,
              sellerId: p.seller_shop_id ?? p.seller_id ?? '',
              sellerName: shopNameMap[p.seller_shop_id] || p.seller_name || 'Seller',
              title: p.product_name ?? p.title ?? 'Untitled Product',
              description: p.description || '',
              category: p.category || 'general',
              price: priceInr,
              mrp: calculatedMrp >= priceInr ? calculatedMrp : priceInr,
              stock: Number(p.stock_quantity ?? p.stock ?? 0),
              imageUrl: p.image_url || '',
              badge: p.badge || undefined,
              rating: Number(p.rating ?? 0),
              ratingCount: Number(p.rating_count ?? 0),
              isCodAvailable: true,
              isFeatured: Boolean(p.is_featured),
              createdAt: p.created_at || new Date().toISOString()
            };
          });
          notify();
        }

        // 3. Fetch Reviews
        const { data: dbReviews, error: reviewsError } = await supabase.from('reviews').select('*');
        if (reviewsError) throw reviewsError;
        if (dbReviews) {
          globalState.reviews = dbReviews.map((r: any) => ({
            id: r.id,
            productId: r.product_id,
            customerName: r.customer_name,
            customerCity: r.customer_city || '',
            rating: Number(r.rating ?? 0),
            title: r.title,
            comment: r.comment,
            isVerifiedBuyer: Boolean(r.is_verified_buyer),
            helpfulCount: Number(r.helpful_count || 0),
            createdAt: r.created_at || new Date().toISOString()
          }));
          notify();
        }

        // 4. Check Current Supabase Auth Session
        const { data: sessionData } = await supabase.auth.getSession();
        if (sessionData?.session?.user) {
          const authUser = sessionData.session.user;
          // Fetch from customer_profiles
          const { data: profile } = await supabase
            .from('customer_profiles')
            .select('*')
            .eq('owner_id', authUser.id)
            .maybeSingle();

          const assignedRole = (profile?.account_role || 'customer') as UserRole;

          // Private seller records are fetched only for authenticated seller/admin
          // sessions; database grants and RLS remain the authorization boundary.
          if (assignedRole === 'seller' || assignedRole === 'admin') {
            const { data: privateShops, error: privateShopsError } = await supabase
              .from('seller_shops')
              .select('*');
            if (privateShopsError) {
              console.warn('Private seller details could not be loaded:', privateShopsError);
            } else if (privateShops) {
              const privateSellers = privateShops.map((s: any): Seller => ({
                id: s.id,
                userId: s.owner_id || s.user_id || '',
                storeName: s.shop_name || s.store_name || '',
                ownerName: s.owner_name || '',
                phone: s.phone || '',
                email: s.email || '',
                city: s.city || '',
                state: s.state || '',
                pincode: s.pincode || '',
                pickupAddress: s.pickup_address || '',
                bankAccount: s.bank_account || '',
                ifscCode: s.ifsc_code || '',
                upiId: s.upi_id || '',
                status: (s.approval_status || s.status || 'pending') as any,
                commissionRate: Number(s.commission_rate ?? 0),
                rating: Number(s.rating ?? 0),
                createdAt: s.created_at || ''
              }));
              const privateById = new Map(privateSellers.map((seller) => [seller.id, seller]));
              globalState.sellers = [
                ...globalState.sellers.filter((seller) => !privateById.has(seller.id)),
                ...privateSellers
              ];
              for (const seller of privateSellers) shopNameMap[seller.id] = seller.storeName;
              notify();
            }
          }

          globalState.currentUser = {
            id: authUser.id,
            email: authUser.email || '',
            fullName: profile?.display_name || authUser.email?.split('@')[0] || 'User',
            phone: profile?.phone || '',
            role: assignedRole,
            createdAt: authUser.created_at
          };
          globalState.activeRole = assignedRole;

          // Fetch Cart from cart_items table
          const { data: dbCart, error: cartError } = await supabase
            .from('cart_items')
            .select('product_id, quantity')
            .eq('owner_id', authUser.id);
          if (cartError) throw cartError;

          const syncedCart: CartItem[] = [];
          for (const item of dbCart || []) {
            const prod = globalState.products.find((p) => p.id === item.product_id);
            const quantity = Number(item.quantity);
            if (prod && Number.isSafeInteger(quantity) && quantity > 0 && quantity <= prod.stock) {
              syncedCart.push({ product: prod, quantity });
            }
          }
          globalState.cart = syncedCart;

          // Wishlist is private account data; reload it for every authenticated session
          // so one account's saved items are never shown to another account.
          const { data: dbWishlist, error: wishlistError } = await supabase
            .from('wishlist_items')
            .select('product_id')
            .eq('owner_id', authUser.id);
          if (wishlistError) throw wishlistError;
          globalState.wishlistIds = (dbWishlist || [])
            .map((item: { product_id: string }) => item.product_id)
            .filter((productId: string) => globalState.products.some((product) => product.id === productId));

          // Load orders through customer/admin RLS, or the dedicated seller-safe view.
          const approvedOwnedShop = globalState.sellers.some((seller) =>
            seller.userId === authUser.id && seller.status === 'approved'
          );
          if (approvedOwnedShop && assignedRole !== 'admin') {
            const { data: sellerRows, error: sellerRowsError } = await supabase
              .from('seller_order_items_view')
              .select('*');
            if (sellerRowsError) throw sellerRowsError;
            const grouped = new Map<string, any[]>();
            for (const row of sellerRows || []) {
              const rows = grouped.get(row.order_id) || [];
              rows.push(row);
              grouped.set(row.order_id, rows);
            }
            globalState.orders = Array.from(grouped.entries()).map(([orderId, rows]) => ({
              id: orderId,
              databaseId: orderId,
              customerId: '',
              customerName: rows[0].delivery_name || '',
              customerPhone: rows[0].delivery_phone || '',
              shippingAddress: rows[0].delivery_address || '',
              city: rows[0].delivery_city || '',
              state: rows[0].delivery_state || '',
              pincode: rows[0].delivery_pincode || '',
              items: rows.map((item) => {
                const product = globalState.products.find((p) => p.id === item.product_id);
                return {
                  id: item.id,
                  productId: item.product_id || '',
                  sellerId: item.seller_id || '',
                  title: product?.title || 'Order item',
                  price: Number(item.unit_price || 0),
                  quantity: Number(item.quantity || 0),
                  imageUrl: product?.imageUrl || ''
                };
              }),
              totalAmount: rows.reduce((sum, item) => sum + Number(item.item_subtotal || 0), 0),
              paymentMethod: 'cod' as const,
              status: (rows[0].item_status || 'placed') as OrderStatus,
              statusHistory: [],
              createdAt: rows[0].order_date || new Date().toISOString()
            }));
          } else {
            const { data: dbOrders, error: ordersError } = await supabase.from('orders').select('*');
            if (ordersError) throw ordersError;
            const orderIds = (dbOrders || []).map((order: any) => order.id);
            let dbOrderItems: any[] = [];
            if (orderIds.length > 0) {
              const { data: items, error: itemsError } = await supabase
                .from('order_items')
                .select('*')
                .in('order_id', orderIds);
              if (itemsError) throw itemsError;
              dbOrderItems = items || [];
            }
            globalState.orders = (dbOrders || []).map((order: any) => ({
              id: order.order_code || order.id,
              databaseId: order.id,
              customerId: order.customer_id || '',
              customerName: order.customer_name || '',
              customerPhone: order.customer_phone || '',
              customerEmail: order.customer_email || undefined,
              shippingAddress: order.shipping_address || '',
              city: order.city || '',
              state: order.state || '',
              pincode: order.pincode || '',
              items: dbOrderItems.filter((item) => item.order_id === order.id).map((item) => ({
                id: item.id,
                productId: item.product_id || '',
                sellerId: item.seller_shop_id || '',
                title: item.product_name || '',
                price: Number(item.price_inr || 0),
                quantity: Number(item.quantity || 0),
                imageUrl: item.image_url || ''
              })),
              totalAmount: Number(order.total_amount || 0),
              paymentMethod: 'cod' as const,
              status: (order.status || 'placed') as OrderStatus,
              statusHistory: [],
              createdAt: order.created_at || new Date().toISOString()
            }));
          }

          notify();
        }
      } catch (err) {
        console.error('Supabase data sync failed. Marketplace data may be incomplete:', err);
      }
    }

    syncSupabase();

    // Auth callbacks must stay synchronous: Supabase holds an auth lock while
    // notifying listeners. Defer database reads until after that callback returns.
    const supabase = getSupabase();
    if (supabase) {
      const { data: authListener } = supabase.auth.onAuthStateChange((event, session) => {
        if (event === 'SIGNED_IN' && session?.user) {
          const userId = session.user.id;
          Promise.resolve().then(async () => {
            // Ignore a queued sign-in sync if the active session has since changed.
            const { data: currentSession } = await supabase.auth.getSession();
            if (currentSession.session?.user?.id !== userId) return;
            await syncSupabase();
          }).catch((error) => {
            console.error('Post-sign-in data sync failed:', error);
          });
        } else if (event === 'SIGNED_OUT') {
          globalState.currentUser = null;
          globalState.activeRole = 'customer';
          globalState.sellers = [...publicSellerSnapshot];
          globalState.cart = [];
          globalState.wishlistIds = [];
          globalState.orders = [];
          clearCheckoutIdempotencyKey();
          notify();
        }
      });

      return () => {
        authListener?.subscription?.unsubscribe();
      };
    }
  }, []);

  // Role switching
  const setActiveRole = (role: UserRole) => {
    // Security: Only allow admin view if user's actual profile has account_role === 'admin'
    if (role === 'admin' && globalState.currentUser?.role !== 'admin') {
      alert('Access restricted: Only verified administrators with account_role = "admin" can access Central Admin Operations.');
      return;
    }
    globalState.activeRole = role;
    notify();
  };

  // Real Supabase Auth: Login / Signup
  const loginUserWithSupabase = async (
    email: string,
    password?: string,
    isSignUp = false,
    fullName = '',
    phone = '',
    requestedRole: UserRole = 'customer'
  ): Promise<{ success: boolean; message: string }> => {
    const supabase = getSupabase();

    if (supabase && password) {
      try {
        if (isSignUp) {
          // 1. Real Supabase Auth Signup
          const { data: authData, error: authErr } = await supabase.auth.signUp({
            email: email.trim(),
            password,
            options: {
              data: {
                display_name: fullName.trim() || email.split('@')[0],
                phone: phone.trim()
              }
            }
          });

          if (authErr) {
            return { success: false, message: authErr.message };
          }

          const userId = authData.user?.id;
          if (userId) {
            // Safe role assignment: default to customer, prevent self-promoting to admin
            const safeRole: UserRole = 'customer'; // Seller access is granted only after a database-approved shop.

            // Insert into customer_profiles
            const { error: profileError } = await supabase.from('customer_profiles').upsert({
              id: generateUuid(),
              owner_id: userId,
              display_name: fullName.trim() || email.split('@')[0],
              email: email.trim(),
              phone: phone.trim(),
              account_role: safeRole,
              updated_at: new Date().toISOString()
            }, { onConflict: 'owner_id' });
            if (profileError) {
              await supabase.auth.signOut();
              return { success: false, message: `Account profile was not saved: ${profileError.message}` };
            }

            globalState.currentUser = {
              id: userId,
              email: email.trim(),
              fullName: fullName.trim() || email.split('@')[0],
              phone: phone.trim(),
              role: safeRole,
              createdAt: new Date().toISOString()
            };
            globalState.activeRole = safeRole;
            notify();
            return { success: true, message: 'Account created successfully in Supabase!' };
          }
        } else {
          // 2. Real Supabase Auth Sign In
          const { data: authData, error: authErr } = await supabase.auth.signInWithPassword({
            email: email.trim(),
            password
          });

          if (authErr) {
            return { success: false, message: authErr.message };
          }

          const userId = authData.user?.id;
          if (userId) {
            const { data: profile } = await supabase
              .from('customer_profiles')
              .select('*')
              .eq('owner_id', userId)
              .maybeSingle();

            const realRole = (profile?.account_role || 'customer') as UserRole;
            globalState.currentUser = {
              id: userId,
              email: email.trim(),
              fullName: profile?.display_name || email.split('@')[0],
              phone: profile?.phone || '',
              role: realRole,
              createdAt: authData.user?.created_at || new Date().toISOString()
            };
            globalState.activeRole = realRole;
            notify();
            return { success: true, message: 'Welcome back to SARVEX India!' };
          }
        }
      } catch (err: any) {
        return { success: false, message: err?.message || 'Authentication error.' };
      }
    }

    return {
      success: false,
      message: supabase
        ? 'Password is required for Supabase authentication.'
        : 'Supabase is not configured. Connect Supabase before signing in or creating an account.'
    };
  };

  const logoutUser = async () => {
    const supabase = getSupabase();
    if (supabase) {
      try {
        await supabase.auth.signOut();
      } catch (e) {
        console.warn('SignOut error:', e);
      }
    }
    globalState.currentUser = null;
    globalState.activeRole = 'customer';
    globalState.cart = [];
    globalState.wishlistIds = [];
    globalState.orders = [];
    globalState.sellers = globalState.sellers.filter((seller) => !seller.phone && !seller.email && !seller.pickupAddress && !seller.bankAccount && !seller.ifscCode && !seller.upiId);
    clearCheckoutIdempotencyKey();
    notify();
  };

  const setSearchQuery = (query: string) => {
    globalState.searchQuery = query;
    notify();
  };

  const setSelectedCategory = (catSlug: string | null) => {
    globalState.selectedCategory = catSlug;
    notify();
  };

  // Cart actions with cloud sync (cart_items table)
  const addToCart = async (product: Product, quantity = 1) => {
    if (!product?.id || !Number.isSafeInteger(quantity) || quantity < 1) {
      throw new Error('Choose a valid product quantity.');
    }
    const availableStock = Number.isFinite(product.stock) ? Math.floor(product.stock) : 0;
    if (availableStock < 1) throw new Error('This product is currently out of stock.');
    const existingIndex = globalState.cart.findIndex((item) => item.product.id === product.id);
    const currentQty = existingIndex > -1 ? globalState.cart[existingIndex].quantity : 0;
    const newQty = Math.min(availableStock, currentQty + quantity);
    if (newQty < 1) throw new Error('This product is currently out of stock.');

    if (existingIndex > -1) {
      globalState.cart[existingIndex] = {
        ...globalState.cart[existingIndex],
        quantity: newQty
      };
    } else {
      globalState.cart.push({ product, quantity: newQty });
    }
    notify();

    // Sync to Supabase cart_items table if user is logged in
    const supabase = getSupabase();
    if (supabase && globalState.currentUser?.id && isUuid(globalState.currentUser.id)) {
      try {
        await supabase.from('cart_items').upsert({
          id: generateUuid(),
          owner_id: globalState.currentUser.id,
          product_id: product.id,
          quantity: newQty,
          updated_at: new Date().toISOString()
        }, { onConflict: 'owner_id,product_id' });
      } catch (e) {
        console.warn('Cart cloud sync skipped:', e);
      }
    }
  };

  const updateCartQuantity = async (productId: string, quantity: number) => {
    if (!Number.isFinite(quantity)) throw new Error('Choose a valid cart quantity.');
    const item = globalState.cart.find((i) => i.product.id === productId);
    const requestedQuantity = Math.floor(quantity);
    const effectiveQuantity = requestedQuantity <= 0
      ? 0
      : Math.min(Math.max(0, Math.floor(item?.product.stock ?? 0)), requestedQuantity);

    if (effectiveQuantity === 0) {
      globalState.cart = globalState.cart.filter((cartItem) => cartItem.product.id !== productId);
    } else if (item) {
      item.quantity = effectiveQuantity;
    }
    notify();

    const supabase = getSupabase();
    if (supabase && globalState.currentUser?.id && isUuid(globalState.currentUser.id)) {
      try {
        if (effectiveQuantity === 0) {
          await supabase.from('cart_items').delete().eq('owner_id', globalState.currentUser.id).eq('product_id', productId);
        } else {
          await supabase.from('cart_items').update({
            quantity: effectiveQuantity,
            updated_at: new Date().toISOString()
          }).eq('owner_id', globalState.currentUser.id).eq('product_id', productId);
        }
      } catch (e) {
        console.warn('Cart quantity cloud sync skipped:', e);
      }
    }
  };

  const removeFromCart = async (productId: string) => {
    globalState.cart = globalState.cart.filter((item) => item.product.id !== productId);
    notify();

    const supabase = getSupabase();
    if (supabase && globalState.currentUser?.id && isUuid(globalState.currentUser.id)) {
      try {
        await supabase.from('cart_items').delete().eq('owner_id', globalState.currentUser.id).eq('product_id', productId);
      } catch (e) {
        console.warn('Cart remove cloud sync skipped:', e);
      }
    }
  };

  const clearCart = async () => {
    globalState.cart = [];
    notify();

    const supabase = getSupabase();
    if (supabase && globalState.currentUser?.id && isUuid(globalState.currentUser.id)) {
      try {
        await supabase.from('cart_items').delete().eq('owner_id', globalState.currentUser.id);
      } catch (e) {
        console.warn('Cart clear cloud sync skipped:', e);
      }
    }
  };

  // Wishlist actions
  const toggleWishlist = async (productId: string) => {
    if (globalState.wishlistIds.includes(productId)) {
      globalState.wishlistIds = globalState.wishlistIds.filter((id) => id !== productId);
    } else {
      globalState.wishlistIds.push(productId);
    }
    notify();

    const supabase = getSupabase();
    if (supabase && globalState.currentUser?.id && isUuid(globalState.currentUser.id)) {
      try {
        if (globalState.wishlistIds.includes(productId)) {
          await supabase.from('wishlist_items').upsert({
            id: generateUuid(),
            owner_id: globalState.currentUser.id,
            product_id: productId
          }, { onConflict: 'owner_id,product_id' });
        } else {
          await supabase.from('wishlist_items').delete().eq('owner_id', globalState.currentUser.id).eq('product_id', productId);
        }
      } catch (e) {
        console.warn('Wishlist cloud sync skipped:', e);
      }
    }
  };

  // Real Cash on Delivery Order placement (orders & order_items tables)
  const placeOrder = async (orderData: {
    customerName: string;
    customerPhone: string;
    customerEmail?: string;
    shippingAddress: string;
    city: string;
    state: string;
    pincode: string;
  }): Promise<Order> => {
    const orderUuid = generateUuid();
    const datePart = new Date().toISOString().slice(2, 10).replace(/-/g, '');
    const randPart = generateUuid().replace(/-/g, '').slice(0, 8).toUpperCase();
    const orderCode = `SRX-${datePart}-${randPart}`;

    // Security: Require authenticated user for COD orders
    const supabase = getSupabase();
    if (!supabase) {
      throw new Error('Supabase is not connected. Order placement is disabled until the real database is configured.');
    }
    if (!globalState.currentUser?.id || !isUuid(globalState.currentUser.id)) {
      throw new Error('Authentication required: Please log in or create an account to place a Cash on Delivery order.');
    }
    if (globalState.cart.length === 0) {
      throw new Error('Your cart is empty. Add a real product before placing an order.');
    }

    const orderItems: OrderItem[] = globalState.cart.map((c) => ({
      id: generateUuid(),
      productId: c.product.id,
      sellerId: c.product.sellerId,
      title: c.product.title,
      price: c.product.price,
      quantity: c.quantity,
      imageUrl: c.product.imageUrl
    }));

    const total = globalState.cart.reduce(
      (sum, item) => sum + item.product.price * item.quantity,
      0
    );

    const newOrder: Order = {
      id: orderCode, // Unique collision-resistant order code
      customerId: globalState.currentUser?.id || generateUuid(),
      customerName: orderData.customerName,
      customerPhone: orderData.customerPhone,
      customerEmail: orderData.customerEmail,
      shippingAddress: orderData.shippingAddress,
      city: orderData.city,
      state: orderData.state,
      pincode: orderData.pincode,
      items: orderItems,
      totalAmount: total,
      paymentMethod: 'cod',
      status: 'placed',
      statusHistory: [
        {
          status: 'placed',
          timestamp: new Date().toISOString(),
          note: 'Order placed successfully with Cash on Delivery (COD).'
        }
      ],
      createdAt: new Date().toISOString()
    };

    // Execute server-side transactional order placement via RPC if connected to Supabase
    if (supabase) {
      const basePayload = {
        p_customer_name: orderData.customerName,
        p_customer_phone: orderData.customerPhone,
        p_customer_email: orderData.customerEmail || '',
        p_shipping_address: orderData.shippingAddress,
        p_city: orderData.city,
        p_state: orderData.state,
        p_pincode: orderData.pincode,
        p_items: globalState.cart.map((c) => ({
          product_id: c.product.id,
          quantity: c.quantity
        }))
      };
      const rpcPayload = {
        ...basePayload,
        // Reuse the same key when the same checkout is retried after a network failure.
        p_idempotency_key: getCheckoutIdempotencyKey(basePayload)
      };

      const { data: rpcRes, error: rpcErr } = await supabase.rpc('place_sarvex_order', rpcPayload);
      if (rpcErr) {
        throw new Error(rpcErr.message || 'Server order validation failed. Please check stock and seller approval.');
      }
      if (!rpcRes || !rpcRes.order_code) {
        throw new Error('The database did not confirm the order. No local order was created.');
      }
      newOrder.id = rpcRes.order_code;
      newOrder.databaseId = rpcRes.order_id;
      if (rpcRes.total_amount !== undefined && rpcRes.total_amount !== null) {
        newOrder.totalAmount = Number(rpcRes.total_amount);
      }
      clearCheckoutIdempotencyKey();
    }

    // Update product stock locally
    globalState.cart.forEach((c) => {
      const prod = globalState.products.find((p) => p.id === c.product.id);
      if (prod) {
        prod.stock = Math.max(0, prod.stock - c.quantity);
      }
    });

    globalState.orders.unshift(newOrder);
    globalState.cart = [];
    notify();

    return newOrder;
  };

  const updateOrderStatus = async (orderId: string, nextStatus: OrderStatus, note?: string) => {
    const supabase = getSupabase();
    if (!supabase) throw new Error('Supabase is not connected. Order status cannot be changed offline.');
    const order = globalState.orders.find((item) => item.id === orderId || item.databaseId === orderId);
    if (!order) throw new Error('Order not found in the current database-backed state.');
    const itemIds = order.items.map((item) => item.id).filter(isUuid);
    if (itemIds.length === 0) throw new Error('No database order-item records are available for fulfillment.');

    // Preflight the exact writable set before mutating anything. Seller RLS may
    // expose only that seller's items in a multi-seller order.
    const { data: visibleItems, error: visibilityError } = await supabase
      .from('order_items')
      .select('id')
      .in('id', itemIds);
    if (visibilityError) throw new Error(`Order items could not be verified: ${visibilityError.message}`);
    const visibleIds = new Set((visibleItems || []).map((row: { id: string }) => row.id));
    if (visibleIds.size !== itemIds.length || itemIds.some((id) => !visibleIds.has(id))) {
      throw new Error('The full set of order items is not visible for this account. No status changes were attempted; refresh order details.');
    }

    const { data, error } = await supabase
      .from('order_items')
      .update({ item_status: nextStatus })
      .in('id', itemIds)
      .select('id');
    if (error) throw new Error(`Order item status was not saved: ${error.message}`);
    const updatedIds = new Set((data || []).map((row: { id: string }) => row.id));
    if (updatedIds.size !== itemIds.length || itemIds.some((id) => !updatedIds.has(id))) {
      // The visibility check can race with a policy/data change. Do not claim
      // aggregate success; a transactional server-side RPC is needed for atomicity.
      throw new Error('The database changed which order items were writable during the update. Refresh order details and verify item statuses.');
    }

    order.status = nextStatus;
    const statusLabels: Record<OrderStatus, string> = {
      placed: 'Order placed with Cash on Delivery',
      confirmed: 'Seller verified & confirmed package',
      packed: 'Package packed for dispatch',
      shipped: 'Marked as shipped',
      out_for_delivery: 'Marked out for delivery',
      delivered: 'Marked as delivered',
      cancelled: 'Order item cancelled'
    };
    order.statusHistory.push({
      status: nextStatus,
      timestamp: new Date().toISOString(),
      note: note || statusLabels[nextStatus]
    });
    notify();
  };

  // Seller Management (seller_shops table)
  const registerSeller = async (sellerData: Omit<Seller, 'id' | 'status' | 'commissionRate' | 'rating' | 'createdAt'>): Promise<Seller> => {
    const supabase = getSupabase();
    const ownerId = globalState.currentUser?.id;
    if (!supabase || !ownerId || !isUuid(ownerId)) {
      throw new Error('Please connect Supabase and sign in before registering a seller account.');
    }
    const shopUuid = generateUuid();
    const newSeller: Seller = {
      ...sellerData,
      id: shopUuid,
      userId: ownerId,
      status: 'pending',
      commissionRate: 10,
      rating: 0,
      createdAt: new Date().toISOString()
    };

    const { error } = await supabase.from('seller_shops').insert({
      id: shopUuid,
      owner_id: ownerId,
      shop_name: newSeller.storeName,
      owner_name: newSeller.ownerName,
      phone: newSeller.phone,
      email: newSeller.email,
      city: newSeller.city,
      state: newSeller.state,
      pincode: newSeller.pincode,
      pickup_address: newSeller.pickupAddress,
      upi_id: newSeller.upiId || null,
      approval_status: 'pending',
      rating: 0
    });
    if (error) throw new Error(`Seller application was not saved: ${error.message}`);

    globalState.sellers.push(newSeller);
    notify();
    return newSeller;
  };

  const approveSeller = async (sellerId: string) => {
    const supabase = getSupabase();
    if (!supabase || globalState.currentUser?.role !== 'admin') {
      throw new Error('Admin authentication and Supabase connection are required.');
    }
    const { data, error } = await supabase
      .from('seller_shops')
      .update({ approval_status: 'approved' })
      .eq('id', sellerId)
      .select('id');
    if (error) throw new Error(`Seller approval failed: ${error.message}`);
    if (!data || data.length === 0) throw new Error('Seller was not approved. Check admin permissions.');
    const seller = globalState.sellers.find((item) => item.id === sellerId);
    if (seller) seller.status = 'approved';
    notify();
  };

  const rejectSeller = async (sellerId: string) => {
    const supabase = getSupabase();
    if (!supabase || globalState.currentUser?.role !== 'admin') {
      throw new Error('Admin authentication and Supabase connection are required.');
    }
    const { data, error } = await supabase
      .from('seller_shops')
      .update({ approval_status: 'rejected' })
      .eq('id', sellerId)
      .select('id');
    if (error) throw new Error(`Seller rejection failed: ${error.message}`);
    if (!data || data.length === 0) throw new Error('Seller was not rejected. Check admin permissions.');
    const seller = globalState.sellers.find((item) => item.id === sellerId);
    if (seller) seller.status = 'rejected';
    notify();
  };

  // Product Management (products table: id UUID, seller_shop_id, product_name, price_inr, stock_quantity)
  const addProduct = async (productData: Omit<Product, 'id' | 'rating' | 'ratingCount' | 'createdAt'>): Promise<Product> => {
    const supabase = getSupabase();
    const currentSeller = globalState.sellers.find((seller) =>
      seller.userId === globalState.currentUser?.id && seller.status === 'approved'
    );
    if (!supabase || !globalState.currentUser?.id || !currentSeller) {
      throw new Error('An approved seller account and active Supabase connection are required to list products.');
    }
    if (productData.sellerId !== currentSeller.id) {
      throw new Error('You can only add products to your own approved seller shop.');
    }
    if (productData.price <= 0 || productData.mrp < productData.price || productData.stock < 0) {
      throw new Error('Check product price, MRP and stock values.');
    }

    const productUuid = generateUuid();
    const discount = productData.mrp > productData.price
      ? Math.round(((productData.mrp - productData.price) / productData.mrp) * 100)
      : 0;
    const newProduct: Product = {
      ...productData,
      id: productUuid,
      rating: 0,
      ratingCount: 0,
      createdAt: new Date().toISOString()
    };

    const { error } = await supabase.from('products').insert({
      id: productUuid,
      seller_shop_id: currentSeller.id,
      product_name: newProduct.title,
      category: newProduct.category,
      image_url: newProduct.imageUrl,
      description: newProduct.description,
      price_inr: newProduct.price,
      discount_percent: discount,
      rating: 0,
      rating_count: 0,
      stock_quantity: newProduct.stock,
    });
    if (error) throw new Error(`Product was not saved: ${error.message}`);

    globalState.products.unshift(newProduct);
    notify();
    return newProduct;
  };

  const deleteProduct = async (productId: string) => {
    const supabase = getSupabase();
    if (!supabase || !isUuid(productId)) {
      throw new Error('A connected database and valid product record are required to delete a listing.');
    }
    const { data, error } = await supabase.from('products').delete().eq('id', productId).select('id');
    if (error) throw new Error(`Product deletion failed: ${error.message}`);
    if (!data || data.length === 0) throw new Error('Product was not deleted. Check seller ownership and permissions.');
    globalState.products = globalState.products.filter((product) => product.id !== productId);
    globalState.cart = globalState.cart.filter((item) => item.product.id !== productId);
    notify();
  };

  // Reviews are persisted by Supabase; database triggers determine verified-purchase status.
  const addReview = async (productId: string, reviewData: {
    customerName: string;
    customerCity?: string;
    rating: number;
    title: string;
    comment: string;
  }): Promise<Review> => {
    const supabase = getSupabase();
    const customerId = globalState.currentUser?.id;
    if (!supabase || !customerId || !isUuid(customerId) || !isUuid(productId)) {
      throw new Error('Sign in and connect Supabase before submitting a review.');
    }
    if (!Number.isInteger(reviewData.rating) || reviewData.rating < 1 || reviewData.rating > 5) {
      throw new Error('Review rating must be between 1 and 5.');
    }
    const { data, error } = await supabase.from('reviews').insert({
      id: generateUuid(),
      product_id: productId,
      customer_id: customerId,
      customer_name: reviewData.customerName.trim(),
      customer_city: reviewData.customerCity?.trim() || null,
      rating: reviewData.rating,
      title: reviewData.title.trim(),
      comment: reviewData.comment.trim(),
      is_verified_buyer: false,
      helpful_count: 0
    }).select('*').single();
    if (error) throw new Error(`Review was not saved: ${error.message}`);
    if (!data) throw new Error('The database did not confirm the review.');

    const savedReview: Review = {
      id: data.id,
      productId: data.product_id,
      customerName: data.customer_name,
      customerCity: data.customer_city || '',
      rating: Number(data.rating),
      title: data.title,
      comment: data.comment,
      isVerifiedBuyer: Boolean(data.is_verified_buyer),
      createdAt: data.created_at,
      helpfulCount: Number(data.helpful_count || 0)
    };
    globalState.reviews.unshift(savedReview);
    notify();
    return savedReview;
  };

  const markReviewHelpful = async (reviewId: string) => {
    const supabase = getSupabase();
    if (!supabase || !isUuid(reviewId) || !globalState.currentUser) {
      throw new Error('Sign in and connect Supabase before voting on a review.');
    }
    const { data: newCount, error } = await supabase.rpc('vote_review_helpful', { p_review_id: reviewId });
    if (error) throw new Error(`Helpful vote was not saved: ${error.message}`);
    if (typeof newCount !== 'number') throw new Error('The database did not confirm the helpful vote.');
    const review = globalState.reviews.find((item) => item.id === reviewId);
    if (review) review.helpfulCount = newCount;
    notify();
  };

  // Filtered views
  const filteredProducts = globalState.products.filter((p) => {
    const matchesSearch =
      !globalState.searchQuery ||
      p.title.toLowerCase().includes(globalState.searchQuery.toLowerCase()) ||
      p.description.toLowerCase().includes(globalState.searchQuery.toLowerCase()) ||
      p.category.toLowerCase().includes(globalState.searchQuery.toLowerCase()) ||
      p.sellerName.toLowerCase().includes(globalState.searchQuery.toLowerCase());

    const matchesCategory =
      !globalState.selectedCategory || p.category === globalState.selectedCategory;

    return matchesSearch && matchesCategory;
  });

  const cartTotalAmount = globalState.cart.reduce(
    (acc, item) => acc + item.product.price * item.quantity,
    0
  );

  const cartTotalMrp = globalState.cart.reduce(
    (acc, item) => acc + item.product.mrp * item.quantity,
    0
  );

  const cartTotalSavings = cartTotalMrp - cartTotalAmount;

  const currentSeller = globalState.sellers.find(
    (s) => s.userId === globalState.currentUser?.id
  );

  const stats = {
    gmv: globalState.orders.reduce((sum, o) => sum + o.totalAmount, 0),
    totalOrders: globalState.orders.length,
    totalSellers: globalState.sellers.length,
    activeProducts: globalState.products.length,
    pendingApprovals: globalState.sellers.filter((s) => s.status === 'pending').length
  };

  return {
    ...state,
    filteredProducts,
    cartTotalAmount,
    cartTotalMrp,
    cartTotalSavings,
    currentSeller,
    stats,
    setActiveRole,
    loginUserWithSupabase,
    logoutUser,
    setSearchQuery,
    setSelectedCategory,
    addToCart,
    updateCartQuantity,
    removeFromCart,
    clearCart,
    toggleWishlist,
    placeOrder,
    updateOrderStatus,
    registerSeller,
    approveSeller,
    rejectSeller,
    addProduct,
    deleteProduct,
    addReview,
    markReviewHelpful
  };
}
