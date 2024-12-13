pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- 100 rooms of doom
-- rocco panella

-- to do:
-- title screen
	-- story mode - select a stage, par times and 3 stars each
	-- challenge mode - 3 lives, speedrun a decade, 10 stars gives you a life
	-- super challenge mode - 3 lives, speedrun whole game

-- no repeater
poke(0x5f5c,255)

function _init()
	cartdata("100_rooms_of_doom_data")
	skips = 3
	start_title()
end

function start_title()
	_update60 = update_title
	_draw = draw_title
end

function update_title()
	if btnp(4) or btnp(5) then
		start_level_select()
	end
end

function draw_title()
	cls()
	camera()
	print("100 rooms of doom",20,30,7)
	print("press a button to start",12,40,7)	
end

function start_level()
	build_level()
	start_game()
end

function build_level()
	maxx=0 -- max camera bounds
	maxy=0 -- max camera bounds
	stars = {}
	starcount = 0
	nuns = {}
	bads = {}
	crumbleblocks = {}
	anchors = {}
	pipes = {}
	ankhs = {}
	waiting = {}
	keys = {}
	bluekey = false
	for xx=0,127,1 do for yy=0,63,1 do
		local id = mget(xx,yy)
		if id==1 then
			make_p1(xx,yy)			
		elseif id==23 then
			add(stars,{x=xx*8,y=yy*8})
		elseif id==24 then
			add(nuns,{x=xx*8,y=yy*8})
		elseif id==41 then
			add(anchors,{x=xx,y=yy})
		elseif id>=52 and id<=55 then
			make_pipe(xx,yy,id)
		elseif id==56 then
			for b in all(bads) do
				if (b.x+8)\8==xx and (b.y)\8==yy then
					add(ankhs,b)
				end
			end
		elseif id==64 then
			add(keys,{c="blue",x=xx*8,y=yy*8,sp=64})
		elseif contains({36,37,38,39,40},id) then
			local b = {x=xx,y=yy,t=10,dieing=false}
			crumbleblocks[xx+256*yy] = b
			mset(xx,yy,40)
		elseif id==66 then
			mset(xx,yy,65)
		elseif contains(list_of_bads,id) then
			make_bad(id,xx*8,yy*8)
		end
		if fget(id,2) then --breakable
			mset(xx,yy,id-1)
		end
		if id > 0 then
			maxx = max(maxx,16*(xx\16))
			maxy = max(maxy,16*(yy\16))
		end
	end end

	for bb in all(bads) do
		bb:init()
	end
	
end

function start_game()
	_update60 = update_gameplay
	_draw = draw_gameplay
end

function update_gameplay()
	
	p1:update_early()
	p1:update()
	
	for st in all(stars) do
		if collide(p1,st) then
			starcount += 1
			del(stars,st)
		end
	end
	
	for k in all(keys) do
		if collide(p1,k) then
			del(keys,k)
			if (k.c=="blue") bluekey=true
		end
	end
	
	for b in all(bads) do
		b:update()
	end
	
	for p in all(pipes) do
		update_pipe(p)
	end
	
	update_ankhs()
	
	if (p1.punching) punch_check()
	hurt_check()
	pipe_check()
	
	for ix,c in pairs(crumbleblocks) do
		if c.dieing then
			c.t-=1
			if c.t<=0 then
				_id=mget(c.x,c.y)
				mset(c.x,c.y,_id-1)
				c.t=10
				if (_id == 37) crumbleblocks[ix]=nil
			end
		end
	end
end

function draw_gameplay()
	cls()
	fix_camera(p1)
	map(0,0,0,0,256,128,0b01111011)
	
	for n in all(nuns) do
		spr(24,n.x,n.y)
	end
	
	for b in all(bads) do
		b:draw()
	end
	
	for p in all(pipes) do
		if p.y0 != p.y and p.x0 != p.x then
			rectfill(p.x0,p.y0,p.x,p.y,8+(tf()\6)%2)
		end
	end
	
	p1:draw()
	
	for st in all(stars) do
		spr(23,st.x,st.y)
	end
	
	for k in all(keys) do
		spr(k.sp,k.x,k.y)
	end
	
end

