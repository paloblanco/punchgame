-- TODO:
-- save, load, and select slots - working
    -- display number of existing levels - done
    -- default counter to move to the first available slot, can't move beyond - sort of done
    -- allow you to save to a slot and push other items back
    -- delete - done
-- memswapping - send to working cart, save locally, export, etc
    -- every time you do a memory operation, create a timestamped backup - done
-- drawing utils
    -- rectfill
    -- directional fill


function _init()
	-- poke(0x5F36, 0x8) -- draw sprite 0 
    -- poke(0x5f36,1) -- multidisplay
    poke(0x5f36,9)
	poke(24365,1) -- mouse
    poke(0x5f56,0x80) -- extended mem for map
    poke(0x5f57,0) -- map width. 256. yuge.
    
    camera_all(0,0)

	--clear extended
	-- memset(0x8000,0,0x7fff)
    -- poke(0xffff,0)
	--clear regular
	--memset(0x2000,0,0x1000)
	-- memset(0x3000,0,0x0100)

	--maptest
	xbound=16--256
	ybound=16--127
	-- for xx=0,xbound-1,1 do mset(xx,0,1) mset(xx,ybound-1,1) end
	-- for yy=0,ybound-1,1 do mset(0,yy,1) mset(xbound-1,yy,1) end
    
    -- mapping vars
    current_tile = 0
    undo_stack = {}
    viewgrid = true

	current_address = 0x2000
    len_address = 0x2fff
	address_list = {}
	current_level_ix = 0
    assign_max_ix()

    -- control vars
    -- mouse
    m0 = false
    m0p = false
    m1 = false
    m1p = false
    m2 = false
    m2p = false
    ms = 0 --scroll
    key=nil
    bucket=false
    movespeed=6
    
    rect_click = false
    rectx0=0
    rectx1=0
    recty0=0
    recty1=0
end

function assign_max_ix()
    max_ix=-1
    local i=0
    local len=peek(len_address-i)
    while len>0 do
        i+=1
        len=peek(len_address-i)
    end
    max_ix = i-1
end

function _update()
    controls()
    if (m0 and (not bucket)) place_tile()
    if (m0 and (bucket)) fill_tile()
    if (m1) dropper_tile()
    

    -- keyboard
	if (check_key("1")) compress_map_to_location()
	if (check_key("2")) decompress_from_memory_to_map()
	if (check_key("3")) compress_to_current_ix()

    if (check_key(",")) current_level_ix = max(0,current_level_ix-1)
    if (check_key(".")) current_level_ix += 1

    if (check_key("4")) save_export()
    if (check_key("5")) save_local()

	if (check_key("6")) delete_current_ix()
    if (check_key("7")) clear_working_map()
    if (check_key("8")) clear_longterm_memory()

    if (check_key("[")) xbound -= 16
    if (check_key("]")) xbound += 16
    if (check_key("-")) ybound -= 16
    if (check_key("=")) ybound += 16

    if (check_key("g")) viewgrid = not viewgrid
    if (check_key("b")) bucket = not bucket
    if (check_key("r")) rect_fill()
    if (check_key("z")) undo()
    assign_max_ix()

end

function rect_fill()
    if not rect_click then
        rectx0 = mousex\8
        recty0 = mousey\8
        rect_click = true
    else
        rectx1 = mousex\8
        recty1 = mousey\8
        for xx=rectx0,rectx1,sgn(rectx1-rectx0) do for yy=recty0,recty1,sgn(recty1-recty0) do
            place_tile(xx,yy)
        end end
        rect_click = false
    end
end

function clear_working_map()
    memset(0x8000,0,0x7fff)
    poke(0xffff,0)
end

function clear_longterm_memory()
    memset(0x2000,0,0x1000)
end

function delete_current_ix()
    cstore(0,0,0X3100,"backups/bu"..time2str()..".p8")
	dst = 0x6000 -- use screen as buffer storage
    memset(0x6000,0,0x1000) 
	if peek(0x2fff-current_level_ix)==0 then
        popup("IX out of range")
        return
    end
    src_len=peek(0x2fff)
    src_start = 0x2000
    ix_check=0
    ix_poke=0
    while src_len > 0 do
        if ix_check != current_level_ix then
            memcpy(dst,src_start,src_len)
            poke(0x6fff-ix_poke,src_len)
            ix_poke+=1
            dst+=src_len
        end
        ix_check+=1
        src_start+=src_len
        src_len=peek(0x2fff-ix_check)
    end
    memcpy(0x2000,0x6000,0x1000)
	popup("deleted "..current_level_ix)
