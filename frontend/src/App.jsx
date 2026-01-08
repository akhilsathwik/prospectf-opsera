import { useState, useEffect } from 'react'
import axios from 'axios'
import { motion, AnimatePresence } from 'framer-motion'
import { Send, Zap, MessageCircle, Loader2, AlertCircle, CheckCircle2, Settings, Key, Eye, EyeOff, X } from 'lucide-react'
import { cn } from './lib/utils'

// Use relative URLs in production - nginx will proxy to backend service
// In Kubernetes, nginx proxies /api, /test, /chat, /admin to backend
// For local development, use http://localhost:8000
// Check if we're in production build (Vite sets NODE_ENV during build)
const API_URL = typeof window !== 'undefined' && window.location.hostname !== 'localhost' ? '' : 'http://localhost:8000'

function App() {
  const [message, setMessage] = useState('')
  const [chatResponse, setChatResponse] = useState('')
  const [testResponse, setTestResponse] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')

  // Admin settings state
  const [showSettings, setShowSettings] = useState(false)
  const [apiKey, setApiKey] = useState('')
  const [showApiKey, setShowApiKey] = useState(false)
  const [apiKeyStatus, setApiKeyStatus] = useState({ configured: false, source: null })
  const [settingsLoading, setSettingsLoading] = useState(false)
  const [settingsMessage, setSettingsMessage] = useState('')

  // Check API key status on mount
  useEffect(() => {
    checkApiKeyStatus()
  }, [])

  const checkApiKeyStatus = async () => {
    try {
      const response = await axios.get(`${API_URL}/admin/api-key/status`)
      setApiKeyStatus(response.data)
    } catch (err) {
      console.error('Failed to check API key status')
    }
  }

  const saveApiKey = async () => {
    if (!apiKey.trim()) return
    setSettingsLoading(true)
    setSettingsMessage('')
    try {
      await axios.post(`${API_URL}/admin/api-key`, { api_key: apiKey })
      setSettingsMessage('API key saved successfully!')
      setApiKey('')
      await checkApiKeyStatus()
    } catch (err) {
      setSettingsMessage(err.response?.data?.detail || 'Failed to save API key')
    } finally {
      setSettingsLoading(false)
    }
  }

  const clearApiKey = async () => {
    setSettingsLoading(true)
    setSettingsMessage('')
    try {
      await axios.delete(`${API_URL}/admin/api-key`)
      setSettingsMessage('API key cleared')
      await checkApiKeyStatus()
    } catch (err) {
      setSettingsMessage(err.response?.data?.detail || 'Failed to clear API key')
    } finally {
      setSettingsLoading(false)
    }
  }

  const testBackend = async () => {
    setLoading(true)
    setError('')
    setTestResponse('')
    try {
      const response = await axios.get(`${API_URL}/test`)
      setTestResponse(response.data.message)
    } catch (err) {
      setError(err.response?.data?.detail || 'Failed to connect to backend')
    } finally {
      setLoading(false)
    }
  }

  const sendChat = async () => {
    if (!message.trim()) return
    setLoading(true)
    setError('')
    setChatResponse('')
    try {
      const response = await axios.post(`${API_URL}/chat`, {
        message: message,
        model: 'gpt-4-turbo-preview'
      })
      setChatResponse(response.data.response)
      setMessage('')
    } catch (err) {
      setError(err.response?.data?.detail || 'Failed to get response')
    } finally {
      setLoading(false)
    }
  }

  const handleKeyPress = (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault()
      sendChat()
    }
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-50 to-slate-100">
      <div className="max-w-3xl mx-auto px-4 py-12">
        {/* Header */}
        <motion.div
          initial={{ opacity: 0, y: -20 }}
          animate={{ opacity: 1, y: 0 }}
          className="text-center mb-12"
        >
          <div className="flex items-center justify-center gap-4 mb-2">
            <h1 className="text-4xl font-bold text-slate-800">
              Fullstack App
            </h1>
            <button
              onClick={() => setShowSettings(!showSettings)}
              className={cn(
                "p-2 rounded-lg transition-all duration-200",
                showSettings ? "bg-slate-200 text-slate-700" : "bg-slate-100 text-slate-500 hover:bg-slate-200"
              )}
            >
              <Settings className="w-5 h-5" />
            </button>
          </div>
          <p className="text-slate-500">
            FastAPI + React + OpenAI Integration
          </p>
          {/* API Key Status Badge */}
          <div className="mt-3">
            <span className={cn(
              "inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-medium",
              apiKeyStatus.configured
                ? "bg-green-100 text-green-700"
                : "bg-amber-100 text-amber-700"
            )}>
              <Key className="w-3 h-3" />
              {apiKeyStatus.configured
                ? `API Key: ${apiKeyStatus.source}`
                : "API Key: Not configured"}
            </span>
          </div>
        </motion.div>

        {/* Admin Settings Panel */}
        <AnimatePresence>
          {showSettings && (
            <motion.div
              initial={{ opacity: 0, height: 0 }}
              animate={{ opacity: 1, height: 'auto' }}
              exit={{ opacity: 0, height: 0 }}
              className="mb-6 overflow-hidden"
            >
              <div className="bg-white rounded-2xl shadow-sm border border-slate-200 p-6">
                <div className="flex items-center justify-between mb-4">
                  <div className="flex items-center gap-3">
                    <div className="p-2 bg-purple-100 rounded-lg">
                      <Settings className="w-5 h-5 text-purple-600" />
                    </div>
                    <h2 className="text-lg font-semibold text-slate-800">Admin Settings</h2>
                  </div>
                  <button
                    onClick={() => setShowSettings(false)}
                    className="p-1 hover:bg-slate-100 rounded-lg transition-colors"
                  >
                    <X className="w-5 h-5 text-slate-400" />
                  </button>
                </div>

                <div className="space-y-4">
                  <div>
                    <label className="block text-sm font-medium text-slate-700 mb-2">
                      OpenAI API Key
                    </label>
                    <div className="flex gap-2">
                      <div className="relative flex-1">
                        <input
                          type={showApiKey ? "text" : "password"}
                          value={apiKey}
                          onChange={(e) => setApiKey(e.target.value)}
                          placeholder="sk-..."
                          className={cn(
                            "w-full px-4 py-2.5 pr-10 rounded-xl border border-slate-200",
                            "focus:outline-none focus:ring-2 focus:ring-purple-500 focus:border-transparent",
                            "text-slate-700 placeholder:text-slate-400"
                          )}
                        />
                        <button
                          type="button"
                          onClick={() => setShowApiKey(!showApiKey)}
                          className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600"
                        >
                          {showApiKey ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                        </button>
                      </div>
                      <button
                        onClick={saveApiKey}
                        disabled={settingsLoading || !apiKey.trim()}
                        className={cn(
                          "px-4 py-2.5 rounded-xl font-medium transition-all duration-200",
                          "bg-purple-500 hover:bg-purple-600 text-white",
                          "disabled:opacity-50 disabled:cursor-not-allowed"
                        )}
                      >
                        {settingsLoading ? <Loader2 className="w-5 h-5 animate-spin" /> : "Save"}
                      </button>
                    </div>
                  </div>

                  {apiKeyStatus.configured && apiKeyStatus.source === 'memory' && (
                    <button
                      onClick={clearApiKey}
                      disabled={settingsLoading}
                      className="text-sm text-red-600 hover:text-red-700 font-medium"
                    >
                      Clear stored API key
                    </button>
                  )}

                  {settingsMessage && (
                    <p className={cn(
                      "text-sm",
                      settingsMessage.includes('success') ? "text-green-600" : "text-amber-600"
                    )}>
                      {settingsMessage}
                    </p>
                  )}

                  <p className="text-xs text-slate-500">
                    The API key is stored in server memory and will be cleared when the server restarts.
                  </p>
                </div>
              </div>
            </motion.div>
          )}
        </AnimatePresence>

        {/* Test Connection Card */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.1 }}
          className="bg-white rounded-2xl shadow-sm border border-slate-200 p-6 mb-6"
        >
          <div className="flex items-center gap-3 mb-4">
            <div className="p-2 bg-amber-100 rounded-lg">
              <Zap className="w-5 h-5 text-amber-600" />
            </div>
            <h2 className="text-lg font-semibold text-slate-800">Test Connection</h2>
          </div>

          <button
            onClick={testBackend}
            disabled={loading}
            className={cn(
              "w-full py-3 px-4 rounded-xl font-medium transition-all duration-200",
              "bg-amber-500 hover:bg-amber-600 text-white",
              "disabled:opacity-50 disabled:cursor-not-allowed",
              "flex items-center justify-center gap-2"
            )}
          >
            {loading ? (
              <Loader2 className="w-5 h-5 animate-spin" />
            ) : (
              <>
                <Zap className="w-5 h-5" />
                Test Backend
              </>
            )}
          </button>

          <AnimatePresence>
            {testResponse && (
              <motion.div
                initial={{ opacity: 0, height: 0 }}
                animate={{ opacity: 1, height: 'auto' }}
                exit={{ opacity: 0, height: 0 }}
                className="mt-4 p-4 bg-green-50 border border-green-200 rounded-xl flex items-start gap-3"
              >
                <CheckCircle2 className="w-5 h-5 text-green-600 flex-shrink-0 mt-0.5" />
                <p className="text-green-700">{testResponse}</p>
              </motion.div>
            )}
          </AnimatePresence>
        </motion.div>

        {/* Chat Card */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.2 }}
          className="bg-white rounded-2xl shadow-sm border border-slate-200 p-6"
        >
          <div className="flex items-center gap-3 mb-4">
            <div className="p-2 bg-blue-100 rounded-lg">
              <MessageCircle className="w-5 h-5 text-blue-600" />
            </div>
            <h2 className="text-lg font-semibold text-slate-800">Chat with AI</h2>
          </div>

          <div className="flex gap-3">
            <textarea
              value={message}
              onChange={(e) => setMessage(e.target.value)}
              onKeyPress={handleKeyPress}
              placeholder="Type your message..."
              rows={3}
              className={cn(
                "flex-1 px-4 py-3 rounded-xl border border-slate-200",
                "focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent",
                "resize-none text-slate-700 placeholder:text-slate-400"
              )}
            />
            <button
              onClick={sendChat}
              disabled={loading || !message.trim()}
              className={cn(
                "px-6 rounded-xl font-medium transition-all duration-200",
                "bg-blue-500 hover:bg-blue-600 text-white",
                "disabled:opacity-50 disabled:cursor-not-allowed",
                "flex items-center justify-center"
              )}
            >
              {loading ? (
                <Loader2 className="w-5 h-5 animate-spin" />
              ) : (
                <Send className="w-5 h-5" />
              )}
            </button>
          </div>

          <AnimatePresence>
            {chatResponse && (
              <motion.div
                initial={{ opacity: 0, height: 0 }}
                animate={{ opacity: 1, height: 'auto' }}
                exit={{ opacity: 0, height: 0 }}
                className="mt-4 p-4 bg-slate-50 border border-slate-200 rounded-xl"
              >
                <p className="text-sm font-medium text-slate-500 mb-2">AI Response</p>
                <p className="text-slate-700 whitespace-pre-wrap">{chatResponse}</p>
              </motion.div>
            )}
          </AnimatePresence>
        </motion.div>

        {/* Error Display */}
        <AnimatePresence>
          {error && (
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -20 }}
              className="mt-6 p-4 bg-red-50 border border-red-200 rounded-xl flex items-start gap-3"
            >
              <AlertCircle className="w-5 h-5 text-red-600 flex-shrink-0 mt-0.5" />
              <p className="text-red-700">{error}</p>
            </motion.div>
          )}
        </AnimatePresence>

        {/* Footer */}
        <motion.p
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 0.3 }}
          className="text-center text-slate-400 text-sm mt-8"
        >
          Backend: localhost:8000 | Frontend: localhost:5173
        </motion.p>
      </div>
    </div>
  )
}

export default App