function fix_camera(s)
	s = s or {x=0,y=0}
	
	cx = max(0,s.x-60)
	cx = min(cx,maxx*8)
	
	cy = max(0,s.y-64)
	cy = min(cy,maxy*8)
	
	camera(cx,cy)
	
end
-->8
-- player

grav = 0.1
maxfall = 2
punchspeed = 2
punchtime = 15
fliptime = 14 -- how long you flip after airjump?
latetime = 6 -- how many frames late can you input a jump?

function make_p1(xx,yy)
	p1 = {}
	p1.x = xx*8
	p1.y = yy*8
	p1.dx=0
	p1.dy=0
	p1.sp=1
	p1.faceleft=false
	
	p1.update_early = update_early
	p1.update = update_floor
	p1.draw = draw_floor
	p1.canairjump = true
	p1.canpunch = true
	p1.jumptime = 0 -- how long you flip after airjump
	p1.walltime = 0 -- how long you lose control walljumping
	p1.latetime = 0
	p1.punchtime = 0 -- how long you punch for
	p1.wallright=false
	p1.wallleft=false
	
	-- state stuff
	p1.punching=false
end

function update_early(s)
	-- early step. always runs.
	s.punching=false
	--if (bluekey) keycheck(s,65)
end

function update_floor(s)
	s.dx=0
	s.dy=0
	
	s.canpunch = true
	
	if btn(0) then 
		s.dx=-1
		s.faceleft=true
	elseif btn(1) then
		s.dx=1
		s.faceleft=false
	end
	
	if btnp(5) then
		jump(s)
	end
	
	if not check_down(s) then
		start_fall(s)
	end
	
	_move(s)
	_bump_up(s)
	_bump_walls(s)
	
	if btnp(4) then
		punch(s)
	end
	
	_check_hazards(s)
	
end

function jump(s)
	s.update = update_air
	s.draw = draw_air
	s.dy = -2
	s.canairjump = true
end

function airjump(s)
	s.update = update_air
	s.draw = draw_air
	s.dy = -2
	s.canairjump = false
	s.jumptime = fliptime
end

function walljump(s)
	s.update = update_walljump
	s.draw = draw_air
	s.dy = -2
	s.dx = -1
	if (s.faceleft) s.dx = 1
	s.faceleft = s.dx==-1
	s.canairjump = false
	s.walltime = 10
end

function _breakwalls(s)
	x0 = s.x-1
	x1 = s.x+8
	y0 = s.y
	y1 = s.y+7
	
	for _x in all({x0,x1}) do
	for _y in all({y0,y1}) do
		xx = _x\8
		yy = _y\8
--		for i=0,30,1 do
--			_draw()
--			rect(xx*8,yy*8,xx*8+7,yy*8+7,7)
--			print(xx,1,1,7)
--			print(yy,1,7,7)
--			flip()
--		end
		id = mget(xx,yy)
		if fget(id,1) then
			mset(xx,yy,id+1)
		end
	end
	end
	
end

function _bump_walls(s)
	s.wallright=false
	s.wallleft=false
	if s.dx>=0 then
		while collide_right(s) do
			s.x \= 1
			s.dx = 0
			s.x -= 1
			s.wallright=true
		end
	elseif s.dx <= 0 then 
		while collide_left(s) do
			s.x \= 1
			s.dx = 0
			s.x += 1
			s.wallleft=true
		end
	end
end

function check_down(s)
	yy = (s.y+8) \ 8
	x1 = (s.x+2) \ 8
	x2 = (s.x+5) \ 8
	return solid(x1,yy) or solid(x2,yy)
end

function start_fall(s)
 s.canairjump = true
	s.update = update_air
	s.draw = draw_air
	s.dy += grav
	s.latetime = latetime
end

function start_fall_no_jump(s)
	s.update = update_air
	s.draw = draw_air
	s.dy += grav
end

function update_walljump(s)
	s.dy+=grav
	s.dy = min(maxfall,s.dy)
	
	_move(s)
	_bump_walls(s)
	_bump_up(s)
	
	if check_down(s) and s.dy>0 then
		land(s)
	end
	
	if s.wallright or s.wallleft then
		start_wallslide(s)
	end
	
	s.walltime -= 1
 if (s.walltime <=0) start_fall(s)
	
	_check_hazards(s)
	
