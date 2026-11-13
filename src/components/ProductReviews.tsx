import React, { useState } from 'react';
import {
  Star,
  CheckCircle2,
  ThumbsUp,
  MessageSquare,
  PenTool,
  ShieldCheck,
  ChevronDown,
  ChevronUp,
  Send
} from 'lucide-react';
import { useMarketplace } from '../lib/marketplaceStore';
import { Review } from '../types/marketplace';

interface ProductReviewsProps {
  productId: string;
}

const RATING_LABELS: Record<number, string> = {
  1: 'Poor',
  2: 'Fair',
  3: 'Good',
  4: 'Very Good',
  5: 'Excellent'
};

export const ProductReviews: React.FC<ProductReviewsProps> = ({ productId }) => {
  const { reviews, addReview, markReviewHelpful, currentUser } = useMarketplace();

  // Filter reviews for this product
  const productReviews = reviews.filter((r) => r.productId === productId);

  // Form states
  const [showReviewForm, setShowReviewForm] = useState(false);
  const [selectedRating, setSelectedRating] = useState<number>(5);
  const [hoverRating, setHoverRating] = useState<number | null>(null);
  const [title, setTitle] = useState('');
  const [comment, setComment] = useState('');
  const [customerName, setCustomerName] = useState(currentUser?.fullName || '');
  const [customerCity, setCustomerCity] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [successNotice, setSuccessNotice] = useState('');
  const [votedReviews, setVotedReviews] = useState<Record<string, boolean>>({});

  // Calculations for rating breakdown
  const totalReviewsCount = productReviews.length;
  const averageRating = totalReviewsCount > 0
    ? Number((productReviews.reduce((sum, r) => sum + r.rating, 0) / totalReviewsCount).toFixed(1))
    : 0;

  const starCounts: Record<number, number> = { 5: 0, 4: 0, 3: 0, 2: 0, 1: 0 };
  productReviews.forEach((r) => {
    if (starCounts[r.rating] !== undefined) {
      starCounts[r.rating] += 1;
    }
  });

  const handleSubmitReview = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!currentUser || !title.trim() || !comment.trim()) return;
    setIsSubmitting(true);
    try {
      await addReview(productId, {
        customerName: customerName.trim() || currentUser.fullName,
        customerCity: customerCity.trim() || undefined,
        rating: selectedRating,
        title: title.trim(),
        comment: comment.trim()
      });
      setTitle('');
      setComment('');
      setShowReviewForm(false);
      setSuccessNotice('Your review was saved to the database. Verified-purchase status is determined by the database.');
      setTimeout(() => setSuccessNotice(''), 4000);
    } catch (error: any) {
      setSuccessNotice(error?.message || 'Review could not be saved.');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleHelpfulClick = (reviewId: string) => {
    if (votedReviews[reviewId]) return;
    void markReviewHelpful(reviewId).catch((error) => setSuccessNotice(error?.message || 'Vote could not be saved.'));
    setVotedReviews((prev) => ({ ...prev, [reviewId]: true }));
  };

  return (
    <div className="border-t border-gray-200 pt-4 space-y-4">
      {/* Top Header */}
      <div className="flex items-center justify-between">
        <div>
          <h3 className="text-xs font-bold text-gray-900 uppercase tracking-wider flex items-center gap-1.5">
            <Star size={15} className="fill-[#f97316] text-[#f97316]" />
            Customer Ratings & Reviews
          </h3>
          <p className="text-[11px] text-gray-500">
            {totalReviewsCount} Verified buyer ratings from Indian customers
          </p>
        </div>

        <button
          onClick={() => setShowReviewForm(!showReviewForm)}
          className="flex items-center gap-1 px-3 py-1.5 bg-[#1e3a8a] text-white text-xs font-bold rounded-lg shadow-xs hover:bg-blue-800 transition tap-effect"
        >
          <PenTool size={13} />
          <span>{showReviewForm ? 'Close Form' : 'Rate Product'}</span>
        </button>
      </div>

      {successNotice && (
        <div className="p-3 bg-emerald-50 border border-emerald-200 text-emerald-800 text-xs rounded-xl font-bold flex items-center gap-2">
          <CheckCircle2 size={16} className="text-emerald-600 shrink-0" />
          <span>{successNotice}</span>
        </div>
      )}

      {/* Review Form (Expandable) */}
      {showReviewForm && (
        <form
          onSubmit={handleSubmitReview}
          className="bg-amber-50/50 border border-amber-200/80 rounded-xl p-3.5 space-y-3 animate-in slide-in-from-top-2 duration-150"
        >
          <div className="flex items-center justify-between border-b border-amber-200/50 pb-2">
            <h4 className="text-xs font-bold text-[#1e3a8a] flex items-center gap-1.5">
              <Star size={14} className="fill-amber-500 text-amber-500" /> Write a Verified Product Review
            </h4>
            <span className="text-[10px] font-bold text-emerald-700 bg-emerald-100 px-1.5 py-0.5 rounded flex items-center gap-0.5">
              <ShieldCheck size={11} /> Verified Buyer
            </span>
          </div>

          {/* Star selector */}
          <div>
            <label className="text-[11px] font-bold text-gray-700 block mb-1">
              Select Your Rating *
            </label>
            <div className="flex items-center gap-2">
              <div className="flex items-center gap-1 bg-white p-1.5 rounded-lg border border-gray-300">
                {[1, 2, 3, 4, 5].map((starValue) => {
                  const isActive = (hoverRating !== null ? hoverRating : selectedRating) >= starValue;
                  return (
                    <button
                      key={starValue}
                      type="button"
                      onMouseEnter={() => setHoverRating(starValue)}
                      onMouseLeave={() => setHoverRating(null)}
                      onClick={() => setSelectedRating(starValue)}
                      className="p-1 transition-transform hover:scale-110"
                      aria-label={`${starValue} stars`}
                    >
                      <Star
                        size={22}
                        className={
                          isActive
                            ? 'fill-amber-400 text-amber-500'
                            : 'text-gray-300'
                        }
                      />
                    </button>
                  );
                })}
              </div>
              <span className="text-xs font-bold text-gray-800">
                {RATING_LABELS[hoverRating !== null ? hoverRating : selectedRating]}
              </span>
            </div>
          </div>

          {/* Title */}
          <div>
            <label className="text-[11px] font-bold text-gray-700 block mb-1">
              Review Title / Headline *
            </label>
            <input
              type="text"
              required
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              placeholder="e.g. Excellent sound quality & quick delivery!"
              className="w-full text-xs px-3 py-2 border border-gray-300 rounded-lg bg-white focus:ring-2 focus:ring-[#1e3a8a] focus:outline-none"
            />
          </div>

          {/* Detailed comment */}
          <div>
            <label className="text-[11px] font-bold text-gray-700 block mb-1">
              Detailed Experience *
            </label>
            <textarea
              required
              rows={3}
              value={comment}
              onChange={(e) => setComment(e.target.value)}
              placeholder="What did you like about the product? How is the build, packaging, or value for money?"
              className="w-full text-xs px-3 py-2 border border-gray-300 rounded-lg bg-white focus:ring-2 focus:ring-[#1e3a8a] focus:outline-none"
            />
          </div>

          {/* Customer Name & City */}
          <div className="grid grid-cols-2 gap-2">
            <div>
              <label className="text-[11px] font-bold text-gray-700 block mb-1">
                Your Name
              </label>
              <input
                type="text"
                value={customerName}
                onChange={(e) => setCustomerName(e.target.value)}
                placeholder="Your name"
                className="w-full text-xs px-2.5 py-1.5 border border-gray-300 rounded-lg bg-white focus:ring-2 focus:ring-[#1e3a8a] focus:outline-none"
              />
            </div>
            <div>
              <label className="text-[11px] font-bold text-gray-700 block mb-1">
                City / Town
              </label>
              <input
                type="text"
                value={customerCity}
                onChange={(e) => setCustomerCity(e.target.value)}
                placeholder="Jaipur / Delhi"
                className="w-full text-xs px-2.5 py-1.5 border border-gray-300 rounded-lg bg-white focus:ring-2 focus:ring-[#1e3a8a] focus:outline-none"
              />
            </div>
          </div>

          {/* Submit */}
          <div className="flex justify-end gap-2 pt-1">
            <button
              type="button"
              onClick={() => setShowReviewForm(false)}
              className="px-3 py-1.5 text-xs font-semibold text-gray-600 bg-white border border-gray-300 rounded-lg hover:bg-gray-50"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={isSubmitting || !title.trim() || !comment.trim()}
              className="px-4 py-1.5 text-xs font-bold text-white bg-[#f97316] hover:bg-orange-600 rounded-lg shadow-sm transition tap-effect flex items-center gap-1.5 disabled:opacity-50"
            >
              <Send size={13} />
              <span>{isSubmitting ? 'Submitting...' : 'Submit Review'}</span>
            </button>
          </div>
        </form>
      )}

      {/* Ratings Scorecard & Progress Bars */}
      <div className="bg-gray-50 border border-gray-200 rounded-xl p-3.5 flex flex-col sm:flex-row items-center gap-4">
        {/* Left: Overall Score */}
        <div className="text-center sm:text-left sm:pr-4 sm:border-r border-gray-200 shrink-0">
          <div className="flex items-center justify-center sm:justify-start gap-1">
            <span className="text-3xl font-black text-gray-900 leading-none">
              {averageRating}
            </span>
            <Star size={24} className="fill-emerald-600 text-emerald-600" />
          </div>
          <p className="text-xs font-bold text-emerald-700 mt-1">
            {averageRating >= 4.5 ? 'Very Good' : averageRating >= 4 ? 'Good' : 'Satisfactory'}
          </p>
          <p className="text-[10px] text-gray-500">
            Based on {totalReviewsCount} ratings
          </p>
        </div>

        {/* Right: Progress bars 5 down to 1 */}
        <div className="flex-1 w-full space-y-1.5 text-xs">
          {[5, 4, 3, 2, 1].map((stars) => {
            const count = starCounts[stars] || 0;
            const pct = totalReviewsCount > 0 ? Math.round((count / totalReviewsCount) * 100) : 0;
            return (
              <div key={stars} className="flex items-center gap-2">
                <span className="w-6 text-[11px] font-bold text-gray-700 flex items-center justify-end gap-0.5">
                  {stars} <Star size={9} className="fill-amber-500 text-amber-500" />
                </span>
                <div className="flex-1 h-2 bg-gray-200 rounded-full overflow-hidden">
                  <div
                    className={`h-full rounded-full transition-all duration-300 ${
                      stars >= 4
                        ? 'bg-emerald-600'
                        : stars === 3
                        ? 'bg-amber-500'
                        : 'bg-red-500'
                    }`}
                    style={{ width: `${pct}%` }}
                  />
                </div>
                <span className="w-8 text-[10px] text-gray-500 text-right font-medium">
                  {count}
                </span>
              </div>
            );
          })}
        </div>
      </div>

      {/* Customer Reviews Feed */}
      <div className="space-y-3">
        {productReviews.length === 0 ? (
          <div className="text-center py-6 bg-gray-50 rounded-xl border border-gray-100 p-4">
            <MessageSquare size={28} className="mx-auto text-gray-400 mb-1.5" />
            <h4 className="font-bold text-xs text-gray-800">No reviews yet for this product</h4>
            <p className="text-[11px] text-gray-500 mb-2">
              Have you purchased this item? Be the first to share your experience with buyers across India!
            </p>
            <button
              onClick={() => setShowReviewForm(true)}
              className="text-xs text-[#1e3a8a] font-bold underline"
            >
              Write the First Review
            </button>
          </div>
        ) : (
          productReviews.map((rev) => {
            const hasVoted = Boolean(votedReviews[rev.id]);
            return (
              <div
                key={rev.id}
                className="bg-white border border-gray-200 rounded-xl p-3.5 space-y-2 shadow-xs"
              >
                {/* Header: Rating & Title */}
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <span
                      className={`flex items-center gap-0.5 text-white text-[10px] font-black px-1.5 py-0.5 rounded ${
                        rev.rating >= 4
                          ? 'bg-emerald-700'
                          : rev.rating === 3
                          ? 'bg-amber-600'
                          : 'bg-red-600'
                      }`}
                    >
                      {rev.rating} <Star size={9} className="fill-white" />
                    </span>
                    <h5 className="text-xs font-bold text-gray-900 leading-snug">
                      {rev.title}
                    </h5>
                  </div>
                  <span className="text-[10px] text-gray-400">
                    {new Date(rev.createdAt).toLocaleDateString('en-IN', {
                      day: 'numeric',
                      month: 'short'
                    })}
                  </span>
                </div>

                {/* Body comment */}
                <p className="text-xs text-gray-700 leading-relaxed font-normal">
                  {rev.comment}
                </p>

                {/* Footer: Verified Buyer & Helpful button */}
                <div className="flex items-center justify-between pt-1 border-t border-gray-100 text-[11px]">
                  <div className="flex items-center gap-2 text-gray-500">
                    <span className="font-semibold text-gray-700">
                      {rev.customerName}
                    </span>
                    {rev.customerCity && (
                      <span className="text-gray-400">• {rev.customerCity}</span>
                    )}
                    {rev.isVerifiedBuyer && (
                      <span className="text-[10px] font-bold text-emerald-700 bg-emerald-50 px-1.5 py-0.2 rounded flex items-center gap-0.5">
                        <CheckCircle2 size={10} className="text-emerald-600" />
                        Verified Purchase
                      </span>
                    )}
                  </div>

                  <button
                    onClick={() => handleHelpfulClick(rev.id)}
                    className={`flex items-center gap-1 text-[10px] font-bold px-2 py-0.5 rounded transition ${
                      hasVoted
                        ? 'bg-blue-50 text-[#1e3a8a]'
                        : 'text-gray-500 hover:text-gray-800 hover:bg-gray-100'
                    }`}
                  >
                    <ThumbsUp size={11} className={hasVoted ? 'fill-[#1e3a8a]' : ''} />
                    <span>Helpful ({rev.helpfulCount})</span>
                  </button>
                </div>
              </div>
            );
          })
        )}
      </div>
    </div>
  );
};
