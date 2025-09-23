import { calculateDayTotals } from '../app/js/modules/calendar.js';

describe('calculateDayTotals', () => {
  it('sums signed amounts by day', () => {
    const totals = calculateDayTotals([
      { id: '1', date: '2025-09-20', amount: 40 },
      { id: '2', date: '2025-09-20', amount: 27.75 },
      { id: '3', date: '2025-09-20', amount: -7.44 },
      { id: '4', date: '2025-09-21', amount: 10 },
    ]);

    expect(totals[20]).toBeCloseTo(60.31, 2);
    expect(totals[21]).toBe(10);
  });

  it('ignores entries without a parseable day', () => {
    const totals = calculateDayTotals([
      { id: '1', date: 'not-a-date', amount: 10 },
      { id: '2', date: '2025-09', amount: 20 },
      { id: '3', date: '2025-09-01', amount: 5 },
      { id: '4', amount: 5 },
    ]);

    expect(totals).toEqual({ 1: 5 });
  });

  it('supports legacy day-month-year formatted dates', () => {
    const totals = calculateDayTotals([
      { id: '1', date: '20-09-2025', amount: 12 },
      { id: '2', date: '20-09-2025', amount: 8 },
    ]);

    expect(totals).toEqual({ 20: 20 });
  });
});
