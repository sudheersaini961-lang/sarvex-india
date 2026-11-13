import React, { useState, useEffect } from 'react';
import { ChevronRight, ChevronLeft, ShieldCheck, Truck, Percent, Store } from 'lucide-react';

interface BannerSliderProps {
  onRegisterSellerClick: () => void;
  onExploreDealsClick: () => void;
}

export const BannerSlider: React.FC<BannerSliderProps> = ({
  onRegisterSellerClick,
  onExploreDealsClick,
}) => {
  const [currentSlide, setCurrentSlide] = useState(0);

  const banners = [
    {
      id: 1,
      bg: 'from-[#1e3a8a] via-[#1d4ed8] to-[#1e3a8a]',
      accentBg: 'bg-[#f97316]',
      tag: 'SARVEX MARKETPLACE',
      title: 'Discover Products Across Categories',
      subtitle: 'Browse marketplace categories and view products listed by approved sellers.',
      featureIcon: Truck,
      featureText: 'Cash on Delivery availability depends on the listing.',
      ctaText: 'Shop Best Deals',
      onCta: onExploreDealsClick
    },
    {
      id: 2,
      bg: 'from-[#ea580c] via-[#f97316] to-[#c2410c]',
      accentBg: 'bg-[#1e3a8a]',
      tag: 'SELLER ONBOARDING',
      title: 'Start Selling on SARVEX India',
      subtitle: 'Apply for a seller account. Product listing is enabled only after approval.',
      featureIcon: Store,
      featureText: 'Seller applications are subject to admin review.',
      ctaText: 'Register as Seller',
      onCta: onRegisterSellerClick
    },
    {
      id: 3,
      bg: 'from-[#0f172a] via-[#1e293b] to-[#1e3a8a]',
      accentBg: 'bg-[#22c55e]',
      tag: 'ORDER INFORMATION',
      title: 'Cash on Delivery Where Available',
      subtitle: 'Payment and return terms will be shown only when configured for a real listing.',
      featureIcon: ShieldCheck,
      featureText: 'Seller verification and return policies are being configured.',
      ctaText: 'Explore Categories',
      onCta: onExploreDealsClick
    }
  ];

  useEffect(() => {
    const timer = setInterval(() => {
      setCurrentSlide((prev) => (prev + 1) % banners.length);
    }, 4500);
    return () => clearInterval(timer);
  }, [banners.length]);

  return (
    <div className="relative overflow-hidden mx-3 mt-3 rounded-2xl shadow-md">
      <div
        className="flex transition-transform duration-500 ease-out"
        style={{ transform: `translateX(-${currentSlide * 100}%)` }}
      >
        {banners.map((banner) => {
          const Icon = banner.featureIcon;
          return (
            <div
              key={banner.id}
              className={`min-w-full bg-gradient-to-r ${banner.bg} text-white p-4 sm:p-6 flex flex-col justify-between`}
            >
              <div>
                <span className={`inline-block ${banner.accentBg} text-white text-[10px] font-black uppercase tracking-wider px-2 py-0.5 rounded-full mb-2`}>
                  {banner.tag}
                </span>
                <h2 className="text-lg sm:text-2xl font-black tracking-tight leading-tight mb-1 text-white">
                  {banner.title}
                </h2>
                <p className="text-xs sm:text-sm text-blue-100/90 font-normal max-w-sm mb-3">
                  {banner.subtitle}
                </p>
              </div>

              <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2.5 pt-2 border-t border-white/15">
                <div className="flex items-center gap-1.5 text-xs text-white/90">
                  <Icon size={16} className="text-amber-300 shrink-0" />
                  <span className="text-[11px] sm:text-xs font-medium">{banner.featureText}</span>
                </div>
                <button
                  onClick={banner.onCta}
                  className="self-start sm:self-auto px-3.5 py-1.5 bg-white text-gray-900 font-bold text-xs rounded-lg shadow hover:bg-gray-100 transition tap-effect flex items-center gap-1"
                >
                  <span>{banner.ctaText}</span>
                  <ChevronRight size={14} />
                </button>
              </div>
            </div>
          );
        })}
      </div>

      {/* Dots Indicator */}
      <div className="absolute bottom-2 right-3 flex items-center gap-1.5">
        {banners.map((_, idx) => (
          <button
            key={idx}
            onClick={() => setCurrentSlide(idx)}
            className={`h-1.5 rounded-full transition-all ${
              currentSlide === idx ? 'w-5 bg-white' : 'w-1.5 bg-white/40'
            }`}
            aria-label={`Go to slide ${idx + 1}`}
          />
        ))}
      </div>
    </div>
  );
};
