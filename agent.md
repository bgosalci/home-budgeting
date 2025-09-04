# Agent Notes

- Prefer repository search tools to locate symbols and usages.
- Respect module boundaries in `app/js/modules/` and avoid duplicating logic already present there.
- Keep UI element IDs and existing behavior unchanged when refactoring.
- Tests are required for logic and DOM:
  - Unit tests cover utils, model, predictor modules.
  - UI tests use jsdom and minimal DOM fixtures; do not depend on network or real browser.
- Verification checklist for any PR:
  - `npm install` and `npm test` pass locally.
  - Open `index.html` and smoke test: add income, category, transaction; check analysis tab; ensure no console errors.
  - Update `readme.md` when adding user-facing changes or commands.
  - Keep commits small and descriptive; explain any non-functional refactors in the PR description.
  - Never commit secrets or credentials.
