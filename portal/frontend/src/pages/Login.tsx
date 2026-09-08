import { useEffect, useState } from 'react';

export function Login() {
  const apiUrl = import.meta.env.VITE_API_URL || 'http://localhost:3000';
  const [oauthConfigured, setOAuthConfigured] = useState<boolean | null>(null);

  useEffect(() => {
    void fetch(`${apiUrl}/auth/github/availability`)
      .then(async (response) => {
        if (!response.ok) {
          throw new Error('GitHub OAuth availability check failed');
        }
        return response.json() as Promise<{ data: { configured: boolean } }>;
      })
      .then((response) => setOAuthConfigured(response.data.configured))
      .catch(() => setOAuthConfigured(false));
  }, [apiUrl]);

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50">
      <div className="bg-white p-8 rounded-lg shadow text-center">
        <h1 className="text-2xl font-bold mb-2">Basecoat Portal</h1>
        <p className="text-gray-500 mb-6">Sign in to manage your Copilot assets</p>
        {oauthConfigured === false && (
          <p className="mb-4 text-sm text-red-700" role="alert">
            GitHub sign-in is not configured. Set the GitHub OAuth client ID and secret for this environment.
          </p>
        )}
        <button
          type="button"
          disabled={oauthConfigured !== true}
          onClick={() => window.location.assign(`${apiUrl}/auth/github`)}
          className="inline-flex items-center gap-2 rounded-lg bg-gray-900 px-6 py-3 text-white hover:bg-gray-700 disabled:cursor-not-allowed disabled:opacity-50"
        >
          {oauthConfigured === null ? 'Checking GitHub sign-in…' : 'Sign in with GitHub'}
        </button>
      </div>
    </div>
  );
}
