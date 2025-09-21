import { predictBalance } from '../app/js/modules/balancePredictor.js';

describe('predictBalance', () => {
  const months = {
    '2023-01': {
      incomes: [{ amount: 2000 }],
      transactions: [
        { date: '2023-01-01', amount: 300 },
        { date: '2023-01-08', amount: 200 },
        { date: '2023-01-15', amount: 300 },
        { date: '2023-01-28', amount: 200 },
      ],
    },
    '2023-02': {
      incomes: [{ amount: 2000 }],
      transactions: [
        { date: '2023-02-02', amount: 250 },
        { date: '2023-02-05', amount: 150 },
        { date: '2023-02-18', amount: 300 },
        { date: '2023-02-25', amount: 200 },
      ],
    },
    '2023-03': {
      incomes: [{ amount: 2000 }],
      transactions: [
        { date: '2023-03-05', amount: 100 },
        { date: '2023-03-09', amount: 150 },
        { date: '2023-03-12', amount: 250 },
        { date: '2023-03-20', amount: 200 },
      ],
    },
    '2023-04': {
      incomes: [{ amount: 2000 }],
      transactions: [
        { date: '2023-04-04', amount: 200 },
        { date: '2023-04-09', amount: 180 },
        { date: '2023-04-10', amount: 20 },
      ],
    },
    '2023-05': {
      incomes: [{ amount: 2100 }],
      transactions: [
        { date: '2023-05-03', amount: 400 },
        { date: '2023-05-11', amount: 300 },
        { date: '2023-05-21', amount: 200 },
        { date: '2023-05-31', amount: 100 },
      ],
    },
    '2023-06': {
      incomes: [{ amount: 2050 }],
      transactions: [],
    },
  };

  test('uses median remainder to project final balance for the active month', () => {
    const result = predictBalance('2023-04', months, new Date(2023, 3, 15));
    expect(result).not.toBeNull();
    expect(result.predictedSpend).toBeCloseTo(600, 2);
    expect(result.predictedLeftover).toBeCloseTo(1400, 2);
    expect(result.observationDay).toBe(15);
    expect(result.remainderUsedDay).toBe(15);
    expect(result.sampleSize).toBe(5);
  });

  test('returns actual leftover when the month has already finished', () => {
    const result = predictBalance('2023-05', months, new Date(2023, 7, 1));
    expect(result.observationDay).toBe(31);
    expect(result.remainderUsedDay).toBe(31);
    expect(result.predictedSpend).toBeCloseTo(1000, 2);
    expect(result.predictedLeftover).toBeCloseTo(1100, 2);
  });

  test('falls back to day zero median when there is no current spending yet', () => {
    const result = predictBalance('2023-06', months, new Date(2023, 4, 20));
    expect(result.observationDay).toBe(0);
    expect(result.remainderUsedDay).toBe(0);
    expect(result.predictedSpend).toBeCloseTo(900, 2);
    expect(result.predictedLeftover).toBeCloseTo(1150, 2);
  });
});
