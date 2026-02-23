function dbg(...)
  if Config.Debug and Config.Debug.print then
    print('[GS-BlackMarket]', ...)
  end
end

function clamp(n, a, b)
  if n < a then return a end
  if n > b then return b end
  return n
end

function now()
  return os.time(os.date('!*t'))
end

function randBetween(a, b)
  if a >= b then return a end
  return math.random(a, b)
end