end

function update_air(s)
	s.dx=0
	s.dy+=grav
	s.dy = min(maxfall,s.dy)
	
	if btn(0) then 
		s.dx=-1
		s.faceleft=true
	elseif btn(1) then
		s.dx=1
		s.faceleft=false
	end
	
	if btnp(5) and s.latetime > 0 then
		jump(s)
		s.latetime=0
	elseif btnp(5) and s.canairjump then
		airjump(s)
	end
	
	if btnp(4) and s.canpunch then
		punch(s)
		return
	end
	
	_move(s)
	_bump_walls(s)
	_bump_up(s)
	
	if check_down(s) and s.dy>0 then
		land(s)
	end
	
	if s.wallright or s.wallleft then
		start_wallslide(s)
	end	
	
	_check_hazards(s)
	
	s.latetime = max(0,s.latetime-1)
end

function punch(s)
	s.dx = punchspeed
	s.dy = 0
	s.canpunch = false
	if (s.faceleft) s.dx = -punchspeed
	s.punchtime = punchtime
	s.update = update_punch
	s.draw = draw_punch
end

function update_punch(s)
	s.punching=true
	
	_move(s)
	_breakwalls(s)
	_bump_walls(s)
	_check_hazards(s)
	
	s.punchtime -= 1
	
	for n in all(nuns) do
		if collide(s,n) then
			del(nuns,n)
			if #nuns==0 then
				fade_out()
				build_level()
			end
		end
	end
	
	if (s.punchtime == 0) start_fall_no_jump(s)
end

function _check_hazards(s)
	id = mget((s.x+4)\8,(s.y+4)\8)
	if fget(id,3) then
		die()
	end
end

function start_wallslide(s)
	s.dy = min(s.dy,.75)
	s.draw = draw_wallslide
	s.update = update_wallslide
end

function update_wallslide(s)
	s.dx=0
	s.dy += grav
	s.dy = min(s.dy,.5)
	
	s.canpunch = true
	
	if btn(0) then 
		s.dx=-1
		s.faceleft=true
	elseif btn(1) then
		s.dx=1
		s.faceleft=false
	end
	
	if (not s.wallright) and
		(not s.wallleft) then
		start_fall(s)
	elseif btnp(5) then
		walljump(s)
	end
	
	_move(s)
	_bump_walls(s)
	_bump_up(s)
	
	if check_down(s) and s.dy>0 then
		land(s)
	end
	
	_check_hazards(s)
	
end

function _bump_up(s)
	if s.dy<0 then
		while collide_up(s) do
			s.dy=0
			s.y \= 1 
			s.y += 1
		end
	end
end

function land(s)
	s.dy=0
	s.y \= 1
	while collide_down(s) do
		s.y-=1
	end
	s.update = update_floor
	s.draw = draw_floor
end

function _move(s)
	s.x+=s.dx
	s.y+=s.dy
end

function collide_down(s)
	yy = (s.y+7) \ 8
	x1 = (s.x+2) \ 8
	x2 = (s.x+5) \ 8
	return solid(x1,yy) or solid(x2,yy)
end

function solid(xx,yy)
	id = mget(xx,yy)
	if id==65 then 
		chain_destroy(xx,yy,65)
		id=0
	end
	if (id==40) crumbleblocks[xx+256*yy].dieing=true
	return fget(id,0)
end

function collide_up(s)
	yy = (s.y) \ 8
	x1 = (s.x+2) \ 8
	x2 = (s.x+5) \ 8
	return solid(x1,yy) or solid(x2,yy)
end

function collide_right(s)
	xx = (s.x+6) \ 8
	y1 = (s.y+2) \ 8
	y2 = (s.y+5) \ 8
	return solid(xx,y1) or solid(xx,y2)
end

function collide_left(s)
	xx = (s.x+1) \ 8
	y1 = (s.y+2) \ 8
	y2 = (s.y+5) \ 8
	return solid(xx,y1) or solid(xx,y2)
end

function die()
	p1.draw = draw_die
	yadd=0
	yold=p1.y
	for _=0,60,1 do
		yadd=(_%6)\3
		p1.y=yold+yadd
		_draw()
		flip()
	end
	build_level()
