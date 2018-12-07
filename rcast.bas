#include once "SDL2/SDL.bi"

#define FULLSCREEN 1
#define SCREEN_X   352'532'1920'352
#define SCREEN_Y   198'300'1080'198
#define HALF_X     SCREEN_X \ 2
#define HALF_Y     SCREEN_Y \ 2


#define PREC         (2^14)
#define PREC_SHIFT   14
#define MAX_DISTANCE (4096 shl PREC_SHIFT) '300
#define MAX_INT      (2^16)

dim shared HEIGHT_RATIO as integer
HEIGHT_RATIO = SCREEN_X shl PREC_SHIFT

#include once "modules/inc/timer.bi"
#include once "modules/inc/gfont.bi"
#include once "modules/inc/vector.bi"
#include once "modules/inc/mesh.bi"
#include once "modules/inc/flatmap.bi"
#include once "modules/inc/bsp.bi"
#include once "modules/inc/rgb.bi"

'// GRAPHICS FUNCTIONS  ================================================
declare sub gfx_dice(sprites() as SDL_RECT, filename as string, img_w as integer, img_h as integer, sp_w as integer, sp_h as integer, scale_x as double=1.0, scale_y as double=0)
declare sub drawLine(x0 as integer, y0 as integer, x1 as integer, y1 as integer, colr as integer, pixels as integer ptr, pitch as integer)
declare sub drawTriangle(x0 as integer, y0 as integer, x1 as integer, y1 as integer, x2 as integer, y2 as integer, colr as integer, pixels as integer ptr, pitch as integer)
declare sub drawTriangleTop(x0 as integer, y0 as integer, x1 as integer, y1 as integer, x2 as integer, y2 as integer, colr as integer, pixels as integer ptr, pitch as integer)
declare sub drawTriangleBtm(x0 as integer, y0 as integer, x1 as integer, y1 as integer, x2 as integer, y2 as integer, colr as integer, pixels as integer ptr, pitch as integer)
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

enum MeshIds
    horse = 0
end enum

