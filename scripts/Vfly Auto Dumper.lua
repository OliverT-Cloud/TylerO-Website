local O={
    Humanoid_SeatPart=0xF8, --Humanoid::SeatPart
    BasePart_Primitive=0x178, --BasePart::Primitive
    Model_PrimaryPart=0x248, --Model::PrimaryPart
    Primitive_AssemblyLinearVelocity=0xE0, --Primitive::AssemblyLinearVelocity
    Primitive_AssemblyAngularVelocity=0xEC, --Primitive::AssemblyAngularVelocity
    Primitive_Rotation=0xB0, --Primitive::Rotation
    Camera_Rotation=0xC8, --Camera::Rotation
    VehicleSeat_SteerFloat=0x21C, --VehicleSeat::SteerFloat
    VehicleSeat_ThrottleFloat=0x220, --VehicleSeat::ThrottleFloat
    SolverPtrA=0x0, --AUTO DUMP
    SolverLinearVelA=0x0, --AUTO DUMP
    SolverAngularVelA=0x0, --AUTO DUMP
    SolverPtrB=0x0, --AUTO DUMP
    SolverLinearVelB=0x0, --AUTO DUMP
    SolverAngularVelB=0x0 --AUTO DUMP
}

local V=Vector3.new
local T,C,D="vfly","Main","Dump"
ui.newTab(T,"VFly")
ui.NewContainer(T,C,"Vehicle Fly",{autosize=true,next=true})
ui.NewContainer(T,D,"Auto Dumper",{autosize=true})

local en=ui.NewCheckbox(T,C,"Enable VFly")
local hotkey=ui.NewHotkey(T,C,"VFly",true)
local speed=ui.newSliderFloat(T,C,"VFly Speed",0.1,20,1)
local follow=ui.newSliderFloat(T,C,"Camera Follow",1,50,20)
local rollLock=ui.newSliderFloat(T,C,"Roll Lock",1,8,4)
local maxrot=ui.newSliderFloat(T,C,"Max Rotation Speed",1,40,18)

local rd,wr=memory.Read,memory.Write
local cache={seat=0,p=0}
local camCache,dumped=false,nil
local scan={armed=false}

local function valid(a)
    if not a or a==0 then return false end
    local o,v=pcall(memory.IsValid,a)
    return not o or v
end

local function rp(a)
    local o,v=pcall(rd,"pointer",a)
    return o and valid(v) and v or nil
end

local function rv(a)
    local o,v=pcall(rd,"vector3",a)
    return o and v or nil
end

local function wv(a,v)return a and v and pcall(wr,"vector3",a,v)end
local function wf(a,v)return a and pcall(wr,"float",a,v)end
local function key(k)local o,v=pcall(keyboard.IsPressed,k)return o and v or false end
local function dot(a,b)return a.X*b.X+a.Y*b.Y+a.Z*b.Z end
local function cross(a,b)return V(a.Y*b.Z-a.Z*b.Y,a.Z*b.X-a.X*b.Z,a.X*b.Y-a.Y*b.X)end

local function resolve(a)
    if not valid(a) then return end
    local d=workspace:GetDescendants()
    for i=1,#d do local x=d[i]if x and x.Address==a then return x end end
end

local function camera()
    if camCache and camCache.Address then return camCache end
    local o,c=pcall(function()return workspace.CurrentCamera end)
    if o and c and c.Address then camCache=c return c end
    local d=workspace:GetDescendants()
    for i=1,#d do
        local x=d[i]
        if x and x.ClassName=="Camera" and x.Address then camCache=x return x end
    end
end

