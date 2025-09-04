import { fmt, monthKey, sum, parseCSV, toCSV } from '../app/js/modules/utils.js';

test('fmt formats currency with pound sign and two decimals', ()=>{
  expect(fmt(0)).toBe('£0.00');
  expect(fmt(12.3)).toBe('£12.30');
  expect(fmt(-5)).toBe('£-5.00');
});

test('monthKey returns yyyy-mm for Date and passthrough for string', ()=>{
  const d = new Date('2024-07-15');
  expect(monthKey(d)).toBe('2024-07');
  expect(monthKey('2025-09')).toBe('2025-09');
});

test('sum adds values using mapper', ()=>{
  expect(sum([1,2,3])).toBe(6);
  expect(sum([{a:2},{a:5}], x=>x.a)).toBe(7);
});

test('parseCSV and toCSV roundtrip basic rows', ()=>{
  const csv = [
    'Date,Description,Category,Amount',
    '01/07/2024,"Tesco, groceries",Food,£12.34',
    '02/07/2024,"Gym ""Membership""",Leisure,£25.00'
  ].join('\n');
  const rows = parseCSV(csv, undefined, true, false);
  expect(rows[0]).toEqual({date:'2024-07-01', desc:'Tesco, groceries', category:'Food', amount:12.34});
  expect(rows[1]).toEqual({date:'2024-07-02', desc:'Gym "Membership"', category:'Leisure', amount:25});
  const out = toCSV(rows);
  expect(out.split('\n').length).toBe(3);
});
