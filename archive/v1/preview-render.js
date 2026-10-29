const canvas=document.querySelector('canvas'),ctx=canvas.getContext('2d');let mode='dusk',shapes,metrics,fonts={};
const modes={dusk:['日照金山','晨昏时，天空转为烟紫与暖橙，雪峰染上金色。自动模式按本地时间 06:00–07:00、17:00–19:00 显示。'],day:['晴日青山','远山、主峰、山麓与针叶林组成四层景深。外圈的暖色细线表示步数目标完成度。'],night:['月下雪峰','深蓝夜空、月牙与微微闪动的星点。主峰和时间保持清晰，睡眠状态下只留下低亮小钟。'],rain:['山间落雨','灰蓝天空与每秒变化的雨线。降水概率 ≥ 60% 触发，表示降雨可能性，不等于现场雨量。'],stress:['山口微光','最近有效压力值达到 70 时，山口泛起橙红色，火星随秒变化。阈值可调整。'],goal:['雨后彩虹','每日总消耗达到默认 2500 kcal 后，雪山上方出现四色彩虹。目标可调整。'],battery:['电量提醒','电量 ≤ 20% 时，天空右侧出现闪电，底部显示 LOW BATTERY；阈值可调整。'],charging:['正在充电','手表报告充电状态时，以闪电和 CHARGING 表示。'],move:['起身走走','读取手表的久坐进度条，在底部显示 TIME TO MOVE。'],message:['收到消息','底部显示系统未读通知数量，不读取或展示通知内容。'],missing:['暂无数据','没有有效心率、天气、海拔时显示 --。景色照常存在，缺失的数据保持空缺。'],aod:['息屏常显','仅保留暗灰小钟，每分钟改变位置。实际常显是否持续显示由手表系统设置决定。']};
for(const [id,[label]] of Object.entries(modes)){const b=document.createElement('button');b.textContent=label;b.dataset.mode=id;b.onclick=()=>select(id);document.querySelector('#modes').append(b)}
function select(id){mode=id;document.querySelectorAll('button').forEach(b=>b.setAttribute('aria-pressed',b.dataset.mode===id));document.querySelector('#description').textContent=modes[id][1];render()}
function polygon(points,color){ctx.fillStyle=color;ctx.beginPath();points.forEach(([x,y],i)=>i?ctx.lineTo(x,y):ctx.moveTo(x,y));ctx.closePath();ctx.fill()}
function circle(x,y,r,color){ctx.fillStyle=color;ctx.beginPath();ctx.arc(x,y,r,0,Math.PI*2);ctx.fill()}
function line(x,y,x2,y2,color,width=1){ctx.strokeStyle=color;ctx.lineWidth=width;ctx.beginPath();ctx.moveTo(x,y);ctx.lineTo(x2,y2);ctx.stroke()}
function text(x,y,t,name='SmallFont',color='#e5ece9'){
 t=String(t);const m=metrics[name];let w=[...t].reduce((n,ch)=>n+(m[ch]?.[2]||0),0),left=x-w/2;
 const scratch=document.createElement('canvas');scratch.width=Math.max(1,w);scratch.height=m['0'][3];const d=scratch.getContext('2d');let dx=0;
 for(const ch of t){let g=m[ch];if(!g)continue;d.drawImage(fonts[name],...g,dx,0,g[2],g[3]);dx+=g[2]}
 d.globalCompositeOperation='source-in';d.fillStyle=color;d.fillRect(0,0,scratch.width,scratch.height);ctx.drawImage(scratch,left,y);
}
function blend(a,b,t){return '#'+[16,8,0].map(n=>Math.floor(((a>>n)&255)*(1-t)+((b>>n)&255)*t).toString(16).padStart(2,'0')).join('')}
function arc(r,start,end,color,width=3){ctx.strokeStyle=color;ctx.lineWidth=width;ctx.beginPath();ctx.arc(227,227,r,-start*Math.PI/180,-end*Math.PI/180);ctx.stroke()}
function render(){
 if(!metrics||!fonts.TimeFont?.complete)return;
 const now=new Date(),sec=now.getSeconds(),night=mode==='night',dusk=mode==='dusk',wet=mode==='rain',volcano=mode==='stress',missing=mode==='missing';ctx.clearRect(0,0,454,454);ctx.fillStyle='#000';ctx.fillRect(0,0,454,454);
 if(mode==='aod'){let shift=(now.getMinutes()%3-1)*12;text(227+shift,205+shift,'21:38','MediumFont','#777');return}
 for(let y=20;y<263;y++){let half=Math.floor(Math.sqrt(207**2-(y-227)**2)),top=night?0x0B142B:dusk?0x302C44:0x163A4C,bottom=night?0x32636B:dusk?0xC08A70:0x77AAA8;if(wet){top=0x222E40;bottom=0x69828A}ctx.fillStyle=blend(top,bottom,(y-20)/243);ctx.fillRect(227-half,y,half*2,1)}
 if(night){circle(325,115,14,'#d7e6e5');circle(331,110,13,'#172e42');for(let i=0;i<18;i++){let x=95+i*47%260,y=83+i*31%100;if((x-227)**2+(y-227)**2<180**2)circle(x,y,1,(i+sec)%5===0?'#fff':'#6b9ca9')}}else circle(143,122,16,dusk?'#e6ad78':'#e7d9ab');
 if(wet)for(let j=0;j<18;j++){let x=90+j*37%280,y=80+(j*23+sec*9)%125;if((x-227)**2+(y-227)**2<180**2)line(x,y,x-4,y+10,'#a2bec9',2)}
 shapes.forEach(([c,p])=>polygon(p,dusk&&c==='#e3e9dc'?'#e6bd8d':c));
 if(volcano){polygon([[242,112],[249,119],[241,143],[250,163],[239,188],[243,165],[234,146]],'#e88355');for(let k=0;k<7;k++)circle(244+k*13%32-16,108-(k*11+sec*3)%32,2,'#ff9b45')}
 if(['battery','charging'].includes(mode))polygon([[349,102],[339,121],[347,121],[341,137],[359,116],[350,116]],'#f8cc68');
 if(mode==='goal')['#da766b','#e9b85e','#86b88d','#72b4cc'].forEach((c,i)=>arc(137-i*4,150,30,c));
 arc(218,225,-45,'#203033');if(!missing)arc(218,225,225-0.8642*270,'#c6b38c');
 text(227,261,night?'21:38':dusk?'17:38':'14:38','TimeFont','#f3f2e7');text(381,310,String(sec).padStart(2,'0'),'SmallFont','#b8c9c6');text(73,274,'24H','SmallFont','#869a9d');
 text(87,178,'ALT','SmallFont','#c3d4cd');text(87,201,missing?'--M':'128M','SmallFont','#e7ece3');text(367,178,'TEMP','SmallFont','#c3d4cd');text(367,201,missing?'--':'18C','SmallFont','#e7ece3');
 text(227,40,'FRI  23  OCT','SmallFont','#e0e6dc');text(227,66,mode==='battery'?'B 15%':'B 82%','SmallFont','#a9bab4');line(104,351,350,351,'#30413f');circle(227,351,2,'#c6b38c');
 text(124,366,missing?'--':'8642','MediumFont','#e0e7dd');text(227,366,missing?'--':'68','MediumFont','#e0e7dd');text(330,366,missing?'--':mode==='goal'?'2630':'1840','MediumFont','#e0e7dd');
 text(124,401,'STEPS','SmallFont','#829790');text(227,401,'HEART','SmallFont','#829790');text(330,401,'KCAL','SmallFont','#829790');text(227,428,({battery:'LOW BATTERY',charging:'CHARGING',message:'MSG 3',move:'TIME TO MOVE'})[mode]||'M O U N T A I N','SmallFont','#c6b38c');
}
async function start(){[shapes,metrics]=await Promise.all(['landscape.json','font-metrics.json'].map(p=>fetch(p).then(r=>r.json())));await Promise.all(Object.keys(metrics).map(name=>new Promise((res,rej)=>{let im=new Image();im.onload=res;im.onerror=rej;im.src=`resources/fonts/${name}.png`;fonts[name]=im})));let p=new URLSearchParams(location.search);if(p.has('face')){document.body.classList.add('face-only')}select(modes[p.get('mode')]?p.get('mode'):'dusk');setInterval(render,1000)}start();
