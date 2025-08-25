  // ===== Utils
  const Utils = (()=>{
    const fmt = (n)=>`£${(n||0).toFixed(2)}`;
    const setText = (el,n)=>{ el.textContent = fmt(n); el.classList.toggle('danger', n<0); };
    const id = () => Math.random().toString(36).slice(2,9);
    const monthKey = (d)=>{
      if(typeof d === 'string') return d; // already key
      const dt = d || new Date();
      const m = String(dt.getMonth()+1).padStart(2,'0');
      return `${dt.getFullYear()}-${m}`;
    };
    const groupBy = (arr, fn)=>arr.reduce((a,x)=>{const k=fn(x);(a[k]=a[k]||[]).push(x);return a;},{});
    const sum = (arr, fn=(x)=>x)=>arr.reduce((a,x)=>a+fn(x),0);
    const clone = (o)=>JSON.parse(JSON.stringify(o));
    const parseCSV = (text)=>{
      const lines = text.trim().split(/\r?\n/).filter(l=>l);
      if(lines[0] && /^date/i.test(lines[0])) lines.shift();
      return lines.map(line=>{
        const [dRaw,desc,category,aRaw] = line.split(',').map(s=>s.trim());
        const [dd,mm,yyyy] = dRaw.split(/[\/]/);
        const date = `${yyyy}-${mm}-${dd}`;
        const amount = Number(aRaw.replace(/[^0-9.-]/g,'')) || 0;
        return {date,desc,category,amount};
      });
    };
    const toCSV = (txs)=>[
      'Date,Description,Category,Amount',
      ...txs.map(t=>{
        const [y,m,d] = (t.date||'').split('-');
        const date = d?`${d}/${m}/${y}`:'';
        return [date,t.desc,t.category,`£${Number(t.amount||0).toFixed(2)}`].join(',');
      })
    ].join('\n');
    return {fmt,id,monthKey,groupBy,sum,clone,parseCSV,toCSV,setText};
  })();

  // ===== Dialog (modal pop-ups)
  const Dialog = (()=>{
    const dlg = document.getElementById('dialog');
    const msg = document.getElementById('dialog-message');
    const ok = document.getElementById('dialog-ok');
    const cancel = document.getElementById('dialog-cancel');
    const open = (type, message, showCancel)=>{
      dlg.className = `dialog ${type}`;
      msg.textContent = message;
      return new Promise(resolve=>{
        cancel.classList.toggle('hidden', !showCancel);
        ok.onclick = ()=>{ dlg.close(); resolve(true); };
        cancel.onclick = ()=>{ dlg.close(); resolve(false); };
        dlg.oncancel = (e)=>{ e.preventDefault(); dlg.close(); resolve(false); };
        dlg.showModal();
      });
    };
    const alert = (m)=>open('alert',m,false).then(()=>{});
    const info = (m)=>open('info',m,false).then(()=>{});
    const confirm = (m)=>open('confirm',m,true);
    return {alert,info,confirm};
  })();

  // ===== Storage (localStorage) – closure encapsulation
  const Store = (()=>{
    const KEY = 'budget.local.v1';
    const load = ()=>{
      try{
        return JSON.parse(localStorage.getItem(KEY)) || {version:1, months:{}, categories:{}, mapping:{exact:{}, tokens:{}}, descMap:{exact:{}, tokens:{}}, ui:{collapsed:{}}, descList:[]};
      }
      catch{
        return {version:1, months:{}, categories:{}, mapping:{exact:{}, tokens:{}}, descMap:{exact:{}, tokens:{}}, ui:{collapsed:{}}, descList:[]};
      }
    };
    const save = (state)=>localStorage.setItem(KEY, JSON.stringify(state));
    const state = load();
    if(!state.categories){
      state.categories = {};
    }
    for(const m of Object.values(state.months||{})){
      if(m.categories){
        state.categories = {...state.categories, ...m.categories};
        delete m.categories;
      }
    }
    save(state);
    const getMonth = (mk)=> state.months[mk];
    const setMonth = (mk, data)=>{ state.months[mk]=data; save(state); };
    const allMonths = ()=> Object.keys(state.months).sort();
    const categories = ()=> state.categories || (state.categories={});
    const setCategories = (cats)=>{ state.categories = cats; save(state); };
    const mapping = ()=> state.mapping;
    const setMapping = (m)=>{ state.mapping = m; save(state); };
    const descMap = ()=> state.descMap || (state.descMap={exact:{},tokens:{}});
    const setDescMap = (m)=>{ state.descMap = m; save(state); };
    const descList = ()=> state.descList || (state.descList=[]);
    const setDescList = (list)=>{ state.descList = list; save(state); };
    const exportData = (kind, mk)=>{
      if(kind==='transactions'){
        const m = state.months[mk];
        return m ? (m.transactions||[]) : [];
      }
      if(kind==='categories'){
        return {categories: state.categories};
      }
      if(kind==='prediction'){
        return {mapping: state.mapping, descMap: state.descMap, descList: state.descList||[]};
      }
      // all data
      return {version:state.version, months: state.months, categories: state.categories, mapping: state.mapping, descMap: state.descMap, descList: state.descList||[]};
    };
    const importData = (json)=>{
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
      state.categories = {...state.categories, ...(incoming.categories||{})};
      for(const [mk,month] of Object.entries(incoming.months)){
        if(month.categories){
          state.categories = {...state.categories, ...month.categories};
          delete month.categories;
        }
        state.months[mk]=month;
      } // last-write-wins
      save(state);
    };
    // Collapsed groups (UI state)
    const collapsedFor = (mk)=>{ state.ui = state.ui || {collapsed:{}}; state.ui.collapsed = state.ui.collapsed || {}; state.ui.collapsed[mk] = state.ui.collapsed[mk] || {}; return state.ui.collapsed[mk]; };
    const isCollapsed = (mk,g)=> !!collapsedFor(mk)[g];
    const setCollapsed = (mk,g,val)=>{ collapsedFor(mk)[g]=!!val; save(state); };
    const toggleCollapsed = (mk,g)=>{ setCollapsed(mk,g,!isCollapsed(mk,g)); };
    const setAllCollapsed = (mk, groups, val)=>{ const obj = collapsedFor(mk); (groups||[]).forEach(g=>obj[g]=!!val); save(state); };
    return {state,getMonth,setMonth,allMonths,categories,setCategories,mapping,setMapping,descMap,setDescMap,descList,setDescList,exportData,importData,collapsedFor,isCollapsed,setCollapsed,toggleCollapsed,setAllCollapsed};
  })();

  // ===== Charts (vanilla Canvas)
  const Charts = (()=>{
    const bar = (canvas, labels, series)=>{
      if(!canvas) return; const ctx = canvas.getContext('2d');
      const W = canvas.width = canvas.clientWidth*2; const H = canvas.height = canvas.clientHeight*2;
      ctx.clearRect(0,0,W,H); ctx.font = '24px system-ui'; ctx.fillStyle = '#111';
      const left=90, right=40, bottom=80, top=30; const plotW=W-left-right, plotH=H-top-bottom;
      const max = Math.max(1, ...series.flat());
      // axes
      ctx.strokeStyle = '#e5e7eb'; ctx.lineWidth=2; ctx.beginPath(); ctx.moveTo(left,top); ctx.lineTo(left,H-bottom); ctx.lineTo(W-right,H-bottom); ctx.stroke();
      const n = labels.length; const groups = series.length; const band = plotW/n; const barW = Math.min(50,(band-20)/groups);
      const colors = ['#f59e0b','#0ea5e9','#10b981','#ef4444','#8b5cf6'];
      labels.forEach((lab,i)=>{
        const x0 = left + i*band + 10;
        series.forEach((s,g)=>{
          const val = s[i]||0; const h = (val/max)*plotH; const x = x0 + g*(barW+8); const y = H-bottom - h;
          ctx.fillStyle = colors[g%colors.length]; ctx.fillRect(x,y,barW,h);
        });
        ctx.save(); ctx.fillStyle = '#374151'; ctx.textAlign='center';
        ctx.translate(x0+band/2-10,H-bottom+28); ctx.rotate(-0.2); ctx.fillText(lab,0,0); ctx.restore();
      });
      // legend
      const names = ['Budget','Actual'];
      names.forEach((name,i)=>{ ctx.fillStyle = colors[i]; ctx.fillRect(left + i*160, 8, 28, 18); ctx.fillStyle='#111'; ctx.fillText(name, left + i*160 + 36, 24); });
    };

    const donut = (canvas, parts)=>{
      if(!canvas) return; const ctx = canvas.getContext('2d');
      const W = canvas.width = canvas.clientWidth*2; const H = canvas.height = canvas.clientHeight*2;
      ctx.clearRect(0,0,W,H);
      const cx=W/2, cy=H/2, r=Math.min(W,H)/3, r2=r*0.64; const total = Object.values(parts).reduce((a,b)=>a+b,0)||1;
      let start=-Math.PI/2; const colors=['#0ea5e9','#ef4444','#10b981','#f59e0b','#8b5cf6','#14b8a6','#e11d48','#84cc16','#06b6d4'];
      let i=0; for(const [k,v] of Object.entries(parts)){
        const ang = (v/total)*Math.PI*2; ctx.beginPath(); ctx.moveTo(cx,cy); ctx.fillStyle = colors[i++%colors.length];
        ctx.arc(cx,cy,r,start,start+ang); ctx.closePath(); ctx.fill();
        // label
        const mid=start+ang/2; const lx=cx+Math.cos(mid)*(r+24); const ly=cy+Math.sin(mid)*(r+24);
        ctx.fillStyle='#111'; ctx.font='22px system-ui'; ctx.fillText(`${k}`, lx-10, ly);
        start += ang;
      }
      // hole
      ctx.globalCompositeOperation='destination-out'; ctx.beginPath(); ctx.arc(cx,cy,r2,0,Math.PI*2); ctx.fill(); ctx.globalCompositeOperation='source-over';
      ctx.fillStyle='#111'; ctx.font='28px system-ui'; ctx.textAlign='center'; ctx.fillText('Budget',cx,cy+10);
    };

    return {bar,donut};
  })();

  // ===== Predictor (learn tokens)
  const Predictor = (()=>{
    const tokensOf = (s)=> (s||'').toLowerCase().replace(/[^a-z0-9\s]/g,' ').split(/\s+/).filter(Boolean);
    const predict = (desc, cats)=>{
      const map = Store.mapping();
      const exact = map.exact[desc?.trim().toLowerCase()];
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
    const learn = (desc, cat)=>{
      if(!desc||!cat) return; const map = Store.mapping();
      const key = desc.trim().toLowerCase();
      map.exact[key]=cat;
      for(const t of desc.toLowerCase().split(/\s+/).filter(Boolean)){
        const bag = map.tokens[t]||{}; bag[cat]=(bag[cat]||0)+1; map.tokens[t]=bag;
      }
      Store.setMapping(map);
    };
    return {predict,learn};
  })();

  // ===== Description Predictor (learn full descriptions)
  const DescPredictor = (()=>{
    const predict = (partial)=>{
      if(!partial) return [];
      const list = Store.descList();
      const lower = partial.trim().toLowerCase();
      return list.filter(d=>d.toLowerCase().startsWith(lower)).slice(0,4);
    };
    const learn = (desc)=>{
      if(!desc) return;
      const list = Store.descList();
      const norm = desc.trim();
      const exists = list.some(d=>d.toLowerCase()===norm.toLowerCase());
      if(!exists){
        list.push(norm);
        Store.setDescList(list);
      }
    };
    return {predict,learn};
  })();

  // ===== Model for a Month
  const Model = (()=>{
    const emptyMonth = ()=>({
      incomes:[],
      transactions:[] // {id,date,desc,amount,category}
    });

    // Default empty template – start with no categories or incomes
    const template = () => emptyMonth();

    const addCat = (name, group, budget)=>{
      const cats = Store.categories();
      cats[name] = {group, budget: Number(budget)||0};
      Store.setCategories(cats);
    };

    const setCat = (name, group, budget)=>{ addCat(name,group,budget); };
    const delCat = (name)=>{ const cats = Store.categories(); delete cats[name]; Store.setCategories(cats); };

    const addIncome = (month, name, amount)=>{ month.incomes.push({id:Utils.id(), name, amount:Number(amount)||0}); };
    const setIncome = (month, id, name, amount)=>{
      const inc = month.incomes.find(x=>x.id===id);
      if(inc){ inc.name = name; inc.amount = Number(amount)||0; }
    };
    const delIncome = (month, id)=>{ month.incomes = month.incomes.filter(x=>x.id!==id); };

    const addTx = (month, {date,desc,amount,category})=>{ month.transactions.push({id:Utils.id(),date,desc,amount:Number(amount)||0,category}); };
    const delTx = (month, id)=>{ month.transactions = month.transactions.filter(x=>x.id!==id); };

    const totals = (month)=>{
      const income = Utils.sum(month.incomes, x=>x.amount);
      const budgetPerCat = {}; const actualPerCat = {};
      const cats = Store.categories();
      for(const [name,meta] of Object.entries(cats)) budgetPerCat[name]=(meta.budget||0);
      for(const tx of month.transactions) actualPerCat[tx.category]=(actualPerCat[tx.category]||0)+tx.amount;
      const groups = {};
      for(const [cat,meta] of Object.entries(cats)){
        const g = meta.group||'Other';
        const b = budgetPerCat[cat]||0; const a = actualPerCat[cat]||0;
        const gg = groups[g] || {budget:0,actual:0}; gg.budget+=b; gg.actual+=a; groups[g]=gg;
      }
      const budgetTotal = Utils.sum(Object.values(budgetPerCat));
      const actualTotal = Utils.sum(Object.values(actualPerCat));
      return {income,budgetPerCat,actualPerCat,groups,budgetTotal,actualTotal,leftoverActual: income-actualTotal,leftoverBudget: income-budgetTotal};
    };

    return {emptyMonth,template,addCat,setCat,delCat,addIncome,setIncome,delIncome,addTx,delTx,totals};
  })();

  // ===== UI Controller
  const UI = (()=>{
    const els = {
      headerMonth: document.getElementById('header-month'),
      leftoverPill: document.getElementById('leftover-pill'),
      monthPicker: document.getElementById('month-picker'),
      newMonth: document.getElementById('new-month'),
      duplicateMonth: document.getElementById('duplicate-month'),
      openMonth: document.getElementById('open-month'),
      exportBtn: document.getElementById('export-data'),
      exportDialog: document.getElementById('export-dialog'),
      exportKind: document.getElementById('export-kind'),
      exportMonth: document.getElementById('export-month'),
      exportMonthRow: document.getElementById('export-month-row'),
      exportType: document.getElementById('export-type'),
      exportTypeRow: document.getElementById('export-type-row'),
      exportConfirm: document.getElementById('export-confirm'),
      exportCancel: document.getElementById('export-cancel'),
      importBtn: document.getElementById('import-trans'),
      importDialog: document.getElementById('import-dialog'),
      importKind: document.getElementById('import-kind'),
      importMonth: document.getElementById('import-month'),
      importMonthRow: document.getElementById('import-month-row'),
      importType: document.getElementById('import-type'),
      importTypeRow: document.getElementById('import-type-row'),
      importFile: document.getElementById('import-file'),
      importConfirm: document.getElementById('import-confirm'),
      importCancel: document.getElementById('import-cancel'),

      // Tabs
      tabBudget: document.getElementById('tab-budget'),
      tabTx: document.getElementById('tab-transactions'),
      tabAnalysis: document.getElementById('tab-analysis'),
      tabLearning: document.getElementById('tab-learning'),
      panelBudget: document.getElementById('panel-budget'),
      panelTx: document.getElementById('panel-transactions'),
      panelAnalysis: document.getElementById('panel-analysis'),
      panelLearning: document.getElementById('panel-learning'),
      analysisSelect: document.getElementById('analysis-select'),
      analysisChartType: document.getElementById('analysis-chart-type'),
      analysisPlannedTitle: document.getElementById('analysis-planned-title'),
      analysisActualTitle: document.getElementById('analysis-actual-title'),
      analysisChart: document.getElementById('analysis-chart'),
      analysisChartActual: document.getElementById('analysis-chart-actual'),
      analysisCharts: document.getElementById('analysis-charts'),
      analysisMonthRow: document.getElementById('analysis-month-row'),
      analysisMonth: document.getElementById('analysis-month'),
      analysisGroupRow: document.getElementById('analysis-group-row'),
      analysisGroup: document.getElementById('analysis-group'),

      // Income
      incomeList: document.getElementById('income-list'),
      incomeName: document.getElementById('income-name'),
      incomeAmount: document.getElementById('income-amount'),
      addIncome: document.getElementById('add-income'),
      totalIncome: document.getElementById('total-income'),
      leftoverActual: document.getElementById('leftover-actual'),

      // Categories table
      catName: document.getElementById('cat-name'),
      catGroup: document.getElementById('cat-group'),
      catBudget: document.getElementById('cat-budget'),
      addCategory: document.getElementById('add-category'),
      collapseAll: document.getElementById('collapse-all'),
      expandAll: document.getElementById('expand-all'),
      catTable: document.getElementById('category-table').querySelector('tbody'),
      totBud: document.getElementById('tot-bud'),
      totAct: document.getElementById('tot-act'),
      totDiff: document.getElementById('tot-diff'),

      // Transactions
      txDate: document.getElementById('tx-date'),
      txDesc: document.getElementById('tx-desc'),
      txAmt: document.getElementById('tx-amt'),
      txCat: document.getElementById('tx-cat'),
      txSearch: document.getElementById('tx-search'),
      txFilterCat: document.getElementById('tx-filter-cat'),
      addTx: document.getElementById('add-tx'),
      txList: document.getElementById('tx-list'),
      txTotal: document.getElementById('tx-total'),
      predictHint: document.getElementById('predict-hint'),
      descPredictHint: document.getElementById('desc-predict-hint'),
      descTooltip: document.getElementById('desc-tooltip'),

      // Learning
      learnDesc: document.getElementById('learn-desc'),
      learnCat: document.getElementById('learn-cat'),
      learnAdd: document.getElementById('learn-add'),
      learnList: document.getElementById('learn-list')
      };

    let currentMonthKey = Utils.monthKey();
    let editingIncomeId = null;
    let editingTxId = null;
    let analysisChart = null;
    let analysisChartActual = null;
    const ICON_EDIT = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 20h9"/><path d="M16.5 3.5l4 4L7 21H3v-4L16.5 3.5z"/></svg>`;
    const ICON_DELETE = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6m5-3h4a1 1 0 0 1 1 1v2H9V4a1 1 0 0 1 1-1z"/></svg>`;
    els.descPredictHint.textContent = 'Desc: –';
    els.descTooltip.classList.add('hidden');
    let descSuggestions = [];
    let descSelIdx = 0;

    const hideDescSuggestions = ()=>{
      descSuggestions = [];
      els.descTooltip.classList.add('hidden');
      els.descTooltip.innerHTML = '';
    };

    const renderDescSuggestions = ()=>{
      els.descTooltip.innerHTML = '';
      descSuggestions.forEach((s,i)=>{
        const div = document.createElement('div');
        div.textContent = s;
        div.className = 'option'+(i===descSelIdx?' selected':'');
        div.addEventListener('mousedown', (e)=>{
          e.preventDefault();
          chooseDescSuggestion(i);
        });
        els.descTooltip.appendChild(div);
      });
      els.descTooltip.classList.remove('hidden');
    };

    const highlightDescSuggestion = ()=>{
      [...els.descTooltip.children].forEach((el,i)=>{
        el.classList.toggle('selected', i===descSelIdx);
      });
    };

    const chooseDescSuggestion = (i)=>{
      if(!descSuggestions[i]) return;
      els.txDesc.value = descSuggestions[i] + ' ';
      hideDescSuggestions();
      els.txDesc.dispatchEvent(new Event('input'));
    };

    // ---- init data if empty
    (function bootstrap(){
      if(Store.allMonths().length===0){
        const mk = Utils.monthKey(new Date());
        const month = Model.template();
        // Initialize with an empty month; no default incomes
        Store.setMonth(mk, month);
      }
      currentMonthKey = Store.allMonths().slice(-1)[0] || Utils.monthKey();
      els.monthPicker.value = currentMonthKey;
    })();

    function loadMonth(mk){
      const month = Store.getMonth(mk);
      if(!month) return;
      editingIncomeId = null; els.addIncome.textContent='Add Income';
      editingTxId = null; els.addTx.textContent='Add';
      currentMonthKey = mk; els.headerMonth.textContent = new Date(mk+'-01').toLocaleString(undefined,{month:'long',year:'numeric'});
      // populate incomes
      els.incomeList.innerHTML = '';
      month.incomes.forEach(x=> addIncomeRow(x));
      // populate categories
      renderCategories(month);
      // populate tx dropdown and list
      refreshCategoryDropdowns();
      els.txSearch.value='';
      els.txFilterCat.value='';
      renderTransactions(month);
      // refresh open-month select
      refreshMonthPicker();
      // charts + KPIs
      refreshKPIs();
    }

    function refreshMonthPicker(){
      const opts = Store.allMonths().map(mk=>`<option value="${mk}" ${mk===currentMonthKey?'selected':''}>${new Date(mk+'-01').toLocaleString(undefined,{month:'short',year:'numeric'})}</option>`).join('');
      els.openMonth.innerHTML = `<option value="">Select Month</option>` + opts;
      els.openMonth.value = currentMonthKey;
    }

    function addIncomeRow(x){
      const row = document.createElement('div'); row.className='list-item';
      row.innerHTML = `<div class="grow"><strong>${x.name}</strong><div><small></small></div></div>`+
                      `<div class="actions"><button class="icon-btn" data-act="edit" aria-label="Edit">${ICON_EDIT}</button> <button class="icon-btn" data-act="del" aria-label="Delete">${ICON_DELETE}</button></div>`;
      Utils.setText(row.querySelector('small'), x.amount);
      row.onclick = async (e)=>{
        const act = e.target.closest('button')?.dataset?.act; if(!act) return;
        const m=Store.getMonth(currentMonthKey);
        if(act==='del'){
          if(await Dialog.confirm('Delete this income?')){ Model.delIncome(m,x.id); Store.setMonth(currentMonthKey,m); loadMonth(currentMonthKey); }
        }
        if(act==='edit'){ els.incomeName.value=x.name; els.incomeAmount.value=x.amount; editingIncomeId=x.id; els.addIncome.textContent='Update Income'; }
      };
      els.incomeList.appendChild(row);
    }

    function renderCategories(month){
      els.catTable.innerHTML='';
      const totals = Model.totals(month);
      const cats = Store.categories();
      const entries = Object.entries(cats);
      const byGroup = {};
      for(const [name,meta] of entries){ const g=meta.group||'Other'; (byGroup[g]=byGroup[g]||[]).push([name,meta]); }
      const groups = Object.keys(byGroup).sort();
      for(const g of groups){
        const gBud = totals.groups[g]?.budget||0; const gAct = totals.groups[g]?.actual||0; const gDiff = gBud - gAct; const gCls = gDiff>=0?'success':'danger'; const gBudCls = gBud<0?'danger':''; const gActCls = gAct<0?'danger':'';
        const collapsed = Store.isCollapsed(currentMonthKey,g); const icon = collapsed ? '▶' : '▼';
        const trh = document.createElement('tr'); trh.className='group-row';
        trh.innerHTML = `<td colspan="2"><button class="toggle" data-group="${g}" aria-label="toggle">${icon}</button><strong>${g}</strong></td>
                         <td class="right ${gBudCls}">${Utils.fmt(gBud)}</td>
                         <td class="right ${gActCls}">${Utils.fmt(gAct)}</td>
                         <td class="right ${gCls}">${Utils.fmt(gDiff)}</td>
                         <td></td>`;
        trh.querySelector('button.toggle').onclick = (e)=>{ e.stopPropagation(); Store.toggleCollapsed(currentMonthKey,g); renderCategories(month); };
        els.catTable.appendChild(trh);
        const items = byGroup[g].sort((a,b)=> a[0].localeCompare(b[0]));
        for(const [name,meta] of items){
          const act = totals.actualPerCat[name]||0; const diff = (meta.budget||0) - act; const cls = diff>=0?'success':'danger'; const budCls = (meta.budget||0)<0?'danger':''; const actCls = act<0?'danger':'';
          const tr = document.createElement('tr'); if(collapsed) tr.classList.add('hidden'); tr.dataset.cat=name; tr.dataset.group=g;
          tr.innerHTML = `<td></td>
                          <td>${name}</td>
                          <td class="right ${budCls}">${Utils.fmt(meta.budget||0)}</td>
                          <td class="right ${actCls}">${Utils.fmt(act)}</td>
                          <td class="right ${cls}">${Utils.fmt(diff)}</td>
                          <td class="right"><div class="actions"><button class="icon-btn" data-act="edit" aria-label="Edit">${ICON_EDIT}</button> <button class="icon-btn" data-act="del" aria-label="Delete">${ICON_DELETE}</button></div></td>`;
          tr.onclick = async (e)=>{
            const actn = e.target.closest('button')?.dataset?.act; if(!actn) return;
            if(actn==='del'){
              if(await Dialog.confirm('Delete this category?')){ Model.delCat(name); renderCategories(month); refreshKPIs(); refreshCategoryDropdowns(); }
            }
            if(actn==='edit'){ els.catName.value=name; els.catGroup.value=meta.group||''; els.catBudget.value=meta.budget||0; }
          };
          els.catTable.appendChild(tr);
        }
      }
        const t = Model.totals(month);
        Utils.setText(els.totBud, t.budgetTotal);
        Utils.setText(els.totAct, t.actualTotal);
        Utils.setText(els.totDiff, t.budgetTotal - t.actualTotal);
      }

    function refreshCategoryDropdowns(){
      const opts = Object.keys(Store.categories()).sort().map(c=>`<option>${c}</option>`).join('');
      const curFilter = els.txFilterCat.value;
      els.txCat.innerHTML = `<option value="">— select —</option>`+opts;
      els.learnCat.innerHTML = opts;
      els.txFilterCat.innerHTML = `<option value="">All categories</option>`+opts;
      els.txFilterCat.value = curFilter;
    }

    function renderTransactions(month){
      els.txList.innerHTML='';
      const search = els.txSearch.value.trim().toLowerCase();
      const filterCat = els.txFilterCat.value;
      const items = month.transactions
        .filter(t => (search === '' || t.desc.toLowerCase().includes(search)) &&
                     (!filterCat || t.category === filterCat))
        .slice()
        .sort((a,b)=> a.date.localeCompare(b.date));
      const byDate = Utils.groupBy(items, t=>t.date);
      const dates = Object.keys(byDate).sort();
      let idx = 1;
      let runningTotal = 0;
      for(const date of dates){
        const dayTotal = Utils.sum(byDate[date], t=>t.amount);
        const dayCount = byDate[date].length;
        runningTotal += dayTotal;

        const hdr = document.createElement('div');
        hdr.className = 'tx-date';
        const dateLabel = new Date(date).toLocaleDateString(undefined,{weekday:'short', day:'numeric', month:'short'});
        hdr.innerHTML = `<span>${dateLabel}<span class="tx-count"><span class="badge">${dayCount}</span> transactions</span></span>`+
                        `<span class="totals"><span class="day"></span><span class="run"></span></span>`;
        const dayEl = hdr.querySelector('.day');
        dayEl.textContent = `Day: ${Utils.fmt(dayTotal)}`;
        if(dayTotal < 0) dayEl.classList.add('danger');
        const runEl = hdr.querySelector('.run');
        runEl.textContent = `Total: ${Utils.fmt(runningTotal)}`;
        if(runningTotal < 0) runEl.classList.add('danger');
        els.txList.appendChild(hdr);

        for(const t of byDate[date]){
            const row = document.createElement('div'); row.className='list-item';
            const aCls = t.amount<0?'danger':'';
            row.innerHTML = `<div class="tx-index">${idx++}</div>`+
                             `<div class="grow"><strong>${t.desc}</strong><div><small>${t.category||'Uncategorised'}</small></div></div>`+
                             `<div class="tx-amount ${aCls}">${Utils.fmt(t.amount)}</div>`+
                             `<div class="actions"><button class="icon-btn" data-act="edit" data-id="${t.id}" aria-label="Edit">${ICON_EDIT}</button> <button class="icon-btn" data-act="del" data-id="${t.id}" aria-label="Delete">${ICON_DELETE}</button></div>`;
          row.querySelector('[data-act="del"]').onclick = async ()=>{
            if(await Dialog.confirm('Delete this transaction?')){ const m=Store.getMonth(currentMonthKey); Model.delTx(m,t.id); Store.setMonth(currentMonthKey,m); loadMonth(currentMonthKey); }
          };
          row.querySelector('[data-act="edit"]').onclick = ()=>{ els.txDate.value=t.date; els.txDesc.value=t.desc; els.txAmt.value=t.amount; els.txCat.value=t.category; editingTxId=t.id; els.addTx.textContent='Update'; };
          els.txList.appendChild(row);
        }
      }
      const total = Utils.sum(items, t=>t.amount);
      Utils.setText(els.txTotal, total);
      refreshKPIs();
    }

        function refreshKPIs(){
          const month = Store.getMonth(currentMonthKey);
          const t = Model.totals(month);
          Utils.setText(els.totalIncome, t.income);
          Utils.setText(els.leftoverActual, t.leftoverActual);
          els.leftoverPill.textContent = `Left Over ${Utils.fmt(t.leftoverActual)}`;
          els.leftoverPill.classList.toggle('danger', t.leftoverActual < 0);

        }

    // ---- Event wiring
    els.addIncome.onclick = ()=>{
      const name = els.incomeName.value.trim() || 'Income';
      const amt = parseFloat(els.incomeAmount.value||'0');
      const m = Store.getMonth(currentMonthKey);
      if(editingIncomeId){
        Model.setIncome(m, editingIncomeId, name, amt);
        editingIncomeId = null; els.addIncome.textContent='Add Income';
      }else{
        Model.addIncome(m,name,amt);
      }
      Store.setMonth(currentMonthKey,m);
      els.incomeName.value=''; els.incomeAmount.value='';
      loadMonth(currentMonthKey);
    };

    els.addCategory.onclick = ()=>{
      const name = els.catName.value.trim(); const group = els.catGroup.value.trim()||'Other'; const bud = parseFloat(els.catBudget.value||'0');
      if(!name) return;
      Model.setCat(name,group,bud);
      els.catName.value=''; els.catGroup.value=''; els.catBudget.value=''; loadMonth(currentMonthKey);
    };

    // Collapse/Expand all groups
    els.collapseAll.onclick = ()=>{
      const m = Store.getMonth(currentMonthKey);
      const groups = [...new Set(Object.values(Store.categories()).map(x=>x.group||'Other'))];
      Store.setAllCollapsed(currentMonthKey, groups, true); renderCategories(m);
    };
    els.expandAll.onclick = ()=>{
      const m = Store.getMonth(currentMonthKey);
      const groups = [...new Set(Object.values(Store.categories()).map(x=>x.group||'Other'))];
      Store.setAllCollapsed(currentMonthKey, groups, false); renderCategories(m);
    };

    // Transaction prediction
    els.txDesc.addEventListener('input', ()=>{
      const cats = Object.keys(Store.categories());
      const guess = Predictor.predict(els.txDesc.value, cats);
      els.predictHint.textContent = 'Prediction: '+(guess||'–');
      if(guess){ els.txCat.value = guess; }
      const val = els.txDesc.value;
      const matches = DescPredictor.predict(val);
      els.descPredictHint.textContent = 'Desc: '+(matches[0]||'–');
      descSuggestions = matches.filter(d=>d.toLowerCase() !== val.trim().toLowerCase());
      if(descSuggestions.length){
        descSelIdx = 0;
        renderDescSuggestions();
      }else{
        hideDescSuggestions();
      }
    });

    els.txDesc.addEventListener('keydown', (e)=>{
      if(!descSuggestions.length) return;
      if(e.key === 'ArrowDown'){
        e.preventDefault();
        descSelIdx = (descSelIdx + 1) % descSuggestions.length;
        highlightDescSuggestion();
      }else if(e.key === 'ArrowUp'){
        e.preventDefault();
        descSelIdx = (descSelIdx - 1 + descSuggestions.length) % descSuggestions.length;
        highlightDescSuggestion();
      }else if(e.key === 'Enter'){
        e.preventDefault();
        chooseDescSuggestion(descSelIdx);
      }
    });

    els.txDesc.addEventListener('blur', ()=>{
      setTimeout(hideDescSuggestions, 100);
    });
    const handleAddTx = ()=>{
      const date = els.txDate.value.trim();
      const desc = els.txDesc.value.trim();
      const amt = parseFloat(els.txAmt.value);
      const cat = els.txCat.value;
      if(!date || !desc || isNaN(amt)) return;
      const m = Store.getMonth(currentMonthKey);
      if(editingTxId){
        const tx = m.transactions.find(x=>x.id===editingTxId);
        if(tx){ tx.date=date; tx.desc=desc; tx.amount=amt; tx.category=cat; }
        editingTxId = null; els.addTx.textContent='Add';
      } else {
        Model.addTx(m,{date,desc,amount:amt,category:cat});
      }
      Store.setMonth(currentMonthKey,m);
      Predictor.learn(desc,cat);
      DescPredictor.learn(desc);
      els.txDesc.value=''; els.txAmt.value='';
      renderTransactions(m); renderCategories(m);
      els.descPredictHint.textContent = 'Desc: –';
      hideDescSuggestions();
      els.txDesc.focus();
    };

    els.addTx.onclick = handleAddTx;

    [els.txDate, els.txDesc, els.txAmt, els.txCat].forEach(el=>{
      el.addEventListener('keydown', (e)=>{
        if(e.key === 'Enter'){
          if(el === els.txDesc && descSuggestions.length){
            e.preventDefault();
            return;
          }
          handleAddTx();
        }
      });
    });

    els.txSearch.oninput = ()=>renderTransactions(Store.getMonth(currentMonthKey));
    els.txFilterCat.onchange = ()=>renderTransactions(Store.getMonth(currentMonthKey));

    // Learning panel
    els.learnAdd.onclick = ()=>{ Predictor.learn(els.learnDesc.value, els.learnCat.value); DescPredictor.learn(els.learnDesc.value); els.learnDesc.value=''; renderLearnList(); };

    function renderLearnList(){
      const map = Store.mapping();
      els.learnList.innerHTML = '';
      for(const [k,v] of Object.entries(map.exact)){
        const row = document.createElement('div'); row.className='list-item';
        row.innerHTML = `<div><strong>${k}</strong><div><small>${v}</small></div></div>`;
        els.learnList.appendChild(row);
      }
    }

    // Month controls
    els.newMonth.onclick = ()=>{
      const mk = els.monthPicker.value || Utils.monthKey();
      if(Store.getMonth(mk)) { Dialog.alert('Month already exists. Use Duplicate if needed.'); return; }
      const month = Model.template(); Store.setMonth(mk, month); loadMonth(mk);
    };
    els.duplicateMonth.onclick = ()=>{
      const months = Store.allMonths(); if(months.length<1) return;
      const prev = months[months.length-1]; const mk = els.monthPicker.value || Utils.monthKey();
      const dup = Utils.clone(Store.getMonth(prev)); dup.transactions=[]; // carry incomes, not tx
      Store.setMonth(mk, dup); loadMonth(mk);
    };
    els.openMonth.onchange = (e)=>{ if(e.target.value) loadMonth(e.target.value); };

    // Export/Import
    function download(name, data, type='json'){
      const blob = type==='csv'
        ? new Blob([data], {type:'text/csv'})
        : new Blob([JSON.stringify(data,null,2)], {type:'application/json'});
      const a=document.createElement('a'); a.href=URL.createObjectURL(blob); a.download=name; a.click();
    }

    function updateExportVis(){
      const tx = els.exportKind.value==='transactions';
      els.exportMonthRow.classList.toggle('hidden', !tx);
      els.exportTypeRow.classList.toggle('hidden', !tx);
    }
    els.exportBtn.onclick = ()=>{
      els.exportKind.value='transactions';
      els.exportMonth.value=currentMonthKey;
      els.exportType.value='json';
      updateExportVis();
      els.exportDialog.showModal();
    };
    els.exportCancel.onclick = ()=>{ els.exportDialog.close(); };
    els.exportKind.onchange = updateExportVis;
    els.exportConfirm.onclick = ()=>{
      const kind = els.exportKind.value;
      if(kind==='transactions'){
        const mk = Utils.monthKey(els.exportMonth.value);
        if(!mk){ Dialog.alert('Select month'); return; }
        const txs = Store.exportData('transactions', mk);
        if(els.exportType.value==='csv'){
          const csv = Utils.toCSV(txs);
          download(`transactions-${mk}.csv`, csv, 'csv');
        }else{
          download(`transactions-${mk}.json`, txs);
        }
      }else if(kind==='categories'){
        const data = Store.exportData('categories');
        download('categories.json', data);
      }else if(kind==='prediction'){
        const data = Store.exportData('prediction');
        download('prediction-map.json', data);
      }else{
        const data = Store.exportData('all');
        download('budget-all.json', data);
      }
      els.exportDialog.close();
    };

    function updateImportVis(){
      const tx = els.importKind.value==='transactions';
      els.importMonthRow.classList.toggle('hidden', !tx);
      els.importTypeRow.classList.toggle('hidden', !tx);
      const t = els.importType.value;
      els.importFile.accept = tx && t==='csv'?'.csv':'application/json,.json';
    }
    els.importBtn.onclick = ()=>{
      els.importKind.value='transactions';
      els.importMonth.value = currentMonthKey;
      els.importType.value='json';
      els.importFile.value='';
      updateImportVis();
      els.importDialog.showModal();
    };
    els.importCancel.onclick = ()=>{ els.importDialog.close(); };
    els.importKind.onchange = updateImportVis;
    els.importType.onchange = updateImportVis;
    els.importConfirm.onclick = ()=>{
      const kind = els.importKind.value;
      const file = els.importFile.files[0];
      if(!file){ Dialog.alert('Select file'); return; }
      const r = new FileReader();
      r.onload = ()=>{
        try{
          const text = r.result;
          let targetMonth = currentMonthKey;
          if(kind==='transactions'){
            const mk = Utils.monthKey(els.importMonth.value);
            if(!mk){ Dialog.alert('Select month'); return; }
            targetMonth = mk;
            let txs;
            if(els.importType.value==='json'){
              const parsed = JSON.parse(text);
              txs = Array.isArray(parsed) ? parsed : parsed.transactions;
            }else{
              txs = Utils.parseCSV(text);
            }
            if(!Array.isArray(txs)) throw new Error('bad');
            let m = Store.getMonth(mk) || Model.emptyMonth();
            for(const t of txs) Model.addTx(m,t);
            Store.setMonth(mk,m);
          }else if(kind==='categories'){
            const parsed = JSON.parse(text);
            const cats = parsed.categories || parsed;
            Store.setCategories({...Store.categories(), ...cats});
          }else if(kind==='prediction'){
            const parsed = JSON.parse(text);
            Store.importData({months:{}, ...parsed});
          }else{
            const parsed = JSON.parse(text);
            Store.importData(parsed);
          }
          loadMonth(targetMonth);
          Dialog.info('Import completed.');
          els.importDialog.close();
        }catch{
          Dialog.alert('Invalid file');
        }
      };
      r.readAsText(file);
    };

    const runAnalysis = ()=>{
      const opt = els.analysisSelect.value;
      els.analysisCharts.classList.remove('charts');
      if(opt === 'budget-spread'){
        els.analysisMonthRow.classList.remove('hidden');
        els.analysisGroupRow.classList.add('hidden');
        const months = Store.allMonths();
        const opts = months.map(m=>`<option value="${m}">${new Date(m+'-01').toLocaleString(undefined,{month:'short',year:'numeric'})}</option>`).join('');
        const prev = els.analysisMonth.value;
        els.analysisMonth.innerHTML = opts;
        els.analysisMonth.value = months.includes(prev) ? prev : currentMonthKey;
        const prevType = els.analysisChartType.value;
        els.analysisChartType.innerHTML = `<option value="pie">Pie Chart</option><option value="bar">Bar Chart</option>`;
        els.analysisChartType.value = ['pie','bar'].includes(prevType) ? prevType : 'bar';
      }else if(opt === 'monthly-spend'){
        els.analysisMonthRow.classList.add('hidden');
        els.analysisGroupRow.classList.remove('hidden');
        const cats = Store.categories();
        const groups = [...new Set(Object.values(cats).map(x=>x.group||'Other'))].sort();
        const prevGroup = els.analysisGroup.value;
        const opts = ['<option value="">All</option>', ...groups.map(g=>`<option value="${g}">${g}</option>`)];
        els.analysisGroup.innerHTML = opts.join('');
        els.analysisGroup.value = groups.includes(prevGroup) ? prevGroup : '';
        const prevType = els.analysisChartType.value;
        els.analysisChartType.innerHTML = `<option value="line">Line Chart</option><option value="bar">Vertical Bar Chart</option>`;
        els.analysisChartType.value = ['line','bar'].includes(prevType) ? prevType : 'line';
      }
      const style = els.analysisChartType.value;
      if(analysisChart){ analysisChart.destroy(); analysisChart = null; }
      if(analysisChartActual){ analysisChartActual.destroy(); analysisChartActual = null; }
      els.analysisPlannedTitle.classList.add('hidden');
      els.analysisActualTitle.classList.add('hidden');
      els.analysisChartActual.classList.add('hidden');
      if(opt === 'monthly-spend'){
        const months = Store.allMonths();
        const labels = months;
        const group = els.analysisGroup.value;
        const cats = Store.categories();
        const data = months.map(mk=>{
          const m = Store.getMonth(mk) || {transactions:[]};
          const txs = m.transactions||[];
          return Utils.sum(txs.filter(t=>{
            if(!group) return true;
            const meta = cats[t.category] || {};
            const g = meta.group || 'Other';
            return g === group;
          }), t=>t.amount);
        });
        const label = group ? `${group} Spend` : 'Total Spend';
        analysisChart = new Chart(els.analysisChart.getContext('2d'), {
          type: style === 'bar' ? 'bar' : 'line',
          data: {
            labels,
            datasets: [{
              label,
              data,
              borderColor: '#0ea5e9',
              backgroundColor: '#0ea5e9',
              tension: 0.2,
              fill: false
            }]
          },
          options: { scales: { y: { beginAtZero: true } } }
        });
      }else if(opt === 'budget-spread'){
        const mk = els.analysisMonth.value || currentMonthKey;
        // Fetch the selected month's data rather than the currently open month
        const monthForChart = Utils.clone(Store.getMonth(mk) || Model.emptyMonth());
        const totals = Model.totals(monthForChart);
        const labels = Object.keys(totals.groups).sort();
        const planned = labels.map(l=>totals.groups[l]?.budget || 0);
        const actual = labels.map(l=>totals.groups[l]?.actual || 0);
        const plannedTot = Utils.sum(planned);
        const actualTot = Utils.sum(actual);
        const plannedPct = planned.map(v=> plannedTot ? (v/plannedTot*100) : 0);
        const actualPct = actual.map(v=> actualTot ? (v/actualTot*100) : 0);
        const palette = ['#0ea5e9','#f43f5e','#10b981','#f59e0b','#8b5cf6','#ec4899','#14b8a6','#f97316','#22c55e','#d946ef'];
        const colors = labels.map((_,i)=>palette[i%palette.length]);
        const percentPlugin = {
          id:'pct',
          afterDatasetsDraw(chart){
            const {ctx} = chart;
            const dataset = chart.data.datasets[0];
            chart.getDatasetMeta(0).data.forEach((arc,i)=>{
              const val = dataset.data[i]||0;
              const pos = arc.tooltipPosition();
              ctx.save();
              ctx.fillStyle='#fff';
              ctx.font='14px system-ui';
              ctx.textAlign='center';
              ctx.textBaseline='middle';
              ctx.fillText(`${val.toFixed(1)}%`, pos.x, pos.y);
              ctx.restore();
            });
          }
        };
        const pieOpts = {
          plugins:{
            tooltip:{callbacks:{label:c=>`${c.label}: ${c.parsed.toFixed(1)}%`}}
          }
        };
        const barOpts = {
          plugins:{tooltip:{callbacks:{label:c=>`${c.dataset.label}: ${Utils.fmt(c.parsed.y)}`}}},
          scales:{y:{beginAtZero:true,ticks:{callback:v=>Utils.fmt(v)}}}
        };
        if(style === 'pie'){
          els.analysisCharts.classList.add('charts');
          els.analysisPlannedTitle.classList.remove('hidden');
          els.analysisActualTitle.classList.remove('hidden');
          els.analysisChartActual.classList.remove('hidden');
          analysisChart = new Chart(els.analysisChart.getContext('2d'), {
            type:'pie',
            data:{labels,datasets:[{label:'Planned %', data: plannedPct, backgroundColor: colors}]},
            options: pieOpts,
            plugins:[percentPlugin]
          });
          analysisChartActual = new Chart(els.analysisChartActual.getContext('2d'), {
            type:'pie',
            data:{labels,datasets:[{label:'Actual %', data: actualPct, backgroundColor: colors}]},
            options: pieOpts,
            plugins:[percentPlugin]
          });
        }else{
          analysisChart = new Chart(els.analysisChart.getContext('2d'), {
            type:'bar',
            data:{
              labels,
              datasets:[
                {label:'Planned', data: planned, backgroundColor:'#0ea5e9'},
                {label:'Actual', data: actual, backgroundColor:'#f43f5e'}
              ]
            },
            options: barOpts
          });
        }
      }
    };

    // Tabs
    function selectTab(key){
      const map = {
        budget:[els.tabBudget,els.panelBudget],
        tx:[els.tabTx,els.panelTx],
        analysis:[els.tabAnalysis,els.panelAnalysis],
        learn:[els.tabLearning,els.panelLearning]
      };
      for(const [k,[btn,pan]] of Object.entries(map)){ const on = (k===key); btn.setAttribute('aria-selected',on); pan.classList.toggle('hidden',!on); }
    }
    els.tabBudget.onclick = ()=>selectTab('budget');
    els.tabTx.onclick = ()=>selectTab('tx');
    els.tabAnalysis.onclick = ()=>{ selectTab('analysis'); runAnalysis(); };
    els.tabLearning.onclick = ()=>{ selectTab('learn'); renderLearnList(); };
    els.analysisSelect.onchange = runAnalysis;
    els.analysisChartType.onchange = runAnalysis;
    els.analysisMonth.onchange = runAnalysis;
    els.analysisGroup.onchange = runAnalysis;

    // Initial load
    loadMonth(currentMonthKey);
  })();
