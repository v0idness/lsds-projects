require"splay.base"
rpc = require"splay.urpc"
-- to use TCP RPC, replace previous by the following line
--rpc = require"splay.rpc"

rpc.server(job.me.port)

-- constants
anti_entropy_period = 5 -- gossip every 5 seconds
max_time = 120 -- we do not want to run forever ...

-- variables
infected = false
current_cycle = 0

-- gossip framework
-- selectPartner(): return a random peer from job.get_live_nodes()
function selectPartner()
  repeat -- make sure that the node calls someone else
    n = math.random(1,#job.get_live_nodes())
  until n ~= job.position
  return n
end

-- selectToSend(): return infected
function selectToSend()
  return infected
end

-- selectToKeep(received): return infected or received
function selectToKeep(received)
  if infected == false and received then -- received infection 
    log:print("i_am_infected")
    infected = received
    return infected
  elseif infected then return infected     -- already infected
  else return received    -- P and Q not infected
  end
end


-- helping functions
function terminator()
  events.sleep(max_time)
  log:print("FINAL: node "..job.position.." "..tostring(infected)) 
  os.exit()
end

function main()
  -- init random number generator
  math.randomseed(job.position*os.time())
  -- wait for all nodes to start up (conservative)
  events.sleep(2)
  -- desynchronize the nodes
  local desync_wait = (anti_entropy_period * math.random())
  -- the first node is the source and is infected since the beginning
  if job.position == 1 then
    infected = true
    log:print("i_am_infected")
    desync_wait = 0
  end
  log:print("waiting for "..desync_wait.." to desynchronize")
  events.sleep(desync_wait)  

  -- command that starts the periodic gossiping activity
  events.periodic(anti_entropy_period, function()
    local success, res = rpc.acall(job.get_live_nodes()[selectPartner()], {"selectToKeep", selectToSend()})
    if success then selectToKeep(res[1])
    else log:print("call failed") end
    current_cycle = current_cycle+1
  end)

  -- this thread will be in charge of killing the node after max_time seconds
  -- need to start the thread before going into infinite loop
  events.thread(terminator)
end  

events.thread(main)  
events.loop()