sub loadHorse()
    restore horse
    dim x as integer, y as integer
    dim m as Mesh
    dim c as integer
    dim row as string
    dim scale as double
    scale = .1
    for y = 15 to 0 step -1
        read row
        for x = 1 to 16
            if mid(row, x, 1) = "#" then
                'm.addCube((x-7.5)*1, (y-7.5)*1, 0, 1, 1, 1)
                meshes(MeshIds.horse).addCube((x-7.5), (y-7.5), 0, scale, scale, scale)
            end if
        next x
    next y
    'meshes(MeshIds.horse) = m.copy()
    meshCount += 1
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
    dim flyingSpeed as double = 10
    'dim pitch as double
    dim mode as integer = 1
    dim strafeAngle as double
    dim strafeValue as double
    
    dim texture as SDL_Texture ptr
    texture = SDL_CreateTexture(gfxRenderer, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_STREAMING, SCREEN_X, SCREEN_Y)
    
    loadHorse()
    
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
        dim height as double
        height = 0.25
        
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
            pa += 100*delta
        end if
        if keys[SDL_SCANCODE_RIGHT] then
            pa -= 100*delta
        end if
        
        if keys[SDL_SCANCODE_LCTRL]  then speed *= 1.5
        if keys[SDL_SCANCODE_LSHIFT] then speed *= 0.2
        
        if keys[SDL_SCANCODE_A] then
            
            vf = vectorFromAngle(pa)
            vf = vectorToRight(vf)
            vf.x = vf.x * speed * iif(keys[SDL_SCANCODE_LCTRL], 1.5, 1) * delta
            vf.y = vf.y * speed * iif(keys[SDL_SCANCODE_LCTRL], 1.5, 1) * delta
            px -= vf.x
            py -= vf.y
            
            if mode = 2 then
                nph = map->heights(int(px), int(py))*0.01+height
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
                nph = map->heights(int(px), int(py))*0.01+height
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
                
                nph = map->heights(int(px), int(py))*0.01+height
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
                
                nph = map->heights(int(px), int(py))*0.01+height
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
                ph += speed * delta
            else
                'dv = -0.3333
                dv = -10
            end if
        end if
        if keys[SDL_SCANCODE_TAB] then
            ph -= speed * delta
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
        
            nph = map->heights(int(px), int(py))*0.01+height
        
            if ph < nph then
               ph = nph
               dv = 0
            end if
        end if
        
        strafeValue = cos(strafeAngle*TO_RAD)*iif(keys[SDL_SCANCODE_LCTRL], 0.05, 0.05)*0.2
        
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
            dim c as integer    
            dim ix as integer, iy as integer
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
            
            atmosphereFactor = 0.0015
            
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
                    colr = rgbAdd(colr, map->normals(lx, ly))
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
                    if r > 255 then r = 255: if r < 0 then r = 0
                    if g > 255 then g = 255: if g < 0 then g = 0
                    if b > 255 then b = 255: if b < 0 then b = 0
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
                    colr = rgbAdd(colr, map->normals(lx, ly))
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
                    r = (wallR+(skyR*dc))*dc1
                    g = (wallG+(skyG*dc))*dc1
                    b = (wallB+(skyB*dc))*dc1
                    if r > 255 then r = 255: if r < 0 then r = 0
                    if g > 255 then g = 255: if g < 0 then g = 0
                    if b > 255 then b = 255: if b < 0 then b = 0
                    colr = rgb(r, g, b)
                    'drawLine f, top, f, bottom, colr, 0
                    if top < 0 then top = 0
                    while yPix >= top: *(pixelNow) = colr: pixelNow -= pitch: yPix -=1: wend
                    bottom = top-1
                end if
                
                if bottom < 0 then exit do
                
            loop
            
            
            'end
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
        
        '// draw meshes
            dim m as Mesh
            dim mp as MeshPoly ptr
            dim mv as Vector ptr
            'dim fx as double, fy as double
            'dim ix as integer, iy as integer
            dim v3 as Vector3
            dim vCenter as Vector
            
            vCenter = Vector(0, 0, 0)
            
            SDL_SetRenderDrawColor(gfxRenderer, &hff, 0, 0, 0)
            dim hh as double
            hh = highres.heights(512, 512)*0.01+3
            
            for i = 0 to meshCount-1
                m.copy(@meshes(i))
                m.rotateY((seconds*120) mod 360)
                m.translate(py-512, -(ph-hh), 512-px)
                m.rotateY(-pa)
                m.sort()
                m.startOver()
                c = 0
                do
                    mp = m.getNext()
                    if mp = 0 then exit do
                    
                    v3 = mp->copy()
                    dim vc as Vector, dot as double
                    
                    vc = vectorToUnit(vectorCross(v3.v(2)-v3.v(0), v3.v(1)-v3.v(0)))
                    dim vff as Vector
                    vff.x = vf.y
                    vff.y = 0'ha*0.3*.02625
                    vff.z = -vf.x
                    dot = vectorDot(vc, vectorToUnit(vff))
                    if 1 then 'dot < 0 then
                        dot = (vectorDot(vc, vectorToUnit(Vector(-1, 1, 0))))
                        'v3.translate(py-512, -(ph-hh), 512-px)
                        'v3.rotateY(-pa)
                        
                        'dim v4 as Vector3
                        'v4.v(0) = (v3.v(0)+v3.v(1)+v3.v(2))/3
                        'v4.v(1) = v4.v(0)
                        'v4.v(2) = v3.v(2)
                        'v4.v(1) += vc*0.1
                        
                        if (v3.v(0).z > 0) and (v3.v(1).z > 0) and (v3.v(2).z > 0) then
                            v3.make2d(SCREEN_X, SCREEN_Y, 2.2222, 1)
                            'v4.make2d(SCREEN_X, SCREEN_Y, 2.2222, 1)
                            v3.translate(0, midline-HALF_Y, 0)
                            'v4.translate(0, midline-HALF_Y, 0)
                            'fx = v3.v(0).x: fy = v3.v(0).y
                            'ix = cast(integer, fx): iy = cast(integer, fy)
                            'if ix >= 0 and ix < SCREEN_X and iy >= 0 and iy < SCREEN_Y then
                                'pixelNow = pixels+ix+iy*pitch
                                '*pixelNow = rgb(255, 0, 0)
                            'end if
                            'print c, ix, iy
                            'fx = v3.v(1).x: fy = v3.v(1).y
                            'ix = cast(integer, fx): iy = cast(integer, fy)
                            'if ix >= 0 and ix < SCREEN_X and iy >=0 and iy < SCREEN_Y then
                                'pixelNow = pixels+ix+iy*pitch
                                '*pixelNow = rgb(255, 255, 0)
                            'end if
                            'print c, ix, iy
                            'fx = v3.v(2).x: fy = v3.v(2).y
                            'ix = cast(integer, fx): iy = cast(integer, fy)
                            'if ix >= 0 and ix < SCREEN_X and iy >=0 and iy < SCREEN_Y then
                                'pixelNow = pixels+ix+iy*pitch
                                '*pixelNow = rgb(255, 0, 255)
                            'end if
                            r = &hff+dot*50
                            g = &he4+dot*50
                            b = &hd8+dot*50
                            if r > 255 then r = 255
                            if g > 255 then g = 255
                            if b > 255 then b = 255
                            colr = rgb(r, g, b)
                            drawTriangle(v3.v(0).x, v3.v(0).y, v3.v(1).x, v3.v(1).y, v3.v(2).x, v3.v(2).y, colr, pixels, pitch)
                            'drawLine(v4.v(0).x, v4.v(0).y, v4.v(1).x, v4.v(1).y, &hff0000, pixels, pitch)
                            
                            'SDL_RenderDrawLine(gfxRenderer, v3.v(0).x, v3.v(0).y, v3.v(1).x, v3.v(1).y)
                            'SDL_RenderDrawLine(gfxRenderer, v3.v(1).x, v3.v(1).y, v3.v(2).x, v3.v(2).y)
                            'SDL_RenderDrawLine(gfxRenderer, v3.v(2).x, v3.v(2).y, v3.v(0).x, v3.v(0).y)
                            'c += 1
                            'ix = cast(integer, fx): iy = cast(integer, fy)
                            ix = v3.v(0).x: iy = v3.v(0).z
                        end if
                    end if
                    'print c, ix, iy
                loop
            next i
        
        SDL_UnlockTexture(texture)
        SDL_RenderCopy(gfxRenderer, texture, null, null)
        
        
        
        '// RAYCAST END  ===============================================
        game_font.writeText( "FPS: "+str(fps), 3, 3 )
        game_font.writeText( "X: "+str(int(px)), 3, 15 )
        game_font.writeText( "Y: "+str(int(py)), 3, 27 )
        game_font.writeText( "PA: "+str(int(pa)), 3, 39 )
        'game_font.writeText( "PITCH: "+str(ha), 3, 3 )
        'game_font.writeText( "MLINE: "+str(midline), 3, 15 )
        game_font.writeText( "+", HALF_X-4, HALF_Y-4 )
        'game_font.writeText( str(int(512-px)), 3, 51 )
        'game_font.writeText( str(int(512-py)), 3, 63 )
        game_font.writeText( str((-(ph-hh))), 3, 51 )
        game_font.writeText( str(int(iy)), 3, 63 )
        
        SDL_RenderPresent gfxRenderer
        
    loop