end

function draw_die(s)
	s.sp=14
	spr(s.sp,s.x,s.y,1,1,s.faceleft)
end

function draw_floor(s)
	s.sp=1
	if abs(s.dx)>0 then 
		s.sp = ((tf()\3)%5)+1
	end
	spr(s.sp,s.x,s.y,1,1,s.faceleft)
end

function draw_wallslide(s)
	s.sp=12
	spr(s.sp,s.x,s.y,1,1,s.faceleft)
end

function draw_punch(s)
 s.sp=13
	spr(s.sp,s.x,s.y,1,1,s.faceleft)
end

function draw_air(s)
	s.sp = 11
	if (s.dy<0) s.sp=10
	if s.jumptime >= 0 then
		s.sp = 10 - s.jumptime\3
		s.jumptime -= 1
	end
	spr(s.sp,s.x,s.y,1,1,s.faceleft)
end

function hurt_check()
	for b in all(bads) do
		if collide(p1,b,5) then
			die()
			return
		end
	end
end

function punch_check()
	for b in all(bads) do
		if b.vulnerable then
		if collide(p1,b,8) then
			del(bads,b)
		end
		end
	end
end

function pipe_check()
	for p in all(pipes) do
		if collide_box(p,p1) then
			die()
			return
		end
	end
end
-->8
-- utils

function tf()
	-- get the current frame as int
	return ((t()*60)\1)%60
end

function collide(s1,s2,r)
	r = r or 8
	if abs(s1.x-s2.x)<=r and
	abs(s1.y-s2.y)<=r then
		return true
	end
	return false
end

function collide_box(box,point)
	xx0=min(box.x0,box.x)
	xx1=max(box.x0,box.x)
	yy0=min(box.y0,box.y)
	yy1=max(box.y0,box.y)
	if point.x+4>=xx0 and point.x+4<=xx1
		and point.y+4>=yy0 and point.y+4<=yy1 then
		return true
	end
	return false
end

function fade_out()
	camera()
	local r = 0
	while r < 100 do
		circfill(64,64,r,1)
		flip()
		r += 3
		--if (btn(4) or btn(5)) r+=6
	end
end

function fade_in()
	camera()
	local r = 100
	while r >= 0 do
		_draw()
		circfill(64,64,r,1)
		flip()
		r -= 3
		--if (btn(4) or btn(5)) r-=6
	end
end

function contains(t,v)
	for _ in all(t) do
		if (_==v) return true
	end
	return false
end

function chain_destroy(xx,yy,id)
 if (mget(xx,yy) != id) return
 mset(xx,yy,id+1)
 chain_destroy(xx-1,yy,id)
 chain_destroy(xx+1,yy,id)
 chain_destroy(xx,yy-1,id)
 chain_destroy(xx,yy+1,id)
end
-->8
-- bads

bad_updates = {}
bad_inits = {}
list_of_bads = {}

function make_bad(id,x,y)
	local bb = {}
	bb.id = id
	bb.sp = id
	bb.x = x
	bb.y = y
	bb.dx=0
	bb.dy=0
	bb.vulnerable=true
	bb.faceleft=false
	bb.draw = bad_draw_norm
	bb.update = bad_updates[id]
	bb.init = bad_inits[id]
	add(bads,bb)
	--b:init()
end

function bad_draw_norm(b)
	adder = (tf()\10)%2
	spr(b.sp+adder,b.x,b.y,1,1,b.faceleft)
end

function bad_draw_static(b)
	spr(b.sp,b.x,b.y,1,1,b.faceleft)
end

side_eye=26
add(list_of_bads,side_eye)
bad_inits[side_eye] = function(b)
	b.dx = .5
end
bad_updates[side_eye] = function(b)
	b.x += b.dx
	b.faceleft = b.dx<0
	if b.dx>0 then
		xcheck = b.x+7
	else
		xcheck = b.x
	end
	tile=mget((xcheck)\8,(b.y+4)\8)
	if fget(tile,0) or tile==25 then
		b.dx = -b.dx			
	end
end

up_eye=28
add(list_of_bads,up_eye)
bad_inits[up_eye] = function(b)
	b.dy = .5
