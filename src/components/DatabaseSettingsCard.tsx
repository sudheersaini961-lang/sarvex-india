import React, { useState, useEffect } from 'react';
import {
  Database,
  CheckCircle2,
  XCircle,
  RefreshCw,
  ShieldCheck,
  AlertTriangle,
  Trash2,
  Eye,
  EyeOff
} from 'lucide-react';
import {
  getStoredSupabaseConfig,
  saveSupabaseConfig,
  clearSupabaseConfig,
  testSupabaseConnection,
  isSafeSupabaseAnonKey,
  isValidSupabaseProjectUrl
} from '../lib/supabaseClient';

interface DatabaseSettingsCardProps {
  onSuccess?: () => void;
  className?: string;
}

export const DatabaseSettingsCard: React.FC<DatabaseSettingsCardProps> = ({
  onSuccess,
  className = '',
}) => {
  const [config, setConfig] = useState(getStoredSupabaseConfig());
  const [url, setUrl] = useState(config.url);
  const [anonKey, setAnonKey] = useState(config.key);
  const [showKey, setShowKey] = useState(false);
  const [isTesting, setIsTesting] = useState(false);
  const [resultStatus, setResultStatus] = useState<{
    success?: boolean;
    message?: string;
  } | null>(null);

  // Re-read config when custom event fires
  useEffect(() => {
    const handleUpdate = () => {
      const updated = getStoredSupabaseConfig();
      setConfig(updated);
      setUrl(updated.url);
      setAnonKey(updated.key);
    };

    window.addEventListener('sarvex:supabase_config_changed', handleUpdate);
    return () => {
      window.removeEventListener('sarvex:supabase_config_changed', handleUpdate);
    };
  }, []);

  const handleTestConnection = async () => {
    setIsTesting(true);
    setResultStatus(null);

    const testRes = await testSupabaseConnection(url.trim(), anonKey.trim());
    setIsTesting(false);
    setResultStatus(testRes);

    if (testRes.success) {
      saveSupabaseConfig(url.trim(), anonKey.trim());
      if (onSuccess) onSuccess();
    }
  };

  const handleSaveOnly = () => {
    if (!url.trim() || !anonKey.trim()) {
      setResultStatus({
        success: false,
        message: 'Please provide both Supabase Project URL and Anon Public Key.'
      });
      return;
    }

    if (!isValidSupabaseProjectUrl(url.trim())) {
      setResultStatus({
        success: false,
        message: 'Invalid Supabase Project URL. Use the exact HTTPS project URL ending in .supabase.co.'
      });
      return;
    }

    if (!isSafeSupabaseAnonKey(anonKey.trim())) {
      setResultStatus({
        success: false,
        message: 'Unsafe or unsupported API key. Use a Supabase publishable key or legacy anon JWT key only. Never use a secret/service_role key.'
      });
      return;
    }

    saveSupabaseConfig(url.trim(), anonKey.trim());
    setResultStatus({
      success: true,
      message: 'Configuration saved! Click "Test Connection" to verify real connectivity.'
    });
  };

  const handleDisconnect = () => {
    clearSupabaseConfig();
    setUrl('');
    setAnonKey('');
    setResultStatus({
      success: false,
      message: 'Supabase configuration cleared. Marketplace transactions remain disabled until a real database is connected.'
    });
  };



  return (
    <div className={`bg-white border-2 border-[#1e3a8a]/20 rounded-2xl p-4 shadow-sm space-y-3.5 ${className}`}>
      {/* Title & Status Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 border-b border-gray-100 pb-3">
        <div className="flex items-center gap-2">
          <div className="p-2 bg-blue-50 text-[#1e3a8a] rounded-xl border border-blue-100">
            <Database size={20} />
          </div>
          <div>
            <h3 className="font-bold text-sm sm:text-base text-gray-900 leading-tight">
              Database Settings
            </h3>
            <p className="text-[11px] text-gray-500">
              Supabase Cloud PostgreSQL Database (Free Tier)
            </p>
          </div>
        </div>

        {/* Live Status Badge */}
        <div className="self-start sm:self-auto">
          {config.isConfigured ? (
            <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-bold bg-emerald-50 text-emerald-800 border border-emerald-300">
              <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse"></span>
              <span>Status: Configured — test required</span>
            </span>
          ) : (
            <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-bold bg-amber-50 text-amber-800 border border-amber-300">
              <span className="w-2 h-2 rounded-full bg-amber-500"></span>
              <span>Status: Not Configured</span>
            </span>
          )}
        </div>
      </div>

      {/* Info Notice */}
      <div className="bg-blue-50/70 border border-blue-100 rounded-xl p-3 text-xs text-[#1e3a8a] space-y-1">
        <div className="flex items-center gap-1.5 font-bold">
          <ShieldCheck size={14} className="text-[#f97316]" />
          <span>Supabase Configuration</span>
        </div>
        <p className="text-[11px] text-gray-600 leading-normal">
Connect a Supabase project and run the approved migration before using marketplace transactions. Configuration alone does not prove database connectivity. Local browser storage is only a temporary cache and is not an order or account database.
        </p>
      </div>

      {/* Real Response Alert */}
      {resultStatus && (
        <div
          className={`p-3 rounded-xl border text-xs font-semibold flex items-start gap-2 ${
            resultStatus.success
              ? 'bg-emerald-50 border-emerald-200 text-emerald-800'
              : 'bg-red-50 border-red-200 text-red-700'
          }`}
        >
          {resultStatus.success ? (
            <CheckCircle2 size={16} className="text-emerald-600 shrink-0 mt-0.5" />
          ) : (
            <XCircle size={16} className="text-red-600 shrink-0 mt-0.5" />
          )}
          <div className="flex-1 leading-normal">
            <span>{resultStatus.message}</span>
          </div>
        </div>
      )}

      {/* Configuration Input Fields */}
      <div className="space-y-3">
        {/* Project URL */}
        <div>
          <label className="text-[11px] font-bold text-gray-700 block mb-1">
            Supabase Project URL *
          </label>
          <input
            type="url"
            value={url}
            onChange={(e) => setUrl(e.target.value)}
            placeholder="https://xyzabcdefg.supabase.co"
            className="w-full text-xs px-3 py-2 border border-gray-300 rounded-lg font-mono focus:ring-2 focus:ring-[#1e3a8a] focus:outline-none bg-white text-gray-900"
          />
          <span className="text-[10px] text-gray-400 mt-0.5 block">
            Found in Supabase: Project Settings → API → Project URL
          </span>
        </div>

        {/* Anon Public Key */}
        <div>
          <div className="flex items-center justify-between mb-1">
            <label className="text-[11px] font-bold text-gray-700">
              Supabase Anon Public API Key *
            </label>
            <button
              type="button"
              onClick={() => setShowKey(!showKey)}
              className="text-[10px] text-blue-700 hover:underline flex items-center gap-0.5"
            >
              {showKey ? <EyeOff size={11} /> : <Eye size={11} />}
              <span>{showKey ? 'Hide Key' : 'Reveal Key'}</span>
            </button>
          </div>
          <div className="relative">
            <input
              type={showKey ? 'text' : 'password'}
              value={anonKey}
              onChange={(e) => setAnonKey(e.target.value)}
              placeholder="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
              className="w-full text-xs px-3 py-2 border border-gray-300 rounded-lg font-mono focus:ring-2 focus:ring-[#1e3a8a] focus:outline-none bg-white text-gray-900"
            />
          </div>
          {/* Security Guarantee Notice */}
          <div className="flex items-center gap-1 mt-1 text-[10px] text-amber-700 font-medium">
            <AlertTriangle size={11} className="shrink-0" />
            <span>Use the safe "anon" public key only. Never provide the secret "service_role" key.</span>
          </div>
        </div>
      </div>

      {/* Buttons Row */}
      <div className="flex flex-wrap items-center gap-2 pt-1 border-t border-gray-100">
        <button
          type="button"
          onClick={handleTestConnection}
          disabled={isTesting || !url.trim() || !anonKey.trim()}
          className="flex-1 py-2.5 px-3 bg-[#1e3a8a] hover:bg-blue-800 text-white font-bold text-xs rounded-xl shadow-xs transition tap-effect flex items-center justify-center gap-1.5 disabled:opacity-50"
        >
          {isTesting ? (
            <>
              <RefreshCw size={14} className="animate-spin" />
              <span>Testing Real Connection...</span>
            </>
          ) : (
            <>
              <CheckCircle2 size={14} />
              <span>Test Connection</span>
            </>
          )}
        </button>

        <button
          type="button"
          onClick={handleSaveOnly}
          disabled={!url.trim() || !anonKey.trim()}
          className="py-2.5 px-3 bg-[#f97316] hover:bg-orange-600 text-white font-bold text-xs rounded-xl shadow-xs transition tap-effect disabled:opacity-50"
        >
          Save
        </button>

        {config.isConfigured && (
          <button
            type="button"
            onClick={handleDisconnect}
            className="py-2.5 px-3 bg-red-50 text-red-700 hover:bg-red-100 font-bold text-xs rounded-xl border border-red-200 transition tap-effect flex items-center gap-1"
            title="Clear saved Supabase configuration"
          >
            <Trash2 size={13} />
            <span>Disconnect</span>
          </button>
        )}
      </div>


    </div>
  );
};
