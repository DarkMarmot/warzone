
view = {ships={}, missiles={}}
commands = {}
status = {hull=100, energy=100, position = {x=0, y=0}, velocity = {x=0, y=0}, stardate=0}

function fire(options)

    local charge = options.charge or 1
    local angle = options.angle or 0
    local duration = options.duration or 1
    local speed = options.speed or 0
    local cmd = {name="fire", charge=charge, angle=angle, duration=duration, speed=speed}
    table.insert(commands, cmd)

end

function thrust(options)

    local power = options.power or 1
    local angle = options.angle or 0
    local cmd = {name="thrust", power=power, angle=angle}
    table.insert(commands, cmd)

end

function cloak(options)

    local power = options.power or 1
    local cmd = {name="cloak", power=power}
    table.insert(commands, cmd)

end

function scan(options)

    local power = options.power or 1
    local cmd = {name="scan", power=power}
    table.insert(commands, cmd)

end