end
bad_updates[up_eye] = function(b)
	b.y += b.dy
	--b.faceleft = b.dx<0
	if b.dy>0 then
		ycheck = b.y+7
	else
		ycheck = b.y
	end
	tile=mget((b.x+4)\8,(ycheck)\8)
	if fget(tile,0) or tile==25 then
		b.dy = -b.dy			
	end
end

bat=30
add(list_of_bads,bat)
bad_inits[bat] = function(b) end
bad_updates[bat] = function(b) end

roto_balls={43,44,45,46,59,60,61,62}
function rball_init(b)
	-- find anchor
	local d = 1000
	condition = b.id%16 - 10
	for a in all(anchors) do
		ax = a.x*8
		ay = a.y*8
		if (condition==1 and ax < b.x) or
			 (condition==2 and ay < b.y) or
			 (condition==3 and ax > b.x) or
			 (condition==4 and ay > b.y) then
			local dd = ((b.x-ax)^2 + (b.y-ay)^2)^0.5
			if dd<d then
				b.ax = ax
				b.ay = ay
				b.d = dd
			end
		end
	end
	b.dang = 0.01
	if (b.id>50) b.dang *= -1
	if not b.ax then
	 del(bads,b)
	 return
	end
	b.ang = atan2(b.x-b.ax,b.y-b.ay)
	b.vulnerable = false
	b.sp = 42
	b.draw = bad_draw_static
end
rball_update = function(b)
	b.ang += b.dang
	b.x = b.d*cos(b.ang) + b.ax
	b.y = b.d*sin(b.ang) + b.ay
end
for r in all(roto_balls) do
 add(list_of_bads,r)
 bad_inits[r] = rball_init
 bad_updates[r] = rball_update
end

-->8
-- gimmicks

function make_pipe(xx,yy,id)
	--52,53,54,55
	--up,left,down,right
	xa0={0,-1,0,8}
	ya0={-1,0,8,0}
	xa={7,-1,7,8}
	ya={-1,7,8,7}
	
	id-=51
	xa0=xa0[id]
	ya0=ya0[id]
	xa=xa[id]
	ya=ya[id]
	
	dx={0,-1,0,1}
	dx=dx[id]
	dy={-1,0,1,0}
	dy=dy[id]
	
	local p={
		x=xx*8+xa,
		y=yy*8+ya,
		x0=xx*8+xa0,
		y0=yy*8+ya0,
		dx=dx,
		dy=dy,
		t=60,
		opening=true}
	add(pipes,p)
end

function update_pipe(p)
	p.t -= 1
	if p.t <= 0 then
		if p.opening then
			p.y += p.dy
			p.x += p.dx
			local tile=mget(p.x\8,p.y\8)
			if tile==25 or fget(tile,0) then
				p.opening=false
				p.t=60
				p.y+=-p.dy
				p.x+=-p.dx
			end
		else
			p.y += -p.dy
			p.x += -p.dx
			if p.y==p.y0 or p.x==p.x0 then
				p.opening=true
				p.t=60
			end
		end
	end
end

function update_ankhs()
	for a in all(ankhs) do
		if not contains(bads,a) do
			add(waiting,{120,a})
			del(ankhs,a)
		end
	end
	for aa in all(waiting) do
		aa[1] -= 1
		if aa[1] <= 0 then
			add(bads,aa[2])
			add(ankhs,aa[2])
			del(waiting,aa)
		end
	end
end
-->8
-- persistent mem stuff
-- 255 bytes available
pers_start_loc = 0x5e00

-- locations 0-99, level info
		-- 0,1,2 = stars
		-- 3 = time
		-- 4 = beaten
		-- 5 = available
		-- 6-7 = ???
		
function get_level_data(ix)
	return peek(pers_start_loc + ix)
end
		
-- 100 - levels beaten count
-- 101-140 times for 1-10 challenges
		-- do this in steps of 4 so
		-- you can poke4
-- 144 master time


-->8
-- level select

function start_level_select()
	row = 0
	column = 0
	lcx=0
	lcy=0
	lcx_targ=0
	lcy_targ=0
	_update60 = update_level_select
	_draw = draw_level_select
end


