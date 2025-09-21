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

export const alert = (m)=>open('alert',m,false).then(()=>{});
export const info = (m)=>open('info',m,false).then(()=>{});
export const confirm = (m)=>open('confirm',m,true);
