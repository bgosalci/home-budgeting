import { emptyMonth, addCat, delCat, addIncome, setIncome, delIncome, addTx, delTx, clearTx, totals } from '../app/js/modules/model.js';

test('emptyMonth initializes structures', ()=>{
  const m = emptyMonth();
  expect(m.incomes).toEqual([]);
  expect(m.transactions).toEqual([]);
  expect(m.categories).toEqual({});
});

test('category and income operations and totals', ()=>{
  const m = emptyMonth();
  addCat(m, 'Food', 'Living', 200);
  addCat(m, 'Rent', 'Living', 800);
  addIncome(m, 'Salary', 1500);
  const incId = m.incomes[0].id;
  setIncome(m, incId, 'Salary', 1600);
  addTx(m, {date:'2024-07-01', desc:'Groceries', amount:50, category:'Food'});
  addTx(m, {date:'2024-07-02', desc:'Rent', amount:800, category:'Rent'});
  let t = totals(m);
  expect(t.income).toBe(1600);
  expect(t.budgetPerCat.Food).toBe(200);
  expect(t.actualPerCat.Food).toBe(50);
  expect(t.groups.Living.budget).toBe(1000);
  expect(t.actualTotal).toBe(850);
  expect(t.leftoverActual).toBe(750);

  delTx(m, m.transactions[0].id);
  t = totals(m);
  expect((t.actualPerCat.Food || 0)).toBe(0);

  delIncome(m, incId);
  expect(m.incomes.length).toBe(0);

  delCat(m, 'Food');
  expect(m.categories.Food).toBeUndefined();

  clearTx(m);
  expect(m.transactions.length).toBe(0);
});
