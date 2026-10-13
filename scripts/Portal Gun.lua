PORTAL_RUNTIME_GEN=(PORTAL_RUNTIME_GEN or 0)+1
local GEN=PORTAL_RUNTIME_GEN
local PW,PH,EXIT,CD,EPS,SEG=3.15,5.1,5.6,0,1e-6,16
local TOUCH,BOOST_FLOOR,BOOST_OTHER=.5,34,10
local abs,sqrt,sin,cos,rad,min,max,deg=math.abs,math.sqrt,math.sin,math.cos,math.rad,math.min,math.max,math.deg
local atan2=math.atan2 or function(y,x)if x>0 then return math.atan(y/x)elseif x<0 then return math.atan(y/x)+(y>=0 and math.pi or-math.pi)elseif y>0 then return math.pi*.5 elseif y<0 then return-math.pi*.5 end return 0 end
local blue,orange,blocked,lastTP,clearHeld,prevRoot,pendingTP=nil,nil,nil,0,false,nil,nil
local aimYaw,aimPitch,lastMX,lastMY=nil,nil,nil,nil
local ENV=getfenv and getfenv(1)or nil
local RC=(ENV and ENV.raycast)or raycast
local RCast=RC and(RC.Cast or RC.cast)
local RBetween=RC and(RC.Between or RC.between)
local RUpdate=RC and(RC.Update or RC.update)

