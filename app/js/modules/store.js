import { clone } from './utils.js';

const KEY = 'budget.local.v1';
const load = ()=>{
  try{
    return JSON.parse(localStorage.getItem(KEY)) || {version:1, months:{}, mapping:{exact:{}, tokens:{}}, descMap:{exact:{}, tokens:{}}, ui:{collapsed:{}}, descList:[], notes:[]};
  }
  catch{
    return {version:1, months:{}, mapping:{exact:{}, tokens:{}}, descMap:{exact:{}, tokens:{}}, ui:{collapsed:{}}, descList:[], notes:[]};
  }
};
const save = (state)=>localStorage.setItem(KEY, JSON.stringify(state));
const state = load();
for(const m of Object.values(state.months||{})){
  m.categories = m.categories || {};
}
state.notes = state.notes || [];
if(state.categories){
  for(const m of Object.values(state.months)){
    m.categories = {...clone(state.categories), ...m.categories};
  }
  delete state.categories;
  save(state);
}

export const getMonth = (mk)=> state.months[mk];
export const setMonth = (mk, data)=>{ state.months[mk]=data; save(state); };
export const allMonths = ()=> Object.keys(state.months).sort();
export const categories = (mk)=> state.months[mk]?.categories || {};
export const mapping = ()=> state.mapping;
export const setMapping = (m)=>{ state.mapping = m; save(state); };
export const descMap = ()=> state.descMap || (state.descMap={exact:{},tokens:{}});
export const setDescMap = (m)=>{ state.descMap = m; save(state); };
export const descList = ()=> state.descList || (state.descList=[]);
export const setDescList = (list)=>{ state.descList = list; save(state); };
export const exportData = (kind, mk)=>{
  if(kind==='transactions'){
    const m = state.months[mk];
    return m ? (m.transactions||[]) : [];
  }
  if(kind==='categories'){
    const m = state.months[mk];
    return {categories: m ? (m.categories||{}) : {}};
  }
  if(kind==='prediction'){
    return {mapping: state.mapping, descMap: state.descMap, descList: state.descList||[]};
  }
  return {version:state.version, months: state.months, mapping: state.mapping, descMap: state.descMap, descList: state.descList||[]};
};
export const importData = (json)=>{
  const incoming = typeof json === 'string' ? JSON.parse(json) : json;
  if(!incoming || !incoming.months) return;
  state.version = incoming.version || state.version;
  state.mapping.exact = {...state.mapping.exact, ...(incoming.mapping?.exact||{})};
  for(const [k,v] of Object.entries(incoming.mapping?.tokens||{})){
    const cur = state.mapping.tokens[k] || {};
    for(const [cat,cnt] of Object.entries(v)) cur[cat] = (cur[cat]||0)+cnt;
    state.mapping.tokens[k] = cur;
  }
  state.descMap = state.descMap || {exact:{},tokens:{}};
  state.descMap.exact = {...state.descMap.exact, ...(incoming.descMap?.exact||{})};
  for(const [k,v] of Object.entries(incoming.descMap?.tokens||{})){
    const cur = state.descMap.tokens[k] || {};
    for(const [desc,cnt] of Object.entries(v)) cur[desc] = (cur[desc]||0)+cnt;
    state.descMap.tokens[k] = cur;
  }
  const inList = incoming.descList || [];
  const curList = descList();
  for(const d of inList){
    if(!curList.some(x=>x.toLowerCase()===d.toLowerCase())) curList.push(d);
  }
  state.descList = curList;
  if(incoming.categories){
    for(const m of Object.values(incoming.months)){
      m.categories = {...incoming.categories, ...(m.categories||{})};
    }
  }
  for(const [mk,month] of Object.entries(incoming.months)){
    month.categories = month.categories || {};
    state.months[mk]=month;
  }
  save(state);
};

const collapsedFor = (mk)=>{ state.ui = state.ui || {collapsed:{}}; state.ui.collapsed = state.ui.collapsed || {}; state.ui.collapsed[mk] = state.ui.collapsed[mk] || {}; return state.ui.collapsed[mk]; };
export const isCollapsed = (mk,g)=> !!collapsedFor(mk)[g];
export const setCollapsed = (mk,g,val)=>{ collapsedFor(mk)[g]=!!val; save(state); };
export const toggleCollapsed = (mk,g)=>{ setCollapsed(mk,g,!isCollapsed(mk,g)); };
export const setAllCollapsed = (mk, groups, val)=>{ const obj = collapsedFor(mk); (groups||[]).forEach(g=>obj[g]=!!val); save(state); };
export const notes = ()=> state.notes || [];
export const setNotes = (list)=>{ state.notes = list; save(state); };

export const reset = ()=>{
  if(typeof process !== 'undefined' && process.env?.NODE_ENV === 'test'){
    Object.assign(state, {version:1, months:{}, mapping:{exact:{}, tokens:{}}, descMap:{exact:{}, tokens:{}}, ui:{collapsed:{}}, descList:[], notes:[]});
  }
};

export { state };