end

function compress_to_current_ix()
    cstore(0,0,0X3100,"backups/bu"..time2str()..".p8")
	dst = 0x6000 -- use screen as buffer storage
    memset(0x6000,0,0x1000) 
	if peek(0x2fff-current_level_ix)==0 then
        popup("IX out of range")
        return
    end
    src_len=peek(0x2fff)
    src_start = 0x2000
    ix_check=0
    ix_poke=0
    while src_len > 0 do
        if ix_check == current_level_ix then
            prev_len = src_len
            src_len = px9_comp(0,0,xbound,ybound,dst,mget)
            poke(0x6fff-ix_poke,src_len)
            ix_poke+=1
            ix_check+=1
            dst+=src_len
            src_start += prev_len
            src_len=peek(0x2fff-ix_check)
        else
            memcpy(dst,src_start,src_len)
            poke(0x6fff-ix_poke,src_len)
            ix_poke+=1
            dst+=src_len
            ix_check+=1
            src_start+=src_len
            src_len=peek(0x2fff-ix_check)
        end
    end
    memcpy(0x2000,0x6000,0x1000)
	popup("saved to "..current_level_ix)
    cstore(0,0,0X3100,"backups/bu"..time2str()..".p8")
    save_local()
end

function compress_map_to_location()
	-- regular map is at 0x2000
    len_ix=0
    oldlen=peek(len_address-len_ix)
    dst=0x2000
    while oldlen != 0 do
        dst += oldlen
        len_ix+=1
        oldlen=peek(len_address-len_ix)
    end

	length = px9_comp(0,0,xbound,ybound,dst,mget)
	--add(address_list,{current_address,length})
    poke(len_address-len_ix,length)
	popup("len "..length)
	--current_address += length
end

function popup(str)
	for i=1,15,1 do
		rectfill(30,30,90,90,7)
		print(str,34,45,0)
		flip()
	end
end


function decompress_from_memory_to_map()
	source=0x2000
    oldlen=0
    for i=0,current_level_ix,1 do
        len=peek(len_address-i)
        if len==0 then
            popup("ix out of range")
            return
        end
        source+=oldlen
        oldlen=len
    end
	-- first clear the map
	memset(0x8000,0,0x7fff)
	-- decomp from regular map memory
    popup("pull from "..source)
	px9_decomp(0,0,source,mget,mset)
end

