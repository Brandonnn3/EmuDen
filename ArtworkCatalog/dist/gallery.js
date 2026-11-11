const gallery=document.querySelector('#gallery'),summary=document.querySelector('#summary'),query=document.querySelector('#query'),viewer=document.querySelector('#viewer');
let entries=[],kind='cover';
function render(){
 gallery.replaceChildren();gallery.classList.toggle('scenes',kind==='scene');
 const visible=entries.filter(g=>g.title.toLocaleLowerCase().includes(query.value.toLocaleLowerCase()));
 for(const game of visible){
  const asset=game[kind],tile=document.createElement(asset?'button':'div');tile.className='tile';
  if(asset)tile.type='button';
  const frame=document.createElement('div');frame.className='frame';
  if(asset){const img=new Image();img.src=asset.path;img.alt=`${game.title} — original ${kind}`;img.loading='lazy';img.decoding='async';frame.append(img);tile.addEventListener('click',()=>{viewer.querySelector('img').src=asset.path;viewer.querySelector('img').alt=img.alt;viewer.querySelector('p').textContent=game.title;viewer.showModal()})}
  else{const placeholder=document.createElement('div');placeholder.className='placeholder';const title=document.createElement('strong');title.textContent=game.title;const detail=document.createElement('span');detail.textContent=kind==='scene'?'Uses the console background':'Uses existing cover artwork';placeholder.append(title,detail);frame.append(placeholder)}
  const label=document.createElement('div');label.className='label';label.textContent=game.title;const meta=document.createElement('div');meta.className='meta';meta.textContent=game.rank?`COMMUNITY SELECTION · ${String(game.rank).padStart(2,'0')}`:'LIBRARY FAVORITE';tile.append(frame,label,meta);gallery.append(tile);
 }
 if(!visible.length){const message=document.createElement('p');message.textContent='No matching games.';gallery.append(message)}
}
query.addEventListener('input',render);
document.querySelectorAll('[data-kind]').forEach(button=>button.addEventListener('click',()=>{kind=button.dataset.kind;document.querySelectorAll('[data-kind]').forEach(b=>b.setAttribute('aria-pressed',String(b===button)));render()}));
document.querySelector('#close').addEventListener('click',()=>viewer.close());
viewer.addEventListener('click',event=>{if(event.target===viewer)viewer.close()});
fetch('catalog.json',{cache:'no-cache'}).then(response=>{if(!response.ok)throw Error('catalog');return response.json()}).then(data=>{entries=data.games;const images=entries.reduce((n,g)=>n+Number(Boolean(g.cover))+Number(Boolean(g.scene)),0);summary.textContent=`${entries.length} game entries · ${images} original images · Offline caching in EmuDen`;render()}).catch(()=>{summary.textContent='Collection unavailable';document.querySelector('#error').hidden=false});
