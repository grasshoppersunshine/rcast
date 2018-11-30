#include once "SDL2/SDL.bi"

#define FULLSCREEN 1
#define SCREEN_X   1920'352
#define SCREEN_Y   1080'198
#define HALF_X     SCREEN_X \ 2
#define HALF_Y     SCREEN_Y \ 2
#define SUPERBIG   &h7fffffff
#define SUPERSML   0.00000001


#define PREC         (2^14)
#define PREC_SHIFT   14
#define MAX_DISTANCE (4096 shl PREC_SHIFT)' 300
#define MAX_INT      (2^16)

dim shared HEIGHT_RATIO as integer
HEIGHT_RATIO = 127*(SCREEN_Y/300) shl PREC_SHIFT

#include once "modules/inc/timer.bi"
#include once "modules/inc/gfont.bi"
#include once "modules/inc/vector.bi"
#include once "modules/inc/mesh.bi"
#include once "modules/inc/flatmap.bi"
#include once "modules/inc/bsp.bi"
#include once "modules/inc/rgb.bi"

'// GRAPHICS FUNCTIONS  ================================================
declare sub gfx_dice(sprites() as SDL_RECT, filename as string, img_w as integer, img_h as integer, sp_w as integer, sp_h as integer, scale_x as double=1.0, scale_y as double=0)
'// END GRAPHICS FUNCTIONS  ============================================

declare sub main()
declare sub loadMap(highres as FlatMap, medres as FlatMap, lowres as FlatMap)

'// SHARED  ============================================================
dim shared highres as FlatMap = FlatMap(MAP_WIDTH, MAP_HEIGHT)
dim shared medres as FlatMap = FlatMap(MAP_WIDTH \ 2, MAP_HEIGHT \ 2)
dim shared lowres as FlatMap = FlatMap(MAP_WIDTH \ 4, MAP_HEIGHT \ 4)
dim shared subres as FlatMap = FlatMap(MAP_WIDTH \ 8, MAP_HEIGHT \ 8)
'//=====================================================================

'// INIT SDL SYSTEM AND GRAPHICS  ======================================
dim shared gfxWindow as SDL_Window ptr
dim shared gfxRenderer as SDL_Renderer ptr
dim shared gfxSprites as SDL_Texture ptr

'SDL_Init( SDL_INIT_AUDIO or SDL_INIT_JOYSTICK or SDL_INIT_HAPTIC )
SDL_Init( SDL_INIT_VIDEO )

if FULLSCREEN then SDL_ShowCursor( 0 )

gfxWindow = SDL_CreateWindow( "Ashes of Eternity", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, SCREEN_X, SCREEN_Y, SDL_WINDOW_FULLSCREEN_DESKTOP )
gfxRenderer = SDL_CreateRenderer( gfxWindow, -1, null )
SDL_RenderSetLogicalSize( gfxRenderer, SCREEN_X, SCREEN_Y )
SDL_SetRenderDrawBlendMode( gfxRenderer, SDL_BLENDMODE_NONE )

dim shared game_font as GFONT = GFONT(@gfxRenderer)
game_font.load("font.bmp", 256, 256, 8, 8, GFONT_W/8)

'//=====================================================================

loadMap highres, medres, lowres
main

'// SHUTDOWN SDL  ======================================================
SDL_DestroyTexture( gfxSprites )
SDL_DestroyRenderer( gfxRenderer )
SDL_DestroyWindow( gfxWindow )
    
SDL_Quit
'//=====================================================================

end

dim shared meshCount as integer = 0
dim shared meshes(64) as Mesh

sub loadHorse()
    restore horse
    dim grid(16, 16) as integer
    dim x as integer, y as integer
    dim row as string
    for y = 0 to 15
        read row
        for x = 1 to 16
            if mid(row, x, 1) = "#" then
                
            end if
        next x
    next y
end sub

