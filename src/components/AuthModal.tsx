import React, { useState } from 'react';
import { X, User, Mail, Phone, Lock, Eye, EyeOff, ShieldCheck, Store, LogIn, AlertCircle, CheckCircle2 } from 'lucide-react';
import { useMarketplace } from '../lib/marketplaceStore';
import { UserRole } from '../types/marketplace';

interface AuthModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export const AuthModal: React.FC<AuthModalProps> = ({ isOpen, onClose }) => {
  const { currentUser, loginUserWithSupabase, logoutUser } = useMarketplace();

  const [isSignUp, setIsSignUp] = useState(false);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [fullName, setFullName] = useState('');
  const [phone, setPhone] = useState('');
  const [role, setRole] = useState<UserRole>('customer');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [errorMessage, setErrorMessage] = useState('');
  const [successMessage, setSuccessMessage] = useState('');

  if (!isOpen) return null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setErrorMessage('');
    setSuccessMessage('');

    if (!email.trim() || !password.trim()) {
      setErrorMessage('Please provide both email and password.');
      return;
    }

    if (password.length < 6) {
      setErrorMessage('Password must be at least 6 characters long.');
      return;
    }

    setIsSubmitting(true);
    const result = await loginUserWithSupabase(
      email.trim(),
      password,
      isSignUp,
      fullName.trim(),
      phone.trim(),
      role
    );
    setIsSubmitting(false);

