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
f = 5
HTL = 6
buffer_period = 5 -- cycle every 5 seconds
max_time = 120 -- we do not want to run forever ...

-- variables
infected = false
buffered = false
buffered_h = 0

-- rumor mongering framework
function notify(h)
	if infected == false then 
		infected = true 
		log:print(os.date("%X").." ("..job.position..") i_am_infected")
	else
		log:print(os.date("%X").." ("..job.position..") duplicate_received")
	end
	if (buffered == false) or (buffered and ((h-1) > buffered_h)) then
		buffered = true
		buffered_h = h-1
	end
end

function forward()
	if buffered == true and buffered_h > 0 then
		other_nodes = misc.dup(job.nodes())
		for i,n in ipairs(other_nodes) do          -- table of nodes excluding the source
			if n.ip == job.me.ip and n.port == job.me.port then
				table.remove(other_nodes,i)
			end
		end
    destinations = misc.random_pick(other_nodes, f) -- get f random nodes excluding source
    for i,neighbor in ipairs(destinations) do
    	events.thread(function() rpc.acall(neighbor, {"notify", buffered_h}) end)    -- thread the rpc calls: all in loop can be executed at ca. the same time
    end
	end
	buffered = false
end

-- helping functions
function terminator()
	events.sleep(max_time)
	log:print("FINAL: node "..job.position.." "..tostring(infected)) 
	events.exit() 
	os.exit()
end

function main()
  -- init random number generator
  math.randomseed(job.position*os.time())
  -- wait for all nodes to start up (conservative)
  events.sleep(2)
  -- desynchronize the nodes
  local desync_wait = (buffer_period * math.random())
  -- the first node is the source and is infected since the beginning
  if job.position == 1 then
  	log:print("f="..f.." HTL="..HTL)
  	infected = true
    buffered = true -- first node has the message, i.e. something that needs to be propagated
    buffered_h = HTL -- message is instantiated with HTL
    log:print(os.date("%X").." ("..job.position..") i_am_infected")
    desync_wait = 0
  end
  log:print("waiting for "..desync_wait.." to desynchronize")
  events.sleep(desync_wait)  

  -- start rumor mongering
  events.periodic(buffer_period, forward)

  -- this thread will be in charge of killing the node after max_time seconds
  events.thread(terminator)
end  
events.thread(main)  
events.loop()