function update_level_select()
	if (btnp(0)) column += -1
	if (btnp(1)) column += 1
	if (btnp(2)) row += -1
	if (btnp(3)) row += 1
	
	row = row%10
	column = column%10
	
	x_select = column*36
	y_select = row*16
	
	while x_select < lcx_targ do
		lcx_targ -= 1
	end
	
	while x_select > lcx_targ+80 do
		lcx_targ += 1
	end

	while y_select < lcy_targ do
		lcy_targ -= 1
	end
	
	while y_select > lcy_targ+80 do
		lcy_targ += 1
	end
		
	lcx += (lcx_targ - lcx) / 4
	lcy += (lcy_targ - lcy) / 4
	
	camera(lcx,lcy)
	
	if (btnp(4) or btnp(5)) start_level()
	
end


function draw_level_select()
	cls()
	for c=0,9,1 do
		for r=0,9,1 do
			draw_level_box(c,r)
		end
	end
	
	select_color = 9 + (tf()\6)%2
	draw_level_box(column,row,select_color)
	
end

function draw_level_box(c,r,clr)
	local data = get_level_data(c+10*r)
	
	clr = clr or 5
	
	if clr == 5 then
		if (data&16>0) clr=6
	end
	
	x=4+c*36
	y=20+r*16

	rect(x,y,x+33,y+13,clr)
	
	print("★",x+1,y+8,1)
	if (data&1>0) print("★",x+1,y+8,10)
	print("★",x+9,y+8,1)
	if (data&2>0) print("★",x+9,y+8,10)
	print("★",x+17,y+8,1)
	if (data&4>0) print("★",x+17,y+8,10)
	print("⧗",x+27,y+8,1)
	if (data&8>0) print("⧗",x+27,y+8,10)
	print(""..(r+1).."-"..c+1,x+10,y+2,clr)
	
