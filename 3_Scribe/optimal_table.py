import re

def node_get_all(me_id, inp):
	all_ = []
	for node in inp:
		match = re.search(r'([a-z0-9]*):([a-z0-9\.]*)', node)
		id_ = match.group(1)
		ping = match.group(2)
		if id_ != me_id and len(id_)>0:
			all_.append((id_,ping))
	return all_

def optimal_table(me_id, all_ids):
	# only interested in rows 0-2
	optim_row_0 = optim_entries(cand_entries(me_id, 0, all_ids))
	optim_row_1 = optim_entries(cand_entries(me_id, 1, [(i,p) for (i,p) in all_ids if i[0]==me_id[0]]))
	optim_row_2 = optim_entries(cand_entries(me_id, 2, [(i,p) for (i,p) in all_ids if i[0]==me_id[0] and i[1]==me_id[1]]))
	return [optim_row_0, optim_row_1, optim_row_2]

def cand_entries(me_id, row, cand_set):
	cand_setset = []
	for i in range(10)+["a","b","c","d","e","f"]:
		if str(i) != me_id[row]:
			cand_setset.append([(i_,float(p)) for (i_,p) in cand_set if i_[row]==str(i)])
		else: 
			cand_setset.append([])
	return cand_setset

def optim_entries(cand_set):
	cand_opt = range(16)
	for i in range(16):
		if len(cand_set[i]) > 0:
			# sorts to get the first nearest (by ping time)
			cand_opt[i] = [i_ for (i_,p) in sorted(cand_set[i], key=lambda tup: tup[-1])][0]
		else:
			# no suitable cand for routing table entry
			cand_opt[i] = "-"
	return cand_opt


def main():
	# dictionary for optimal tables where key is string:(nodeID)
	opt_tables = {}

	# with open("churn_10p.log", "r") as log_in:
	with open("nochurn.log", "r") as log_in:
		for line in log_in:
			match1 = re.search(r'(\S*)\s*START: ([a-z0-9]*)', line)
			if match1:
				me_node = match1.group(1)
				me_id = match1.group(2)
				# init dict entry with node, id, empty routing table, current routing table, number of routing tables read
				opt_tables[me_node] = [me_id, range(3), range(9), 0]
			else:
				match2 = re.search(r'(\S*)\s*ALL_PROX:', line)
				if match2:
					me_node = match2.group(1)
					inp = line.split()
					inp = inp[2:len(inp)]
					me_id = opt_tables[me_node][0]
					opt_tables[me_node][1] = optimal_table(me_id, node_get_all(me_id, inp))
				else:
					# found routing table
					match3 = re.search(r'(\S*)\s+(\d):', line)
					if match3:
						me_node = match3.group(1)
						row = int(match3.group(2))
						inp = line.split()
						inp = inp[3:len(inp)]
						opt_tables[me_node][2][row] = inp
						if int(row) == 8:
							# routing table end
							opt_tables[me_node][3] += 1
							if opt_tables[me_node][1] == opt_tables[me_node][2][0:3]:
								print me_node + " first 3 rows of routing table ideal after " + str(opt_tables[me_node][3]) 
							else:
								print me_node + " incorrect after " + str(opt_tables[me_node][3]) 

if __name__ == "__main__":
    main()