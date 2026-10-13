if not memory.GetBase() then return end
local R,W=memory.Read,memory.Write
local LP=game.LocalPlayer
if not LP then return end
local RS=game.GetService("ReplicatedStorage")
local WS=game.GetService("Workspace")
local OFF,TEX={},{}
local STR_LEN
local THEO_URL="https://offsets.imtheo.lol/offsets.txt"
local theoLoaded,theoError=false,"Theo offsets are still loading"
local function theoPick(t,...)
    for i=1,select("#",...)do
        local v=t[select(i,...)]
        if type(v)=="number"then return v end
    end
end
local function loadTheo(body)
    if type(body)~="string"or body==""then theoError="Theo returned no offset data"return end
    local o={}
    for line in body:gmatch("[^\r\n]+")do
        local n,h=line:match("([%w_%.:%-]+)%s*=%s*0x([%x]+)")
        if n and h then o[n]=tonumber(h,16)end
    end
    OFF.Parent=theoPick(o,"Instance::Parent")
    OFF.Children=theoPick(o,"Instance::ChildrenStart","Instance::Children")
    OFF.ChildrenEnd=theoPick(o,"Instance::ChildrenEnd")
    OFF.Name=theoPick(o,"Instance::NameContainer","Instance::Name")
    STR_LEN=theoPick(o,"Misc::StringLength","Instance::StringLength")
    TEX.Texture=theoPick(o,"Textures::Texture_Texture","Texture::Texture")
    TEX.Decal=theoPick(o,"Textures::Decal_Texture","Decal::Texture")
    local missing={}
    if not OFF.Parent then missing[#missing+1]="Instance::Parent"end
    if not OFF.Children then missing[#missing+1]="Instance::ChildrenStart"end
    if not OFF.ChildrenEnd then missing[#missing+1]="Instance::ChildrenEnd"end
    if not OFF.Name then missing[#missing+1]="Instance::NameContainer"end
    if not STR_LEN then missing[#missing+1]="Misc::StringLength"end
    if not TEX.Texture then missing[#missing+1]="Textures::Texture_Texture"end
    if not TEX.Decal then missing[#missing+1]="Textures::Decal_Texture"end
    if #missing>0 then theoError="Theo missing: "..table.concat(missing,", ") return end
    theoLoaded=true
    theoError=nil
end
local okTheo=pcall(function()
    http.Get(THEO_URL,{},function(body)
        local ok,err=pcall(loadTheo,body)
        if not ok then theoLoaded=false theoError="Theo parse failed: "..tostring(err)end
    end)
end)
if not okTheo then theoError="Theo request failed"end
local function needTheo(...)
    if not theoLoaded then return false,theoError or"Theo offsets unavailable"end
    for i=1,select("#",...)do if select(i,...)==nil then return false,"Required Theo offset unavailable"end end
    return true
end
local function valid(a)if type(a)~="number"or a==0 then return false end local ok,v=pcall(memory.IsValid,a)return ok and v==true end
local function mr(t,a)if not valid(a)then return nil end local ok,v=pcall(R,t,a)return ok and v or nil end
local function mw(t,a,v)if not valid(a)then return false end local ok=pcall(W,t,a,v)return ok end
local function kids(o)if not o then return{}end local ok,v=pcall(function()return o:GetChildren()end)return ok and type(v)=="table"and v or{}end
local function prop(o,p)if not o then return nil end local ok,v=pcall(function()return o[p]end)return ok and v or nil end
local function isa(o,c)if not o then return false end local ok,v=pcall(function()return o:IsA(c)end)return ok and v==true end
local function walk(root,fn,maxNodes,skipCharm)
    if not root then return 0 end
    local stack={root}
    local n=0
    maxNodes=maxNodes or 512
    while #stack>0 and n<maxNodes do
        local o=table.remove(stack)
        n=n+1
        pcall(fn,o)
        for _,c in ipairs(kids(o))do
            local name=tostring(prop(c,"Name")or"")
            if not(skipCharm and name=="_charm_attachment_model")then
                stack[#stack+1]=c
            end
        end
    end
    return n
end
local ps=LP:FindFirstChild("PlayerScripts")
local psAssets=ps and ps:FindFirstChild("Assets")
local psVM=psAssets and psAssets:FindFirstChild("ViewModels")
local psWF=psVM and psVM:FindFirstChild("Weapons")
local psMI=psAssets and psAssets:FindFirstChild("Misc")
local psWrap=psAssets and psAssets:FindFirstChild("WrapTextures")
local rsAssets=RS:FindFirstChild("Assets")
local rsTemp=rsAssets and rsAssets:FindFirstChild("Temp")
local rsVM=rsTemp and rsTemp:FindFirstChild("ViewModels")
local rsWF=rsVM and rsVM:FindFirstChild("Weapons")
local rsMI=rsTemp and rsTemp:FindFirstChild("Misc")
local rsWrap=rsTemp and rsTemp:FindFirstChild("WrapTextures")
local wfFolder=psWF or rsWF
local vmFolder=psVM or rsVM
local miFolder=psMI or rsMI
local wrapFolder=psWrap or rsWrap
if not wfFolder or not vmFolder or not miFolder then
    print("[Rivals] required asset folders missing")
    return
end
local function currentVM()
    local vms=WS:FindFirstChild("ViewModels")
    local fp=vms and vms:FindFirstChild("FirstPerson")
    if not fp then return nil,nil end
    for _,vm in ipairs(kids(fp))do
        local iv=vm:FindFirstChild("ItemVisual")
        if iv then return vm,iv end
    end
end
local function childRange(parent)
    if not parent or not parent.Address then return nil,nil end
    if not needTheo(OFF.Children,OFF.ChildrenEnd)then return nil,nil end
    local vec=mr("pointer",parent.Address+OFF.Children)
    if not vec then return nil,nil end
    return mr("pointer",vec),mr("pointer",vec+OFF.ChildrenEnd)
end
local function findSlot(b,e,target)
    if not b or not e or e<b then return nil end
    local count=math.floor((e-b)/16)
    if count<0 or count>4096 then return nil end
    for i=0,count-1 do
        local s=b+i*16
        if mr("pointer",s)==target then return s end
    end
end
local weapons={}for _,o in ipairs(kids(wfFolder))do local n=tostring(prop(o,"Name")or"")if n~=""then weapons[#weapons+1]=n end end table.sort(weapons)
local skins,skinSet={},{ }
for _,f in ipairs(kids(vmFolder))do
    if isa(f,"Folder")and prop(f,"Name")~="Weapons"then
        for _,s in ipairs(kids(f))do
            if isa(s,"Model")or isa(s,"Folder")then
                local n=tostring(prop(s,"Name")or"")
                if n~=""and not skinSet[n]then skinSet[n]=true skins[#skins+1]=n end
            end
        end
    end
end
table.sort(skins)
local defaults={}
for _,w in ipairs(weapons)do
    local o=wfFolder:FindFirstChild(w)
    if o then defaults[w]=o end
end
local effectFolders,folderDefaults={},{ }
for _,f in ipairs(kids(miFolder))do
    if isa(f,"Folder")then
        local n=tostring(prop(f,"Name")or"")
        effectFolders[n]=f
        local d=f:FindFirstChild("Default")
        if not d then local c=kids(f)d=c[1]end
        if d then folderDefaults[n]=d end
    end
end
local skinSwaps,weaponSwaps={},{ }
local activeSkinByWeapon={}
local nextSwapId=0
local function addSwap(weapon,parent,defaultObj,skinObj,slot)
    if not needTheo(OFF.Name,OFF.Parent)then return false end
    if not skinObj or not defaultObj or defaultObj==skinObj or not slot then return true end
    if not valid(defaultObj.Address)or not valid(skinObj.Address)or not valid(parent.Address)then return false end
    local origName=mr("pointer",skinObj.Address+OFF.Name)
    local origParent=mr("pointer",skinObj.Address+OFF.Parent)
    local defaultName=mr("pointer",defaultObj.Address+OFF.Name)
    if not origName or not origParent or not defaultName then return false end
    if not mw("pointer",slot,skinObj.Address)then return false end
    if not mw("pointer",skinObj.Address+OFF.Name,defaultName)then
        mw("pointer",slot,defaultObj.Address)
        return false
    end
    if not mw("pointer",skinObj.Address+OFF.Parent,parent.Address)then
        mw("pointer",skinObj.Address+OFF.Name,origName)
        mw("pointer",slot,defaultObj.Address)
        return false
    end
    if mr("pointer",slot)~=skinObj.Address then
        mw("pointer",skinObj.Address+OFF.Name,origName)
        mw("pointer",skinObj.Address+OFF.Parent,origParent)
        mw("pointer",slot,defaultObj.Address)
        return false
    end
    nextSwapId=nextSwapId+1
    local id=nextSwapId
    skinSwaps[id]={weapon=weapon,parent=parent,default=defaultObj,skin=skinObj,slot=slot,origName=origName,origParent=origParent}
    weaponSwaps[weapon]=weaponSwaps[weapon]or{}
    weaponSwaps[weapon][#weaponSwaps[weapon]+1]=id
    return true
end
local function revertSwap(id)
    if not needTheo(OFF.Name,OFF.Parent)then return false end
    local s=skinSwaps[id]
    if not s then return true end
    local ok=true
    if valid(s.slot)and s.default and valid(s.default.Address)then ok=mw("pointer",s.slot,s.default.Address)and ok end
    if s.skin and valid(s.skin.Address)then
        ok=mw("pointer",s.skin.Address+OFF.Name,s.origName)and ok
        ok=mw("pointer",s.skin.Address+OFF.Parent,s.origParent)and ok
    end
    if ok then
        skinSwaps[id]=nil
        local list=weaponSwaps[s.weapon]
        if list then
            for i=#list,1,-1 do if list[i]==id then table.remove(list,i)end end
            if #list==0 then weaponSwaps[s.weapon]=nil end
        end
    end
    return ok
end
local function revertWeapon(name)
    local list=weaponSwaps[name]
    if not list then activeSkinByWeapon[name]=nil return true end
    local ids={}
    for _,id in ipairs(list)do ids[#ids+1]=id end
    local ok=true
    for i=#ids,1,-1 do if not revertSwap(ids[i])then ok=false end end
    if ok then activeSkinByWeapon[name]=nil end
    return ok
end
local function revertAllSkins()
    local names={}
    for n in pairs(weaponSwaps)do names[#names+1]=n end
    local ok=true
    for _,n in ipairs(names)do if not revertWeapon(n)then ok=false end end
    return ok
end
local function findSkinIn(root,name)
    if not root or not name then return nil end
    for _,f in ipairs(kids(root))do
        if isa(f,"Folder")and prop(f,"Name")~="Weapons"then
            local s=f:FindFirstChild(name)
            if s then return s end
        end
    end
end
local function findSkin(name)return findSkinIn(vmFolder,name)end
local function applySkinPair(weapon,skin)
    if not weapon or not skin then return false,"Select a weapon and skin"end
    local tok,tmsg=needTheo(OFF.Parent,OFF.Children,OFF.ChildrenEnd,OFF.Name)
    if not tok then return false,tmsg end
    if weaponSwaps[weapon]and not revertWeapon(weapon)then return false,"Could not revert current skin"end
    local d=defaults[weapon]
    local s=findSkin(skin)
    if not d or not s then return false,"Skin asset not found"end
    if d==s then return true,"Default skin"end
    local b,e=childRange(wfFolder)
    local slot=b and findSlot(b,e,d.Address)
    if not slot then return false,"Weapon slot not found"end
    if not addSwap(weapon,wfFolder,d,s,slot)then
        revertWeapon(weapon)
        return false,"Weapon skin swap failed"
    end
    for folderName,f in pairs(effectFolders)do
        local de=folderDefaults[folderName]
        local se=de and f:FindFirstChild(skin)
        if de and se and se~=de then
            local fb,fe=childRange(f)
            local fs=fb and findSlot(fb,fe,de.Address)
            if fs and not addSwap(weapon,f,de,se,fs)then
                revertWeapon(weapon)
                return false,"Effect swap failed"
            end
        end
    end
    activeSkinByWeapon[weapon]=skin
    return true,"Applied · "..weapon.." / "..skin
end
local MATERIALS={"Plastic","SmoothPlastic","Neon","Wood","WoodPlanks","Marble","Basalt","Slate","CrackedLava","Concrete","Limestone","Granite","Pavement","Brick","Pebble","Cobblestone","Rock","Sandstone","CorrodedMetal","DiamondPlate","Foil","Metal","Grass","LeafyGrass","Sand","Fabric","Snow","Mud","Ground","Asphalt","Salt","Ice","Glacier","Glass","ForceField","Air","Water","Cardboard","Carpet","CeramicTiles","ClayRoofTiles","RoofShingles","Leather","Plaster","Rubber"}
local materialState={enabled=false,weapon=nil,material=MATERIALS[1]}
local originalMaterials={}
local function renderable(o)
    if not o then return false end
    local ok,a=pcall(function()return o:IsA("Part")end)
    if ok and a then return true end
    local ok2,b=pcall(function()return o:IsA("MeshPart")end)
    return ok2 and b or false
end
local function rememberAndSetMaterial(o,mat)
    if not renderable(o)then return end
    if originalMaterials[o]==nil then
        local ok,old=pcall(function()return o.Material end)
        if ok then originalMaterials[o]=old end
    end
    pcall(function()o.Material=mat end)
end
local function applyMaterialTree(root,mat)
    if not root then return end
    rememberAndSetMaterial(root,mat)
    local ok,desc=pcall(function()return root:GetDescendants()end)
    if not ok or not desc then return end
    for _,o in ipairs(desc)do rememberAndSetMaterial(o,mat)end
end
local function nameMatchesWeapon(o,weapon)
    if not o or not weapon then return false end
    local ok,n=pcall(function()return o.Name end)
    if not ok or type(n)~="string"then return false end
    n,weapon=n:lower(),tostring(weapon):lower()
    return n==weapon or n:find(weapon,1,true)~=nil
end
local function applyMaterialCurrent(weapon,mat)
    if not weapon or not mat then return false,"Select a weapon and material"end
    local asset=wfFolder and wfFolder:FindFirstChild(weapon)
    if asset then applyMaterialTree(asset,mat)end
    local roots={}
    local cam=WS and WS.CurrentCamera
    if cam then roots[#roots+1]=cam end
    if LP and LP.Character then roots[#roots+1]=LP.Character end
    if LP and LP.Backpack then roots[#roots+1]=LP.Backpack end
    for _,root in ipairs(roots)do
        local ok,desc=pcall(function()return root:GetDescendants()end)
        if ok and desc then
            for _,o in ipairs(desc)do
                if nameMatchesWeapon(o,weapon)then applyMaterialTree(o,mat)end
            end
        end
    end
    return true,"Material · "..weapon.." · "..mat
end
local function applyMaterial(weapon,mat)
    if not weapon or not mat then return false,"Select a weapon and material"end
    materialState.weapon=weapon
    materialState.material=mat
    materialState.enabled=true
    return applyMaterialCurrent(weapon,mat)
end
local function restoreMaterials()
    materialState.enabled=false
    materialState.weapon=nil
    local n=0
    for o,mat in pairs(originalMaterials)do
        local ok=pcall(function()o.Material=mat end)
        if ok then n=n+1 end
    end
    originalMaterials={}
    return true,"Materials restored · "..n
end

local partColorState={enabled=false,weapon=nil,r=255,g=255,b=255,invert=false,lastIV=0}
local originalPartColors={}
local function makeColor3(r,g,b)
    r=math.max(0,math.min(255,tonumber(r)or 255))
    g=math.max(0,math.min(255,tonumber(g)or 255))
    b=math.max(0,math.min(255,tonumber(b)or 255))
    local ok,v=pcall(function()
        if Color3 and Color3.fromRGB then return Color3.fromRGB(r,g,b)end
        if Color3 and Color3.new then return Color3.new(r,g,b)end
    end)
    return ok and v or nil
end
local function setPartColor(o,c)
    if not renderable(o)or not c then return false end
    if originalPartColors[o]==nil then
        local old=prop(o,"Color")
        if old~=nil then originalPartColors[o]=old end
    end
    return pcall(function()o.Color=c end)
end
local function applyPartColorTree(root,c)
    if not root or not c then return 0 end
    local n=0
    walk(root,function(o)
        if renderable(o)then
            local name=tostring(prop(o,"Name")or"")
            if name~="_charm_attachment_model"and setPartColor(o,c)then n=n+1 end
        end
    end,768,true)
    return n
end
local function applyPartColor(weapon,r,g,b,invert)
    if not weapon then return false,"Select a weapon"end
    if invert then r,g,b=255-r,255-g,255-b end
    local c=makeColor3(r,g,b)
    if not c then return false,"Color3 unavailable in this Serotonin build"end
    local count=0
    local asset=wfFolder:FindFirstChild(weapon)
    if asset then count=count+applyPartColorTree(asset,c)end
    local vm,iv=currentVM()
    if vm and iv and vmMatchesWeapon(vm,weapon)then
        count=count+applyPartColorTree(iv,c)
    end
    partColorState.enabled=true
    partColorState.weapon=weapon
    partColorState.r,partColorState.g,partColorState.b=r,g,b
    partColorState.invert=false
    partColorState.lastIV=iv and iv.Address or 0
    return true,string.format("Part color applied · %d parts",count)
end
local function restorePartColors()
    for o,c in pairs(originalPartColors)do
        pcall(function()if o then o.Color=c end end)
    end
    originalPartColors={}
    partColorState.enabled=false
    partColorState.weapon=nil
    partColorState.lastIV=0
    return true,"Part colors restored"
end
local function normalizeAsset(v)
    v=tostring(v or""):gsub("%s+","")
    if v==""then return nil end
    if v:match("^rbxassetid://%d+$")then return v end
    local id=v:match("(%d+)")
    return id and("rbxassetid://"..id)or nil
end
local wrapByName={}
local wrapFamilies={}
local familyNames={}
local function familyOf(name)
    local b=name:match("^(.-)_%d+$")
    if b and b~=""then return b end
    b=name:match("^(.-)%d+$")
    if b and b~=""and not name:match("^%d")then return b end
    return name
end
if wrapFolder then
    for _,o in ipairs(kids(wrapFolder))do
        local n=tostring(prop(o,"Name")or"")
        if n~=""then
            wrapByName[n]=o
            local fam=familyOf(n)
            wrapFamilies[fam]=wrapFamilies[fam]or{}
            wrapFamilies[fam][#wrapFamilies[fam]+1]=n
        end
    end
    for fam,list in pairs(wrapFamilies)do
        table.sort(list,function(a,b)
            if a==fam then return true end
            if b==fam then return false end
            local an=tonumber(a:match("(%d+)$"))or 999
            local bn=tonumber(b:match("(%d+)$"))or 999
            if an~=bn then return an<bn end
            return a<b
        end)
        familyNames[#familyNames+1]=fam
    end
    table.sort(familyNames)
end
if #familyNames==0 then familyNames={"Unavailable"}end
local function defaultVariant(fam)
    local list=wrapFamilies[fam]
    if not list or #list==0 then return nil end
    for _,n in ipairs(list)do if n==fam then return n end end
    for _,n in ipairs(list)do if n:match("_?1$")then return n end end
    return list[1]
end
local function readImage(o,depth)
    if not o or not o.Address then return nil end
    if not needTheo(STR_LEN)then return nil end
    local texOff=isa(o,"Texture")and TEX.Texture or(isa(o,"Decal")and TEX.Decal or nil)
    if not texOff then return nil end
    local field=o.Address+texOff
    local uri=mr("string",field)
    local len=mr("uint64",field+STR_LEN)
    local cap=mr("uint64",field+STR_LEN+8)
    local buf=mr("pointer",field)
    if type(uri)~="string"or uri==""then return nil end
    if type(len)~="number"or type(cap)~="number"or cap<0 or cap>4096 then return nil end
    if cap<=15 then buf=field elseif not valid(buf)then return nil end
    return{o=o,address=o.Address,field=field,buf=buf,len=len,cap=cap,uri=uri,depth=depth or 0,name=tostring(prop(o,"Name")or""),class=tostring(prop(o,"ClassName")or"")}
end
local function collectImages(root)
    local out,seen={},{}
    if not root then return out end
    local stack={{o=root,d=0}}
    local n=0
    while #stack>0 and n<1024 do
        local e=table.remove(stack)
        local o,d=e.o,e.d
        n=n+1
        if o~=root and(isa(o,"Texture")or isa(o,"Decal"))and o.Address and not seen[o.Address]then
            local x=readImage(o,d)
            if x then seen[o.Address]=true out[#out+1]=x end
        end
        for _,c in ipairs(kids(o))do stack[#stack+1]={o=c,d=d+1}end
    end
    table.sort(out,function(a,b)
        if a.depth~=b.depth then return a.depth<b.depth end
        if a.name~=b.name then return a.name<b.name end
        return a.address<b.address
    end)
    return out
end
local function dominant(list)
    if #list==0 then return{}end
    local groups,order={},{}
    for _,x in ipairs(list)do
        if not groups[x.uri]then groups[x.uri]={}order[#order+1]=x.uri end
        groups[x.uri][#groups[x.uri]+1]=x
    end
    local best=nil
    for _,k in ipairs(order)do if not best or #groups[k]>#groups[best]then best=k end end
    return best and groups[best]or{}
end
local function baseImages(all)
    if #all==0 then return{}end
    local generic={}
    for _,x in ipairs(all)do
        local n=x.name:lower()
        if x.depth==1 and(n=="texture"or n=="decal")then generic[#generic+1]=x end
    end
    if #generic>0 then
        local g=dominant(generic)
        if #g>1 then return g end
        if #generic<=6 then return generic end
        return g
    end
    local direct={}
    for _,x in ipairs(all)do if x.depth==1 then direct[#direct+1]=x end end
    if #direct>0 then
        local g=dominant(direct)
        if #g>1 then return g end
        if #direct<=6 then return direct end
        return g
    end
    return dominant(all)
end
local function writeImage(x,uri)
    if not needTheo(STR_LEN)then return false end
    if not x or type(uri)~="string"or #uri>x.cap then return false end
    local base=x.cap<=15 and x.field or x.buf
    if not valid(base)then return false end
    local span=x.cap<=15 and 15 or x.cap
    for i=0,span do
        local b=i<#uri and uri:byte(i+1)or 0
        if not mw("byte",base+i,b)then return false end
    end
    if not mw("uint64",x.field+STR_LEN,#uri)then return false end
    return mr("string",x.field)==uri
end
local wrapBackups={}
local clearAlphaState=function()end
local function snapshotWrap(name)
    if wrapBackups[name]then return wrapBackups[name]end
    local root=wrapByName[name]
    if not root then return nil,"Wrap folder not found"end
    local all=collectImages(root)
    if #all==0 then return nil,"No writable image layers"end
    local b={items={}}
    for _,x in ipairs(all)do
        local base=x.cap<=15 and x.field or x.buf
        if not valid(base)then return nil,"Invalid image buffer"end
        local span=x.cap<=15 and 15 or x.cap
        local bytes={}
        for i=0,span do bytes[i]=mr("byte",base+i)or 0 end
        local tr=prop(x.o,"Transparency")
        local tint=prop(x.o,"Color3")
        b.items[#b.items+1]={
            o=x.o,address=x.address,field=x.field,buf=x.buf,cap=x.cap,len=x.len,bytes=bytes,uri=x.uri,
            tint=tint,transparency=type(tr)=="number"and tr or nil
        }
    end
    wrapBackups[name]=b
    return b
end
local function restoreWrap(name,remove)
    local tok,tmsg=needTheo(STR_LEN)
    if not tok then return false,tmsg end
    local b=wrapBackups[name]
    if not b then return true,"Already native · "..tostring(name)end
    for _,q in ipairs(b.items)do
        if not valid(q.field)then return false,"Wrap data changed; restore stopped"end
        local base=q.cap<=15 and q.field or q.buf
        if not valid(base)then return false,"Wrap buffer changed; restore stopped"end
        local span=q.cap<=15 and 15 or q.cap
        for i=0,span do if not mw("byte",base+i,q.bytes[i]or 0)then return false,"Restore write failed"end end
        if not mw("uint64",q.field+STR_LEN,q.len)then return false,"Restore length failed"end
        if valid(q.address)then
            if q.o and q.tint~=nil then pcall(function()q.o.Color3=q.tint end)end
            if q.o and type(q.transparency)=="number"then
                pcall(function()q.o.Transparency=q.transparency end)
            end
        end
    end
    if remove~=false then wrapBackups[name]=nil end
    return true,"Restored native · "..name
end
local function restoreAllWraps()
    clearAlphaState()
    local names={}
    for n in pairs(wrapBackups)do names[#names+1]=n end
    table.sort(names)
    local bad={}
    for _,n in ipairs(names)do local ok=restoreWrap(n,true)if not ok then bad[#bad+1]=n end end
    if #bad>0 then return false,"Could not restore · "..table.concat(bad,", ")end
    return true,"All wraps restored"
end
local weaponRef,skinRef,materialRef,materialAutoRef
local skinStatusRef,materialStatusRef
local targetFamilyRef,sourceFamilyRef,mainSwapRef,decalSwapRef,customMainAssetRef,customDecalAssetRef,defaultEffectsRef,overlayEnableRef,overlayColorRef,overlayGlowRef,tintEffectsRef,partColorEnableRef,partColorRef,partInvertRef,partAutoRef,wrapStatusRef,partStatusRef,configNameRef,configDropRef,configStatusRef
local busy=false
local function setStatus(ref,text)if ref then pcall(function()ui.setValue(ref,tostring(text or""))end)end end
local function selectedWeapon()local i=weaponRef and ui.getValue(weaponRef)return i~=nil and weapons[i+1]or nil end
local function selectedSkin()local i=skinRef and ui.getValue(skinRef)return i~=nil and skins[i+1]or nil end
local function selectedMaterial()local i=materialRef and ui.getValue(materialRef)return i~=nil and MATERIALS[i+1]or nil end
local function selectedFamily(ref)local i=ref and ui.getValue(ref)return i~=nil and familyNames[i+1]or nil end
local alphaState={enabled=false,mult=1,targets={},lastApplied={}}
clearAlphaState=function()
    alphaState={enabled=false,mult=1,targets={},lastApplied={}}
end
local function registerAlphaTarget(o,mult)
    if not o or not o.Address or not valid(o.Address)then return end
    alphaState.enabled=mult<0.999
    alphaState.mult=mult
    alphaState.targets[o.Address]=o
end
local function updateAlphaState()
    if not alphaState.enabled then return end
    local mult=alphaState.mult
    local dead={}
    for addr,o in pairs(alphaState.targets)do
        if not o or not valid(addr)then
            dead[#dead+1]=addr
        else
            local cur=prop(o,"Transparency")
            local last=alphaState.lastApplied[addr]
            if type(cur)=="number"and cur==cur then
                if last==nil or math.abs(cur-last)>0.0005 then
                    local native=math.max(0,math.min(1,cur))
                    local filtered=1-(1-native)*mult
                    local ok=pcall(function()o.Transparency=filtered end)
                    if ok then alphaState.lastApplied[addr]=filtered end
                end
            end
        end
    end
    for _,a in ipairs(dead)do
        alphaState.targets[a]=nil
        alphaState.lastApplied[a]=nil
    end
end
local function pickerRGBA(ref)
    local ok,v=pcall(function()return ui.getValue(ref)end)
    if not ok or type(v)~="table"then return 255,255,255,255 end
    local r=tonumber(v.r or v.R or v[1])or 255
    local g=tonumber(v.g or v.G or v[2])or 255
    local b=tonumber(v.b or v.B or v[3])or 255
    local a=tonumber(v.a or v.A or v[4])or 255
    if r<=1 and g<=1 and b<=1 then r,g,b=r*255,g*255,b*255 end
    if a<=1 then a=a*255 end
    local function c(x)return math.max(0,math.min(255,x))end
    return c(r),c(g),c(b),c(a)
end
local function setTint(x,r,g,b,glow)
    if not x or not x.o or not valid(x.address)then return false end
    glow=math.max(0,math.min(4,tonumber(glow)or 1))
    local rr=(r/255)*glow
    local gg=(g/255)*glow
    local bb=(b/255)*glow
    local ok,c=pcall(function()return Color3.new(rr,gg,bb)end)
    if not ok or c==nil then return false end
    return pcall(function()x.o.Color3=c end)
end
local function setLayerTransparency(x,v)if not x or not x.o then return false end v=math.max(0,math.min(1,tonumber(v)or 0))return pcall(function()x.o.Transparency=v end)end
local function addressSet(list)local t={}for _,x in ipairs(list or{})do t[x.address]=true end return t end
local function extraImages(all)
    local base=baseImages(all)
    local baseSet=addressSet(base)
    local extra={}
    for _,x in ipairs(all or{})do
        if not baseSet[x.address]then extra[#extra+1]=x end
    end
    return base,extra
end
local function chooseUri(list,i)if not list or #list==0 then return nil end local q=list[((i-1)%#list)+1]return q and q.uri or nil end
local function originalUriList(name)
    local root=wrapByName[name]
    local current=root and collectImages(root)or{}
    local b=wrapBackups[name]
    if b and b.items then
        for i,x in ipairs(current)do
            local q=b.items[i]
            if q and q.uri then x.uri=q.uri end
        end
    end
    return current
end
local function prepareSelectedWrap()
    clearAlphaState()
    local tok,tmsg=needTheo(STR_LEN,TEX.Texture,TEX.Decal)
    if not tok then return false,tmsg end
    local targetFam=selectedFamily(targetFamilyRef)
    if not targetFam or targetFam=="Unavailable"then return false,"Choose an animated base wrap"end
    local targetMain=defaultVariant(targetFam)
    if not targetMain then return false,"Target wrap has no main variation"end
    local swapMain=mainSwapRef and ui.getValue(mainSwapRef)==true
    local swapDecals=decalSwapRef and ui.getValue(decalSwapRef)==true
    if not swapMain and not swapDecals then
        return false,"Enable Main Texture, Decal / Effect Swap, or both"
    end
    local mainUri=swapMain and normalizeAsset(ui.getValue(customMainAssetRef))or nil
    local decalUri=swapDecals and normalizeAsset(ui.getValue(customDecalAssetRef))or nil
    local sourceFam=selectedFamily(sourceFamilyRef)
    local needBuiltIn=(swapMain and not mainUri)or(swapDecals and not decalUri)
    local sourceMainName=nil
    if needBuiltIn then
        if not sourceFam or sourceFam=="Unavailable"then
            return false,"Choose Built-in Artwork or enter custom IDs for every enabled path"
        end
        sourceMainName=defaultVariant(sourceFam)
        if not sourceMainName then return false,"Built-in source has no main variation"end
    end
    local function sourceLayers(name)
        if not name then return{},{}end
        local all=originalUriList(name)
        return extraImages(all)
    end
    local srcMainBase,srcMainExtra={},{}
    if needBuiltIn then
        srcMainBase,srcMainExtra=sourceLayers(sourceMainName)
    end
    local defaultEffects=defaultEffectsRef and ui.getValue(defaultEffectsRef)==true
    local overrideTint=overlayEnableRef and ui.getValue(overlayEnableRef)==true
    local r,g,b,a=pickerRGBA(overlayColorRef)
    local glow=tonumber(ui.getValue(overlayGlowRef))or 1
    local alphaMult=math.max(0,math.min(1,a/255))
    local tintExtra=defaultEffects and overrideTint and tintEffectsRef and ui.getValue(tintEffectsRef)==true
    local touched={}
    local mainChanged,decalChanged,tinted,hidden=0,0,0,0
    local decalMissing={}
    local function restoreBefore(name)
        if wrapBackups[name]then
            local ok,msg=restoreWrap(name,true)
            if not ok then return false,msg end
        end
        return true
    end
    local function applyMain(name)
        local rok,rmsg=restoreBefore(name)
        if not rok then return false,rmsg end
        local root=wrapByName[name]
        local all=root and collectImages(root)or{}
        if #all==0 then return false,"No writable image layers · "..name end
        local base,extra=extraImages(all)
        if swapMain and #base==0 then return false,"No base artwork layers · "..name end
        local _,err=snapshotWrap(name)
        if err then return false,err end
        local selectedSet={}
        local ok=true
        if swapMain then
            for i,x in ipairs(base)do
                local uri=mainUri or chooseUri(srcMainBase,i)
                if not uri then return false,"Main texture source unavailable"end
                if #uri>x.cap then return false,"Main URI too long · "..name end
                if not writeImage(x,uri)then ok=false break end
                selectedSet[x.address]=true
                mainChanged=mainChanged+1
            end
        end
        if ok and swapDecals then
            if #extra==0 then
                decalMissing[#decalMissing+1]=name
            else
                for i,x in ipairs(extra)do
                    local uri=decalUri or chooseUri(srcMainExtra,i)
                    if not uri then break end
                    if #uri>x.cap then return false,"Decal/effect URI too long · "..name end
                    if not writeImage(x,uri)then ok=false break end
                    selectedSet[x.address]=true
                    decalChanged=decalChanged+1
                end
            end
        end
        local baseSet,extraSet=addressSet(base),addressSet(extra)
        if not defaultEffects then
            for _,x in ipairs(all)do
                local isBase=baseSet[x.address]==true
                local isExtra=extraSet[x.address]==true
                local selected=selectedSet[x.address]==true
                if selected then
                    ok=setTint(x,255,255,255,1)and ok
                elseif (swapMain and isBase) or (swapDecals and isExtra) then
                    if x.class=="Texture"or x.class=="Decal"then
                        ok=setLayerTransparency(x,1)and ok
                        hidden=hidden+1
                    end
                end
            end
        end
        if overrideTint then
            for _,x in ipairs(all)do
                local isBase=baseSet[x.address]==true
                local isExtra=extraSet[x.address]==true
                local selected=selectedSet[x.address]==true
                local belongsToEnabledPath=(swapMain and isBase) or (swapDecals and isExtra)
                if selected or(tintExtra and belongsToEnabledPath and not selected)then
                    ok=setTint(x,r,g,b,glow)and ok
                    if alphaMult<0.999 then registerAlphaTarget(x.o,alphaMult)end
                    tinted=tinted+1
                end
            end
        end
        if not ok then return false,"Apply failed · "..name end
        touched[#touched+1]=name
        return true
    end
    local ok,msg=applyMain(targetMain)
    if not ok then
        for _,n in ipairs(touched)do restoreWrap(n,true)end
        clearAlphaState()
        return false,msg
    end
    if alphaState.enabled then updateAlphaState()end
    local parts={}
    if swapMain then parts[#parts+1]="Main="..(mainUri and"custom"or sourceMainName)end
    if swapDecals then parts[#parts+1]="Decals="..(decalUri and"custom"or"built-in effects")end
    local fx=defaultEffects and"default effects"or("bare + "..hidden.." unused layers hidden")
    if overrideTint then fx=fx..string.format(" + tint %d%%",math.floor(alphaMult*100+0.5))end
    if #decalMissing>0 then
        fx=fx.." · no separate decal/effect layer on "..table.concat(decalMissing,", ")
    end
    return true,string.format(
        "%s · main=%s · %s · changed M%d/D%d",
        targetFam,tostring(targetMain),table.concat(parts," / "),mainChanged,decalChanged
    )
end
local function restoreSelectedFamily()
    clearAlphaState()
    local fam=selectedFamily(targetFamilyRef)
    if not fam or fam=="Unavailable"then return false,"Select a wrap"end
    local list=wrapFamilies[fam]or{}
    local bad={}
    for _,n in ipairs(list)do local ok=restoreWrap(n,true)if not ok then bad[#bad+1]=n end end
    if #bad>0 then return false,"Restore failed · "..table.concat(bad,", ")end
    return true,"Restored family · "..fam
end

local updateWrapUIVisibility=function()end
local CFG_DIR="RivalsWrapConfigs"
local function fv(ref,default)
    if not ref then return default end
    local ok,v=pcall(function()return ui.getValue(ref)end)
    return ok and v~=nil and v or default
end
local function safeName(v)
    v=tostring(v or""):gsub("^%s+",""):gsub("%s+$",""):gsub("%s+","_"):gsub("[^%w%-%_]","_"):gsub("_+","_")
    return v:sub(1,48)
end
local function enc(v)
    return(tostring(v or""):gsub("([^%w%-%._~])",function(c)return string.format("%%%02X",string.byte(c))end))
end
local function dec(v)
    return(tostring(v or""):gsub("%%(%x%x)",function(h)return string.char(tonumber(h,16))end))
end
local function ensureCfgDir()
    if type(file)~="table"then return false end
    local mk=file.mkdir or file.Mkdir
    if type(mk)~="function"then return false end
    local ok=pcall(mk,CFG_DIR)
    return ok
end
local function cfgPath(name)return CFG_DIR.."/"..safeName(name)..".cfg"end
local function listConfigs()
    ensureCfgDir()
    local out={}
    local ls=type(file)=="table"and(file.listdir or file.ListDir)
    if type(ls)=="function"then
        local ok,a=pcall(ls,CFG_DIR)
        if ok and type(a)=="table"then
            for _,v in ipairs(a)do
                local x=type(v)=="table"and tostring(v.name or v.Name or v.path or v.Path or"")or tostring(v or"")
                x=x:gsub("\\","/")
                local n=x:match("([^/]+)%.cfg$")
                if n then out[#out+1]=n end
            end
        end
    end
    table.sort(out,function(a,b)return a:lower()<b:lower()end)
    return out
end
local function colorValue(ref)
    local r,g,b,a=pickerRGBA(ref)
    return string.format("%g,%g,%g,%g",r,g,b,a)
end
local function parseColor(v)
    local r,g,b,a=tostring(v or""):match("^([^,]+),([^,]+),([^,]+),([^,]+)$")
    if not r then return nil end
    return{r=tonumber(r)or 255,g=tonumber(g)or 255,b=tonumber(b)or 255,a=tonumber(a)or 255}
end
local function findIndex(list,name)
    name=tostring(name or"")
    for i,v in ipairs(list or{})do if tostring(v)==name then return i-1 end end
    return nil
end
local function captureConfig()
    return{
        version="1",
        weapon=selectedWeapon()or"",
        skin=selectedSkin()or"",
        material=selectedMaterial()or"",
        materialAuto=fv(materialAutoRef,false)and"1"or"0",
        targetFamily=selectedFamily(targetFamilyRef)or"",
        sourceFamily=selectedFamily(sourceFamilyRef)or"",
        mainSwap=fv(mainSwapRef,false)and"1"or"0",
        mainAsset=tostring(fv(customMainAssetRef,"")or""),
        decalSwap=fv(decalSwapRef,false)and"1"or"0",
        decalAsset=tostring(fv(customDecalAssetRef,"")or""),
        partEnable=fv(partColorEnableRef,false)and"1"or"0",
        partColor=colorValue(partColorRef),
        partInvert=fv(partInvertRef,false)and"1"or"0",
        partAuto=fv(partAutoRef,false)and"1"or"0",
        defaultEffects=fv(defaultEffectsRef,false)and"1"or"0",
        overlayEnable=fv(overlayEnableRef,false)and"1"or"0",
        overlayColor=colorValue(overlayColorRef),
        overlayGlow=tostring(fv(overlayGlowRef,1)or 1),
        tintEffects=fv(tintEffectsRef,false)and"1"or"0"
    }
end
local CFG_ORDER={"version","weapon","skin","material","materialAuto","targetFamily","sourceFamily","mainSwap","mainAsset","decalSwap","decalAsset","partEnable","partColor","partInvert","partAuto","defaultEffects","overlayEnable","overlayColor","overlayGlow","tintEffects"}
local function saveConfig(name)
    if type(file)~="table"then return false,"File API unavailable"end
    local wr=file.write or file.Write
    if type(wr)~="function"then return false,"file.write unavailable"end
    ensureCfgDir()
    local c=captureConfig()
    local lines={}
    for _,k in ipairs(CFG_ORDER)do lines[#lines+1]=k.."="..enc(c[k])end
    local ok,r=pcall(wr,cfgPath(name),table.concat(lines,"\n"))
    return ok and r~=false,(ok and r~=false)and("Saved · "..safeName(name))or"Save failed"
end
local function readConfig(name)
    if type(file)~="table"then return nil,"File API unavailable"end
    local rd=file.read or file.Read
    if type(rd)~="function"then return nil,"file.read unavailable"end
    local ok,body=pcall(rd,cfgPath(name))
    if not ok or type(body)~="string"or body==""then return nil,"Config not found · "..safeName(name)end
    local c={}
    for line in body:gmatch("[^\r\n]+")do
        local k,v=line:match("^([^=]+)=(.*)$")
        if k then c[k]=dec(v)end
    end
    return c
end
local function setv(ref,v)if ref and v~=nil then pcall(function()ui.setValue(ref,v)end)end end
local function loadUiConfig(name)
    local c,err=readConfig(name)
    if not c then return false,err end
    local i=findIndex(weapons,c.weapon)if i~=nil then setv(weaponRef,i)end
    i=findIndex(skins,c.skin)if i~=nil then setv(skinRef,i)end
    i=findIndex(MATERIALS,c.material)if i~=nil then setv(materialRef,i)end
    i=findIndex(familyNames,c.targetFamily)if i~=nil then setv(targetFamilyRef,i)end
    i=findIndex(familyNames,c.sourceFamily)if i~=nil then setv(sourceFamilyRef,i)end
    setv(materialAutoRef,c.materialAuto=="1")
    setv(mainSwapRef,c.mainSwap=="1")
    setv(customMainAssetRef,c.mainAsset or"")
    setv(decalSwapRef,c.decalSwap=="1")
    setv(customDecalAssetRef,c.decalAsset or"")
    setv(partColorEnableRef,c.partEnable=="1")
    setv(partInvertRef,c.partInvert=="1")
    setv(partAutoRef,c.partAuto=="1")
    setv(defaultEffectsRef,c.defaultEffects=="1")
    setv(overlayEnableRef,c.overlayEnable=="1")
    setv(overlayGlowRef,tonumber(c.overlayGlow)or 1)
    setv(tintEffectsRef,c.tintEffects=="1")
    local pc=parseColor(c.partColor)if pc then setv(partColorRef,pc)end
    local oc=parseColor(c.overlayColor)if oc then setv(overlayColorRef,oc)end
    return true,"Loaded · "..safeName(name)
end
local function deleteConfig(name)
    if type(file)~="table"then return false,"File API unavailable"end
    local del=file.delete or file.Delete
    if type(del)~="function"then return false,"file.delete unavailable"end
    local ok,r=pcall(del,cfgPath(name))
    return ok and r~=false,(ok and r~=false)and("Deleted · "..safeName(name))or"Delete failed"
end
local function loadApplyConfig(name)
    local ok,msg=loadUiConfig(name)
    if not ok then return false,msg end
    pcall(updateWrapUIVisibility)
    local errors={}
    local w,sk=selectedWeapon(),selectedSkin()
    if w and sk then local a,b=applySkinPair(w,sk)if not a then errors[#errors+1]=tostring(b)end end
    local mat=selectedMaterial()
    if w and mat then local a,b=applyMaterial(w,mat)if not a then errors[#errors+1]=tostring(b)end end
    if fv(partColorEnableRef,false)and w then
        local r,g,b=pickerRGBA(partColorRef)
        local a,m=applyPartColor(w,r,g,b,fv(partInvertRef,false))
        if not a then errors[#errors+1]=tostring(m)end
    else
        restorePartColors()
    end
    if fv(mainSwapRef,false)or fv(decalSwapRef,false)then
        local a,m=prepareSelectedWrap()
        if not a then errors[#errors+1]=tostring(m)end
    end
    if #errors>0 then return false,"Loaded, partial apply · "..table.concat(errors," | ")end
    return true,"Loaded + applied · "..safeName(name)
end
local configNames={"No configs"}
local function configWidget()
    if type(configDropRef)=="table"or type(configDropRef)=="userdata"then return configDropRef end
    local f=ui and(ui.GetWidget or ui.getWidget)
    if type(f)=="function"then
        local ok,w=pcall(f,"rivals_static_wrap","config","Config")
        if ok then return w end
    end
end
local function setConfigItems(a)
    local w=configWidget()
    if not w then return false end
    return pcall(function()
        if type(w.items)=="function"then w:items(a)
        elseif type(w.Items)=="function"then w:Items(a)
        elseif type(w.setItems)=="function"then w:setItems(a)
        elseif type(w.SetItems)=="function"then w:SetItems(a)
        elseif type(w.setOptions)=="function"then w:setOptions(a)
        elseif type(w.SetOptions)=="function"then w:SetOptions(a)
        else error("no item mutator")end
    end)
end
local function selectedConfig()
    local i=tonumber(fv(configDropRef,0))or 0
    local n=configNames[i+1]
    if not n or n=="No configs"then return nil end
    return n
end
local function selectConfigName(name)
    for i=1,#configNames do
        if configNames[i]==name then setv(configDropRef,i-1)return true end
    end
    return false
end
local function refreshConfigs(sel)
    local old=sel or selectedConfig()
    local a=listConfigs()
    if #a==0 then a={"No configs"}end
    configNames=a
    setConfigItems(a)
    if old and selectConfigName(old)then return true end
    setv(configDropRef,0)
    return true
end
local function configChoiceOrName()
    local n=selectedConfig()
    if n then return n end
    n=safeName(fv(configNameRef,""))
    return n~=""and n or nil
end
local function locked(ref,fn)
    if busy then return end
    busy=true
    local ok,a,b=xpcall(fn,function(e)return tostring(e)end)
    busy=false
    if not ok then
        setStatus(ref,"Protected error · "..tostring(a))
        print("[Rivals]",a)
        return
    end
    setStatus(ref,(a and"✓ "or"✗ ")..tostring(b or""))
end
ui.newTab("rivals_cosmetics","Rivals")
ui.NewContainer("rivals_cosmetics","skin","Weapon Skin",{autosize=true})
weaponRef=ui.NewDropdown("rivals_cosmetics","skin","Weapon",weapons,0)
skinRef=ui.NewDropdown("rivals_cosmetics","skin","Skin",skins,0)
skinStatusRef=ui.newInputText("rivals_cosmetics","skin","Status","Ready")
ui.NewButton("rivals_cosmetics","skin","Apply Skin",function()
    locked(skinStatusRef,function()return applySkinPair(selectedWeapon(),selectedSkin())end)
end)
ui.NewButton("rivals_cosmetics","skin","Revert Skin",function()
    locked(skinStatusRef,function()
        local w=selectedWeapon()
        if not w then return false,"Select a weapon"end
        local ok=revertWeapon(w)
        return ok,ok and("Reverted · "..w)or"Revert failed"
    end)
end)
ui.NewContainer("rivals_cosmetics","material","Material",{autosize=true,next=true})
materialRef=ui.NewDropdown("rivals_cosmetics","material","Material",MATERIALS,0)
materialAutoRef=ui.NewCheckbox("rivals_cosmetics","material","Auto Reapply")
materialStatusRef=ui.newInputText("rivals_cosmetics","material","Status","Ready")
ui.NewButton("rivals_cosmetics","material","Apply Material",function()
    locked(materialStatusRef,function()return applyMaterial(selectedWeapon(),selectedMaterial())end)
end)
ui.NewButton("rivals_cosmetics","material","Restore Material",function()
    locked(materialStatusRef,function()
        pcall(function()ui.setValue(materialAutoRef,false)end)
        return restoreMaterials()
    end)
end)
ui.NewContainer("rivals_cosmetics","reset","Reset",{autosize=true})
ui.NewButton("rivals_cosmetics","reset","Revert Everything",function()
    locked(skinStatusRef,function()
        local s=revertAllSkins()
        pcall(function()ui.setValue(materialAutoRef,false)end)
        restoreMaterials()
        restorePartColors()
        local w=restoreAllWraps()
        return s and w,(s and w)and"Everything restored"or"Partial restore"
    end)
end)
ui.newTab("rivals_static_wrap","Wraps")
ui.NewContainer("rivals_static_wrap","art","Artwork Versions",{autosize=true})
targetFamilyRef=ui.NewDropdown("rivals_static_wrap","art","Animated Base",familyNames,0)
sourceFamilyRef=ui.NewDropdown("rivals_static_wrap","art","Built-in Artwork",familyNames,0)
mainSwapRef=ui.NewCheckbox("rivals_static_wrap","art","Main Texture Swap")
customMainAssetRef=ui.newInputText("rivals_static_wrap","art","Main Custom Asset ID","")
decalSwapRef=ui.NewCheckbox("rivals_static_wrap","art","Decal / Effect Swap")
customDecalAssetRef=ui.newInputText("rivals_static_wrap","art","Decal Custom Asset ID","")
pcall(function()ui.setValue(mainSwapRef,true)end)
pcall(function()ui.setValue(decalSwapRef,false)end)
pcall(function()ui.setVisibility("rivals_static_wrap","art","Main Custom Asset ID",true)end)
pcall(function()ui.setVisibility("rivals_static_wrap","art","Decal Custom Asset ID",false)end)
ui.NewContainer("rivals_static_wrap","parts","Regular Parts",{autosize=true,next=true})
partColorEnableRef=ui.NewCheckbox("rivals_static_wrap","parts","Enable Part Color")
partColorRef=ui.NewColorpicker("rivals_static_wrap","parts","Part Color",{r=255,g=255,b=255,a=255})
partInvertRef=ui.NewCheckbox("rivals_static_wrap","parts","Invert Color")
partAutoRef=ui.NewCheckbox("rivals_static_wrap","parts","Auto Reapply")
partStatusRef=ui.newInputText("rivals_static_wrap","parts","Status","Colors normal gun Parts / MeshParts")
ui.NewButton("rivals_static_wrap","parts","Apply Part Color",function()
    locked(partStatusRef,function()
        if ui.getValue(partColorEnableRef)~=true then return false,"Enable Part Color first"end
        local r,g,b=pickerRGBA(partColorRef)
        return applyPartColor(selectedWeapon(),r,g,b,ui.getValue(partInvertRef)==true)
    end)
end)
ui.NewButton("rivals_static_wrap","parts","Restore Part Color",function()
    locked(partStatusRef,restorePartColors)
end)
ui.NewContainer("rivals_static_wrap","overlay","Effects / Overlay",{autosize=true})
defaultEffectsRef=ui.NewCheckbox("rivals_static_wrap","overlay","Default Effects")
overlayEnableRef=ui.NewCheckbox("rivals_static_wrap","overlay","Override Overlay Tint")
overlayColorRef=ui.NewColorpicker("rivals_static_wrap","overlay","Overlay Tint",{r=255,g=255,b=255,a=255})
overlayGlowRef=ui.newSliderFloat("rivals_static_wrap","overlay","Tint Brightness",0,4,1)
tintEffectsRef=ui.NewCheckbox("rivals_static_wrap","overlay","Tint Extra Effect Layers")
ui.NewContainer("rivals_static_wrap","apply","Apply / Restore",{autosize=true,next=true})
wrapStatusRef=ui.newInputText(
    "rivals_static_wrap","apply","Status",
    "Main Texture + optional Decal / Effect texture swap"
)
ui.NewButton("rivals_static_wrap","apply","Apply Artwork / Overlay",function()
    locked(wrapStatusRef,prepareSelectedWrap)
end)
ui.NewButton("rivals_static_wrap","apply","Restore Selected Wrap",function()
    locked(wrapStatusRef,restoreSelectedFamily)
end)
ui.NewButton("rivals_static_wrap","apply","Restore All Wraps",function()
    locked(wrapStatusRef,restoreAllWraps)
end)
ui.NewContainer("rivals_static_wrap","config","Custom Configs",{autosize=true})
configNameRef=ui.newInputText("rivals_static_wrap","config","Config Name","","name")
do
    local a=listConfigs()
    configNames=#a>0 and a or{"No configs"}
end
configDropRef=ui.NewDropdown("rivals_static_wrap","config","Config",configNames,0)
configStatusRef=ui.newInputText("rivals_static_wrap","config","Config Status","Ready")
ui.NewButton("rivals_static_wrap","config","Save",function()
    locked(configStatusRef,function()
        local n=safeName(fv(configNameRef,""))
        if n==""then n=selectedConfig()or""end
        if n==""then return false,"Enter a config name"end
        local ok,msg=saveConfig(n)
        if ok then setv(configNameRef,n)refreshConfigs(n)end
        return ok,msg
    end)
end)
ui.NewButton("rivals_static_wrap","config","Load",function()
    locked(configStatusRef,function()
        local n=configChoiceOrName()
        if not n then return false,"Select a config"end
        local ok,msg=loadApplyConfig(n)
        if ok then setv(configNameRef,n)selectConfigName(n)pcall(updateWrapUIVisibility)end
        return ok,msg
    end)
end)
ui.NewButton("rivals_static_wrap","config","Refresh",function()
    locked(configStatusRef,function()
        refreshConfigs()
        return true,#configNames==1 and configNames[1]=="No configs"and"No saved configs"or("Configs · "..#configNames)
    end)
end)
ui.NewButton("rivals_static_wrap","config","Delete",function()
    locked(configStatusRef,function()
        local n=configChoiceOrName()
        if not n then return false,"Select a config"end
        local ok,msg=deleteConfig(n)
        if ok then setv(configNameRef,"")refreshConfigs()end
        return ok,msg
    end)
end)
refreshConfigs()
local uiVisibilityState={main=nil,decal=nil}
updateWrapUIVisibility=function()
    local main=mainSwapRef and ui.getValue(mainSwapRef)==true
    local decal=decalSwapRef and ui.getValue(decalSwapRef)==true
    if uiVisibilityState.main~=main then
        uiVisibilityState.main=main
        pcall(function()ui.setVisibility("rivals_static_wrap","art","Main Custom Asset ID",main)end)
    end
    if uiVisibilityState.decal~=decal then
        uiVisibilityState.decal=decal
        pcall(function()ui.setVisibility("rivals_static_wrap","art","Decal Custom Asset ID",decal)end)
    end
end
pcall(updateWrapUIVisibility)
local matTick=0
pcall(function()
    cheat.register("onUpdate",function()
        pcall(updateWrapUIVisibility)
        if alphaState.enabled then pcall(updateAlphaState)end
        matTick=matTick+1
        if matTick<15 then return end
        matTick=0
        local vm,iv=currentVM()
        local a=iv and iv.Address or 0
        if partColorState.enabled and partAutoRef and ui.getValue(partAutoRef)==true and a~=partColorState.lastIV then
            local r,g,b=pickerRGBA(partColorRef)
            applyPartColor(partColorState.weapon,r,g,b,partInvertRef and ui.getValue(partInvertRef)==true)
        end
        if materialState.enabled and ui.getValue(materialAutoRef)==true then
            applyMaterialCurrent(materialState.weapon,materialState.material)
        end
    end)
end)
print("Made By Aoruen :3")
