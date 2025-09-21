import { mapping, setMapping } from './store.js';

const tokensOf = (s)=> (s||'').toLowerCase().replace(/[^a-z0-9\s]/g,' ').split(/\s+/).filter(Boolean);

export const predict = (desc, cats, amount)=>{
  const map = mapping();
  const base = desc?.trim().toLowerCase();
  if(!base) return '';
  if(amount !== undefined && !isNaN(amount)){
    const amtKey = base + '|' + Number(amount).toFixed(2);
    const exactAmt = map.exact[amtKey];
    if(exactAmt) return exactAmt;
  }
  const exact = map.exact[base];
  if(exact) return exact;
  const tok = tokensOf(desc);
  const scores = {};
  for(const t of tok){
    const counts = map.tokens[t];
    if(counts) for(const [cat,v] of Object.entries(counts)) scores[cat]=(scores[cat]||0)+v;
  }
  let best=null, bestScore=0; for(const [cat,score] of Object.entries(scores)) if(score>bestScore){best=cat;bestScore=score;}
  return best && cats.includes(best) ? best : '';
};

export const learn = (desc, cat, amount)=>{
  if(!desc||!cat) return; const map = mapping();
  const base = desc.trim().toLowerCase();
  if(amount !== undefined && !isNaN(amount)){
    const amtKey = base + '|' + Number(amount).toFixed(2);
    map.exact[amtKey] = cat;
  } else {
    map.exact[base] = cat;
  }
  for(const t of desc.toLowerCase().split(/\s+/).filter(Boolean)){
    const bag = map.tokens[t]||{}; bag[cat]=(bag[cat]||0)+1; map.tokens[t]=bag;
  }
  setMapping(map);
};