end sub

sub drawTriangleTop(x0 as integer, y0 as integer, x1 as integer, y1 as integer, x2 as integer, y2 as integer, colr as integer, pixels as integer ptr, pitch as integer)

    dim dx as double, dy as double
    dim sx0 as double, sy0 as double
    dim sx1 as double, sy1 as double
    dim vx0 as double, vy0 as double
    dim vx1 as double, vy1 as double
    dim vm as double
    
    dim x as integer, y as integer
    dim pixelNow as integer ptr   
     
    if y0 > y1 then swap y0, y1: swap x0, x1
    if y0 > y2 then swap y0, y2: swap x0, x2
    if y1 > y2 then swap y1, y2: swap x1, x2
    if y0 > y1 then swap y0, y1: swap x0, x1
    
    dx = x1-x0: dy = y1-y0: vx0 = iif(dx <> 0, dx, 0.00000001)/dy
    dx = x2-x0: dy = y2-y0: vx1 = iif(dx <> 0, dx, 0.00000001)/dy
    
    sx0 = x0+0.5: sy0 = y0+0.5
    sx1 = x0+0.5: sy1 = y0+0.5
	dim i as integer
    dim n as integer
    dim l as integer
	for i = y0 to y1
		l = int(abs(int(sx1)-int(sx0)))
        n = 0
        x = int(iif(sx0 < sx1, sx0, sx1))
        y = int(iif(sx0 < sx1, sy0, sy1))
        sx0 += vx0: sy0 += 1
        sx1 += vx1: sy1 += 1
        if (y < 0) or (y >= SCREEN_Y) or (x >= SCREEN_X) then
            continue for
        end if
        if x < 0 then
            l += x
            x  = 0
        end if
        if (x+l) >= SCREEN_X then
            l += (SCREEN_X-(x+l))
        end if
        pixelNow = pixels+x+y*pitch
        while n <= l
            *(pixelNow) = colr
            pixelNow += 1
            n += 1
        wend
	next i

