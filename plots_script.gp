set autoscale
set term png
set xlabel 'time from start (s)'

set ylabel 'count'
set output 'result/plots/1.procs_maxthreads.png'
plot 'result/data.out' using 1:2 with lines title 'processes', 'result/data.out' using 1:3 with lines title 'max threads'

set ylabel 'threads'
set output 'result/plots/2.maxthreads_avethreads.png'
plot 'result/data.out' using 1:3 with lines title 'max threads', 'result/data.out' using 1:4 with lines title 'average threads'

set ylabel 'RSS (mb)'
set output 'result/plots/3.sumrss_averss.png'
plot 'result/data.out' using 1:5 with lines title 'sum rss', 'result/data.out' using 1:6 with lines title 'average rss'

set ylabel 'context witches'
set output 'result/plots/4.avevcs_avenvcs.png'
plot 'result/data.out' using 1:7 with lines title 'average vcs', 'result/data.out' using 1:8 with lines title 'average nvcs'