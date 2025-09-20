import { sum, monthKey as toMonthKey } from './utils.js';

const parseMonthKey = (mk) => {
  if (typeof mk !== 'string') return null;
  const match = mk.match(/^(\d{4})-(\d{2})$/);
  if (!match) return null;
  const year = Number(match[1]);
  const month = Number(match[2]);
  if (!Number.isFinite(year) || !Number.isFinite(month) || month < 1 || month > 12) return null;
  return { year, month };
};

const dayFromDate = (date) => {
  if (typeof date !== 'string') return null;
  const parts = date.split('-');
  if (parts.length !== 3) return null;
  const day = Number(parts[2]);
  return Number.isFinite(day) ? day : null;
};

const daysInMonth = (year, month) => {
  if (!Number.isFinite(year) || !Number.isFinite(month)) return 31;
  return new Date(year, month, 0).getDate();
};

const accumulateByDay = (transactions, monthLength) => {
  const totals = Array(monthLength + 1).fill(0);
  for (const tx of transactions || []) {
    const day = dayFromDate(tx?.date);
    if (!day || day < 1 || day > monthLength) continue;
    const amount = Number(tx?.amount) || 0;
    totals[day] += amount;
  }
  const cumulative = Array(monthLength + 1).fill(0);
  for (let day = 1; day <= monthLength; day += 1) {
    cumulative[day] = cumulative[day - 1] + totals[day];
  }
  return { totals, cumulative };
};

const median = (values) => {
  if (!values || values.length === 0) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  if (sorted.length % 2) return sorted[mid];
  return (sorted[mid - 1] + sorted[mid]) / 2;
};

const computeHistoryRemainders = (months, excludeKey) => {
  const map = new Map();
  for (const [mk, month] of Object.entries(months || {})) {
    if (!month || mk === excludeKey) continue;
    const parsed = parseMonthKey(mk);
    if (!parsed) continue;
    const monthLength = daysInMonth(parsed.year, parsed.month);
    const { cumulative } = accumulateByDay(month.transactions || [], monthLength);
    const finalSpend = cumulative[monthLength] || 0;
    for (let day = 0; day <= monthLength; day += 1) {
      const spentSoFar = cumulative[day] || 0;
      const remainder = finalSpend - spentSoFar;
      if (!map.has(day)) map.set(day, []);
      map.get(day).push(remainder);
    }
  }
  return map;
};

const pickRemainder = (map, targetDay) => {
  if (!map || map.size === 0) return { remainder: 0, sourceDay: null, sampleSize: 0 };
  const direct = map.get(targetDay);
  if (direct && direct.length) {
    return { remainder: median(direct), sourceDay: targetDay, sampleSize: direct.length };
  }
  for (let offset = 1; offset < 32; offset += 1) {
    const lower = targetDay - offset;
    if (lower >= 0) {
      const arr = map.get(lower);
      if (arr && arr.length) {
        return { remainder: median(arr), sourceDay: lower, sampleSize: arr.length };
      }
    }
    const higher = targetDay + offset;
    const arr = map.get(higher);
    if (arr && arr.length) {
      return { remainder: median(arr), sourceDay: higher, sampleSize: arr.length };
    }
  }
  const entries = [...map.entries()].sort((a, b) => a[0] - b[0]);
  if (entries.length) {
    const [day, arr] = entries[entries.length - 1];
    return { remainder: median(arr), sourceDay: day, sampleSize: arr.length };
  }
  return { remainder: 0, sourceDay: null, sampleSize: 0 };
};

const determineObservationDay = (monthKey, transactions, today) => {
  const parsed = parseMonthKey(monthKey);
  if (!parsed) return { day: 0, monthLength: 31 };
  const monthLength = daysInMonth(parsed.year, parsed.month);
  const todayKey = toMonthKey(today);
  if (monthKey < todayKey) {
    return { day: monthLength, monthLength };
  }
  const txDays = (transactions || [])
    .map((tx) => dayFromDate(tx?.date))
    .filter((day) => day && day >= 1 && day <= monthLength);
  if (monthKey === todayKey) {
    const todayDay = Math.min(today.getDate(), monthLength);
    if (txDays.length) {
      return { day: Math.max(Math.max(...txDays), todayDay), monthLength };
    }
    return { day: todayDay, monthLength };
  }
  if (txDays.length) {
    return { day: Math.max(...txDays), monthLength };
  }
  return { day: 0, monthLength };
};

export const predictBalance = (monthKey, months, today = new Date()) => {
  if (!months || !monthKey) return null;
  const month = months[monthKey];
  if (!month) return null;
  const { day: observationDay, monthLength } = determineObservationDay(
    monthKey,
    month.transactions || [],
    today,
  );
  const { cumulative } = accumulateByDay(month.transactions || [], monthLength);
  const spentSoFar = cumulative[Math.min(observationDay, monthLength)] || 0;
  const incomesTotal = sum(month.incomes || [], (inc) => Number(inc?.amount) || 0);
  const remainders = computeHistoryRemainders(months, monthKey);
  const { remainder, sourceDay, sampleSize } = pickRemainder(remainders, observationDay);
  const predictedSpend = Math.max(0, spentSoFar + remainder);
  const predictedLeftover = incomesTotal - predictedSpend;
  return {
    predictedSpend,
    predictedLeftover,
    spentSoFar,
    incomesTotal,
    observationDay,
    remainderUsedDay: sourceDay,
    sampleSize,
  };
};

export const __private = {
  parseMonthKey,
  dayFromDate,
  daysInMonth,
  accumulateByDay,
  computeHistoryRemainders,
  pickRemainder,
  determineObservationDay,
  median,
};
