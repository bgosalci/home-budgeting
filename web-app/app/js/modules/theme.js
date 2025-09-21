export function initTheme() {
  const mq = window.matchMedia('(prefers-color-scheme: dark)');
  const apply = () => {
    document.documentElement.classList.toggle('dark', mq.matches);
  };
  apply();
  mq.addEventListener('change', apply);
}
