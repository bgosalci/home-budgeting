import { initTheme } from '../app/js/modules/theme.js';
import { jest } from '@jest/globals';

function mockMatchMedia(matches) {
  const mql = {
    matches,
    addEventListener: jest.fn(),
  };
  window.matchMedia = jest.fn().mockReturnValue(mql);
  return mql;
}

test('initTheme applies dark class when system prefers dark', () => {
  const mql = mockMatchMedia(true);
  document.documentElement.className = '';
  initTheme();
  expect(document.documentElement.classList.contains('dark')).toBe(true);
  expect(mql.addEventListener).toHaveBeenCalled();
});

test('initTheme removes dark class when system prefers light', () => {
  mockMatchMedia(false);
  document.documentElement.className = 'dark';
  initTheme();
  expect(document.documentElement.classList.contains('dark')).toBe(false);
});
