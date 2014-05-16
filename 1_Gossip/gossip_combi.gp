set term epslatex font "Helvetica, 10"

# some line types with different colors, you can use them by using line styles in the plot command afterwards (linestyle X)
set style line 1 lt 1 lc rgb "#FF0000" lw 7 # red
set style line 2 lt 1 lc rgb "#00FF00" lw 7 # green
set style line 3 lt 1 lc rgb "#0000FF" lw 7 # blue
set style line 4 lt 1 lc rgb "#000000" lw 7 # black
set style line 5 lt 1 lc rgb "#CD00CD" lw 7 # purple
set style line 7 lt 3 lc rgb "#000000" lw 7 # black, dashed line
set style line 8 lt 1 lc rgb "#FF6600" lw 7 # orange

set output "gossip_combi.tex"
set title "Notification delay"

# indicates the labels
set xlabel "Time (sec)"
set ylabel "Proportion of notified peers"

# set the grid on
set grid x,y

# set the key, options are top/bottom and left/right
set key bottom right

# indicates the ranges
set yrange [0:] # example of a closed range (points outside will not be displayed)
set xrange [0:] # example of a range closed on one side only, the max will determined automatically

plot "gossip_combi_nodespersec.txt" u ($1):(100*$3) with lines linestyle 4 title "Combined protocols f=2 HTL=3",\
	 "gossip_combi_nodespersec2.txt" u ($1):(100*$3) with lines linestyle 7 title "Combined protocols f=5 HTL=4",\
	 "anti_entropy/anti_entropy_nodespersec.txt" u ($1):(100*$3) with lines linestyle 1 title "Anti-entropy",\
     "rumor_mongering/rumor_mongering_nodespersec.txt" u ($1):(100*$3) with lines linestyle 3 title "Rumor mongering: f=5 HTL=4",\
     "rumor_mongering/rumor_mongering_nodespersec5.txt" u ($1):(100*$3) with lines linestyle 8 title "Rumor mongering: f=2 HTL=3"