local function V(x,y,z)return Vector3.new(x or 0,y or 0,z or 0)end
local function add(a,b)return V(a.X+b.X,a.Y+b.Y,a.Z+b.Z)end
local function sub(a,b)return V(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end
local function mul(a,s)return V(a.X*s,a.Y*s,a.Z*s)end
local function dot(a,b)return a.X*b.X+a.Y*b.Y+a.Z*b.Z end
local function cross(a,b)return V(a.Y*b.Z-a.Z*b.Y,a.Z*b.X-a.X*b.Z,a.X*b.Y-a.Y*b.X)end
local function mag2(a)return dot(a,a)end
local function mag(a)return sqrt(mag2(a))end
local function unit(a)local m=mag(a)return m<EPS and V()or mul(a,1/m)end
local function fin(v)return v and v.X==v.X and v.Y==v.Y and v.Z==v.Z and abs(v.X)<1e30 and abs(v.Y)<1e30 and abs(v.Z)<1e30 end
local function num(v)return type(v)=="number"and v==v and abs(v)<1e30 end
local function clamp(v,a,b)return v<a and a or v>b and b or v end
local function sign(v)return v<0 and-1 or 1 end

local function ctrl()
 for _,k in ipairs({"lctrl","rctrl","ctrl","control"})do local ok,v=pcall(keyboard.is_pressed,k)if ok and v then return true end end
 return false
end

local function mouseXY()
 local ok,m=pcall(utility.GetMousePos)if not ok or not m then return end
 local x,y pcall(function()x=m[1]or m.X or m.x y=m[2]or m.Y or m.y end)
 if num(x)and num(y)then return x,y end
end

local function w2s(p)
 if not fin(p)then return end
 local ok,x,y,on=pcall(utility.WorldToScreen,p)
 if not ok or not(num(x)and num(y))or abs(x)>100000 or abs(y)>100000 then return end
 return x,y,on
end

local function line(x1,y1,x2,y2,r,g,b,a,t)
 if num(x1)and num(y1)and num(x2)and num(y2)then pcall(draw.line,x1,y1,x2,y2,r,g,b,a or 255,t or 1)end
end

local function sget(o,k)local ok,v=pcall(function()return o and o[k]end)return ok and v or nil end
local function asvec(v)
 if not v then return end
 local x,y,z local ok=pcall(function()x=v.X or v.x or v[1]y=v.Y or v.y or v[2]z=v.Z or v.z or v[3]end)
 if ok and num(x)and num(y)and num(z)then return V(x,y,z)end
end

local function dirYP(yaw,pitch)
 local y,p=rad(yaw),rad(pitch)local cp=cos(p)return unit(V(cp*cos(y),sin(p),cp*sin(y)))
end

local function aimTest(o,mx,my,yaw,pitch,best)
 yaw=yaw%360 pitch=clamp(pitch,-89.9,89.9)
 local d=dirYP(yaw,pitch)local x,y,on=w2s(add(o,mul(d,600)))if not x or on~=true then return best end
 local dx,dy=x-mx,y-my local s=dx*dx+dy*dy
 if not best or s<best.s then return{s=s,yaw=yaw,pitch=pitch,dir=d}end
 return best
end

local function solveAim()
 local o=game.CameraPosition local mx,my=mouseXY()if not(fin(o)and mx)then return end
 local best,moved=nil,1e9
 if lastMX then local dx,dy=mx-lastMX,my-lastMY moved=sqrt(dx*dx+dy*dy)end
 if aimYaw and moved<400 then for p=-30,30,5 do for y=-30,30,5 do best=aimTest(o,mx,my,aimYaw+y,aimPitch+p,best)end end end
 if not best or best.s>1 then
  best=nil
  for p=-80,80,10 do for y=0,350,10 do best=aimTest(o,mx,my,y,p,best)end end
  for y=0,330,30 do best=aimTest(o,mx,my,y,89.75,best)best=aimTest(o,mx,my,y,-89.75,best)end
 end
 if not best then return end
 for _,step in ipairs({3,1,.25,.05,.01,.002})do local by,bp=best.yaw,best.pitch for py=-3,3 do for px=-3,3 do best=aimTest(o,mx,my,by+px*step,bp+py*step,best)end end end
 aimYaw,aimPitch,lastMX,lastMY=best.yaw,best.pitch,mx,my
 return o,best.dir,sqrt(best.s),mx,my
end

local function under(o,a)
 if not a then return false end
 for _=1,24 do if not o then return false end if o==a then return true end local p pcall(function()p=o.Parent end)o=p end
 return false
end

local function localData()
 local lp=entity.GetLocalPlayer()if not lp then return end
 local root=lp:GetBoneInstance("HumanoidRootPart")local ch if root then pcall(function()ch=root.Parent end)end
 return ch,root
end

local function isCharacterPart(i)
 if not i then return false end local p=i
 for _=1,5 do
  if not p then break end
  local h pcall(function()h=p:FindFirstChild("Humanoid")end)if h then return true end
  local q pcall(function()q=p.Parent end)p=q
 end
 return false
end

local function skip(i,ch)
 if not i then return false end
 if under(i,ch)or isCharacterPart(i)then return true end
 local n pcall(function()n=i.Name end)return n=="Handle"
end

local function resultData(h)
 if not h then return end
 local p=asvec(sget(h,"Position")or sget(h,"position"))
 local n=asvec(sget(h,"Normal")or sget(h,"normal")or sget(h,"HitNormal")or sget(h,"hitNormal"))
 local d=sget(h,"Distance")or sget(h,"distance")
 local i=sget(h,"Instance")or sget(h,"instance")or sget(h,"Part")or sget(h,"part")
 return p,n,num(d)and d or nil,i
end

local function nativeRaw(o,d,dist)
 if RCast then local ok,h=pcall(RCast,o,d,dist)if ok and h then local p,n,di,i=resultData(h)if p then return p,n,di,i,"Cast"end end end
 if RBetween then local ok,h=pcall(RBetween,o,add(o,mul(d,dist)))if ok and h then local p,n,di,i=resultData(h)if p then return p,n,di,i,"Between"end end end
end

local function instInfo(i)local a,n,c if i then pcall(function()a=i.Address n=i.Name c=i.ClassName end)end return a,n,c end
local function sameInst(a,b)
 if not(a and b)then return false end
 local ok,v=pcall(function()return a==b end)if ok and v then return true end
 local aa,an,ac=instInfo(a)local ba,bn,bc=instInfo(b)
 if aa and ba and aa~=0 and aa==ba then return true end
 return an and bn and ac and bc and an==bn and ac==bc
end

local function normalFromInstance(inst,hp,d)
 if not(inst and fin(hp))then return end
 local pos,size,r,u,l local ok=pcall(function()pos=inst.Position size=inst.Size r=inst.RightVector u=inst.UpVector l=inst.LookVector end)
 if not ok or not(fin(pos)and fin(size)and fin(r)and fin(u)and fin(l))then return end
 r,u,l=unit(r),unit(u),unit(l)
 local za=mul(l,-1)local q=sub(hp,pos)local x,y,z=dot(q,r),dot(q,u),dot(q,za)
 local hx,hy,hz=size.X*.5,size.Y*.5,size.Z*.5
 local dx,dy,dz=abs(abs(x)-hx),abs(abs(y)-hy),abs(abs(z)-hz)
 local n
 if dx<=dy and dx<=dz then n=mul(r,sign(x))elseif dy<=dx and dy<=dz then n=mul(u,sign(y))else n=mul(za,sign(z))end
 if dot(n,d)>0 then n=mul(n,-1)end
 return unit(n)
end

local function sampleHit(o,target,range)
 local d=unit(sub(target,o))if mag(d)<.5 then return end
 return nativeRaw(o,d,range)
end

local function normalFromSamples(o,d,p,dist,inst)
 local ref=abs(d.Y)<.92 and V(0,1,0)or V(1,0,0)
 local sr=unit(cross(ref,d))local su=unit(cross(d,sr))if mag(sr)<.5 or mag(su)<.5 then return end
 local bd=dist or mag(sub(p,o))
 for _,spread in ipairs({clamp(bd*.002,.2,1),clamp(bd*.006,.5,3),clamp(bd*.015,1,8),clamp(bd*.03,2,15)})do
  local range=bd+spread*12+50
  local pr,_,_,ir=sampleHit(o,add(p,mul(sr,spread)),range)
  local pl,_,_,il=sampleHit(o,add(p,mul(sr,-spread)),range)
  local pu,_,_,iu=sampleHit(o,add(p,mul(su,spread)),range)
  local pd,_,_,id=sampleHit(o,add(p,mul(su,-spread)),range)
  local function valid(q,qi)if not q then return false end if inst and qi and sameInst(inst,qi)then return true end return mag(sub(q,p))<=spread*10+4 end
  local vr,vl,vu,vd=valid(pr,ir),valid(pl,il),valid(pu,iu),valid(pd,id)local tr,tu
  if vr and vl then tr=sub(pr,pl)elseif vr then tr=sub(pr,p)elseif vl then tr=sub(p,pl)end
  if vu and vd then tu=sub(pu,pd)elseif vu then tu=sub(pu,p)elseif vd then tu=sub(p,pd)end
  if tr and tu then local n=cross(tr,tu)if mag(n)>.001 then n=unit(n)if dot(n,d)>0 then n=mul(n,-1)end if abs(dot(n,d))>.02 then return n end end end
 end
end

local function nativeCast(o,d)
 local ch=localData()local origin=o local total=0 local CHUNK=9990
 for _=1,2048 do
  local p,n,di,i,how=nativeRaw(origin,d,CHUNK)
  if not p then origin=add(origin,mul(d,CHUNK))total=total+CHUNK if not fin(origin)then return end
  else
   local hd=num(di)and di or mag(sub(p,origin))
   if skip(i,ch)then local step=hd+(isCharacterPart(i)and 7 or 2)origin=add(origin,mul(d,step))total=total+step
   else
    local nq="native"
    if not n then n=normalFromInstance(i,p,d)if n then nq="face"end end
    if not n then n=normalFromSamples(origin,d,p,hd,i)if n then nq="sample"end end
    if not n then return p,nil,i,total+hd,"native:"..tostring(how),"no-normal"end
    return p,unit(n),i,total+hd,"native:"..tostring(how),nq
   end
  end
 end
end

local function basis(n,f)
 n=unit(n)local up
 if abs(n.Y)>.82 then up=sub(f,mul(n,dot(f,n)))if mag(up)<.1 then up=sub(V(0,0,1),mul(n,dot(V(0,0,1),n)))end
 else up=sub(V(0,1,0),mul(n,n.Y))end
 up=unit(up)local r=unit(cross(up,n))
 return r,unit(cross(n,r)),n
end

local function fire(kind)
 local o,f=solveAim()if not(o and f)then return end
 local p,n,obj=nativeCast(o,f)if not(p and n)then return end
 if dot(n,f)>0 then n=mul(n,-1)end
 local r,u,nn=basis(n,f)local q={pos=add(p,mul(nn,.065)),right=r,up=u,normal=nn,obj=obj}
 if kind=="blue"then blue=q else orange=q end
end

local function plocal(p,v)local q=sub(v,p.pos)return dot(q,p.right),dot(q,p.up),dot(q,p.normal)end
local function aperture(x,y,extra)extra=extra or 0 local rx=x/(PW+.35+extra)local ry=y/(PH+.45+extra)return rx*rx+ry*ry<=1 end

local function primaryProbe(p,pos)
 if p.normal.Y>.72 then return add(pos,V(0,-2.75,0))elseif p.normal.Y<-.72 then return add(pos,V(0,2.7,0))end
 return sub(pos,mul(p.normal,1.15))
end

local function segmentCross(p,a,b)
 local ax,ay,az=plocal(p,a)local bx,by,bz=plocal(p,b)local dz=bz-az
 if abs(dz)<EPS then return end
 local t=-az/dz if t<0 or t>1 then return end
 local x=ax+(bx-ax)*t local y=ay+(by-ay)*t
 if aperture(x,y)then return true,x,y,az,bz end
end

local function crossing(p,prev,cur)
 local pa,pb=primaryProbe(p,prev),primaryProbe(p,cur)
 local ax,ay,az=plocal(p,pa)local bx,by,bz=plocal(p,pb)
 if bz>=-.22 and bz<=TOUCH and aperture(bx,by,.15)then return true,bx,by,max(bz,.01)end
 local ok,x,y,side=segmentCross(p,pa,pb)if ok then return true,x,y,side end
 if p.normal.Y>.72 and bz>=-.22 and bz<=TOUCH+.18 and aperture(bx,by,.2)and(not aperture(ax,ay,.1)or az>TOUCH)then return true,bx,by,max(az,.01)end
 return false
end

local function blockedActive(p,pos,vel)
 if not p then return false end
 local q=primaryProbe(p,pos)local x,y,z=plocal(p,q)
 if fin(vel)and dot(vel,p.normal)<-1 then return false end
 return z<=TOUCH+.35 and z>=-.45 and aperture(x,y,.35)
end

local function mapvec(v,a,b)
 local x,y,z=dot(v,a.right),dot(v,a.up),dot(v,a.normal)
 return add(add(mul(b.right,-x),mul(b.up,y)),mul(b.normal,-z))
end

local function faceThrough(root,a,b,nv)
 local look
 pcall(function()look=asvec(root.LookVector)if not look then local cf=root.CFrame look=asvec(cf.LookVector)end end)
 if not fin(look)then look=mag(nv)>.01 and unit(nv)or mul(a.normal,-1)end
 local nl=unit(mapvec(look,a,b))local flat=V(nl.X,0,nl.Z)
 if mag(flat)<.05 then flat=V(nv.X,0,nv.Z)end
 if mag(flat)>.001 then local yaw=deg(atan2(-flat.X,-flat.Z))pcall(function()root.Orientation=V(0,yaw,0)end)pcall(function()root.Rotation=V(0,yaw,0)end)end
end

local function tp(root,a,b,prev,cur)
 local ok,x,y,entrySide=crossing(a,prev,cur)if not ok then return false end
 local vel pcall(function()vel=root.Velocity end)if not fin(vel)then vel=V()end
 local vn=dot(vel,a.normal)
 if abs(vn)<2 then local speed=abs(a.normal.Y)>.72 and 8 or 6 local desired=entrySide>=0 and-speed or speed vel=add(vel,mul(a.normal,desired-vn))end
 local np=add(add(add(b.pos,mul(b.right,-x)),mul(b.up,y)),mul(b.normal,EXIT))
 local nv=mapvec(vel,a,b)local boost=b.normal.Y>.72 and BOOST_FLOOR or BOOST_OTHER local out=dot(nv,b.normal)if out<boost then nv=add(nv,mul(b.normal,boost-out))end
 local now=utility.GetTickCount()local wrote=pcall(function()root.Position=np root.Velocity=nv end)if not wrote then return false end
 faceThrough(root,a,b,nv)pcall(function()root.Velocity=nv end)
 pendingTP=nil blocked=b lastTP=now prevRoot=np
 return true
end

local function commitTP()pendingTP=nil return false end

local function portalPoint(p,a)return add(add(p.pos,mul(p.right,cos(a)*PW)),mul(p.up,sin(a)*PH))end

local function projected(p)
 local pts={}local cx,cy=0,0
 for i=0,SEG-1 do
  local x,y,on=w2s(portalPoint(p,i/SEG*math.pi*2))if not x or on~=true then return end
  pts[#pts+1]={x,y}cx=cx+x cy=cy+y
 end
 return pts,cx/SEG,cy/SEG
end

local function scaled(pts,cx,cy,s)
 local o={}for i=1,#pts do local p=pts[i]o[i]={cx+(p[1]-cx)*s,cy+(p[2]-cy)*s}end return o
end

local function drawPortal(p,isBlue)
 if not p then return end
 local pts,cx,cy=projected(p)if not pts then return end
 local tm=utility.GetTickCount()*.001 local pulse=(sin(tm*3.5)+1)*.5
 local col=isBlue and Color3.new(.07,.4,1)or Color3.new(1,.3,.025)
 local bright=isBlue and Color3.new(.58,.84,1)or Color3.new(1,.76,.35)
 local dark=isBlue and Color3.new(.001,.004,.022)or Color3.new(.028,.003,.001)
 local inner=scaled(pts,cx,cy,.945)
 pcall(draw.ConvexPolyFilled,pts,dark,240)
 pcall(draw.Polyline,pts,col,true,6,55+18*pulse)
 pcall(draw.Polyline,pts,col,true,3,225)
 pcall(draw.Polyline,inner,bright,true,1,200)
 local n=#pts local off=math.floor(tm*7)%n
 for k=0,1 do
  local st=(off+k*math.floor(n*.5))%n local a=pts[st+1]local b=pts[((st+1)%n)+1]
  line(a[1],a[2],b[1],b[2],255,isBlue and 225 or 190,isBlue and 255 or 75,210,2)
 end
end

local function reticle()
 local x,y=mouseXY()if not x then return end
 local c=ctrl()and 255 or 135
 line(x-8,y,x-3,y,c,c,c,225,1)line(x+3,y,x+8,y,c,c,c,225,1)line(x,y-8,x,y-3,c,c,c,225,1)line(x,y+3,x,y+8,c,c,c,225,1)
end

cheat.register("onUpdate",function()
 if GEN~=PORTAL_RUNTIME_GEN then return end
 local _,root=localData()
 if not root then prevRoot=nil blocked=nil pendingTP=nil return end
 local cur pcall(function()cur=root.Position end)if not fin(cur)then prevRoot=nil return end
 if not prevRoot then prevRoot=cur return end
 local vel pcall(function()vel=root.Velocity end)if not fin(vel)then vel=V()end
 if blocked and not blockedActive(blocked,cur,vel)then blocked=nil end
 if blue and orange and utility.GetTickCount()-lastTP>=CD then
  if blue~=blocked and tp(root,blue,orange,prevRoot,cur)then return end
  if orange~=blocked and tp(root,orange,blue,prevRoot,cur)then return end
 end
 prevRoot=cur
end)

cheat.register("onPaint",function()
 if GEN~=PORTAL_RUNTIME_GEN then return end
 local lc=mouse.is_clicked("leftmouse")local rc=mouse.is_clicked("rightmouse")local control=ctrl()
 if not utility.GetMenuState()and control then if lc then fire("blue")end if rc then fire("orange")end end
 local c=keyboard.is_pressed("c")local clearChord=control and c
 if clearChord and not clearHeld then blue,orange,blocked,pendingTP=nil,nil,nil,nil end
 clearHeld=clearChord
 drawPortal(blue,true)drawPortal(orange,false)reticle()
end)

cheat.register("onSlowUpdate",function()
 if GEN~=PORTAL_RUNTIME_GEN then return end
 if RUpdate then pcall(RUpdate)end
end)

cheat.register("newPlace",function()
 if GEN~=PORTAL_RUNTIME_GEN then return end
 blue,orange,blocked,prevRoot,pendingTP=nil,nil,nil,nil,nil
 aimYaw,aimPitch,lastMX,lastMY=nil,nil,nil,nil
 clearHeld=false
 if RUpdate then pcall(RUpdate)end
end)

if RUpdate then pcall(RUpdate)end
print("Made By Aoruen :3")