sub main()

    dim px as double, py as double
    dim pa as double
    dim ph as double
    dim f as double
    dim a as double
    
    px = MAP_WIDTH * 0.5 + 0.5
    py = MAP_HEIGHT * 0.5 + 0.5
    pa = 0
    ph = 1
    
    dim vf as Vector
    dim vr as Vector
    dim vray as Vector
    
    dim dx as uinteger, dy as uinteger
    dim ax as integer, ay as integer
    dim ex as integer, ey as integer
    dim x_dx as uinteger, x_dy as uinteger
    dim y_dx as uinteger, y_dy as uinteger
    dim x_ax as integer, x_ay as integer
    dim y_ax as integer, y_ay as integer
    dim x_ex as uinteger, x_ey as uinteger
    dim y_ex as uinteger, y_ey as uinteger
    dim lx as uinteger, ly as uinteger
    dim xHit as integer, yHit as integer
    dim xDist as uinteger, yDist as uinteger
    dim dist as integer
    dim dc as double
    dim sliceSize as double
    
    dim event as SDL_Event
	dim keys as const ubyte ptr
    dim mousestate as long
    dim mx as long, my as long
    
    dim fps as integer
    dim fps_count as integer
    dim fps_timer as double
    dim seconds as double
    
    dim top as integer
    dim bottom as integer
    
    dim colorFloor as integer
    dim colorWall as integer
    dim colorSky as integer
    dim colorWater as integer
    
    dim fov as double: fov = 1
    
    dim midline as double: midline = HALF_Y
    
    dim map as FlatMap ptr
    dim delta as double
    
    colorFloor = &h8db27c
    colorWall  = &hffe4d8
    colorSky   = &hbec2ff
    colorWater = &h5c73ab

    dim nph as double
    midline += (HALF_Y/2)
    
    dim rayCallback as sub(byref x_dx as uinteger, byref x_dy as uinteger, byref y_dx as uinteger, byref y_dy as uinteger)
    
    dim walkingSpeed as double = 4.0
    dim flyingSpeed as double = 30
    'dim pitch as double
    dim mode as integer = 1
    dim strafeAngle as double
    dim strafeValue as double
    
    dim texture as SDL_Texture ptr
    texture = SDL_CreateTexture(gfxRenderer, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_STREAMING, SCREEN_X, SCREEN_Y)
    
    UpdateSpeed()
    seconds = 0
    do
        delta = UpdateSpeed()
        seconds += delta
        
        fps_count += 1
        fps_timer += delta
        if fps_timer >= 1 then
            fps = fps_count
            fps_count = 0
            fps_timer = 0
        end if
		
		while( SDL_PollEvent( @event ) )
			select case event.type
			case SDL_QUIT_
				return
			end select
		wend
        
        keys = SDL_GetKeyboardState(0)
        mousestate = SDL_GetRelativeMouseState(@mx, @my)
        
        pa -= mx*0.20
        
        dim ha as double
        
        midline -= my*(SCREEN_Y/300)
        if midline < -HALF_Y then midline = -HALF_Y
        'if midline > HALF_Y*10 then midline = HALF_Y*10
        fov = 1+abs(midline-HALF_Y)*0.00125*(300/SCREEN_Y)
        
        map = @highres
        
        ha = (midline-HALF_Y)*(300/SCREEN_Y)
        
        static dv as double
        dim speed as double
        
        speed = iif(mode = 1, flyingSpeed, walkingSpeed)
        
        if keys[SDL_SCANCODE_ESCAPE] then
            return
        end if
        if keys[SDL_SCANCODE_LEFT] then
            pa += 12
        end if
        if keys[SDL_SCANCODE_RIGHT] then
            pa -= 12
        end if
        
        if keys[SDL_SCANCODE_LCTRL] then speed *= 1.5
        
        if keys[SDL_SCANCODE_A] then
            
            vf = vectorFromAngle(pa)
            vf = vectorToRight(vf)
            vf.x = vf.x * speed * iif(keys[SDL_SCANCODE_LCTRL], 1.5, 1) * delta
            vf.y = vf.y * speed * iif(keys[SDL_SCANCODE_LCTRL], 1.5, 1) * delta
            px -= vf.x
            py -= vf.y
            
            if mode = 2 then
                nph = map->heights(int(px), int(py))*0.01+1.5
                if nph-ph > 0.625 then
                    px += vf.x
                    py += vf.y
                'elseif (dv = 0) and ((nph-ph) < 0) and ((nph-ph) > -0.325) then
                '    ph = nph
                end if
            end if
        end if
        if keys[SDL_SCANCODE_D] then
        
            vf = vectorFromAngle(pa)
            vf = vectorToRight(vf)
            vf.x = vf.x * speed * iif(keys[SDL_SCANCODE_LCTRL], 1.5, 1) * delta
            vf.y = vf.y * speed * iif(keys[SDL_SCANCODE_LCTRL], 1.5, 1) * delta
            px += vf.x
            py += vf.y
            
            if mode = 2 then
                nph = map->heights(int(px), int(py))*0.01+1.5
                if nph-ph > 0.625 then
                    px -= vf.x
                    py -= vf.y
                'elseif (dv = 0) and ((nph-ph) < 0) and ((nph-ph) > -0.325) then
                '    ph = nph
                end if
            end if
        end if
        if keys[SDL_SCANCODE_UP] or keys[SDL_SCANCODE_W] then
            select case mode
            case 1
                vf   = vectorFromAngle(pa)
                vf.z = ha*0.3*.02625
                vf   = vectorToUnit(vf)
                
                px += vf.x * speed * iif(keys[SDL_SCANCODE_LCTRL], 1.5, 1) * delta
                py += vf.y * speed * iif(keys[SDL_SCANCODE_LCTRL], 1.5, 1) * delta
                ph += vf.z * speed * iif(keys[SDL_SCANCODE_LCTRL], 1.5, 1) * delta
            case 2
                vf   = vectorFromAngle(pa)
                vf   = vectorToUnit(vf)
                vf.x = vf.x * speed * iif(keys[SDL_SCANCODE_LCTRL], 1.5, 1) * delta
                vf.y = vf.y * speed * iif(keys[SDL_SCANCODE_LCTRL], 1.5, 1) * delta 
                px += vf.x
                py += vf.y
                
                nph = map->heights(int(px), int(py))*0.01+1.5
                if nph-ph > 0.625 then
                    px -= vf.x
                    py -= vf.y
                'elseif (dv = 0) and ((nph-ph) < 0) and ((nph-ph) > -0.325) then
                '    ph = nph
                end if
                
                strafeAngle += delta*600*iif(keys[SDL_SCANCODE_LCTRL], 2, 1)
            end select
        end if
        if keys[SDL_SCANCODE_DOWN] or keys[SDL_SCANCODE_S] then
            select case mode
            case 1
                vf = vectorFromAngle(pa)
                px -= vf.x * speed * iif(keys[SDL_SCANCODE_LCTRL], 1.5, 1) * delta
                py -= vf.y * speed * iif(keys[SDL_SCANCODE_LCTRL], 1.5, 1) * delta
            case 2
                vf   = vectorFromAngle(pa)
                vf   = vectorToUnit(vf)
                vf.x = vf.x * speed * iif(keys[SDL_SCANCODE_LCTRL], 1.5, 1) * delta
                vf.y = vf.y * speed * iif(keys[SDL_SCANCODE_LCTRL], 1.5, 1) * delta 
                px -= vf.x
                py -= vf.y
                
                nph = map->heights(int(px), int(py))*0.01+1.5
                if nph-ph > 0.625 then
                    px -= vf.x
                    py -= vf.y
                'elseif (dv = 0) and ((nph-ph) < 0) and ((nph-ph) > -0.325) then
                '    ph = nph
                end if
            end select
        end if
        if keys[SDL_SCANCODE_SPACE] and (dv = 0) then
            if mode = 1 then
                ph += flyingSpeed * delta
            else
                'dv = -0.3333
                dv = -10
            end if
        end if
        if keys[SDL_SCANCODE_LSHIFT] then
            ph -= flyingSpeed * delta
        end if
        if keys[SDL_SCANCODE_1] then
            mode = 1
        end if
        if keys[SDL_SCANCODE_2] then
            mode = 2
        end if
        
        if pa >= 360 or pa < 0 then pa = pa mod 360
        
        '// RAYCAST BEGIN  =============================================
        
        vf    = vectorFromAngle(pa)
        vr    = vectorToRight(vf)
        vray.x = vf.x-vr.x*abs(fov)
        vray.y = vf.y-vr.y*abs(fov)
        vr.x /= HALF_X: vr.y /= HALF_X
        vr.x *= abs(fov)
        vr.y *= abs(fov)
        
        dim north as Vector
        north.x = 0: north.y = 1
        
        if mode = 2 then
            dim g as double
            g = 30
            dv += g*delta
            ph -= dv*delta
        
            nph = map->heights(int(px), int(py))*0.01+1.5
        
            if ph < nph then
               ph = nph
               dv = 0
            end if
        end if
        
        strafeValue = cos(strafeAngle*TO_RAD)*iif(keys[SDL_SCANCODE_LCTRL], 0.05, 0.05)
        
        dim colr as integer
        dim xDistMax as integer, yDistMax as integer
        dim distMax as integer
        dim i as integer
        
        '// DRAW SKY  ==================================================
        dim y as integer
        dim r as integer, g as integer, b as integer
        dim rr as integer
        r = (colorSky shr 16) and &hff
        g = (colorSky shr  8) and &hff
        b = (colorSky       ) and &hff
        'bottom = midline-HALF_Y-1
        'if bottom >= 0 then
        '    for y = 0 to bottom
        '        drawLine 0, y, SCREEN_X-1, y, rgb(r-100, g, b)
        '    next y
        'end if
        'top = midline-HALF_Y
        'if top < SCREEN_Y then
        '    for y = top to SCREEN_Y-1
        '        rr = r+y-midline: if rr > 255 then rr = 255
        '        if rr < 0 then r = 0
        '        drawLine 0, y, SCREEN_X-1, y, rgb(rr, g, b)
        '    next y
        'end if
        'SDL_SetRenderDrawColor(gfxRenderer, r, g, b, &hff)
        'SDL_RenderClear(gfxRenderer)
        
        dim pixels as integer ptr
        dim pixelNow as integer ptr
        dim pitch as integer
        dim xPix as integer, yPix as integer
        dim pt as integer
        
        SDL_LockTexture(texture, null, @pixels, @pitch)
        pitch = (pitch shr 2)
        
        xPix = 0: yPix = 0
        pt = pitch-SCREEN_X
        pixelNow = pixels
        colr = rgb(r, g, b)
        
        dim xStop as integer ptr
        dim yStop as integer ptr
        
        dim sk as integer
        sk = (midline-HALF_Y)
        'if sk > 0 then sk = 0
        colr = colorSky
        if sk < 0 then
            colr += &h010100*sk
        end if
        dim colstop as integer
        colstop = colorSky-&h010100*12
        
        yStop = pixels+iif(sk >= 0, sk, 0)*pitch
        while pixelNow < yStop
            xStop = pixelNow + SCREEN_X
            while pixelNow < xStop: *pixelNow = colr: pixelNow += 1: wend
            pixelNow += pt
        wend
        yStop = pixels+SCREEN_Y*pitch
        while pixelNow < yStop
            xStop = pixelNow + SCREEN_X
            while pixelNow < xStop: *pixelNow = colr: pixelNow += 1: wend
            pixelNow += pt
            colr -= &h010100
            if colr < colstop then colr = colstop
        wend
        pixelNow = pixels
        
        dim fx as double, fy as double, fo as double
                
        xPix = -1
        for f = 0 to SCREEN_X-1
            xPix += 1
            map = @highres
        
            bottom = SCREEN_Y-1
            
            '// EDGE-OF-MAP INTERSECTION ===============================
            xDistMax = 0
            yDistMax = 0
            fx = 0: fy = 0
            
            if px < 0 or px >= map->w then
                fx += abs(iif(vray.x > 0, -px, MAP_WIDTH-px)/vray.x)
            end if
            
            fx += abs(iif(vray.x > 0, map->w-1-px, -px)/vray.x)
            
            if fx > MAX_INT then fx = MAX_INT
            xDistMax = fx*PREC
            
            if py < 0 or py >= map->h then
                fy += abs(iif(vray.y > 0, -py, MAP_HEIGHT-py)/vray.y)
            end if
            
            fy += abs(iif(vray.y > 0, map->h-1-py, -py)/vray.y)
            
            if fy > MAX_INT then fy = MAX_INT
            yDistMax = fy*PREC
            
            distMax = iif(xDistMax < yDistMax, xDistMax, yDistMax)
            if distMax > MAX_DISTANCE then distMax = MAX_DISTANCE
            
            '// CLOSEST INTERSECTION  ==================================
            xHit = 0
            if px >= 0 and px < map->w then
                fx = iif(vray.x > 0, int(px+1)-px, int(px)-px)
            else
                fx = iif(vray.x > 0, -px, MAP_WIDTH-px)
            end if
            fy = vray.y*abs(fx/vray.x)
            if fy >  MAX_INT then fy =  MAX_INT
            if fy < -MAX_INT then fy = -MAX_INT
            ex = iif(vray.x >= 0, 0, -1)
            ey = 0
            
            fo = abs(fx/vray.x)
            if fo > MAX_INT then fo = MAX_INT
            xDist = fo*PREC
            
            dx = (fx+px)*PREC
            dy = (fy+py)*PREC
            
            x_dx = dx: x_dy = dy
            
            yHit = 0
            if py >= 0 and py < map->h then
                fy = iif(vray.y > 0, int(py+1)-py, int(py)-py)
            else
                fy = iif(vray.y > 0, -py, MAP_HEIGHT-py)
            end if
            fx = vray.x*abs(fy/vray.y)
            if fx >  MAX_INT then fx =  MAX_INT
            if fx < -MAX_INT then fx = -MAX_INT
            ex = 0
            ey = iif(vray.y >= 0, 0, -1)
            
            fo = abs(fy/vray.y)
            if fo > MAX_INT then fo = MAX_INT
            yDist = fo*PREC
            
            dy = (fy+py)*PREC
            dx = (fx+px)*PREC
            
            y_dx = dx: y_dy = dy
            
            if xDist < yDist then
                dx = x_dx: dy = x_dy
                ex = x_ex: ey = x_ey
                dist = xDist
            else
                dy = y_dy: dx = y_dx
                ey = y_ey: ex = y_ex
                dist = yDist
            end if
            lx = (dx shr PREC_SHIFT)+ex: ly = (dy shr PREC_SHIFT)+ey
            
            sliceSize = HEIGHT_RATIO / dist
            dim h as double
            h = map->heights(int(px), int(py))*0.01
            top = midline+int(sliceSize*((ph-h)+strafeValue))+1
            yPix = bottom
            pixelNow = pixels+pitch*yPix+xPix
            '// draw top
            if top <= bottom then
                colr = map->colors(int(px), int(py))
                if top < 0 then top = 0
                while yPix >= top: *(pixelNow) = colr: pixelNow -= pitch: yPix -=1: wend
                bottom = top-1
            end if
            '// draw side
            h = map->heights(lx, ly)*0.01
            top = midline+int(sliceSize*((ph-h)+strafeValue))+1
            if top <= bottom then
                colr = map->colors(lx, ly)
                dc = iif(xDist > yDist, 10, -10)
                if top < 0 then top = 0
                while yPix >= top: *(pixelNow) = colr: pixelNow -= pitch: yPix -=1: wend
                bottom = top-1
            end if
            '// INTERSECTIONS UNTIL EDGE-OF-MAP/MAX-DISTANCE  ==========
            dim x_di as integer
            dim y_di as integer
            
            x_ax = iif(vray.x >= 0, 1, -1)*PREC
            x_ay = (vray.y / abs(vray.x))*PREC
            x_ex = iif(vray.x >= 0, 0, -1)
            x_ey = 0
            x_di = abs(PREC/vray.x)
            
            y_ay = iif(vray.y >= 0, 1, -1)*PREC
            y_ax = (vray.x / abs(vray.y))*PREC
            y_ey = iif(vray.y >= 0, 0, -1)
            y_ex = 0
            y_di = abs(PREC/vray.y)
            
            dim wallR as integer, wallG as integer, wallB as integer
            dim skyR as integer, skyG as integer, skyB as integer
            dim ic as integer
            dim atmosphereFactor as double
            dim dc1 as double
            
            atmosphereFactor = 0.0026
            
            dim xAlign as integer, yAlign as integer
            dim switchedToMed as integer, switchedToLow as integer
            dim switchedToSub as integer
            
            switchedToMed = 0: switchedToLow = 0: switchedToSub = 0
            dim switchCount as integer
            dim nextDist as double
            switchCount = 0: nextDist = 160*PREC'96'160'32'160
            
            do while dist < distMax
                
                if xDist < yDist then
                    x_dx  += x_ax: x_dy += x_ay
                    xDist += x_di
                    if map->callbacks(x_dx, x_dy) <> 0 then
                        map->callbacks(x_dx, x_dy)(x_dx, y_dy, 0, 0)
                    end if
                else
                    y_dy  += y_ay: y_dx += y_ax
                    yDist += y_di
                    if map->callbacks(y_dx, y_dy) <> 0 then
                        map->callbacks(y_dx, y_dy)(0, 0, y_dx, y_dy)
                    end if
                end if
                
                if xDist < yDist then
                    dx = x_dx: dy = x_dy
                    ex = x_ex: ey = x_ey
                    dist = xDist
                else
                    dy = y_dy: dx = y_dx
                    ey = y_ey: ex = y_ex
                    dist = yDist
                end if
                
                sliceSize = HEIGHT_RATIO / dist
                
                '// draw top
                top = midline+int(sliceSize*((ph-h)+strafeValue))+1
                dc = 0
                
                if top <= bottom then
                
                    dim dat as integer
                
                    colr = map->colors(lx, ly)
                    dat = map->datas(lx, ly)
                                    
                    dc = (dist shr PREC_SHIFT)*atmosphereFactor
                    dc = dc*dc*dc
                    dc1 = 1/(dc+1)
                    skyR  = (colorSky  shr 16) and 255: skyG  = (colorSky  shr 8) and 255: skyB  = (colorSky  and 255)
                    if dat = 777 then
                        dim add as integer
                        add = 7-(int(((cos(lx+seconds*0.002)*TO_RAD)*(sin(seconds*0.002-ly)*TO_RAD)*3000000)) and 15)
                        r = &h5c+add: g = &h53+add: b = &hdb+add
                        wallR = (colr shr 16) and 255: wallG = (colr shr 8) and 255: wallB = (colr and 255)
                        colr = rgb((r+wallR)*0.5, (g+wallG)*0.5, (b+wallB)*0.5)
                        wallR = (colr shr 16) and 255: wallG = (colr shr 8) and 255: wallB = (colr and 255)
                    else
                        wallR = (colr shr 16) and 255: wallG = (colr shr 8) and 255: wallB = (colr and 255)
                    end if
                    r = (wallR+(skyR*dc))*dc1
                    g = (wallG+(skyG*dc))*dc1
                    b = (wallB+(skyB*dc))*dc1
                    colr = rgb(r, g, b)
                
                    'drawLine f, top, f, bottom, colr, 0
                    if top < 0 then top = 0
                    while yPix >= top: *(pixelNow) = colr: pixelNow -= pitch: yPix -=1: wend
                    bottom = top-1
                end if
                
                if (dist > nextDist) then
                    switchCount += 1
                    select case switchCount
                    case 1
                        map = @medres
                        nextDist = 320*PREC'160'320'64'320
                    case 2
                        map = @lowres
                        nextDist = 480*PREC'320'480'256'480
                    case 3
                        map = @subres
                        nextDist = &h7fffffff
                    end select
                    xAlign = 1: yAlign = 1
                    x_dx \= 2: x_dy \= 2
                    y_dx \= 2: y_dy \= 2
                    x_di *= 2: y_di *= 2
                    lx   \= 2: ly   \= 2
                    if x_dx-((x_dx shr PREC_SHIFT) shl PREC_SHIFT) <> 0 then
                        x_dx  += x_ax\2: x_dy += x_ay\2
                        xDist += x_di\2
                    end if
                    if y_dy-((y_dy shr PREC_SHIFT) shl PREC_SHIFT) <> 0 then
                        y_dy  += y_ay\2: y_dx += y_ax\2
                        yDist += y_di\2
                    end if
                    
                     if xDist < yDist then
                        dx = x_dx: dy = x_dy
                        ex = x_ex: ey = x_ey
                        dist = xDist
                    else
                        dy = y_dy: dx = y_dx
                        ey = y_ey: ex = y_ex
                        dist = yDist
                    end if
                end if
                
                '// draw side
                lx = (dx shr PREC_SHIFT)+ex: ly = (dy shr PREC_SHIFT)+ey
                h = map->heights(lx, ly)*0.01
                top = midline+int(sliceSize*((ph-h)+strafeValue))+1
                if top <= bottom then
                    colr = map->colors(lx, ly)
                    if dc = 0 then
                        dc = (dist shr PREC_SHIFT)*atmosphereFactor
                        dc = dc*dc*dc
                        dc1 = 1/(dc+1)
                    end if
                    ic = iif(xDist > yDist, 10, -10)
                    wallR = (colr shr 16) and 255: wallG = (colr shr 8) and 255: wallB = (colr and 255)
                    skyR  = (colorSky  shr 16) and 255: skyG  = (colorSky  shr 8) and 255: skyB  = (colorSky  and 255)
                    wallR += ic: wallG += ic: wallB += ic
                    if wallR > 255 then wallR = 255
                    if wallG > 255 then wallG = 255
                    if wallB > 255 then wallB = 255
                    if wallR < 0 then wallR = 0
                    if wallG < 0 then wallG = 0
                    if wallB < 0 then wallB = 0
                    colr = rgb((wallR+(skyR*dc))*dc1, (wallG+(skyG*dc))*dc1, (wallB+(skyB*dc))*dc1)
                    'drawLine f, top, f, bottom, colr, 0
                    if top < 0 then top = 0
                    while yPix >= top: *(pixelNow) = colr: pixelNow -= pitch: yPix -=1: wend
                    bottom = top-1
                end if
                
                if bottom < 0 then exit do
                
            loop
            
            '// draw meshes
            dim mv as MeshTriangle ptr
            for i = 0 to meshCount-1
                meshes(i).startOver()
                mv = meshes(i).getNext()
            next i
            
            '// draw sky
            'if bottom >= 0 then
            '    drawLine f, 0, f, bottom, colorSky
            'end if
            'dim y as integer
            'dim r as integer, g as integer, b as integer
            'for y = -1 to bottom step 3
            '    r = (colorSky shr 16) and &hff
            '    g = (colorSky shr  8) and &hff
            '    b = (colorSky       ) and &hff
            '    r += y-midline: if r > 255 then r = 255
            '    if r < 0 then r = 0
            '    if y+9 <= bottom then
            '        drawLine f, y, f, y+2, rgb(r, g, b)
            '    else
            '        drawLine f, y, f, bottom, rgb(r, g, b)
            '    end if
            'next y
            if bottom > midline then
                top = midline
                if top < 0 then top = 0
                'while yPix >= top: *(pixelNow) = colr: pixelNow -= pitch: yPix -=1: wend
            end if
            
            vray.x += vr.x: vray.y += vr.y
            'if f = HALF_X then
            '    game_font.writeText( "MAX: "+str(int(dist)), 3, 12 )
            'end if
            
        next f
        
        SDL_UnlockTexture(texture)
        SDL_RenderCopy(gfxRenderer, texture, null, null)
        
        '// RAYCAST END  ===============================================
        game_font.writeText( "FPS: "+str(fps), 3, 3 )
        game_font.writeText( "X: "+str(int(px)), 3, 15 )
        game_font.writeText( "Y: "+str(int(py)), 3, 27 )
        'game_font.writeText( "PITCH: "+str(ha), 3, 3 )
        'game_font.writeText( "MLINE: "+str(midline), 3, 15 )
        game_font.writeText( "+", HALF_X-4, HALF_Y-4 )
        
        SDL_RenderPresent gfxRenderer
    
    loop

