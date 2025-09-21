let api;

beforeAll(async ()=>{
  document.body.innerHTML = `
  <dialog id="dialog" class="dialog">
    <div id="dialog-message"></div>
    <div>
      <button id="dialog-ok">OK</button>
      <button id="dialog-cancel">Cancel</button>
    </div>
  </dialog>`;
  const d = document.getElementById('dialog');
  d.showModal = () => {};
  d.close = () => {};
  api = await import('../app/js/modules/dialog.js');
});

test('alert shows dialog and resolves', async ()=>{
  const p = api.alert('Hello');
  document.getElementById('dialog-ok').click();
  await expect(p).resolves.toBeUndefined();
});

test('info shows dialog and resolves', async ()=>{
  const p = api.info('Info');
  document.getElementById('dialog-ok').click();
  await expect(p).resolves.toBeUndefined();
});

test('confirm resolves true/false', async ()=>{
  const p1 = api.confirm('Sure?');
  document.getElementById('dialog-ok').click();
  await expect(p1).resolves.toBe(true);

  const p2 = api.confirm('Sure?');
  document.getElementById('dialog-cancel').click();
  await expect(p2).resolves.toBe(false);
});
