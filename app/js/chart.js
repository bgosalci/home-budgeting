export function monthlySpendChart(ctx, labels, data, style, label){
  return new Chart(ctx, {
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
}

export function budgetSpreadCharts(planCtx, actualCtx, labels, planned, actual, style, colors, plannedPct, actualPct, fmt){
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
    plugins:{tooltip:{callbacks:{label:c=>`${c.dataset.label}: ${fmt(c.parsed.y)}`}}},
    scales:{y:{beginAtZero:true,ticks:{callback:v=>fmt(v)}}}
  };
  let chart, actualChart=null;
  if(style === 'pie'){
    chart = new Chart(planCtx, {
      type:'pie',
      data:{labels,datasets:[{label:'Planned %', data: plannedPct, backgroundColor: colors}]},
      options: pieOpts,
      plugins:[percentPlugin]
    });
    actualChart = new Chart(actualCtx, {
      type:'pie',
      data:{labels,datasets:[{label:'Actual %', data: actualPct, backgroundColor: colors}]},
      options: pieOpts,
      plugins:[percentPlugin]
    });
  }else{
    chart = new Chart(planCtx, {
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
  return {chart, actualChart};
}
