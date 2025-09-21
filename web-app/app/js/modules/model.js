import { id, sum, clone } from './utils.js';

export const emptyMonth = ()=>({
  incomes:[],
  transactions:[],
  categories:{}
});

export const template = () => emptyMonth();

export const addCat = (month, name, group, budget)=>{
  month.categories[name] = {group, budget: Number(budget)||0};
};

export const setCat = (month, name, group, budget)=>{ addCat(month,name,group,budget); };
export const delCat = (month, name)=>{ delete month.categories[name]; };

export const addIncome = (month, name, amount)=>{ month.incomes.push({id:id(), name, amount:Number(amount)||0}); };
export const setIncome = (month, id, name, amount)=>{
  const inc = month.incomes.find(x=>x.id===id);
  if(inc){ inc.name = name; inc.amount = Number(amount)||0; }
};
export const delIncome = (month, id)=>{ month.incomes = month.incomes.filter(x=>x.id!==id); };

export const addTx = (month, {date,desc,amount,category})=>{ month.transactions.push({id:id(),date,desc,amount:Number(amount)||0,category}); };
export const delTx = (month, id)=>{ month.transactions = month.transactions.filter(x=>x.id!==id); };
export const clearTx = (month)=>{ month.transactions = []; };

export const totals = (month)=>{
  const income = sum(month.incomes, x=>x.amount);
  const budgetPerCat = {}; const actualPerCat = {};
  const cats = month.categories || {};
  for(const [name,meta] of Object.entries(cats)) budgetPerCat[name]=(meta.budget||0);
  for(const tx of month.transactions) actualPerCat[tx.category]=(actualPerCat[tx.category]||0)+tx.amount;
  const groups = {};
  for(const [cat,meta] of Object.entries(cats)){
    const g = meta.group||'Other';
    if(!groups[g]) groups[g] = {budget:0, actual:0};
    groups[g].budget += budgetPerCat[cat]||0;
    groups[g].actual += actualPerCat[cat]||0;
  }
  const budgetTotal = sum(Object.values(budgetPerCat));
  const actualTotal = sum(Object.values(actualPerCat));
  const leftoverActual = income - actualTotal;
  return {income, budgetPerCat, actualPerCat, groups, budgetTotal, actualTotal, leftoverActual};
};
