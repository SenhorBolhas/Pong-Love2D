--[[
    GD50 2020
    Pong Multiplayer
    -- Main Program --
    Author: Giovanni Pelloso Gasparetto
    Giovanni_Pelloso@hotmail.com
]]

-- push is a library that will allow us to draw our game at a virtual
-- resolution, instead of however large our window is; used to provide
-- a more retro aesthetic
--
-- https://github.com/Ulydev/push
push = require 'push'

-- the "Class" library we're using will allow us to represent anything in
-- our game as code, rather than keeping track of many disparate variables and
-- methods
--
-- https://github.com/vrld/hump/blob/master/class.lua
Class = require 'class'

-- our Paddle class, which stores position and dimensions for each Paddle
-- and the logic for rendering them
require 'Paddle'

-- our Ball class, which isn't much different than a Paddle structure-wise
-- but which will mechanically function very differently
require 'Ball'

-- size of our actual window
WINDOW_WIDTH = 1280
WINDOW_HEIGHT = 720

-- size we're trying to emulate with push
VIRTUAL_WIDTH = 432
VIRTUAL_HEIGHT = 243

-- paddle movement speed
PADDLE_SPEED = 200

--[[
    Called just once at the beginning of the game; used to set up
    game objects, variables, etc. and prepare the game world.
]]
function love.load()
    -- set love's default filter to "nearest-neighbor", which essentially
    -- means there will be no filtering of pixels (blurriness), which is
    -- important for a nice crisp, 2D look
    love.graphics.setDefaultFilter('nearest', 'nearest')

    -- set the title of our application window
    love.window.setTitle('Pong')

    -- seed the RNG so that calls to random are always random
    math.randomseed(os.time())

    -- initialize our nice-looking retro text fonts
    smallFont = love.graphics.newFont('font.ttf', 8)
    largeFont = love.graphics.newFont('font.ttf', 16)
    scoreFont = love.graphics.newFont('font.ttf', 32)
    love.graphics.setFont(smallFont)

    -- set up our sound effects; later, we can just index this table and
    -- call each entry's `play` method
    sounds = {
        ['paddle_hit'] = love.audio.newSource('sounds/paddle_hit.wav', 'static'),
        ['score'] = love.audio.newSource('sounds/score.wav', 'static'),
        ['wall_hit'] = love.audio.newSource('sounds/wall_hit.wav', 'static')
    }
    
    -- initialize our virtual resolution, which will be rendered within our
    -- actual window no matter its dimensions
    push:setupScreen(VIRTUAL_WIDTH, VIRTUAL_HEIGHT, WINDOW_WIDTH, WINDOW_HEIGHT, {
        fullscreen = false,
        resizable = true,
        vsync = true,
        canvas = false
    })

    -- initialize our player paddles; make them global so that they can be
    -- detected by other functions and modules
    player1 = Paddle(10, VIRTUAL_HEIGHT / 2, 5, 20)
    player2 = Paddle(VIRTUAL_WIDTH - 10, VIRTUAL_HEIGHT / 2, 5, 20)

    -- place a ball in the middle of the screen
    Ball = Ball(VIRTUAL_WIDTH / 2 - 2, VIRTUAL_HEIGHT / 2 - 2, 4, 4)

    -- initialize score variables
    player1Score = 0
    player2Score = 0

    -- either going to be 1 or 2; whomever is scored on gets to serve the
    -- following turn
    servingPlayer = 1

    -- player who won the game; not set to a proper value until we reach
    -- that state in the game
    winningPlayer = 0

    -- the state of our game; can be any of the following:
    -- 1. 'start' (the beginning of the game, before first serve)
    -- 2. 'serve' (waiting on a key press to serve the ball)
    -- 3. 'play' (the ball is in play, bouncing between paddles)
    -- 4. 'done' (the game is over, with a victor, ready for restart)
    -- 5 'gamemode' (the player choose to play against IA or other player)
    gameState = 'start'
end

--[[
    Called whenever we change the dimensions of our window, as by dragging
    out its bottom corner, for example. In this case, we only need to worry
    about calling out to `push` to handle the resizing. Takes in a `w` and
    `h` variable representing width and height, respectively.
]]
function love.resize(w, h)
    push:resize(w, h)
end