end sub

sub rayTeleport(byref x_dx as integer, byref x_dy as integer, byref y_dx as integer, byref y_dy as integer)

end sub

sub loadMap(highres as FlatMap, medres as FlatMap, lowres as FlatMap)
    randomize timer
    dim x as integer, y as integer
    dim v as Vector
    
    dim objects(16, 1) as string
    dim i as integer
    for i = 0 to 15
        read objects(i, 0)
    next i
    for i = 0 to 15
        read objects(i, 1)
    next i
    
    print "Generating world...";
    
    'dim r as Vector
    dim r as integer
    dim h as double = 3000
    v = vectorFromAngle(rnd(1)*360)
    for y = 0 to highres.h-1
        for x = 0 to highres.w-1
            highres.setWall(x, y, 0)
            highres.setHeight(x, y, _
              (abs(sin(x*3*TO_RAD)*cos(y*3*TO_RAD))+sin(x*3*TO_RAD))*-h _
            - (abs(sin(y*TO_RAD)))*-h _
            + (abs(cos(y/10*TO_RAD)))*-h _
            )
            if highres.heights(x, y) < -int(h*0.95) then
                highres.setHeight(x, y, -int(h*0.95))
                'highres.setColor(x, y, rgb(&h8d+r, &hb2+r, &h7c+r))
                'highres.setColor(x, y, &h5c73ab)
                r = int(16*rnd(1))-32
                highres.setColor(x, y, rgb(&h8d+r, &hb2+r, &h7c+r))
                highres.setData(x, y, 0, 777)
            else
                r = int(16*rnd(1))-32
                highres.setColor(x, y, rgb(&h8d+r, &hb2+r, &h7c+r))
            end if
        next x
        if (y and 511) = 0 then print ".";
    next y
    dim dx as integer
    dim dy as integer
    dim c as string
    'dim h as integer
    dim low_h as integer
    dim obj_id as integer
    dim colr as integer
    dim g as integer, b as integer
    dim chance as double
    
    print ".";
    
    '// mountains
    dx = int(highres.w*rnd(1))
    dy = int(highres.h*rnd(1))
    for y = dy-500 to dy+500
    for x = dx-500 to dx+500
        if highres.heights(x, y) > 0 then
            highres.setWall(x, y, 0)
            highres.setHeight(x, y, _
              ((sin((int(y) * int(x))*0.01*TO_RAD))*3000 _
            ))
            'if highres.heights(x, y) < -100 then
            '    highres.setHeight(x, y, -100)
            '    'highres.setColor(x, y, rgb(&h8e-50, &h92-20, &hbf-20))
            '    r = int(16*rnd(1))-32
            '    highres.setColor(x, y, rgb(&h8d+r, &hb2+r, &h7c+r))
            '    highres.setData(x, y, 0, 777)
            'else
                r = int(16*rnd(1))-32
                highres.setColor(x, y, rgb(&hd2+r, &hd2+r, &hd2+r))
                highres.setData(x, y, 0, 0)
            'end if
        end if
    next x
    next y
    
    print ".";
    
    '// desert
    dx = int(highres.w*rnd(1))
    dy = int(highres.h*rnd(1))
    for y = dy-300 to dy+300
    for x = dx-300 to dx+300
        if highres.heights(x, y) > 0 then
            highres.setWall(x, y, 0)
            highres.setHeight(x, y, _
              ((sin((int(y) and int(x))*3*TO_RAD))*3000 _
            ))
            if highres.heights(x, y) < -250 then
                highres.setHeight(x, y, -250)
                r  = (1-sin(y*30))*10
                r += (1-cos(x*30))*10
                r = 0
                r = int(16*rnd(1))-32
                highres.setColor(x, y, rgb(&hdd+r, &hb2+r, &h5c+r))
                highres.setData(x, y, 0, 777)
            else
                r = int(16*rnd(1))-32
                r += int(x*y) and 7
                highres.setColor(x, y, rgb(&hdd+r, &hb2+r, &h5c+r))
                highres.setData(x, y, 0, 0)
            end if
        end if
    next x
    next y
    
    print ".";
    
    '// snow caps
    dx = int(highres.w*rnd(1))
    dy = int(highres.h*rnd(1))
    for y = dy-200 to dy+200
    for x = dx-200 to dx+200
        if highres.heights(x, y) > 0 then
            colr = highres.colors(x, y)
            r = (colr shr 16) and &hff: g = (colr shr 8) and &hff: b = (colr and &hff)
            r += highres.heights(x, y)*0.001+128
            g += highres.heights(x, y)*0.001+128
            b += highres.heights(x, y)*0.001+128
            if r > 255 then r = 255
            if g > 255 then g = 255
            if b > 255 then b = 255
            chance = -int(16*rnd(1))
            highres.setColor(x, y, rgb(r+chance, g+chance, b+chance))
            highres.setData(x, y, 0, 0)
        end if
    next x
    next y
    
    print ".";
    
    '// swamp
    dx = int(highres.w*rnd(1))
    dy = int(highres.h*rnd(1))
    for y = dy-200 to dy+200
        for x = dx-200 to dx+200
            highres.setHeight(x, y, highres.heights(x, y)/5)
            r = int(16*rnd(1))-32
            highres.setColor(x, y, rgb(&h7d+r, &h92+r, &h6c+r))
            highres.setData(x, y, 0, 0)
        next x
    next y
    for y = dy-180 to dy+180
        for x = dx-180 to dx+180
            if int(32*rnd(1)) = 1 then
                highres.setHeight(x, y, highres.heights(x, y)+300+int(rnd(1)*1))
                highres.setColor(x, y, rgb(&h9d+r, &h92+r, &h5c+r))
                highres.setData(x, y, 0, 0)
            end if
        next x
    next y
    
    print ".";
    
    restore objects
    for i = 0 to 0
        obj_id = 1'int(2*rnd(1))
        x = int(highres.w*rnd(1))
        y = int(highres.h*rnd(1))
        low_h = 9999
        for dy = 0 to 15
            for dx = 0 to 15
                if dx = 0 or dy = 0 or dx = 15 or dy = 15 then
                    h = highres.heights(x+dx, y+dy)
                    if h < low_h then
                        low_h = h
                    end if
                end if
            next dx
        next dy
        for dy = 0 to 15
            for dx = 0 to 15
                c = mid(objects(dy, obj_id), dx+1, 1)
                if c = "#" then
                    h = 30
                    r = -20
                elseif c = " " then
                    h = 0
                elseif c = "0" then
                    h = -1
                elseif c >= "a" and c <= "z" then
                    h = asc(c)-97+10
                    r = h*12+80
                else
                    h = val(c)
                    r = h*12+80
                end if
                h *= iif(obj_id = 0, 40, 150)
                highres.setHeight(x+dx, y+dy, low_h+h)
                dim nothing as integer = int(16*rnd(1))-32
                if h = -40 then
                    highres.setColor(x+dx, y+dy, rgb(&h6e, &h72, &h9f))
                elseif h <> 0 then
                    highres.setColor(x+dx, y+dy, rgb(&hff+r, &he4+r, &hd8+r))
                else
                    if (y+dy) and 1 then
                        r = iif((x+dx) and 1, &hbe, &h22)
                    else
                        r = iif((x+dx) and 1, &h22, &hbe)
                    end if
                    highres.setColor(x+dx, y+dy, rgb(&h00+r, &h00+r, &h00+r))
                end if
            next dx
        next dy
    next i
    
    print ".";
    
    '// glow boxes
    dim rx as integer, ry as integer
    dim dist as integer
    for i = 0 to 0
        rx = int(highres.w*rnd(1))
        ry = int(highres.h*rnd(1))
        low_h = 9999
        for y = ry-10 to ry+10
            for x = rx-10 to rx+10
                if highres.heights(x, y) < low_h then
                    low_h = highres.heights(x, y)
                end if
            next x
        next y
        for y = ry-10 to ry+10
            for x = rx-10 to rx+10
                dist = iif(abs(x-rx) > abs(y-ry), abs(x-rx), abs(y-ry))+1
                dist = 1000/(dist*dist)
                colr = highres.colors(x, y)
                r = red(colr): g = grn(colr): b = blu(colr)
                r = iif(r+dist > 255, 255, r+dist)
                g = iif(g+dist > 255, 255, g+dist)
                b = iif(b+dist > 255, 255, b+dist)
                highres.setColor(x, y, rgb(r, g, b))
                'highres.setHeight(x, y, low_h)
            next x
        next y
        highres.setHeight(rx, ry, highres.heights(rx, ry)+25000)
    next i
    
    print ".";
    
    '// portals
    dim dat as integer
    dim xFrom as integer, yFrom as integer
    dim xTo as integer, yTo as integer
    for i = 0 to 9
        do
            xFrom = int(highres.w*rnd(1)): yFrom = int(highres.h*rnd(1))
            xTo = int(highres.w*rnd(1)): yTo = int(highres.h*rnd(1))
        loop while (xFrom = xTo) and (yFrom = yTo)
        highres.setData(x, y, 0, (xFrom shl 16) or yFrom)
        highres.setData(x, y, 1, (xTo shl 16) or yTo)
        highres.setCallback(x, y, @rayTeleport)
    next i
    
    print ".";
    
    '// generate low-res maps
    for y = 0 to medres.h-1
        for x = 0 to medres.w-1
            medres.setWall(x, y, highres.getWallAvg(x*2, y*2, 2))
            medres.setHeight(x, y, highres.getHeightAvg(x*2, y*2, 2))
            medres.setColor(x, y, highres.getColorAvg(x*2, y*2, 2))
            medres.setCallback(x, y, highres.getCallbackAvg(x*2, y*2, 2))
            medres.setData(x, y, 0, highres.getDataAvg(x*2, y*2, 0, 2))
            medres.setData(x, y, 1, highres.getDataAvg(x*2, y*2, 1, 2))
        next x
    next y
    print ".";
    for y = 0 to lowres.h-1
        for x = 0 to lowres.w-1
            lowres.setWall(x, y, highres.getWallAvg(x*4, y*4, 4))
            lowres.setHeight(x, y, highres.getHeightAvg(x*4, y*4, 4))
            lowres.setColor(x, y, highres.getColorAvg(x*4, y*4, 4))
            lowres.setCallback(x, y, highres.getCallbackAvg(x*4, y*4, 4))
            lowres.setData(x, y, 0, highres.getDataAvg(x*4, y*4, 0, 4))
            lowres.setData(x, y, 1, highres.getDataAvg(x*4, y*4, 1, 4))
        next x
    next y
    print ".";
    for y = 0 to subres.h-1
        for x = 0 to subres.w-1
            subres.setWall(x, y, highres.getWallAvg(x*8, y*8, 8))
            subres.setHeight(x, y, highres.getHeightAvg(x*8, y*8, 8))
            subres.setColor(x, y, highres.getColorAvg(x*8, y*8, 8))
            subres.setCallback(x, y, highres.getCallbackAvg(x*8, y*8, 8))
            subres.setData(x, y, 0, highres.getDataAvg(x*8, y*8, 0, 8))
            subres.setData(x, y, 1, highres.getDataAvg(x*8, y*8, 1, 8))
        next x
    next y
    print "ready!"
