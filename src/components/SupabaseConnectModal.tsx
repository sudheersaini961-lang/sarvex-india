import React from 'react';
import { X, Database } from 'lucide-react';
import { DatabaseSettingsCard } from './DatabaseSettingsCard';

interface SupabaseConnectModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export const SupabaseConnectModal: React.FC<SupabaseConnectModalProps> = ({
  isOpen,
  onClose,
}) => {
  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-xs flex justify-center items-end sm:items-center p-0 sm:p-4">
      <div className="bg-white w-full max-w-lg max-h-[92vh] rounded-t-2xl sm:rounded-2xl flex flex-col overflow-hidden shadow-2xl animate-in slide-in-from-bottom duration-200">
        {/* Header */}
        <div className="px-4 py-3 bg-[#1e3a8a] text-white flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Database size={20} className="text-orange-400" />
            <div>
              <h3 className="font-bold text-sm sm:text-base">Database Settings</h3>
              <p className="text-[11px] text-blue-200">Supabase Cloud PostgreSQL Connection</p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-1 text-blue-200 hover:text-white rounded-full"
            aria-label="Close"
          >
            <X size={20} />
          </button>
        </div>

        {/* Scrollable Body */}
        <div className="flex-1 overflow-y-auto p-4">
          <DatabaseSettingsCard onSuccess={onClose} />
        </div>

        {/* Footer */}
        <div className="p-3 bg-white border-t border-gray-200">
          <button
            onClick={onClose}
            className="w-full py-2 bg-gray-100 hover:bg-gray-200 text-gray-800 font-bold text-xs rounded-xl transition tap-effect"
          >
            Done
          </button>
        </div>
      </div>
    </div>
  );
};
