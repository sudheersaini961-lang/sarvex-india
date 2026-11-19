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

// Keep all marketplace writes disabled until the hardened production migration
// is deployed and independently verified against the live Supabase project.
const MARKETPLACE_WRITES_ENABLED = false;

function assertMarketplaceWritesEnabled(): void {
  if (!MARKETPLACE_WRITES_ENABLED) {
    throw new Error('SARVEX marketplace actions are temporarily paused until database security and operational checks are complete.');
  }
}

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
    async function syncSupabase() {
      const supabase = getSupabase();
      if (!supabase) return;

      try {
        // 1. Fetch Sellers / Seller Shops (from existing seller_shops table)
        const { data: dbShops, error: shopsError } = await supabase.from('seller_shops').select('id, owner_id, shop_name, owner_name, phone, email, city, state, pincode, pickup_address, approval_status, commission_rate, rating, created_at');
        if (shopsError) throw shopsError;
        const shopNameMap: Record<string, string> = {};

        if (dbShops) {
          globalState.sellers = dbShops.map((s: any) => {
            const storeName = s.shop_name || s.store_name || 'Store';
            shopNameMap[s.id] = storeName;
            return {
              id: s.id,
              userId: s.owner_id || s.user_id || '',
              storeName,
              ownerName: s.owner_name || 'Verified Merchant',
              phone: s.phone || '',
              email: s.email || '',
              city: s.city || 'India',
              state: s.state || '',
              pincode: s.pincode || '',
              pickupAddress: s.pickup_address || '',
              status: (s.approval_status || s.status || 'pending') as any,
              commissionRate: Number(s.commission_rate || 0),
              rating: Number(s.rating ?? 0),
              createdAt: s.created_at || new Date().toISOString()
            };
          });
          notify();
        }

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
              isCodAvailable: false,
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

          // Do not grant elevated UI roles from a client-readable profile column.
          const assignedRole: UserRole = 'customer';
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
          const { data: dbCart } = await supabase
            .from('cart_items')
            .select('product_id, quantity')
            .eq('owner_id', authUser.id);

          if (dbCart && dbCart.length > 0) {
            const syncedCart: CartItem[] = [];
            for (const item of dbCart) {
              const prod = globalState.products.find((p) => p.id === item.product_id);
              if (prod) syncedCart.push({ product: prod, quantity: item.quantity });
            }
            globalState.cart = syncedCart;
          } else {
            globalState.cart = [];
          }

          // Load orders through customer/admin RLS, or the dedicated seller-safe view.
          const approvedOwnedShop = globalState.sellers.some((seller) =>
            seller.userId === authUser.id && seller.status === 'approved'
          );
          if (MARKETPLACE_WRITES_ENABLED && approvedOwnedShop && assignedRole !== 'admin') {
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

    // Listen to Supabase Auth State Changes
    const supabase = getSupabase();
    if (supabase) {
      const { data: authListener } = supabase.auth.onAuthStateChange(async (event, session) => {
        if (event === 'SIGNED_IN' && session?.user) {
          const authUser = session.user;
          const { data: profile } = await supabase
            .from('customer_profiles')
            .select('*')
            .eq('owner_id', authUser.id)
            .maybeSingle();

          const assignedRole = (profile?.account_role || 'customer') as UserRole;
          globalState.currentUser = {
            id: authUser.id,
            email: authUser.email || '',
            fullName: profile?.display_name || authUser.email?.split('@')[0] || 'User',
            phone: profile?.phone || '',
            role: assignedRole,
            createdAt: authUser.created_at
          };
          globalState.activeRole = assignedRole;
          notify();
        } else if (event === 'SIGNED_OUT') {
          globalState.currentUser = null;
          globalState.activeRole = 'customer';
          globalState.cart = [];
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
          return { success: false, message: 'New account registration is temporarily paused until secure database profile provisioning is deployed and verified.' };

          // 1. Real Supabase Auth Signup
          const { data: authData, error: authErr } = await supabase.auth.signUp({
            email: email.trim(),
            password: password.trim(),
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
            password: password.trim()
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

            // Never trust a client-readable profile role to grant seller/admin access.
            // Role elevation requires a separately verified server-side authorization path.
            const realRole: UserRole = 'customer';
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
    const existingIndex = globalState.cart.findIndex((item) => item.product.id === product.id);
    let newQty = quantity;

    if (existingIndex > -1) {
      const currentQty = globalState.cart[existingIndex].quantity;
      newQty = Math.min(product.stock, currentQty + quantity);
      globalState.cart[existingIndex] = {
        ...globalState.cart[existingIndex],
        quantity: newQty
      };
    } else {
      newQty = Math.min(product.stock, quantity);
      globalState.cart.push({
        product,
        quantity: newQty
      });
    }
    notify();

    // Sync to Supabase cart_items table if user is logged in
    const supabase = getSupabase();
    if (MARKETPLACE_WRITES_ENABLED && supabase && globalState.currentUser?.id && isUuid(globalState.currentUser.id))
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
    if (quantity <= 0) {
      globalState.cart = globalState.cart.filter((item) => item.product.id !== productId);
    } else {
      const item = globalState.cart.find((i) => i.product.id === productId);
      if (item) {
        item.quantity = Math.min(item.product.stock, quantity);
      }
    }
    notify();

    const supabase = getSupabase();
    if (MARKETPLACE_WRITES_ENABLED && supabase && globalState.currentUser?.id && isUuid(globalState.currentUser.id)) {
      try {
        if (quantity <= 0) {
          await supabase.from('cart_items').delete().eq('owner_id', globalState.currentUser.id).eq('product_id', productId);
        } else {
          await supabase.from('cart_items').update({
            quantity,
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
    if (MARKETPLACE_WRITES_ENABLED && supabase && globalState.currentUser?.id && isUuid(globalState.currentUser.id)) {
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
    if (MARKETPLACE_WRITES_ENABLED && supabase && globalState.currentUser?.id && isUuid(globalState.currentUser.id)) {
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
    if (MARKETPLACE_WRITES_ENABLED && supabase && globalState.currentUser?.id && isUuid(globalState.currentUser.id)) {
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

  // Checkout is intentionally fail-closed until the production schema,
  // payment collection, delivery, returns/refunds and reconciliation are verified.
  const placeOrder = async (_orderData: {
    customerName: string;
    customerPhone: string;
    customerEmail?: string;
    shippingAddress: string;
    city: string;
    state: string;
    pincode: string;
  }): Promise<Order> => {
    throw new Error('SARVEX checkout is temporarily unavailable. No order has been placed.');
  };

  const updateOrderStatus = async (orderId: string, nextStatus: OrderStatus, note?: string) => {
    assertMarketplaceWritesEnabled();
    const supabase = getSupabase();
    if (!supabase) throw new Error('Supabase is not connected. Order status cannot be changed offline.');
    const order = globalState.orders.find((item) => item.id === orderId || item.databaseId === orderId);
    if (!order) throw new Error('Order not found in the current database-backed state.');
    const itemIds = order.items.map((item) => item.id).filter(isUuid);
    if (itemIds.length === 0) throw new Error('No database order-item records are available for fulfillment.');

    // Seller RLS permits status updates only on order_items belonging to their own shop.
    const { data, error } = await supabase
      .from('order_items')
      .update({ item_status: nextStatus })
      .in('id', itemIds)
      .select('id');
    if (error) throw new Error(`Order item status was not saved: ${error.message}`);
    if (!data || data.length === 0) throw new Error('No order items were updated. Check seller ownership and permissions.');

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
    assertMarketplaceWritesEnabled();
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
    assertMarketplaceWritesEnabled();
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
    assertMarketplaceWritesEnabled();
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
    assertMarketplaceWritesEnabled();
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
    assertMarketplaceWritesEnabled();
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
    assertMarketplaceWritesEnabled();
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
    assertMarketplaceWritesEnabled();
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