local function setup()
    local lp=game.LocalPlayer
    local ch=lp and lp.Character
    local h=ch and ch:FindFirstChildOfClass("Humanoid")
    if not h or not h.Address then cache={seat=0,p=0}return end
    local sa=rp(h.Address+O.Humanoid_SeatPart)
    if not sa then cache={seat=0,p=0}return end
    if cache.seat==sa and valid(cache.p) then return true end
    local seat=resolve(sa)
    if not seat then return end
    local m=seat.Parent
    for i=1,8 do
        if not m then break end
        if m.ClassName=="Model" and m.Address then
            local ra=rp(m.Address+O.Model_PrimaryPart)
            local root=ra and resolve(ra)
            local p=root and rp(root.Address+O.BasePart_Primitive)
            if root and p then cache={seat=sa,seatObj=seat,root=root,p=p}return true end
        end
        m=m.Parent
    end
end

local function slots()
    if not dumped or not setup() then return end
    local p=cache.p
    local A=rp(p+O.SolverPtrA)
    local B=rp(p+O.SolverPtrB)
    if not A or not B then return end
    return p,A+O.SolverLinearVelA,A+O.SolverAngularVelA,B+O.SolverLinearVelB,B+O.SolverAngularVelB
end

local function rawBasis(a)
    local x,y,z=rv(a),rv(a+0xC),rv(a+0x18)
    if not x or not y or not z then return end
    local r,u,f=V(x.X,y.X,z.X),V(x.Y,y.Y,z.Y),V(-x.Z,-y.Z,-z.Z)
    if r.Magnitude<.001 or u.Magnitude<.001 or f.Magnitude<.001 then return end
    return f.Unit,r.Unit,u.Unit
end

local function cfBasis(cf)
    if not cf then return end
    local o,f,r,u=pcall(function()return cf.LookVector,cf.RightVector,cf.UpVector end)
    if o and f and r and u then return f,r,u end
end

local function camBasis()
    local cam=camera()
    if not cam then return end
    local o,cf=pcall(function()return cam.CFrame end)
    if o and cf then
        local f,r,u=cfBasis(cf)
        if f and r and u then return f,r,u end
    end
    o,cf=pcall(function()return cam.CoordinateFrame end)
    if o and cf then
        local f,r,u=cfBasis(cf)
        if f and r and u then return f,r,u end
    end
    if cam.Address then
        local f,r,u=rawBasis(cam.Address+O.Camera_Rotation)
        if f and r and u then return f,r,u end
    end
end

local function lockedCamBasis()
    local f,cr=camBasis()
    if not f then return end
    local up=V(0,1,0)
    local r=cross(f,up)
    if r.Magnitude<.01 then
        if cr then r=V(cr.X,0,cr.Z)end
        if not r or r.Magnitude<.01 then r=V(1,0,0)end
    end
    r=r.Unit
    local u=cross(r,f)
    if u.Magnitude<.01 then return end
    return f.Unit,r,u.Unit
end

local function neutralizeSeat()
    local s=cache.seatObj
    if not s or not s.Address then return end
    wf(s.Address+O.VehicleSeat_SteerFloat,0)
    wf(s.Address+O.VehicleSeat_ThrottleFloat,0)
end

local function flyVelocity()
    local f,r,u=lockedCamBasis()
    if not f or not r or not u then return end
    local fb=(key("W") and 1 or 0)-(key("S") and 1 or 0)
    local lr=(key("D") and 1 or 0)-(key("A") and 1 or 0)
    local qe=(key("E") and 2 or 0)-(key("Q") and 2 or 0)
    if fb==0 and lr==0 and qe==0 then return V(0,0,0)end
    return (f*fb+r*lr+u*((fb+qe)*.2))*(ui.GetValue(speed)*50)
end

local function cameraAngular(p)
    local tf,tr,tu=lockedCamBasis()
    local f,r,u=rawBasis(p+O.Primitive_Rotation)
    if not tf or not tr or not tu or not f or not r or not u then return end
    local e=(cross(f,tf)+cross(r,tr)+cross(u,tu))*.5
    local roll=dot(e,tf)
    e=e+tf*roll*(ui.GetValue(rollLock)-1)
    if e.Magnitude<.0001 then return V(0,0,0)end
    local av=e*ui.GetValue(follow)
    local m=ui.GetValue(maxrot)
    return av.Magnitude>m and av.Unit*m or av
