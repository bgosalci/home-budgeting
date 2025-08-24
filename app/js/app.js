  // ===== Utils
  const Utils = (()=>{
    const fmt = (n)=>`£${(n||0).toFixed(2)}`;
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
    return {fmt,id,monthKey,groupBy,sum,clone};
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
        return JSON.parse(localStorage.getItem(KEY)) || {version:1, months:{}, mapping:{exact:{}, tokens:{}}, descMap:{exact:{}, tokens:{}}, ui:{collapsed:{}}, descList:[]};
      }
      catch{
        return {version:1, months:{}, mapping:{exact:{}, tokens:{}}, descMap:{exact:{}, tokens:{}}, ui:{collapsed:{}}, descList:[]};
      }
    };
    const save = (state)=>localStorage.setItem(KEY, JSON.stringify(state));
    const state = load();
    const getMonth = (mk)=> state.months[mk];
    const setMonth = (mk, data)=>{ state.months[mk]=data; save(state); };
    const allMonths = ()=> Object.keys(state.months).sort();
    const mapping = ()=> state.mapping;
    const setMapping = (m)=>{ state.mapping = m; save(state); };
    const descMap = ()=> state.descMap || (state.descMap={exact:{},tokens:{}});
    const setDescMap = (m)=>{ state.descMap = m; save(state); };
    const descList = ()=> state.descList || (state.descList=[]);
    const setDescList = (list)=>{ state.descList = list; save(state); };
    const exportMonths = (filterFn)=>{
      const months = {};
      for(const k of Object.keys(state.months)) if(!filterFn || filterFn(k)) months[k]=state.months[k];
      return {version:state.version, months, mapping: state.mapping, descMap: state.descMap, descList: state.descList||[]};
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
      for(const [mk,month] of Object.entries(incoming.months)) state.months[mk]=month; // last-write-wins
      save(state);
    };
    // Collapsed groups (UI state)
    const collapsedFor = (mk)=>{ state.ui = state.ui || {collapsed:{}}; state.ui.collapsed = state.ui.collapsed || {}; state.ui.collapsed[mk] = state.ui.collapsed[mk] || {}; return state.ui.collapsed[mk]; };
    const isCollapsed = (mk,g)=> !!collapsedFor(mk)[g];
    const setCollapsed = (mk,g,val)=>{ collapsedFor(mk)[g]=!!val; save(state); };
    const toggleCollapsed = (mk,g)=>{ setCollapsed(mk,g,!isCollapsed(mk,g)); };
    const setAllCollapsed = (mk, groups, val)=>{ const obj = collapsedFor(mk); (groups||[]).forEach(g=>obj[g]=!!val); save(state); };
    return {state,getMonth,setMonth,allMonths,mapping,setMapping,descMap,setDescMap,descList,setDescList,exportMonths,importData,collapsedFor,isCollapsed,setCollapsed,toggleCollapsed,setAllCollapsed};
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
      if(!partial) return '';
      const list = Store.descList();
      const lower = partial.trim().toLowerCase();
      return list.find(d=>d.toLowerCase().startsWith(lower)) || '';
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
      categories:{}, // name -> {group,budget}
      transactions:[] // {id,date,desc,amount,category}
    });

    // Default empty template – start with no categories or incomes
    const template = () => emptyMonth();

    const addCat = (month, name, group, budget)=>{
      month.categories[name] = {group, budget: Number(budget)||0};
    };

    const setCat = (month, name, group, budget)=>{ addCat(month,name,group,budget); };
    const delCat = (month, name)=>{ delete month.categories[name]; };

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
      for(const [name,meta] of Object.entries(month.categories)) budgetPerCat[name]=(meta.budget||0);
      for(const tx of month.transactions) actualPerCat[tx.category]=(actualPerCat[tx.category]||0)+tx.amount;
      const groups = {};
      for(const [cat,meta] of Object.entries(month.categories)){
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
      exportMonth: document.getElementById('export-month'),
      exportYear: document.getElementById('export-year'),
      exportAll: document.getElementById('export-all'),
      importFile: document.getElementById('import-file'),

      // Tabs
      tabBudget: document.getElementById('tab-budget'),
      tabTx: document.getElementById('tab-transactions'),
      tabLearning: document.getElementById('tab-learning'),
      panelBudget: document.getElementById('panel-budget'),
      panelTx: document.getElementById('panel-transactions'),
      panelLearning: document.getElementById('panel-learning'),

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
    const ICON_EDIT = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 20h9"/><path d="M16.5 3.5l4 4L7 21H3v-4L16.5 3.5z"/></svg>`;
    const ICON_DELETE = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6m5-3h4a1 1 0 0 1 1 1v2H9V4a1 1 0 0 1 1-1z"/></svg>`;
    els.descPredictHint.textContent = 'Desc: –';
    els.descTooltip.classList.add('hidden');
    let descSuggestion = '';

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
      refreshCategoryDropdowns(month);
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
      row.innerHTML = `<div class="grow"><strong>${x.name}</strong><div><small>${Utils.fmt(x.amount)}</small></div></div>`+
                      `<div class="actions"><button class="icon-btn" data-act="edit" aria-label="Edit">${ICON_EDIT}</button> <button class="icon-btn" data-act="del" aria-label="Delete">${ICON_DELETE}</button></div>`;
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
      const totals = Model.totals(Store.getMonth(currentMonthKey));
      const entries = Object.entries(month.categories);
      const byGroup = {};
      for(const [name,meta] of entries){ const g=meta.group||'Other'; (byGroup[g]=byGroup[g]||[]).push([name,meta]); }
      const groups = Object.keys(byGroup).sort();
      for(const g of groups){
        const gBud = totals.groups[g]?.budget||0; const gAct = totals.groups[g]?.actual||0; const gDiff = gBud - gAct; const gCls = gDiff>=0?'success':'danger';
        const collapsed = Store.isCollapsed(currentMonthKey,g); const icon = collapsed ? '▶' : '▼';
        const trh = document.createElement('tr'); trh.className='group-row';
        trh.innerHTML = `<td colspan="2"><button class="toggle" data-group="${g}" aria-label="toggle">${icon}</button><strong>${g}</strong></td>
                         <td class="right">${Utils.fmt(gBud)}</td>
                         <td class="right">${Utils.fmt(gAct)}</td>
                         <td class="right ${gCls}">${Utils.fmt(gDiff)}</td>
                         <td></td>`;
        trh.querySelector('button.toggle').onclick = (e)=>{ e.stopPropagation(); Store.toggleCollapsed(currentMonthKey,g); renderCategories(month); };
        els.catTable.appendChild(trh);
        const items = byGroup[g].sort((a,b)=> a[0].localeCompare(b[0]));
        for(const [name,meta] of items){
          const act = totals.actualPerCat[name]||0; const diff = (meta.budget||0) - act; const cls = diff>=0?'success':'danger';
          const tr = document.createElement('tr'); if(collapsed) tr.classList.add('hidden'); tr.dataset.cat=name; tr.dataset.group=g;
          tr.innerHTML = `<td></td>
                          <td>${name}</td>
                          <td class="right">${Utils.fmt(meta.budget||0)}</td>
                          <td class="right">${Utils.fmt(act)}</td>
                          <td class="right ${cls}">${Utils.fmt(diff)}</td>
                          <td class="right"><div class="actions"><button class="icon-btn" data-act="edit" aria-label="Edit">${ICON_EDIT}</button> <button class="icon-btn" data-act="del" aria-label="Delete">${ICON_DELETE}</button></div></td>`;
          tr.onclick = async (e)=>{
            const actn = e.target.closest('button')?.dataset?.act; if(!actn) return;
            if(actn==='del'){
              if(await Dialog.confirm('Delete this category?')){ delete month.categories[name]; Store.setMonth(currentMonthKey,month); renderCategories(month); refreshKPIs(); refreshCategoryDropdowns(month); }
            }
            if(actn==='edit'){ els.catName.value=name; els.catGroup.value=meta.group||''; els.catBudget.value=meta.budget||0; }
          };
          els.catTable.appendChild(tr);
        }
      }
      const t = Model.totals(month);
      els.totBud.textContent = Utils.fmt(t.budgetTotal);
      els.totAct.textContent = Utils.fmt(t.actualTotal);
      els.totDiff.textContent = Utils.fmt(t.budgetTotal - t.actualTotal);
    }

    function refreshCategoryDropdowns(month){
      const opts = Object.keys(month.categories).sort().map(c=>`<option>${c}</option>`).join('');
      els.txCat.innerHTML = `<option value="">— select —</option>`+opts;
      els.learnCat.innerHTML = opts;
    }

    function renderTransactions(month){
      els.txList.innerHTML='';
      const items = month.transactions.slice().sort((a,b)=> a.date.localeCompare(b.date));
      const byDate = Utils.groupBy(items, t=>t.date);
      const dates = Object.keys(byDate).sort();
      let idx = 1;
      for(const date of dates){
        const hdr = document.createElement('div');
        hdr.className = 'tx-date';
        hdr.textContent = new Date(date).toLocaleDateString(undefined,{weekday:'short', day:'numeric', month:'short'});
        els.txList.appendChild(hdr);
        for(const t of byDate[date]){
          const row = document.createElement('div'); row.className='list-item';
          row.innerHTML = `<div class="tx-index">${idx++}</div>`+
                           `<div class="grow"><strong>${t.desc}</strong><div><small>${t.category||'Uncategorised'}</small></div></div>`+
                           `<div class="tx-amount">${Utils.fmt(t.amount)}</div>`+
                           `<div class="actions"><button class="icon-btn" data-act="edit" data-id="${t.id}" aria-label="Edit">${ICON_EDIT}</button> <button class="icon-btn" data-act="del" data-id="${t.id}" aria-label="Delete">${ICON_DELETE}</button></div>`;
          row.querySelector('[data-act="del"]').onclick = async ()=>{
            if(await Dialog.confirm('Delete this transaction?')){ const m=Store.getMonth(currentMonthKey); Model.delTx(m,t.id); Store.setMonth(currentMonthKey,m); loadMonth(currentMonthKey); }
          };
          row.querySelector('[data-act="edit"]').onclick = ()=>{ els.txDate.value=t.date; els.txDesc.value=t.desc; els.txAmt.value=t.amount; els.txCat.value=t.category; editingTxId=t.id; els.addTx.textContent='Update'; };
          els.txList.appendChild(row);
        }
      }
      const totals = Model.totals(month);
      els.txTotal.textContent = Utils.fmt(totals.actualTotal);
      refreshKPIs();
    }

      function refreshKPIs(){
        const month = Store.getMonth(currentMonthKey);
        const t = Model.totals(month);
        els.totalIncome.textContent = Utils.fmt(t.income);
        els.leftoverActual.textContent = Utils.fmt(t.leftoverActual);
        els.leftoverPill.textContent = `Left Over ${Utils.fmt(t.leftoverActual)}`;

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
      const m = Store.getMonth(currentMonthKey); Model.setCat(m,name,group,bud); Store.setMonth(currentMonthKey,m);
      els.catName.value=''; els.catGroup.value=''; els.catBudget.value=''; loadMonth(currentMonthKey);
    };

    // Collapse/Expand all groups
    els.collapseAll.onclick = ()=>{
      const m = Store.getMonth(currentMonthKey);
      const groups = [...new Set(Object.values(m.categories).map(x=>x.group||'Other'))];
      Store.setAllCollapsed(currentMonthKey, groups, true); renderCategories(m);
    };
    els.expandAll.onclick = ()=>{
      const m = Store.getMonth(currentMonthKey);
      const groups = [...new Set(Object.values(m.categories).map(x=>x.group||'Other'))];
      Store.setAllCollapsed(currentMonthKey, groups, false); renderCategories(m);
    };

    // Transaction prediction
    els.txDesc.addEventListener('input', ()=>{
      const m = Store.getMonth(currentMonthKey); const cats = Object.keys(m.categories);
      const guess = Predictor.predict(els.txDesc.value, cats);
      els.predictHint.textContent = 'Prediction: '+(guess||'–');
      if(guess){ els.txCat.value = guess; }
      const val = els.txDesc.value;
      const dGuess = DescPredictor.predict(val);
      els.descPredictHint.textContent = 'Desc: '+(dGuess||'–');
      if(dGuess && dGuess.toLowerCase() !== val.trim().toLowerCase()){
        descSuggestion = dGuess;
        els.descTooltip.textContent = `${dGuess} (press space to accept)`;
        els.descTooltip.classList.remove('hidden');
      }else{
        descSuggestion = '';
        els.descTooltip.classList.add('hidden');
      }
    });

    els.txDesc.addEventListener('keydown', (e)=>{
      if(e.key === ' ' && descSuggestion){
        e.preventDefault();
        els.txDesc.value = descSuggestion + ' ';
        descSuggestion = '';
        els.descTooltip.classList.add('hidden');
        els.txDesc.dispatchEvent(new Event('input'));
      }
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
      els.descTooltip.classList.add('hidden');
      descSuggestion = '';
      els.txDesc.focus();
    };

    els.addTx.onclick = handleAddTx;

    [els.txDate, els.txDesc, els.txAmt, els.txCat].forEach(el=>{
      el.addEventListener('keydown', (e)=>{
        if(e.key === 'Enter') handleAddTx();
      });
    });

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
      const dup = Utils.clone(Store.getMonth(prev)); dup.transactions=[]; // carry categories & incomes, not tx
      Store.setMonth(mk, dup); loadMonth(mk);
    };
    els.openMonth.onchange = (e)=>{ if(e.target.value) loadMonth(e.target.value); };

    // Export/Import
    function download(name, data){ const a=document.createElement('a'); a.href=URL.createObjectURL(new Blob([JSON.stringify(data,null,2)],{type:'application/json'})); a.download=name; a.click(); }
    els.exportMonth.onclick = ()=>{
      const mk=currentMonthKey; const data = Store.exportMonths(k=>k===mk); download(`budget-${mk}.json`, data);
    };
    els.exportYear.onclick = ()=>{
      const year = (currentMonthKey||Utils.monthKey()).slice(0,4);
      const data = Store.exportMonths(k=>k.startsWith(year+'-')); download(`budget-${year}.json`, data);
    };
    els.exportAll.onclick = ()=>{ const data = Store.exportMonths(); download(`budget-all.json`, data); };
    els.importFile.onchange = (e)=>{
      const file = e.target.files[0]; if(!file) return; const r=new FileReader();
      r.onload = ()=>{ try{ Store.importData(JSON.parse(r.result)); loadMonth(currentMonthKey); Dialog.info('Import completed.'); }catch{ Dialog.alert('Invalid JSON'); } };
      r.readAsText(file);
    };

    // Tabs
    function selectTab(key){
      const map = {budget:[els.tabBudget,els.panelBudget], tx:[els.tabTx,els.panelTx], learn:[els.tabLearning,els.panelLearning]};
      for(const [k,[btn,pan]] of Object.entries(map)){ const on = (k===key); btn.setAttribute('aria-selected',on); pan.classList.toggle('hidden',!on); }
    }
    els.tabBudget.onclick = ()=>selectTab('budget');
    els.tabTx.onclick = ()=>selectTab('tx');
    els.tabLearning.onclick = ()=>{ selectTab('learn'); renderLearnList(); };

    // Initial load
    loadMonth(currentMonthKey);
  })();
