require"splay.base"
--rpc = require"splay.urpc"
-- to use TCP RPC, replace previous by the following line
rpc = require"splay.rpc"

-- addition to allow local run
if not job then
  -- can NOT be required in SPLAY deployments !  
  local utils = require("splay.utils")
  if #arg < 2 then  
    print("lua "..arg[0].." my_position nb_nodes")  
    os.exit()  
  else  
    local pos, total = tonumber(arg[1]), tonumber(arg[2])  
    job = utils.generate_job(pos, total, 20001)  
  end
end

rpc.server(job.me.port)

-- constants
c = 10               -- view size
exch = 5            -- number of peers to be exchanged
H = 3               -- healer parameter
S = 2              -- shuffler parameter
SEL_rand = false     -- partner selection policy: true for "rand" or false for "tail"
exchg_period = 5
max_time = 30      -- we do not want to run forever ...

-- variables
function init_view()
  new_view = {}
  for k,v in ipairs(job.nodes()) do       -- create table of nodes excluding the source
    if not (v.ip == job.me.ip and v.port == job.me.port) then 
      new_view[#new_view+1] = {peer=misc.dup(v),age=0,id=k}
    end
  end
  rnd_view = misc.random_pick(new_view, c)
  return rnd_view
end

view = init_view()

-- Peer Sampling Service functions
-- select exchange partner according to policy (tail/rand)
function selectPartner()
  if SEL_rand then return view[math.random(#view)]
  else
    oldest = misc.dup(view)
    table.sort(oldest, function (x,y) return x.age < y.age end)
    return oldest[#oldest]
  end
end

-- fill own buffered view
function selectToSend()
  toSend = {} 
  toSend[1] = {peer=misc.dup(job.me),age=0,id=job.position}     -- self with age 0
  
  view_sorted = misc.dup(view)
  table.sort(view_sorted, function (x,y) return x.age < y.age end)
  view_shuffles = {}
  view_H = {}
  --view_shuffles_iterator = misc.dup(view_shuffles)
  for k,v in ipairs(view_sorted) do   -- shuffles should only contain first #view-H elements
    if k > (#view-H) then                        -- oldest are placed into view_H
      view_H[#view_H+1] = misc.dup(v)
    else
      view_shuffles[#view_shuffles+1] = misc.dup(v)  -- others into shuffles
    end
  end
  view_shuffles = misc.shuffle(view_shuffles)     -- shuffle (randomness factor)

  for k,v in ipairs(view_shuffles) do       -- take peers from shuffled
    if k < (#view-H) and k < exch then toSend[#toSend+1] = misc.dup(v) end
  end
  for k,v in ipairs(view_H) do              -- take older from view_H, if to be included in exchange (if toSend is still too small)
    if #toSend < exch then toSend[#toSend+1] = misc.dup(v) end
  end
  
  return toSend
end

-- select from received buffer which to keep according to parameters
function selectToKeep(received)
view_iterator = misc.dup(view)
  for k,v in ipairs(received) do   -- append to view
    duplicate = false              -- only add those to view that are not yet there (rmv duplicates) and not self
    for l,w in ipairs(view_iterator) do
      if (w.peer.ip == v.peer.ip and w.peer.port == v.peer.port) then
        duplicate = true
        break
      end
    end
    if duplicate then
      for l,w in ipairs(view) do
        if (w.peer.ip == v.peer.ip and w.peer.port == v.peer.port) then 
          table.remove(view,l)
          duplicate = false
          break
        end
      end
    end
    if job.position ~= v.id then view[#view+1] = misc.dup(v) end
  end

  oldest = misc.dup(view)
  table.sort(oldest, function (x,y) return x.age < y.age end)
  H_oldest = #view - math.min(H,(#view-c))
  for k,v in ipairs(oldest) do   
    if k > H_oldest then         -- remove oldest from view        
      for l,w in ipairs(view) do
        if w.peer.ip == v.peer.ip and w.peer.port == v.peer.port then table.remove(view,l) end
      end
    end
  end

  min = math.min(S,(#view-c))    -- remove S times the first from head of view
  for i=1,min do table.remove(view,1) end

  repeat
    max = math.max(0,#view-c)      -- remove random from view if needed
    for i=1,max do table.remove(view,math.random(#view)) end
  until #view == c
end

function activeThread()
  partner = selectPartner()
  buffer = selectToSend()
  success, received = rpc.acall(partner.peer, {"passiveThread", buffer})
  if success then selectToKeep(received[1])
  else log:print("call failed") end
  for k,v in ipairs(view) do v.age = v.age + 1 end
end

function passiveThread(received)
  buffer = selectToSend()
  selectToKeep(received)
  return buffer
end

-- helping functions
function terminator()
  events.sleep(max_time)
  -- print view at the end before exiting
  output = "VIEW_CONTENT "..job.position
  table.sort(view, function(x,y) return x.id < y.id end)
  for k,v in ipairs(view) do output = output.." "..v.id end
  log:print(output)
  events.exit()
  os.exit()
end

function main()
  -- this thread will be in charge of killing the node after max_time seconds
  events.thread(terminator)
  
  -- init random number generator
  math.randomseed(job.position*os.time())
  -- wait for all nodes to start up (conservative)
  events.sleep(2)
  -- desynchronize the nodes
  local desync_wait = (exchg_period * math.random())
  -- the first node is the source
  if job.position == 1 then desync_wait = 0 end
  log:print("waiting for "..desync_wait.." to desynchronize")
  events.sleep(desync_wait)  
  
  -- start exchanges
  events.periodic(exchg_period, activeThread)
end  

events.thread(main)  
events.loop()