end sub

sub drawTriangleBtm(x0 as integer, y0 as integer, x1 as integer, y1 as integer, x2 as integer, y2 as integer, colr as integer, pixels as integer ptr, pitch as integer)

    dim dx as double, dy as double
    dim sx0 as double, sy0 as double
    dim sx1 as double, sy1 as double
    dim vx0 as double, vy0 as double
    dim vx1 as double, vy1 as double
    dim vm as double
    
    dim x as integer, y as integer
    dim pixelNow as integer ptr   
     
    if y0 > y1 then swap y0, y1: swap x0, x1
    if y0 > y2 then swap y0, y2: swap x0, x2
    if y1 > y2 then swap y1, y2: swap x1, x2
    if y0 > y1 then swap y0, y1: swap x0, x1
    
    dx = x2-x0: dy = y2-y0: vx0 = iif(dx <> 0, dx, 0.00000001)/dy
    dx = x2-x1: dy = y2-y1: vx1 = iif(dx <> 0, dx, 0.00000001)/dy
    
    sx0 = x0+0.5: sy0 = y0+0.5
    sx1 = x1+0.5: sy1 = y1+0.5
	dim i as integer
    dim n as integer
    dim l as integer
	for i = y0 to y2
		l = int(abs(int(sx1)-int(sx0)))
        n = 0
        x = int(iif(sx0 < sx1, sx0, sx1))
        y = int(iif(sx0 < sx1, sy0, sy1))
        sx0 += vx0: sy0 += 1
        sx1 += vx1: sy1 += 1
        if (y < 0) or (y >= SCREEN_Y) or (x >= SCREEN_X) then
            continue for
        end if
        if x < 0 then
            l += x
            x  = 0
        end if
        if (x+l) >= SCREEN_X then
            l += (SCREEN_X-(x+l))
        end if
        pixelNow = pixels+x+y*pitch
        while n <= l
            *(pixelNow) = colr
            pixelNow += 1
            n += 1
        wend
	next i

end sub

