set term epslatex font "Helvetica, 10"

# some line types with different colors, you can use them by using line styles in the plot command afterwards (linestyle X)
set style line 1 lt 1 lc rgb "#FF0000" lw 7 # red
set style line 2 lt 1 lc rgb "#00FF00" lw 7 # green
set style line 3 lt 1 lc rgb "#0000FF" lw 7 # blue
set style line 4 lt 1 lc rgb "#000000" lw 7 # black
set style line 5 lt 1 lc rgb "#CD00CD" lw 7 # purple
set style line 7 lt 3 lc rgb "#000000" lw 7 # black, dashed line

set style line 10 pt 4 lc rgb "#00FF00" lw 7 # green squares
set style line 11 lt 8 lc rgb "#FF0000" lw 7 # red triangles
set style line 12 lt 6 lc rgb "#0000FF" lw 7 # blue circles

set output "indegrees.tex"
set title "Node indegree distribution"

# indicates the labels
set xlabel "Indegree"
set ylabel "Number of nodes"

# set the grid on
set grid x,y
set xtics 1

# set the key, options are top/bottom and left/right
set key top right

set style fill transparent solid 0.7 noborder
set boxwidth 0.25 relative

plot "indegrees_blind.txt" u ($1-0.3):($2) w boxes lc rgb"green" title "Blind" #,\
	 "indegrees_healer.txt" u ($1):($2) w boxes lc rgb"red" title "Healer",\
	 "indegrees_swapper.txt" u ($1+0.3):($2) w boxes lc rgb"blue" title "Swapper"