--[[
    Called every frame, passing in `dt` since the last frame. `dt`
    is short for `deltaTime` and is measured in seconds. Multiplying
    this by any changes we wish to make in our game will allow our
    game to perform consistently across all hardware; otherwise, any
    changes we make will be applied as fast as possible and will vary
    across system hardware.
]]
function love.update(dt)
    if gameState == 'serve' then
        -- before switching to play, initialize ball's velocity based
        -- on player who last scored
        Ball.dy = math.random(-50, 50)
        if servingPlayer == 1 then
            Ball.dx = math.random(140, 200)
        else
            Ball.dx = -math.random(140, 200)
        end
    elseif gameState == 'ai' then
        aiP1 = false
        aiP2 = true
    elseif gameState == '2p' then
        aiP1 = false
        aiP2 = false
    elseif gameState == 'spec' then
        aiP1 = true
        aiP2 = true
    elseif gameState == 'play' then
        -- detect ball collision with paddles, reversing dx if true and
        -- slightly increasing it, then altering the dy based on the position
        -- at which it collided, then playing a sound effect
        if Ball:collides(player1) then
            Ball.dx = -Ball.dx * 1.1
            Ball.x = player1.x + 5

            -- keep velocity going in the same direction, but randomize it
            if Ball.dy < 0 then
                Ball.dy = -math.random(10, 150)
            else
                Ball.dy = math.random(10, 150)
            end

            sounds['paddle_hit']:play()
        end
        if Ball:collides(player2) then
            Ball.dx = -Ball.dx * 1.03
            Ball.x = player2.x - 4

            -- keep velocity going in the same direction, but randomize it
            if Ball.dy < 0 then
                Ball.dy = -math.random(10, 150)
            else
                Ball.dy = math.random(10, 150)
            end

            sounds['paddle_hit']:play()
        end

        -- detect upper and lower screen boundary collision, playing a sound
        -- effect and reversing dy if true
        if Ball.y <= 0 then
            Ball.y = 0
            Ball.dy = -Ball.dy
            sounds['wall_hit']:play()
        end

        -- -4 to account for the ball's size
        if Ball.y >= VIRTUAL_HEIGHT - 4 then
            Ball.y = VIRTUAL_HEIGHT - 4
            Ball.dy = -Ball.dy
            sounds['wall_hit']:play()
        end

        -- if we reach the left or right edge of the screen, go back to serve
        -- and update the score and serving player
        if Ball.x < 0 then
            servingPlayer = 1
            player2Score = player2Score + 1
            sounds['score']:play()

            -- if we've reached a score of 10, the game is over; set the
            -- state to done so we can show the victory message
            if player2Score == 10 then
                winningPlayer = 2
                gameState = 'done'
            else
                gameState = 'serve'
                -- places the ball in the middle of the screen, no velocity                
                Ball:reset()                
                player1:reset1()
                player2:reset2()
            end
        end

        if Ball.x > VIRTUAL_WIDTH then
            servingPlayer = 2
            player1Score = player1Score + 1
            sounds['score']:play()

            if player1Score == 10 then
                winningPlayer = 1
                gameState = 'done'
            else
                gameState = 'serve'
                Ball:reset()
                player1:reset1()
                player2:reset2()
            end
        end
    end

    --
    -- paddles can move no matter what state we're in
    --
    -- player 1
    if love.keyboard.isDown('w') then
        player1.dy = -PADDLE_SPEED
    elseif love.keyboard.isDown('s') then
        player1.dy = PADDLE_SPEED
    else
        player1.dy = 0
    end

    -- player 2
    if love.keyboard.isDown('up') then
        Paddle.dy = -PADDLE_SPEED
    elseif love.keyboard.isDown('down') then
        Paddle.dy = PADDLE_SPEED
    else
        Paddle.dy = 0
    end

    -- update our ball based on its DX and DY only if we're in play state;
    -- scale the velocity by dt so movement is framerate-independent
    -- the artificial intelligence tries its best to follow up the ball
    if gameState == 'play' then
        Ball:update(dt)
        aiActivate(player1, Ball, aiP1)
        aiActivate(player2, Ball, aiP2)
        -- if aiP2 == true then
        --     if ball.y > player2.y and ball.dy > 0 then
        --         player2.dy = ball.dy+1
        --     elseif ball.y > player2.y and ball.dy < 0 then
        --             player2.dy = ball.dy-1
        --     elseif ball.y == player2.y and ball.dy == 0 then
        --         player2.dy = 0
        --     else player2.dy = -ball.dy-1
        --     end
    end

    player1:update(dt)
    player2:update(dt)
end
--[[
    A callback that processes key strokes as they happen, just the once.
    Does not account for keys that are held down, which is handled by a
    separate function (`love.keyboard.isDown`). Useful for when we want
    things to happen right away, just once, like when we want to quit.
]]
function love.keypressed(key)
    -- `key` will be whatever key this callback detected as pressed
    if key == 'escape' then
        -- the function LÖVE2D uses to quit the application
        love.event.quit()
    -- if we press enter during either the start or serve phase, it should
    -- transition to the next appropriate state
    elseif gameState == 'gamemode' then
        if key == '1' then
                gameState = 'ai'
        elseif key == '2' then
                gameState = '2p'
        elseif key == '3' then
                gameState = 'spec'
        -- elseif gameState == '2p' or 'ai' then
        --     gameState = 'serve'
    end
    elseif key == 'enter' or key == 'return' then
        if gameState == 'start' then
            gameState = 'gamemode'
        elseif gameState == 'ai' or gameState == '2p' or gameState == 'spec' then
            gameState = 'serve'
        elseif gameState == 'serve' then
            gameState = 'play'
        elseif gameState == 'done' then
            -- game is simply in a restart phase here, but will set the serving
            -- player to the opponent of whomever won for fairness!
            gameState = 'serve'

            Ball:reset()            
            player1:reset1()
            Paddle:reset2()
            -- reset scores to 0
            player1Score = 0
            player2Score = 0

            -- decide serving player as the opposite of who won
            if winningPlayer == 1 then
                servingPlayer = 2
            else
                servingPlayer = 1
            end
        end
    end
