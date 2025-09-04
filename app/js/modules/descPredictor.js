import { descList, setDescList } from './store.js';

export const predict = (partial)=>{
  if(!partial) return [];
  const list = descList();
  const lower = partial.trim().toLowerCase();
  return list.filter(d=>d.toLowerCase().startsWith(lower)).slice(0,4);
};

export const learn = (desc)=>{
  if(!desc) return;
  const list = descList();
  const norm = desc.trim();
  const exists = list.some(d=>d.toLowerCase()===norm.toLowerCase());
  if(!exists){
    list.push(norm);
    setDescList(list);
  }
};