sub drawTriangle(x0 as integer, y0 as integer, x1 as integer, y1 as integer, x2 as integer, y2 as integer, colr as integer, pixels as integer ptr, pitch as integer)

    dim mx as integer, my as integer
    
    if (x0 < 0) and (x1 < 0) and (x2 < 0) then return
    if (y0 < 0) and (y1 < 0) and (y2 < 0) then return
    if (x0 >= SCREEN_X) and (x1 >= SCREEN_X) and (x2 >= SCREEN_X) then return
    if (y0 >= SCREEN_Y) and (y1 >= SCREEN_Y) and (y2 >= SCREEN_Y) then return
    
    'drawLine(x0, y0, x1, y1, colr, pixels, pitch)
    'drawLine(x1, y1, x2, y2, colr, pixels, pitch)
    'drawLine(x2, y2, x0, y0, colr, pixels, pitch)
    'return
    
    if y0 > y1 then swap y0, y1: swap x0, x1
    if y0 > y2 then swap y0, y2: swap x0, x2
    if y1 > y2 then swap y1, y2: swap x1, x2
    if y0 > y1 then swap y0, y1: swap x0, x1
        
    if (y0 <> y1) and (y1 <> y2) then
        my = y1
        mx = int(x0+((x2-x0)/(y2-y0))*(my-y0))
        drawTriangleTop(x0, y0, x1, y1, mx, my, colr, pixels, pitch)
        drawTriangleBtm(mx, my, x1, y1, x2, y2, colr, pixels, pitch)
    else
        if y1 = y2 then
            drawTriangleTop(x0, y0, x1, y1, x2, y2, colr, pixels, pitch)
        else
            drawTriangleBtm(x0, y0, x1, y1, x2, y2, colr, pixels, pitch)
        end if
    end if

end sub

