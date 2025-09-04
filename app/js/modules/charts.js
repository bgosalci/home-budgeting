export const bar = (canvas, labels, series)=>{
  if(!canvas) return; const ctx = canvas.getContext('2d');
  const W = canvas.width = canvas.clientWidth*2; const H = canvas.height = canvas.clientHeight*2;
  ctx.clearRect(0,0,W,H); ctx.font = '24px system-ui'; ctx.fillStyle = '#111';
  const left=90, right=40, bottom=80, top=30; const plotW=W-left-right, plotH=H-top-bottom;
  const max = Math.max(1, ...series.flat());
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
  const names = ['Budget','Actual'];
  names.forEach((name,i)=>{ ctx.fillStyle = colors[i]; ctx.fillRect(left + i*160, 8, 28, 18); ctx.fillStyle='#111'; ctx.fillText(name, left + i*160 + 36, 24); });
};

export const donut = (canvas, parts)=>{
  if(!canvas) return; const ctx = canvas.getContext('2d');
  const W = canvas.width = canvas.clientWidth*2; const H = canvas.height = canvas.clientHeight*2;
  ctx.clearRect(0,0,W,H);
  const cx=W/2, cy=H/2, r=Math.min(W,H)/3, r2=r*0.64; const total = Object.values(parts).reduce((a,b)=>a+b,0)||1;
  let start=-Math.PI/2; const colors=['#0ea5e9','#ef4444','#10b981','#f59e0b','#8b5cf6','#14b8a6','#e11d48','#84cc16','#06b6d4'];
  let i=0; for(const [k,v] of Object.entries(parts)){
    const ang = (v/total)*Math.PI*2; ctx.beginPath(); ctx.moveTo(cx,cy); ctx.fillStyle = colors[i++%colors.length];
    ctx.arc(cx,cy,r,start,start+ang); ctx.closePath(); ctx.fill();
    const mid=start+ang/2; const lx=cx+Math.cos(mid)*(r+24); const ly=cy+Math.sin(mid)*(r+24);
    ctx.fillStyle='#111'; ctx.font='22px system-ui'; ctx.fillText(`${k}`, lx-10, ly);
    start += ang;
  }
  ctx.globalCompositeOperation='destination-out'; ctx.beginPath(); ctx.arc(cx,cy,r2,0,Math.PI*2); ctx.fill(); ctx.globalCompositeOperation='source-over';
  ctx.fillStyle='#111'; ctx.font='28px system-ui'; ctx.textAlign='center'; ctx.fillText('Budget',cx,cy+10);
};
