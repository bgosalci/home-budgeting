const extractDay = (value) => {
  if (typeof value !== 'string' || value.length < 2) return null;
  const parts = value.split('-');
  if (parts.length !== 3) return null;
  const [first, , third] = parts;
  if (/^\d{4}$/.test(first)) {
    const day = Number.parseInt(third, 10);
    return Number.isFinite(day) ? day : null;
  }
  if (/^\d{4}$/.test(third)) {
    const day = Number.parseInt(first, 10);
    return Number.isFinite(day) ? day : null;
  }
  const fallback = Number.parseInt(third, 10);
  return Number.isFinite(fallback) ? fallback : null;
};

export const calculateDayTotals = (transactions = []) => {
  const totals = {};
  if (!Array.isArray(transactions)) return totals;
  for (const tx of transactions) {
    if (!tx) continue;
    const day = extractDay(tx.date);
    if (!Number.isFinite(day) || day < 1 || day > 31) continue;
    const amount = Number(tx.amount);
    totals[day] = (totals[day] || 0) + (Number.isFinite(amount) ? amount : 0);
  }
  return totals;
};
