export type UserRole = 'customer' | 'seller' | 'admin';

export interface UserProfile {
  id: string;
  email: string;
  fullName: string;
  phone: string;
  role: UserRole;
  avatarUrl?: string;
  createdAt: string;
}

export type SellerStatus = 'pending' | 'approved' | 'rejected';

export interface Seller {
  id: string;
  userId: string;
  storeName: string;
  ownerName: string;
  phone: string;
  email: string;
  city: string;
  state: string;
  pincode: string;
  pickupAddress: string;
  bankAccount?: string;
  ifscCode?: string;
  upiId?: string;
  status: SellerStatus;
  commissionRate: number; // 0 for zero-fee marketplace
  rating: number;
  createdAt: string;
}

export interface Category {
  id: string;
  name: string;
  slug: string;
  iconName: string;
  imageUrl: string;
  itemCount: number;
}

export interface Product {
  id: string;
  sellerId: string;
  sellerName: string;
  title: string;
  description: string;
  category: string;
  price: number; // Current selling price in INR (₹)
  mrp: number; // Original Maximum Retail Price in INR (₹)
  stock: number;
  imageUrl: string;
  badge?: string; // e.g. "SARVEX Assured", "Bestseller", "Deal of the Day"
  rating: number;
  ratingCount: number;
  isCodAvailable: boolean;
  isFeatured?: boolean;
  createdAt: string;
}

export interface Review {
  id: string;
  productId: string;
  customerName: string;
  customerCity?: string;
  rating: number; // 1 to 5
  title: string;
  comment: string;
  isVerifiedBuyer: boolean;
  createdAt: string;
  helpfulCount: number;
}

export interface CartItem {
  product: Product;
  quantity: number;
}

export type OrderStatus =
  | 'placed'
  | 'confirmed'
  | 'packed'
  | 'shipped'
  | 'out_for_delivery'
  | 'delivered'
  | 'cancelled';

export interface OrderItem {
  id: string;
  productId: string;
  sellerId: string;
  title: string;
  price: number;
  quantity: number;
  imageUrl: string;
}

export interface Order {
  id: string; // Human-readable order code shown to customers
  databaseId?: string; // Supabase UUID used for database updates
  customerId: string;
  customerName: string;
  customerPhone: string;
  customerEmail?: string;
  shippingAddress: string;
  city: string;
  state: string;
  pincode: string;
  items: OrderItem[];
  totalAmount: number;
  paymentMethod: 'cod';
  status: OrderStatus;
  statusHistory: {
    status: OrderStatus;
    timestamp: string;
    note: string;
  }[];
  createdAt: string;
}

export interface MarketplaceStats {
  gmv: number;
  totalOrders: number;
  totalSellers: number;
  activeProducts: number;
  pendingApprovals: number;
}
