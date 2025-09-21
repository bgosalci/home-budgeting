export const fmt = (n)=>`£${(n||0).toFixed(2)}`;
export const setText = (el,n)=>{ el.textContent = fmt(n); el.classList.toggle('danger', n<0); };
export const id = () => Math.random().toString(36).slice(2,9);
export const monthKey = (d)=>{
  if(typeof d === 'string') return d;
  const dt = d || new Date();
  const m = String(dt.getMonth()+1).padStart(2,'0');
  return `${dt.getFullYear()}-${m}`;
};
export const isFutureMonth = (mk, referenceDate)=>{
  if(!mk) return false;
  const base = monthKey(referenceDate);
  return mk > base;
};
export const groupBy = (arr, fn)=>arr.reduce((a,x)=>{const k=fn(x);(a[k]=a[k]||[]).push(x);return a;},{});
export const sum = (arr, fn=(x)=>x)=>arr.reduce((a,x)=>a+fn(x),0);
export const clone = (o)=>JSON.parse(JSON.stringify(o));
export const parseCSV = (text, map, hasHeader=true, invert=false)=>{
  const lines = text.trim().split(/\r?\n/).filter(l=>l);
  if(hasHeader) lines.shift();
  let idx = {date:0, desc:1, category:2, amount:3};
  if(map){
    idx = {};
    for(const [k,v] of Object.entries(map)){
      idx[k] = (v==='' || v===null) ? -1 : Number(v);
    }
  }
  const splitLine = (line)=>{
    const cols = [];
    let cur = '';
    let inQuotes = false;
    for(let i=0;i<line.length;i++){
      const ch = line[i];
      if(ch === '"'){
        if(inQuotes && line[i+1] === '"'){ cur+='"'; i++; }
        else inQuotes = !inQuotes;
      }else if(ch===',' && !inQuotes){
        cols.push(cur);
        cur='';
      }else{
        cur+=ch;
      }
    }
    cols.push(cur);
    return cols.map(s=>s.replace(/""/g,'"').trim());
  };
  return lines.map(line=>{
    const cols = splitLine(line);
    const dRaw = idx.date>=0 ? cols[idx.date]||'' : '';
    const desc = idx.desc>=0 ? cols[idx.desc]||'' : '';
    const category = idx.category>=0 ? cols[idx.category]||'' : '';
    let aRaw = idx.amount>=0 ? cols[idx.amount]||'' : '';
    if(idx.amount>=0 && cols.length>Math.max(idx.amount+1,4)){
      aRaw = cols.slice(idx.amount).join('');
    }
    let date = '';
    if(dRaw){
      const [dd,mm,yyyy] = dRaw.split(/[\/]/);
      if(yyyy && mm && dd) date = `${yyyy}-${mm}-${dd}`;
    }
    let amount = Number(aRaw.replace(/[^0-9.-]/g,'')) || 0;
    if(invert) amount = -amount;
    return {date,desc,category,amount};
  });
};
export const toCSV = (txs)=>[
  'Date,Description,Category,Amount',
  ...txs.map(t=>{
    const [y,m,d] = (t.date||'').split('-');
    const date = d?`${d}/${m}/${y}`:'';
    return [date,t.desc,t.category,`£${Number(t.amount||0).toFixed(2)}`].join(',');
  })
].join('\n');