sub drawLine(x0 as integer, y0 as integer, x1 as integer, y1 as integer, colr as integer, pixels as integer ptr, pitch as integer)

    dim vx as double, vy as double
	dim sx as double, sy as double
	dim dx as integer, dy as integer
	dim vm as double
    
    if (x0 < 0) and (x1 < 0) then return
    if (y0 < 0) and (y1 < 0) then return
    if (x0 >= SCREEN_X) and (x1 >= SCREEN_X) then return
    if (y0 >= SCREEN_Y) and (y1 >= SCREEN_Y) then return
    
    dx = x1-x0
	dy = y1-y0
    
    if dx = 0 then dx = 0.00000001
    if dy = 0 then dy = 0.00000001
	
	vm = sqr(dx*dx+dy*dy)
	vx = dx / vm
	vy = dy / vm
    
    if x0 < 0 then y0 = y0-(dy/dx)*x0: x0 = 0
    if x0 >= SCREEN_X then y0 = y0+(dy/dx)*(SCREEN_X-x0): x0 = SCREEN_X-1
    if y0 < 0 then x0 = x0-(dx/dy)*y0: y0 = 0
    if y0 >= SCREEN_Y then x0 = x0+(dx/dy)*(SCREEN_Y-y0): y0 = SCREEN_Y-1
    if x1 < 0 then y1 = y1-(dy/dx)*x1: x1 = 0
    if x1 >= SCREEN_X then y1 = y1+(dy/dx)*(SCREEN_X-x1): x1 = SCREEN_X-1
    if y1 < 0 then x1 = x1-(dx/dy)*y1: y1 = 0
    if y1 >= SCREEN_Y then x1 = x1+(dx/dy)*(SCREEN_Y-y1): y1 = SCREEN_Y-1
    
    dx = x1-x0
	dy = y1-y0
    
    if dx = 0 then dx = 0.00000001
    if dy = 0 then dy = 0.00000001
    
    vm = sqr(dx*dx+dy*dy)
	vx = dx / vm
	vy = dy / vm
    
    sx = x0+0.5: sy = y0+0.5
    dim pixelStop as integer ptr
    dim pixelNow as integer ptr
    pixelStop = pixels+SCREEN_Y*pitch
	dim i as integer
	dim x as integer, y as integer
	for i = 0 to vm
		x = int(sx)
		y = int(sy)
        '*(pixels+x+y*pitch) = colr
        pixelNow = pixels+x+y*pitch
        if pixelNow >= pixels and pixelNow < pixelStop then
            *(pixels+x+y*pitch) = colr
        end if
		sx += vx: sy += vy
	next i

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
    dim h as double = 600
    v = vectorFromAngle(rnd(1)*360)
    for y = 0 to highres.h-1
        for x = 0 to highres.w-1
            highres.setWall(x, y, 0)
            highres.setHeight(x, y, _
              ((abs(sin(x*3*TO_RAD)*cos(y*3*TO_RAD))+sin(x*3*TO_RAD))*-h _
            - (abs(sin(y*TO_RAD)))*-h _
            + (abs(cos(y/10*TO_RAD)))*-h) _
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
              ((sin((int(y) * int(x))*0.01*TO_RAD))*600_
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
              ((sin((int(y) and int(x))*3*TO_RAD))*1000_
            ))
            if highres.heights(x, y) < -25 then
                highres.setHeight(x, y, -25)
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
                highres.setHeight(x, y, highres.heights(x, y)+60+int(rnd(1)*1))
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
                    h = 2
                    r = -20
                elseif c = " " then
                    h = 0
                elseif c = "0" then
                    h = -1
                elseif c >= "a" and c <= "z" then
                    h = (asc(c)-97+10)*0.2
                    r = h*12+20
                else
                    h = val(c)
                    r = h*12+20
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
    
    '// normals
    dim vNorth as Vector = vectorToUnit(Vector(-1, 0, 1))
    dim vNormal as Vector
    dim w as Vector
    dim u as Vector
    dim hh as double
    for y = 0 to highres.h-1
        for x = 0 to highres.w-1
            u.x = x: u.y = y: u.z = highres.heights(x, y)
            v.x = -10: v.y = y-10: v.z = highres.heights(x+10, y+10)
            w = vectorToUnit(vectorCross(u, v))
            vNormal = w
            'vNormal = vectorToUnit(vNormal)
            'v.x = 1: v.y = 0: print int(vectorDot(v, vNorth)*30)
            'v.x = -1: v.y = 0: print int(vectorDot(v, vNorth)*30)
            'v.x = 0: v.y = -1: print int(vectorDot(v, vNorth)*30)
            'v.x = 0: v.y = 1: print int(vectorDot(v, vNorth)*30)
            'v.x = 0: v.y = 0: v.z = 1: print int(vectorDot(v, vNorth)*30)
            'end
            highres.setNormal(x, y, int(vectorDot(vNormal, vNorth)*30))
            'if int(vectorDot(v, vNorth) > 1) or int(vectorDot(v, vNorth) < -1)  then
            '    print vectorDot(v, vNorth)
            '    end
            'end if
        next x
    next y
    
    '// generate low-res maps
    for y = 0 to medres.h-1
        for x = 0 to medres.w-1
            medres.setWall(x, y, highres.getWallAvg(x*2, y*2, 2))
            medres.setHeight(x, y, highres.getHeightAvg(x*2, y*2, 2))
            medres.setColor(x, y, highres.getColorAvg(x*2, y*2, 2))
            medres.setCallback(x, y, highres.getCallbackAvg(x*2, y*2, 2))
            medres.setData(x, y, 0, highres.getDataAvg(x*2, y*2, 0, 2))
            medres.setData(x, y, 1, highres.getDataAvg(x*2, y*2, 1, 2))
            medres.setNormal(x, y, highres.getNormalAvg(x*2, y*2, 2))
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
            lowres.setNormal(x, y, highres.getNormalAvg(x*4, y*4, 4))
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
            subres.setNormal(x, y, highres.getNormalAvg(x*8, y*8, 8))
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
data "................"
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

'//====================
data "................"
data "................"
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