end

local function setLinear(v,p,la,lb)
    wv(la,v)wv(lb,v)wv(p+O.Primitive_AssemblyLinearVelocity,v)
end

local function setAngular(v,p,aa,ab)
    wv(aa,v)wv(ab,v)wv(p+O.Primitive_AssemblyAngularVelocity,v)
end

local function close(a,b,min)
    if not a or not b then return false end
    local x,y,z=a.X-b.X,a.Y-b.Y,a.Z-b.Z
    return math.sqrt(x*x+y*y+z*z)<=math.max(min or .05,b.Magnitude*.06)
end

local function ptrs(p)
    local t={}
    for o=0,0x500,8 do
        local q=rp(p+o)
        if q then t[#t+1]={off=o,ptr=q}end
    end
    return t
end

local function fieldHits(obj,ref,min)
    local t={}
    for o=0x40,0x180,4 do
        if close(rv(obj+o),ref,min) then t[#t+1]=o end
    end
    table.sort(t)
    return t
end

local function startDump()
    if not setup() then print("[DUMP] Sit in a vehicle first")return end

    local p=cache.p
    local seat=cache.seatObj
    local sp=seat and seat.Address and rp(seat.Address+O.BasePart_Primitive)
    if not p or not sp then print("[DUMP] Could not resolve vehicle primitives")return end

    local ref=rv(p+O.Primitive_AssemblyLinearVelocity)
    if not ref or ref.Magnitude<20 then print("[DUMP] Drive faster than 20, then press Auto Dump")return end

    local R,S=ptrs(p),ptrs(sp)
    local smap,objects={},{}

    for i=1,#S do smap[S[i].ptr]=true end

    for i=1,#R do
        local x=R[i]
        if smap[x.ptr] then
            local o=objects[x.ptr]
            if not o then o={ptr=x.ptr,aliases={}}objects[x.ptr]=o end
            o.aliases[#o.aliases+1]=x.off
        end
    end

    local out={}
    for _,o in pairs(objects) do
        table.sort(o.aliases)
        local h=fieldHits(o.ptr,ref,1)
        if #h>0 then out[#out+1]={ptr=o.aliases[1],obj=o.ptr,vel=h[1],score=#h}end
    end

    table.sort(out,function(a,b)
        if a.score~=b.score then return a.score>b.score end
        return a.ptr<b.ptr
    end)

    if #out<2 then print("[DUMP] Could not locate both linear solver objects")return end

    local pick={out[1],out[2]}
    table.sort(pick,function(a,b)return a.ptr<b.ptr end)

    O.SolverPtrA,O.SolverLinearVelA=pick[1].ptr,pick[1].vel
    O.SolverPtrB,O.SolverLinearVelB=pick[2].ptr,pick[2].vel
    O.SolverAngularVelA,O.SolverAngularVelB=0,0
    dumped=false

    scan={
        armed=true,p=p,
        A={obj=pick[1].obj},
        B={obj=pick[2].obj}
    }

    print("========== LINEAR OFFSETS FOUND ==========")
    print(string.format("SolverPtrA=0x%X,",O.SolverPtrA))
    print(string.format("SolverLinearVelA=0x%X,",O.SolverLinearVelA))
    print(string.format("SolverPtrB=0x%X,",O.SolverPtrB))
    print(string.format("SolverLinearVelB=0x%X,",O.SolverLinearVelB))
    print("[DUMP] Turn/spin the vehicle - angular scan is armed")
    print("==========================================")
end

local function finishDump()
    if not scan.armed then return end
    if not setup() or cache.p~=scan.p then return end

    local ref=rv(cache.p+O.Primitive_AssemblyAngularVelocity)
    if not ref or ref.Magnitude<.2 then return end

    local A=fieldHits(scan.A.obj,ref,.05)
    local B=fieldHits(scan.B.obj,ref,.05)
    if #A==0 or #B==0 then return end

    O.SolverAngularVelA=A[1]
    O.SolverAngularVelB=B[1]
    scan.armed=false
    dumped=true

    print("========== VFLY AUTO DUMP COMPLETE ==========")
    print(string.format("SolverPtrA=0x%X,",O.SolverPtrA))
    print(string.format("SolverLinearVelA=0x%X,",O.SolverLinearVelA))
    print(string.format("SolverAngularVelA=0x%X,",O.SolverAngularVelA))
    print(string.format("SolverPtrB=0x%X,",O.SolverPtrB))
    print(string.format("SolverLinearVelB=0x%X,",O.SolverLinearVelB))
    print(string.format("SolverAngularVelB=0x%X",O.SolverAngularVelB))
    print("[DUMP] Applied for this session - VFly is ready")
    print("==============================================")
end

ui.NewButton(T,D,"Auto Dump VFly",function()
    local ok,e=xpcall(startDump,function(e)return tostring(e)end)
    if not ok then print("[DUMP] ERROR =",e)end
end)

local reg=cheat.Register or cheat.register
reg("onUpdate",function()
    if scan.armed then
        local ok,e=xpcall(finishDump,function(e)return tostring(e)end)
        if not ok then scan.armed=false print("[DUMP] ERROR =",e)end
    end

    if not dumped then return end
    if not ui.GetValue(en) or not ui.GetValue(hotkey) then return end

    local p,la,aa,lb,ab=slots()
    if not p then return end

    neutralizeSeat()

    local v=flyVelocity()
    if v then setLinear(v,p,la,lb)end

    local ok,av=pcall(cameraAngular,p)
    if ok and av then setAngular(av,p,aa,ab)end
end)

print("Made By Aoruen :3")

local theoKeys={
    Humanoid_SeatPart="Humanoid::SeatPart",
    BasePart_Primitive="BasePart::Primitive",
    Model_PrimaryPart="Model::PrimaryPart",
    Primitive_AssemblyLinearVelocity="Primitive::AssemblyLinearVelocity",
    Primitive_AssemblyAngularVelocity="Primitive::AssemblyAngularVelocity",
    Primitive_Rotation="Primitive::Rotation",
    Camera_Rotation="Camera::Rotation",
    VehicleSeat_SteerFloat="VehicleSeat::SteerFloat",
    VehicleSeat_ThrottleFloat="VehicleSeat::ThrottleFloat"
}

local function applyTheoOffsets(body)
    if type(body)~="string" then
        print("[VFly] Theo returned no offset text; using saved offsets")
        return
    end
    local found={}
    for line in body:gmatch("[^\r\n]+") do
        local name,hex=line:match("^%s*([%w_]+::[%w_]+)%s*=%s*0[xX]([%x]+)")
        if name and hex then found[name]=tonumber(hex,16)end
    end
    local pending={}
    for field,name in pairs(theoKeys) do
        local value=found[name]
        if not value or value<0x20 or value>0x4000 or value%4~=0 then
            print("[VFly] Theo missing or invalid: "..name.."; using saved offsets")
            return
        end
        pending[field]=value
    end
    local changed=false
    for field,value in pairs(pending) do
        if O[field]~=value then changed=true end
    end
    for field,value in pairs(pending) do O[field]=value end
    if changed then
        cache={seat=0,p=0}
        camCache=nil
        scan={armed=false}
        dumped=false
    end
    print("[VFly] Theo: all 9 regular offsets updated"..(changed and "; re-dump solver offsets if needed" or "; solver auto-dumper unchanged"))
end

if http and type(http.Get)=="function" then
    local ok,err=pcall(http.Get,"https://offsets.imtheo.lol/offsets.txt",{},function(body)
        local applied,reason=pcall(applyTheoOffsets,body)
        if not applied then print("[VFly] Theo parse error: "..tostring(reason).."; using saved offsets")end
    end)
    if not ok then print("[VFly] Theo request failed: "..tostring(err).."; using saved offsets")end
else
    print("[VFly] http.Get unavailable; using saved offsets")
end