    if (result.success) {
      setSuccessMessage(result.message);
      setTimeout(() => {
        onClose();
      }, 1000);
    } else {
      setErrorMessage(result.message);
    }
  };

  return (
    <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-xs flex justify-center items-end sm:items-center p-0 sm:p-4">
      <div className="bg-white w-full max-w-sm rounded-t-2xl sm:rounded-2xl flex flex-col overflow-hidden shadow-2xl animate-in slide-in-from-bottom duration-200">
        {/* Header */}
        <div className="px-4 py-3 bg-[#1e3a8a] text-white flex items-center justify-between">
          <div className="flex items-center gap-2">
            <User size={18} className="text-orange-400" />
            <h3 className="font-bold text-sm sm:text-base">
              {currentUser ? 'My SARVEX Profile' : isSignUp ? 'Create SARVEX Account' : 'Sign In to SARVEX'}
            </h3>
          </div>
          <button
            onClick={onClose}
            className="p-1 text-blue-200 hover:text-white rounded-full"
            aria-label="Close"
          >
            <X size={18} />
          </button>
        </div>

        {/* Content */}
        <div className="p-4 space-y-3.5 text-xs">
          {currentUser ? (
            <div className="space-y-3">
              <div className="p-3.5 bg-blue-50 border border-blue-200 rounded-xl space-y-1.5">
                <div className="flex justify-between items-start">
                  <div>
                    <p className="font-bold text-gray-900 text-sm">{currentUser.fullName}</p>
                    <p className="text-gray-600 text-xs">{currentUser.email}</p>
                    {currentUser.phone && (
                      <p className="text-gray-500 font-mono text-xs">+91 {currentUser.phone}</p>
                    )}
                  </div>
                  <span className="text-[10px] font-bold uppercase px-2 py-0.5 rounded-full bg-[#1e3a8a] text-white">
                    {currentUser.role}
                  </span>
                </div>
              </div>

              <button
                onClick={() => {
                  logoutUser();
                  onClose();
                }}
                className="w-full py-2.5 bg-red-50 text-red-700 font-bold rounded-xl border border-red-200 hover:bg-red-100 transition tap-effect"
              >
                Sign Out of SARVEX
              </button>
            </div>
          ) : (
            <form onSubmit={handleSubmit} className="space-y-3">
              {errorMessage && (
                <div className="p-2.5 bg-red-50 border border-red-200 text-red-700 text-xs rounded-xl flex items-center gap-2">
                  <AlertCircle size={15} className="shrink-0" />
                  <span>{errorMessage}</span>
                </div>
              )}

              {successMessage && (
                <div className="p-2.5 bg-emerald-50 border border-emerald-200 text-emerald-800 text-xs rounded-xl flex items-center gap-2">
                  <CheckCircle2 size={15} className="text-emerald-600 shrink-0" />
                  <span>{successMessage}</span>
                </div>
              )}

              {isSignUp && (
                <div>
                  <label className="text-[11px] font-bold text-gray-700 block mb-1">
                    Full Name *
                  </label>
                  <input
                    type="text"
                    required
                    value={fullName}
                    onChange={(e) => setFullName(e.target.value)}
                    placeholder="Your full name"
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-[#1e3a8a] focus:outline-none"
                  />
                </div>
              )}

              <div>
                <label className="text-[11px] font-bold text-gray-700 block mb-1">
                  Email Address *
                </label>
                <input
                  type="email"
                  required
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="name@example.com"
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-[#1e3a8a] focus:outline-none"
                />
              </div>

              <div>
                <label className="text-[11px] font-bold text-gray-700 block mb-1">
                  Password *
                </label>
                <div className="relative">
                  <input
                    type={showPassword ? 'text' : 'password'}
                    required
                    minLength={6}
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    placeholder="At least 6 characters"
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-[#1e3a8a] focus:outline-none"
                  />
                  <button
                    type="button"
                    onClick={() => setShowPassword(!showPassword)}
                    className="absolute right-2.5 top-2.5 text-gray-400 hover:text-gray-600"
                  >
                    {showPassword ? <EyeOff size={15} /> : <Eye size={15} />}
                  </button>
                </div>
              </div>

              {isSignUp && (
                <div>
                  <label className="text-[11px] font-bold text-gray-700 block mb-1">
                    Mobile Number (10 digits)
                  </label>
                  <input
                    type="tel"
                    maxLength={10}
                    value={phone}
                    onChange={(e) => setPhone(e.target.value.replace(/\D/g, ''))}
                    placeholder="10-digit mobile number"
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg font-mono focus:ring-2 focus:ring-[#1e3a8a] focus:outline-none"
                  />
                </div>
              )}

              {/* Role selection on Signup: Buyer or Seller (Admin is protected and cannot be self-selected) */}
              {isSignUp && (
                <div>
                  <label className="text-[11px] font-bold text-gray-700 block mb-1">
                    Account Type:
                  </label>
                  <div className="grid grid-cols-2 gap-1.5">
                    <button
                      key="customer"
                      type="button"
                      onClick={() => setRole('customer')}
                      className={`py-1.5 px-2 rounded-lg font-bold text-[11px] border transition ${
                        role === 'customer'
                          ? 'bg-[#1e3a8a] text-white border-[#1e3a8a]'
                          : 'bg-gray-50 text-gray-700 border-gray-200'
                      }`}
                    >
                      Buyer (Customer)
                    </button>
                    <button
                      key="seller"
                      type="button"
                      onClick={() => setRole('seller')}
                      className={`py-1.5 px-2 rounded-lg font-bold text-[11px] border transition ${
                        role === 'seller'
                          ? 'bg-[#ea580c] text-white border-[#ea580c]'
                          : 'bg-gray-50 text-gray-700 border-gray-200'
                      }`}
                    >
                      Seller Store
                    </button>
                  </div>
                  <span className="text-[10px] text-gray-500 mt-1 block">
                    Seller selection is only an application preference. Seller permissions are granted after an admin-approved shop; admin access cannot be self-selected.
                  </span>
                </div>
              )}

              <button
                type="submit"
                disabled={isSubmitting}
                className="w-full py-3 bg-[#f97316] hover:bg-orange-600 text-white font-black text-xs rounded-xl shadow-md transition tap-effect mt-2 disabled:opacity-50"
              >
                {isSubmitting
                  ? 'Connecting...'
                  : isSignUp
                  ? 'Create SARVEX Account'
                  : 'Sign In Now'}
              </button>

              <div className="text-center pt-2">
                <button
                  type="button"
                  onClick={() => {
                    setIsSignUp(!isSignUp);
                    setErrorMessage('');
                  }}
                  className="text-xs text-[#1e3a8a] font-bold hover:underline"
                >
                  {isSignUp
                    ? 'Already have an account? Sign In'
                    : "New to SARVEX? Create free account"}
                </button>
              </div>
            </form>
          )}
        </div>
      </div>
    </div>
  );
};