end

--[[
    Called each frame after update; is responsible simply for
    drawing all of our game objects and more to the screen.
]]
function love.draw()
    -- begin drawing with push, in our virtual resolution
    push:start()

    love.graphics.clear(40/255, 45/255, 52/255, 255/255)
    
    -- render different things depending on which part of the game we're in
    if gameState == 'start' then
        -- UI messages
        love.graphics.setFont(smallFont)
        love.graphics.printf('Bem vindo ao Pong do Senhor Bolhas!', 0, 10, VIRTUAL_WIDTH, 'center')
        love.graphics.printf('Aperte Enter para iniciar!', 0, 20, VIRTUAL_WIDTH, 'center')   
    elseif gameState == 'gamemode' then
        -- UI messages
        love.graphics.setFont(largeFont)
        love.graphics.printf("Aperte 1 para Modo Jogador contra IA", 0, 20, VIRTUAL_WIDTH, 'center')
        love.graphics.printf("Aperte 2 para Modo 2 jogadores", 0, 40, VIRTUAL_WIDTH, 'center')
        love.graphics.printf("Aperte 3 para Modo IA vs IA (espectador)", 0, 60, VIRTUAL_WIDTH, 'center')
    elseif gameState == '2p' then
        -- UI messages
        love.graphics.setFont(largeFont)
        love.graphics.printf("Modo 2 Jogadores", 0, 20, VIRTUAL_WIDTH, 'center') 
    elseif gameState == 'ai' then
        -- UI messages
        love.graphics.setFont(largeFont)
        love.graphics.printf("Modo Jogador contra IA", 0, 20, VIRTUAL_WIDTH, 'center') 
    elseif gameState == 'spec' then
        -- UI messages
        love.graphics.setFont(largeFont)
        love.graphics.printf("Modo IA contra IA", 0, 20, VIRTUAL_WIDTH, 'center') 
    elseif gameState == 'serve' then
        -- UI messages
        love.graphics.setFont(smallFont)
        love.graphics.printf('Jogador ' .. tostring(servingPlayer) .. " saca!", 
            0, 10, VIRTUAL_WIDTH, 'center')
        love.graphics.printf('Aperte enter para sacar!', 0, 20, VIRTUAL_WIDTH, 'center')
    elseif gameState == 'play' then
        -- no UI messages to display in play
    elseif gameState == 'done' then
        -- UI messages
        love.graphics.setFont(largeFont)
        love.graphics.printf('Jogador ' .. tostring(winningPlayer) .. ' venceu!',
            0, 10, VIRTUAL_WIDTH, 'center')
        love.graphics.setFont(smallFont)
        love.graphics.printf('Aperte enter para reiniciar!', 0, 30, VIRTUAL_WIDTH, 'center')
    end

    -- show the score before ball is rendered so it can move over the text
    displayScore()
    
    player1:render()
    player2:render()
    Ball:render()

    -- display FPS for debugging; simply comment out to remove
    displayFPS()

    -- end our drawing to push
    push:finish()
end

--[[
    Simple function for rendering the scores.
]]
function displayScore()
    -- score display
    love.graphics.setFont(scoreFont)
    love.graphics.print(tostring(player1Score), VIRTUAL_WIDTH / 2 - 50,
        VIRTUAL_HEIGHT / 3)
    love.graphics.print(tostring(player2Score), VIRTUAL_WIDTH / 2 + 30,
        VIRTUAL_HEIGHT / 3)
end

--[[
    Renders the current FPS.
]]
function displayFPS()
    -- simple FPS display across all states
    love.graphics.setFont(smallFont)
    love.graphics.setColor(0, 255/255, 0, 255/255)
    love.graphics.print('FPS: ' .. tostring(love.timer.getFPS()), 10, 10)
    love.graphics.setColor(255, 255, 255, 255)
end

--[[
    Function that first check if there is an AI, then control the AI movements based on the ball with a some flaws 
        so it is not impossible to defeat.
]]
function aiActivate(Paddle, Ball, Boolean)
    if Boolean == true then
            if Ball.y > Paddle.y and Ball.dy > 0 then
                Paddle.dy = Ball.dy+1
            elseif Ball.y > Paddle.y and Ball.dy < 0 then
                    Paddle.dy = Ball.dy-1
            elseif Ball.y == Paddle.y and Ball.dy == 0 then
                Paddle.dy = 0
            else Paddle.dy = -Ball.dy-1
            end
    end
end