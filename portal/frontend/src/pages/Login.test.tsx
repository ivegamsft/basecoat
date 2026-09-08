import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import { Login } from './Login';

const fetchMock = vi.fn();

describe('Login', () => {
  beforeEach(() => {
    vi.stubGlobal('fetch', fetchMock);
  });

  afterEach(() => {
    vi.unstubAllGlobals();
    vi.clearAllMocks();
  });

  it('disables sign-in and explains when GitHub OAuth is unavailable', async () => {
    fetchMock.mockResolvedValue({
      ok: true,
      json: vi.fn().mockResolvedValue({ data: { configured: false } }),
    });

    render(<Login />);

    await waitFor(() =>
      expect(screen.getByRole('alert')).toHaveTextContent('GitHub sign-in is not configured'),
    );
    expect(screen.getByRole('button', { name: 'Sign in with GitHub' })).toBeDisabled();
  });

  it('links to GitHub sign-in when OAuth is configured', async () => {
    fetchMock.mockResolvedValue({
      ok: true,
      json: vi.fn().mockResolvedValue({ data: { configured: true } }),
    });

    render(<Login />);

    await waitFor(() =>
      expect(screen.getByRole('button', { name: 'Sign in with GitHub' })).toBeEnabled(),
    );
  });
});
