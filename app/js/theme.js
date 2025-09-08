// Standalone theme initialiser executed on load.
// Mirrors the logic in `modules/theme.js` without using ES modules so
// `index.html` can run over the `file://` protocol.
(function initTheme() {
  const mq = window.matchMedia('(prefers-color-scheme: dark)');
  const apply = () => {
    document.documentElement.classList.toggle('dark', mq.matches);
  };
  apply();
  mq.addEventListener('change', apply);
})();
