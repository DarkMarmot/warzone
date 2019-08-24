
view = {ships={}, missiles={}}
commands = {}
status = {hull=100, energy=100, position = {x=0, y=0}, velocity = {x=0, y=0}, age=0}

function face(angle)
    local cmd = {name="face", param=angle}
    table.insert(commands, cmd)
end

function turn(angle)
    local cmd = {name="turn", param=angle}
    table.insert(commands, cmd)
end

function fire(power)
    local cmd = {name="fire", param=power}
    table.insert(commands, cmd)
end

function thrust(power)
    local cmd = {name="thrust", param=power}
    table.insert(commands, cmd)
end

function cloak(power)
    local cmd = {name="cloak", param=power}
    table.insert(commands, cmd)
end

function scan(power)
    local cmd = {name="scan", param=power}
    table.insert(commands, cmd)
end

function target_nearest()
    local best_distance = 10000
    local best_direction = 0
    for _,v in pairs(view.ships) do
        if v.distance < best_distance then
            best_direction = v.direction
        end
    end
    return best_direction
end