function cycle_current_level_ix()
	if #address_list == 0 then
		current_level_ix = 0
		return
	end
	current_level_ix = (current_level_ix % #address_list) + 1
end

function fill_tile()
    local xx = mousex\8
    local yy = mousey\8
    local tt = mget(xx,yy)
    local tnew = current_tile
    if (tt != tnew) flood(xx,yy,tnew,tt)
end

function flood(xx,yy,tnew,tt)
    local t_here = mget(xx,yy)
    if (t_here != tt) return
    if (xx<0) return
    if (xx>=xbound) return
    if (yy<0) return
    if (yy>=ybound) return
    add_undo(xx,yy)
    mset(xx,yy,tnew)
    -- _draw()
    -- flip()
    flood(xx-1,yy,tnew,tt)
    flood(xx+1,yy,tnew,tt)
    flood(xx,yy-1,tnew,tt)
    flood(xx,yy+1,tnew,tt)
end

function add_undo(xx,yy,kind)
    local u = {}
    u.xx=xx
    u.yy=yy
    u.tt=mget(xx,yy)
    u.t =flr(t())
    u.kind = kind or "tile"
    add(undo_stack,u)    
    if (#undo_stack > 10000) del(undo_stack,undo_stack[1])
end

function pop(t)
    local pop_item = t[#t]
    del(t,pop_item)
    return pop_item
end

function undo()
    if (#undo_stack<1) return
    local u = pop(undo_stack)
    if u.kind=="tile" then
        mset(u.xx,u.yy,u.tt)
    elseif u.kind=="flood" then -- this is broken right now
        local tt = mget(u.xx,u.yy)
        flood(u.xx,u.yy,u.t,tt)
    end
    if (#undo_stack<1) return
    local tnext = undo_stack[#undo_stack].t
    if (u.t==tnext) undo()
end

function dropper_tile()
    local xx = mousex\8
    local yy = mousey\8
    if xx>=0 and xx < 256 and yy>=0 and yy < 128 then
        current_tile = mget(xx,yy)
    end
end

function place_tile(xx,yy)
    local xx = xx or mousex\8
    local yy = yy or mousey\8
    local t_here=mget(xx,yy)
    if (t_here==current_tile) return
    if xx>=0 and xx < 256 and yy>=0 and yy < 128 then
        add_undo(xx,yy)
        mset(xx,yy,current_tile)
    end
end

function _draw()
	for i=0,3,1 do
        _map_display(i)
        camera(128*(i%2) + camx,128*(i\2)+camy)
        draw_all()
    end
    draw_picker()
    draw_status()
end

function draw_all()
    cls(1)
    palt(0)
    map()
    grid()
    circfill(mousex,mousey,2,7)
    if rect_click and ((t()*30)\1)%2==0 then
        rectx1 = mousex\8
        recty1 = mousey\8
        for xx=rectx0,rectx1,sgn(rectx1-rectx0) do for yy=recty0,recty1,sgn(recty1-recty0) do
            spr(current_tile,xx*8,yy*8)
        end end
    end
    palt()
end

function grid()
    if (not viewgrid) return
    gridoffx=0
    gridoffy=0
    gridx=16
    gridy=16
    gcolor=6 + (3*t()\1)%2
    for xx=gridoffx,xbound,gridx do
        line(xx*8,0,xx*8,(ybound)*8,gcolor)
    end
    for yy=gridoffy,ybound,gridy do
        line(0,yy*8,(xbound)*8,yy*8,gcolor)
    end
    rectfill(8*xbound+1,0,256*8-1,128*8-1,2)
    rectfill(0,8*ybound+1,256*8-1,128*8-1,2)
end

function camera_all(x,y)
    camx = x
    camy = y
end

function controls()
    move_speed = movespeed*2
    -- ESDF for camera
    if (btn(0,1)) camx += -move_speed
    if (btn(1,1)) camx += move_speed
    if (btn(2,1)) camy += -move_speed
    if (btn(3,1)) camy += move_speed

    -- mouse
    update_mouse()

    -- arrows for tile selection
    if (btnp(0,0)) current_tile += -1
    if (btnp(1,0)) current_tile += 1
    if (btnp(2,0)) current_tile += -16
    if (btnp(3,0)) current_tile += 16
    if (current_tile<0) current_tile = current_tile+8*16 
    if (current_tile>127) current_tile = current_tile-8*16

    key = get_key()

end

function save_local()
    cstore(0,0,0X3100)
end

function save_export()
    cstore(0X2000,0X2000,0X1000,"puncher_decomp.p8")
end

function save_import()
end

function draw_picker()
    _map_display(2)
    camera()
    line(0,63,128,63,6)
    palt(0)
    spr(0,0,64,16,8)
    
    ctilex = 8*(current_tile%16)
    ctiley = 64 + 8*(current_tile\16)
    rect(ctilex,ctiley,ctilex+7,ctiley+7,7)
    palt()
    if (myraw > 128+64) circfill(mxraw,myraw-128,2)
end

function draw_status()
    _map_display(3)
    camera()
    line(0,100,128,100,7)
    if bucket then
        print("fill",1,102,7)
    else
        print("point",1,102,7)
    end
	print(mousex\8,30,102,7)
	print(mousey\8,48,102,7)
	print("address: "..current_address,1,110,7)
	print("ix: "..current_level_ix.."  max_ix: "..max_ix,1,118,7)
end

-- control stuff
function get_key()
    return(stat(31))
end

function check_key(k)
    return key==k
end

function get_m0()
    return stat(34)&1
end

function update_mouse()
    local m0new = stat(34)&1
    local m1new = (stat(34)&2) >>> 1
    local m2new = (stat(34)&4) >>> 2

    m0new = m0new==1
    m1new = m1new==1
    m2new = m2new==1

    m0p = false
    m1p = false
    m2p = false

    if (m0new and not m0) m0p = true
    if (m1new and not m1) m1p = true
    if (m2new and not m2) m2p = true

    m0 = m0new
    m1 = m1new
    m2 = m2new

    ms = stat(36)

    mxraw = stat(32)
    myraw = stat(33)
    mousex = stat(32) + camx
	mousey = stat(33) + camy
end	

function pad_string(n)
    n = ""..n
    if (#n < 2) n="0"..n
    return n
end

function time2str()
    n=""..stat(90)
    for i=91,95,1 do
        n=n..pad_string(stat(i))
    end
    return n
end