end sub
objects:
data "eeeeeeeeeeeeeeee"
data "eaaaaaaaaaaaaaae"
data "eaeeeeeeeeeeeeae"
data "eaeeeeeeeeeeeeae"
data "eaee##eeee##eeae"
data "eaee##eeee##eeae"
data "eaeeeeeeeeeeeeae"
data "eaeeeeeeeeeeeeae"
data "eaeeeeeeeeeeeeae"
data "eae####ee####eae"
data "eae####ee####eae"
data "eae##########eae"
data "eae##########eae"
data "eaeeeeeeeeeeeeae"
data "eaaaaaaaaaaaaaae"
data "eeeeeeeeeeeeeeee"

data "2222222222222222"
data "2444444444444442"
data "2466666666666642"
data "2468888888888642"
data "2468aaaaaaaa8642"
data "2468acccccca8642"
data "2468aceeeeca8642"
data "2468aceeeeca8642"
data "2468aceeeeca8642"
data "2468aceeeeca8642"
data "2468acccccca8642"
data "2468aaaaaaaa8642"
data "2468888888888642"
data "2466666666666642"
data "2444444444444442"
data "2222222222222222"
horse:
data "................"
data "............#..."
data "..........####.."
data "........########"
data "....#######....."
data "############...."
data "...##########..."
data "...##......##..."
data "..##.....##....."
data "..#....##......."
data "................"
data "................"
data "................"
data "................"
data "................"
data "................"
'//====================
data "................"
data "............#..."
data "..........####.."
data "........########"
data "....#######....."
data "############...."
data "...##########..."
data "................"
data "................"
data "................"
data "................"
data "................"
data "................"
data "................"
data "................"
data "................"

sub gfx_dice(sprites() as SDL_RECT, filename as string, img_w as integer, img_h as integer, sp_w as integer, sp_h as integer, scale_x as double=1.0, scale_y as double=0)

	if scale_y = 0 then
		scale_y = scale_x
	end if
	
	dim gfxSource as SDL_Surface ptr = SDL_LoadBMP(filename)
	
	SDL_SetColorKey( gfxSource, SDL_TRUE, SDL_MapRGB(gfxSource->format, 255, 0, 255) )
	gfxSprites = SDL_CreateTextureFromSurface( gfxRenderer, gfxSource )
	
	dim row_w as integer, row_h as integer
	row_w = int(img_w / sp_w)
	row_h = int(img_h / sp_h)
	
	dim i as integer
	for i = 0 to row_w*row_h-1
		sprites(i).x = (i mod row_w)*sp_w
		sprites(i).y = int(i/row_w)*sp_h
		sprites(i).w = sp_w
		sprites(i).h = sp_h
	next i

end sub

