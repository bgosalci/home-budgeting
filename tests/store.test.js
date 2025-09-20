import {
  exportData,
  importData,
  setMapping,
  mapping,
  reset,
  setDescList,
  descList,
  setMonth,
  deleteMonth,
  allMonths,
  getMonth,
  state,
  setCollapsed
} from '../app/js/modules/store.js';

beforeEach(()=>{
  reset();
});

test('import/export transactions and categories', ()=>{
  const data = {
    version: 1,
    months: {
      '2024-07': {
        incomes: [{id:'i1', name:'Salary', amount:1000}],
        transactions: [{id:'t1', date:'2024-07-01', desc:'Groceries', amount:50, category:'Food'}],
        categories: { Food: {group:'Living', budget:200} }
      }
    },
    mapping: {exact:{}, tokens:{}},
    descMap: {exact:{}, tokens:{}},
    descList: []
  };
  importData(data);
  const txs = exportData('transactions', '2024-07');
  expect(txs.length).toBe(1);
  const cats = exportData('categories', '2024-07');
  expect(cats.categories.Food.budget).toBe(200);
});

test('mapping merge and desc list', ()=>{
  setMapping({exact:{'tesco':'Food'}, tokens:{tesco:{Food:2}}});
  importData({
    version:1,
    months:{},
    mapping:{exact:{'uber':'Transport'}, tokens:{uber:{Transport:3}}},
    descMap:{},
    descList:['Waitrose','Lidl']
  });
  const m = mapping();
  expect(m.exact.uber).toBe('Transport');
  expect(m.tokens.uber.Transport).toBe(3);
  setDescList(['A']);
  expect(descList()).toContain('A');
});

test('deleteMonth removes stored data and ui state', ()=>{
  setMonth('2024-08', { incomes: [], transactions: [], categories: {} });
  setCollapsed('2024-08', 'Group', true);
  expect(allMonths()).toContain('2024-08');
  deleteMonth('2024-08');
  expect(allMonths()).not.toContain('2024-08');
  expect(getMonth('2024-08')).toBeUndefined();
  expect(state.ui?.collapsed?.['2024-08']).toBeUndefined();
});
