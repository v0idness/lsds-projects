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
c = 8               -- view size
exch = 4            -- number of peers to be exchanged
H = 0               -- healer parameter
S = 0               -- shuffler parameter
SEL_rand = true     -- partner selection policy: true for "rand" or false for "tail"
getPeer_pss = false  -- peer selection function: complete list (false) or pss (true)

f = 2               -- # of neighbors for rumor mongering; if getPeer_pss then c >= f
HTL = 3             -- hops to live
exchg_period = 5
offset_cycles = 6   -- let PSS run for c cycles before dissemination
max_time = 120      -- we do not want to run forever ...

-- variables
infected = false
buffered = false
buffered_h = 0
current_cycle = 0

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

-- anti-entropy framework
-- selectPartner(): return a random peer from job.nodes()
function ae_selectPartner()
  repeat -- make sure that the node calls someone else
    n = math.random(1,#job.nodes())
  until n ~= job.position
  return job.nodes()[n]
  end

-- rumor mongering framework
function notify(h)
  if infected == false then 
    infected = true 
    log:print("i_am_infected rm")
  else log:print("duplicate_received rm")
  end
  if (buffered == false) or (buffered and ((h-1) > buffered_h)) then
    buffered = true
    buffered_h = h-1
  end
end

function forward()
  if buffered and buffered_h > 0 then
    destinations = {}
    if getPeer_pss then                 -- depending on parameter, get f either from view or complete list
      rand_view = misc.random_pick(view, f)
      for k,v in ipairs(rand_view) do
        destinations[#destinations+1] = misc.dup(v.peer)
      end
    else
      other_nodes = misc.dup(job.nodes())
      for i,n in ipairs(other_nodes) do
        if n.ip == job.me.ip and n.port == job.me.port then
          table.remove(other_nodes,i)
        end
      end
      destinations = misc.random_pick(other_nodes, f)
    end
    for i,neighbor in ipairs(destinations) do
      events.thread(function() rpc.acall(neighbor, {"notify", buffered_h}) end)
    end
  end
  buffered = false
end

-- Peer Sampling Service functions
function getPeer()
  if getPeer_pss then return pss_selectPartner()
  else return ae_selectPartner()
  end
end

-- get either a random or the oldest node from the view
function pss_selectPartner()
  if SEL_rand then return view[math.random(#view)].peer
  else
    oldest = misc.dup(view)
    table.sort(oldest, function (x,y) return x.age < y.age end)
    return oldest[#oldest].peer
  end
end

-- selects view buffer according to parameters, returns exchange buffer (PSS) and infection status (AE)
function selectToSend()
  toSend = {} 
  toSend[1] = {peer=misc.dup(job.me),age=0,id=job.position}     -- self with age 0
  
  view_sorted = misc.dup(view)
  table.sort(view_sorted, function (x,y) return x.age < y.age end)
  view_shuffles = misc.dup(view_sorted)
  view_H = {}
  view_shuffles_iterator = misc.dup(view_shuffles)
  for k,v in ipairs(view_shuffles_iterator) do   -- shuffles should only contain first #view-H elements
    if k > (#view-H) then                        -- oldest are placed into view_H
      view_H[#view_H+1] = misc.dup(v)
      view_shuffles[k] = nil
    end
  end
  view_shuffles = misc.shuffle(view_shuffles)     -- shuffle (randomness factor)

  for k,v in ipairs(view_shuffles) do       -- take peers from shuffled
    if k < (#view-H) and k < exch then toSend[#toSend+1] = misc.dup(v) end
  end
  for k,v in ipairs(view_H) do              -- take older from view_H, if to be included in exchange (if toSend is still too small)
    if #toSend < exch then toSend[#toSend+1] = misc.dup(v) end
  end
  
  return toSend, infected
end

-- combines selectToKeep from anti-entropy and PSS
function selectToKeep(received, status)
  if infected == false and status then -- received infection 
    log:print("i_am_infected ae/pss")
    infected = status
  elseif infected then -- already infected
    log:print("duplicate_received ae/pss")
  end

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

-- combines exchange of views (PSS) and anti-entropy message dissemination
function activeThread()
  -- infect first node, start dissemination after offset_cycles
  if job.position == 1 and current_cycle == offset_cycles then 
    infected = true
    buffered = true -- first node has the message, i.e. something that needs to be propagated
    buffered_h = HTL -- message is instantiated with HTL
    log:print("i_am_infected")
  elseif job.position == 1 and current_cycle < offset_cycles then
    log:print("currently in cycle "..current_cycle.."; wait for "..offset_cycles-current_cycle.." to start dissemination")
  end
  partner = getPeer()
  buffer, status = selectToSend()
  success, received = rpc.acall(partner, {"passiveThread", buffer, status})
  x = received[2]
  if success then selectToKeep(received[1], received[2])
  else log:print("call failed") end
  for k,v in ipairs(view) do v.age = v.age + 1 end
  current_cycle = current_cycle + 1
end

function passiveThread(received, status)
  selectToKeep(received, status)
  buffer, status = selectToSend()
  return buffer, status
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
  if job.position == 1 then 
    log:print("f="..f.." HTL="..HTL)
    desync_wait = 0 
  end
  log:print("waiting for "..desync_wait.." to desynchronize")
  events.sleep(desync_wait)  
  
  -- start rumor mongering, ae/pss exchanges; however, no infection/message yet for offset_cycles
  events.periodic(exchg_period, {activeThread, forward})
end  

events.thread(main)  
events.loop()

