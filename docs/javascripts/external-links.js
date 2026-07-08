(function () {
  function markExternalLinks(root) {
    const container = root || document;
    const links = container.querySelectorAll('a[href]');

    links.forEach((link) => {
      const rawHref = link.getAttribute('href');
      if (!rawHref || rawHref.startsWith('#')) return;
      if (rawHref.startsWith('mailto:') || rawHref.startsWith('tel:')) return;

      let url;
      try {
        url = new URL(rawHref, window.location.href);
      } catch {
        return;
      }

      const isExternal = url.origin !== window.location.origin;
      if (!isExternal) return;

      if (!link.classList.contains('bc-external-link')) {
        link.classList.add('bc-external-link');
      }

      link.setAttribute('target', '_blank');
      link.setAttribute('rel', 'noopener noreferrer');

      if (!link.getAttribute('aria-label')) {
        const labelBase = link.textContent && link.textContent.trim() ? link.textContent.trim() : 'External link';
        link.setAttribute('aria-label', `${labelBase} (external, opens in new tab)`);
      }
    });
  }

  if (window.document$ && typeof window.document$.subscribe === 'function') {
    window.document$.subscribe((root) => markExternalLinks(root));
  } else {
    document.addEventListener('DOMContentLoaded', () => markExternalLinks(document));
  }
})();