end
-->8
-- level loading
__gfx__
00000000000000000000000000999900009999000000000000000000000000000000000000000000009999440000000000000000000000000000000000000000
00000000009999000099990009909090099090900099990000099900009449000099440000999900099090440099990000999900009999000099990000000000
00700700099090900990909009449090449094400990909009449990044944000900449009909090099090900999999009090440099090900909994400000000
00077000099090900944909009449990449994404490944004440090044944900999994009909090449999904490904409090440099090444490904400000000
00077000044999440944999000999900009999004499944004999990090909900900444009449440449999004490904444999990449999444499999000000000
00700700044999440099990004999440004449000099990009440090090909900999449000449440009449000099990044999990449999000999999000000000
00000000009999000099944004000000000040000044990000449900009999000099900000944900000040000044990000099940009944000449944000000000
00000000004404400044000000000000000000000000440000000000000000000000000000000000000000000000044000044040044000000000000000000000
677777762dddddd22dddddd2111111114ffffff44ffffff477070077000a70000011110077077077b00000b000000000b00000bb000000000000000000200200
567777671222222d1222222d111111115444444f5444444f77676677000a70000177711070000007bbbbbbb0b00000b0bbbbbbb0bb00000b0020020000200200
556666771222222d1222222d22a22a225555555f5555555f0666666077aaaa770f0f0f10000000000bb777b0bbbbbbb00b7777b00bbbbbbb0020020000222200
556666772111111221111112222aa2225444444f5444444f066766770aaaaaa00f0f0f10700000070bb707b00bb777b00b7007b00b7777b02022220202822820
556666772222222222222222222aa2225444444f5444444f7766666000aaaa0001111110700000070bb777b00bb707b00b7777b00b7007b02282282222222222
55666677222222222222222222a22a225555555f5555555f0666666000aaaa0007ff7110000000000bb00bb00bb777b00bbbbbb00b7777b02222222222222222
5655556722222222222222222a2222a25444444f5444444f776676770aa00a70011111107000000700bbbb000bb00bb000bbbb000bbbbbb02222222222222222
655555562222222222222222a222222a455555544555555477007077aa0000a706606600770770770000000000bbbb000000000000bbbb002022220202000020
111111112222222222222222a222222a0ffffff0e0f0ff0eeffffffeeffffffeeffffffe0999999000067000000670000006700000067000000aa00000000000
2111111222222222222222222a2222a2d0ffff0fde0fff0fde0fffefdeffffefdeffffef2888888906777760067777600677776006777760067aa76000000000
22122222222dd222222dd22222a22a22dd0ee0ffdde0e0ffdde0e0ffdde0e0ffddeeeeff2889988905666770056667700566677005666770056aa77000000000
2122222222122d2222122d22222aa222dde00effddee0e00ddee0e0fddee0effddeeeeff2828898965667677aaa676776566767765667aaa6566767700000000
1222222222122d2222122d22222aa222dde00eff00e0eeffd0e0eeffdde0eeffddeeeeff2828898955666676aaa666765566667655666aaa5566667600000000
22222221222112222221122222a22a22dd0ee0ffdd0e0effdd0e0effddee0effddeeeeff288228890556667005566670055aa670055666700556667000000000
2111111222222222222222222a2222a2d0dddd0fd0ddd00fdeddd00fdeddddefdeddddef288888890655556006555560065aa560065555600655556000000000
111111112222222222222222a222222a0dddddd0edddddd0eddddddeeddddddeedddddde022222200005600000056000000aa000000560000005600000000000
000000002222222222222222a222222a57777777770777777676666555555055009999000000000000067000000670000006700000067000000aa00000000000
0000000022222222222222222a2222a256666767765666667676666566666567090000900000000006777760067777600677776006777760067aa76000000000
00000000222222222222222222a22a2205555550775777777676666566666567090000900000000005666770058887700588877005888770058aa77000000000
000000002222222222222222222aa22256666767765666667676666566666567009009000000000065667677aaa878776588787765887aaa6588787700000000
000000002dddddd22dddddd2222aa22256666767765666667676666566666567099999900000000055666676aaa888765588887655888aaa5588887600000000
000000001222222d1222222d22a22a225666676776566666055555507777757709999990000000000556667005588870055aa870055888700558887000000000
000000001222222d1222222d111111115666676776566666767666656666656700099000000000000655556006555560065aa560065555600655556000000000
000000002111111221111112111111115666676755055555777777757777707700099000000000000005600000056000000aa000000560000005600000000000
00cccc00cc1111cc7c71717c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0c0000c0c1cccc1cc1cccc1700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0c0000c0c1cccc1c71cccc1c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00cccc00cc1111cccc1111c700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000c0000ccc1cccc7cc1cccc00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000ccc00ccc111ccccc111c700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000c0000ccc1cccc7cc1cccc00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000ccc00ccc111ccc7c717c700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00888800881111887871717800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
08000080818888188188881700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
08000080818888187188881800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00888800881111888811118700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00080000888188887881888800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00088800888111888881118700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00080000888188887881888800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00088800888111888787178700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00bbbb00bb1111bb7b71717b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0b0000b0b1bbbb1bb1bbbb1700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0b0000b0b1bbbb1b71bbbb1b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00bbbb00bb1111bbbb1111b700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000b0000bbb1bbbb7bb1bbbb00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000bbb00bbb111bbbbb111b700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000b0000bbb1bbbb7bb1bbbb00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000bbb00bbb111bbb7b717b700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__gff__
0080000000000000000000000000800001010304030408808080800080800000010103048001010101018080808080000001030401010101800080808080800080018000000000000000000000000000800180000000000000000000000000008001800000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
2131313131313131313131313131312121313131313131313131313131313121000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2117004100000000000000000000002323000000000000000000000000000021000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2100004100000000000000000000002323170000000000000000000000000021000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2141414100000000350000003600002323000000000000000000000000000021000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2100000000000000000000000000002323100000000000000000000000000021000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2100000000000000002900000000002323000000000000000000000000000021000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2100000024240000000000002b00002323000000000000190000000000000021000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
21240000000000000000002b0000002323000000000000000000000000000021000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2100001e3800000000002b001e000023230000000000001c0000000000000021000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2100000000000000000000000000002323000000000000000000000000000021000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
21000100000000001c000000370000232300000000000019001a001900180021000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2100101010100000000000160000002323000000000000000000000000111121000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2100000000000000000000000000002323001700151500000000001111212121000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
21004000000000111100001a0000002323000000151500000000002121212121000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2100000000000021210000000000342323000015151500000000002121212121000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2111111111111121211111111111112121111111111111111111112121212121000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
