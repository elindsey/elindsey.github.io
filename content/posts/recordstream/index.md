---
date: "2022-12-19T00:00:00Z"
title: RecordStream
---

**Note: this post is a historical relic, originally written in 2014.**

This is a tutorial introduction to [RecordStream](https://github.com/benbernard/RecordStream), half-heartedly
adapted from a presentation I gave at SeaGL 2013 some months ago.

Recs is the best ideas of Microsoft's PowerShell applied to the Unix environment.  It's a collection of
scripts for lightweight, ad-hoc data analysis based around a common internal representation.

It's comprised of:

* Input scripts that convert some input data source to newline delimited JSON
* Data processing scripts that work on newline delimited JSON
* Output scripts that convert newline delimited JSON to something pretty (like a table, HTML, gnuplot, etc.)

There are two major advantages over rolling your own data analysis scripts or relying solely on the traditional Unix
utilities: 

1. You spend less time shuffling loosely formatted plaintext from one utility to another
2. Useful data manipulation and output scripts are already written for you

This will be example driven.  You're encouraged to follow along at home.  Try the commands piece by piece, get a feel
for how the different commands are composed and fit together.

We're starting with an access log in roughly common log format:

    > head –1 access.log 
    54.243.31.205 - - [06/Oct/2013 17:10:21 +0000] "GET / HTTP/1.1" 200 3698 "-" "Amazon Route 53 Health Check Service" "0.078"

I'll define a helper for dealing with it in recs.  This is a bit nasty, but it's something we only need to write once
per log format, if at all (check the recs-from* scripts to see if your input format is already covered).

    function recs-fromaccesslog() { 
        recs-frommultire \
            --re 'ip=^(\d+\.\d+\.\d+\.\d+) ' \
            --re 'date=\[([^\]]+)\]' \
            --re 'method,path="(\S+) (\/.*) HTTP' \ 
            --re 'status,bytes=" (\d+) (\d+) "' \
            --re 'ua,latency="([^"]*)" "([^" ]*)"$' \ 
            "$*"
    }

With that done, we can easily shove our access log into recs' internal format (newline delimited JSON records):

    > head -1 access.log | recs-fromaccesslog access.log
    {"ua":"Amazon Route 53 Health Check Service", "bytes":"3698",
    "ip":"54.243.31.205",
    "ate":"06/Oct/2013 17:10:21 +0000", "status":"200",
    "path":"/",
    "method":"GET",
    "latency":"0.078"}

Given this log, we'll try to answer a few simple questions.

## 1. Which of our clients are slow?

Our access log isn't columnar and doesn't have an easily usable delimiter, so parsing fields out is rather annoying.  We
have to arbitrarily choose something that'll work as a delimiter for the fields we're trying to pull out (user agent and
server-side latency), then do some field counting.  The result is none too pretty.

    > head -5 access.log | cut -d'"' -f 6,8
    Amazon Route 53 Health Check Service"0.078
    Amazon Route 53 Health Check Service"0.003
    Amazon Route 53 Health Check Service"0.163
    Amazon Route 53 Health Check Service"0.204
    Amazon Route 53 Health Check Service"0.031

We can sort based on our latency field, it just takes a bit more field counting...

    > head -5 access.log | cut -d'"' -f 6,8 | sort -t'"' -n -k 2
    Amazon Route 53 Health Check Service"0.003
    Amazon Route 53 Health Check Service"0.031
    Amazon Route 53 Health Check Service"0.078
    Amazon Route 53 Health Check Service"0.163
    Amazon Route 53 Health Check Service"0.204

Now we've got the p100 latency, and a collection of worst offenders.

What if we wanted our latency first so it was a bit more readable (and so we didn't have to jump through so many hoops
with sort)?

Cut doesn't do field reordering, so for this we have to jump to Perl/AWK/Ruby/Python (pick your poison).  I'm fond of
Perl.

    > head -5 access.log | perl -lne 'print "$2 $1" if /"([^"]*)" "([^"]*)"$/' | sort -n
    0.003 Amazon Route 53 Health Check Service
    0.031 Amazon Route 53 Health Check Service
    0.078 Amazon Route 53 Health Check Service
    0.163 Amazon Route 53 Health Check Service
    0.204 Amazon Route 53 Health Check Service

The output's much nicer, but that command isn't getting any prettier.

What if we wanted something more complex?  Say, clients by IP and UA, sorted by latency?  Since we don't have a nice
delimiter, we're heading deeper and deeper into the world of regular expressions...

    > head -5 access.log | perl -lne 'print "$3 $2 $1" if /^(\S+) .*" "([^"]*)" "([^"]*)"/' | sort -n
    0.003 Amazon Route 53 Health Check Service 54.241.32.109
    0.031 Amazon Route 53 Health Check Service 54.245.168.45
    0.078 Amazon Route 53 Health Check Service 54.243.31.205
    0.163 Amazon Route 53 Health Check Service 54.228.16.13
    0.204 Amazon Route 53 Health Check Service 54.251.31.173

That's a grossly inefficient regex, but realistically, that's about what I'd manage if I was interactively processing a
log during an event.

If we wanted p90 instead of p100, it'd be a manual process based on line number:

    > wc -l access.log
    13563 access.log
    > echo '0.9 * 13563' | bc
    12206.7
    > cat access.log | perl -lne 'print $1 if /"([^"]*)"$/' | sort -n | head -12206 | tail -1
    0.208

With recs, this is a simple matter of converting our access log to JSON, grouping by user agent, computing arbitrary percentiles, then sorting and printing out.

    > recs-fromaccesslog access.log | recs-collate --key ua --aggregator percs=percmap,'50 100',latency | recs-sort --key percs/100 -r | recs-totable -k percs/100,ua
    percs/100   ua                                                                                                                                                                               
    ---------   ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    29.155      Amazon Route 53 Health Check Service                                                                                                                                             
    1.210       Mozilla/5.0 (iPhone; CPU iPhone OS 7_0_2 like Mac OS X) AppleWebKit/537.51.1 (KHTML, like Gecko) Version/7.0 Mobile/11A501 Safari/9537.53                                        
    0.000       Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 6.1; WOW64; Trident/5.0; SLCC2; .NET CLR 2.0.50727; .NET CLR 3.5.30729; .NET CLR 3.0.30729; Media Center PC 6.0; .NET4.0C; .NET4.0E)
    0.000       -                                                                                                                                                                                
    0.000       Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/30.0.1599.69 Safari/537.36 

Now that our data's in this format, it's much easier to play around and try to get interesting insights.  We don't need to do any new cut'ing, grep'ing, or manual bc - we can just change our grouping parameters.  For example, grouping by both user agent and IP address:

    > recs-fromaccesslog access.log | recs-collate --key ip,ua --aggregator percs=percmap,'50 100',latency | recs-sort --key percs/50,percs/100 -r | recs-totable
    ip                percs                           ua                                                                                                                                                                               
    ---------------   -----------------------------   ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    174.239.197.180   {"50":"0.712","100":"1.210"}    Mozilla/5.0 (iPhone; CPU iPhone OS 7_0_2 like Mac OS X) AppleWebKit/537.51.1 (KHTML, like Gecko) Version/7.0 Mobile/11A501 Safari/9537.53                                        
    54.232.40.109     {"50":"0.223","100":"0.316"}    Amazon Route 53 Health Check Service                                                                                                                                             
    54.232.40.77      {"50":"0.209","100":"0.409"}    Amazon Route 53 Health Check Service                                                                                                                                             
    54.251.31.173     {"50":"0.185","100":"23.189"}   Amazon Route 53 Health Check Service                                                                                                                                             
    54.252.79.141     {"50":"0.184","100":"24.183"}   Amazon Route 53 Health Check Service                                                                                                                                             
    54.251.31.141     {"50":"0.184","100":"0.446"}    Amazon Route 53 Health Check Service                                                                                                                                             
    54.228.16.13      {"50":"0.162","100":"26.193"}   Amazon Route 53 Health Check Service                                                                                                                                             
    54.228.16.45      {"50":"0.159","100":"27.159"}   Amazon Route 53 Health Check Service                                                                                                                                             
    54.252.79.173     {"50":"0.151","100":"29.155"}   Amazon Route 53 Health Check Service                                                                                                                                             
    54.248.220.45     {"50":"0.129","100":"0.274"}    Amazon Route 53 Health Check Service                                                                                                                                             
    54.248.220.13     {"50":"0.121","100":"25.112"}   Amazon Route 53 Health Check Service                                                                                                                                             
    54.243.31.245     {"50":"0.077","100":"0.139"}    Amazon Route 53 Health Check Service                                                                                                                                             
    54.243.31.205     {"50":"0.077","100":"0.085"}    Amazon Route 53 Health Check Service                                                                                                                                             
    162.208.41.4      {"50":"0.032","100":"0.036"}    Mozilla/5.0 (iPhone; CPU iPhone OS 7_0_2 like Mac OS X) AppleWebKit/537.51.1 (KHTML, like Gecko) Version/7.0 Mobile/11A501 Safari/9537.53                                        
    54.245.168.13     {"50":"0.031","100":"0.038"}    Amazon Route 53 Health Check Service                                                                                                                                             
    54.245.168.45     {"50":"0.031","100":"0.037"}    Amazon Route 53 Health Check Service                                                                                                                                             
    54.241.32.77      {"50":"0.004","100":"29.004"}   Amazon Route 53 Health Check Service                                                                                                                                             
    54.241.32.109     {"50":"0.003","100":"0.027"}    Amazon Route 53 Health Check Service                                                                                                                                             
    122.10.92.22      {"50":"0.000","100":"0.000"}    Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 6.1; WOW64; Trident/5.0; SLCC2; .NET CLR 2.0.50727; .NET CLR 3.5.30729; .NET CLR 3.0.30729; Media Center PC 6.0; .NET4.0C; .NET4.0E)
    162.208.41.4      {"50":"0.000","100":"0.000"}    -                                                                                                                                                                                
    162.208.41.4      {"50":"0.000","100":"0.000"}    Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/30.0.1599.69 Safari/537.36  

Or grouping by user agent and URL path:

    > recs-fromaccesslog access.log | recs-collate --key path,ua --aggregator percs=percmap,'50 100',latency | recs-sort --key percs/50,percs/100 -r | recs-totable
    path              percs                            ua                                                                                                                                                                               
    ---------------   ------------------------------   ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    /slowpath         {"50":"26.193","100":"29.155"}   Amazon Route 53 Health Check Service                                                                                                                                             
    /nginx-logo.png   {"50":"0.806","100":"1.210"}     Mozilla/5.0 (iPhone; CPU iPhone OS 7_0_2 like Mac OS X) AppleWebKit/537.51.1 (KHTML, like Gecko) Version/7.0 Mobile/11A501 Safari/9537.53                                        
    /poweredby.png    {"50":"0.712","100":"1.121"}     Mozilla/5.0 (iPhone; CPU iPhone OS 7_0_2 like Mac OS X) AppleWebKit/537.51.1 (KHTML, like Gecko) Version/7.0 Mobile/11A501 Safari/9537.53                                        
    /                 {"50":"0.166","100":"1.160"}     Mozilla/5.0 (iPhone; CPU iPhone OS 7_0_2 like Mac OS X) AppleWebKit/537.51.1 (KHTML, like Gecko) Version/7.0 Mobile/11A501 Safari/9537.53                                        
    /                 {"50":"0.134","100":"0.553"}     Amazon Route 53 Health Check Service                                                                                                                                             
                      {"50":"0.000","100":"0.000"}     Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 6.1; WOW64; Trident/5.0; SLCC2; .NET CLR 2.0.50727; .NET CLR 3.5.30729; .NET CLR 3.0.30729; Media Center PC 6.0; .NET4.0C; .NET4.0E)
                      {"50":"0.000","100":"0.000"}     -                                                                                                                                                                                
    /poweredby.png    {"50":"0.000","100":"0.000"}     Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/30.0.1599.69 Safari/537.36                                                          
    /nginx-logo.png   {"50":"0.000","100":"0.000"}     Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/30.0.1599.69 Safari/537.36                                                          
    /                 {"50":"0.000","100":"0.000"}     Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/30.0.1599.69 Safari/537.36                                                          
    /favicon.ico      {"50":"0.000","100":"0.000"}     Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/30.0.1599.69 Safari/537.36

Moving on to another question... 

## 2. In which time periods did we have bad latency?

We can emit a "good" or "bad" flag for some predefined latency threshold (in this case, 10s).  We also do a bit of clever timestamp matching to group by hour.

    > cat access.log | perl -lne 'print "$1 ",$2 > 10 ? "bad" : "good" if /(\d+\/\S+\/\d+ \d\d):\d\d:.*"([^"]*)"$/' | uniq -c
    1621 06/Oct/2013 17 good
    1726 06/Oct/2013 18 good
    1593 06/Oct/2013 19 good
    1900 06/Oct/2013 20 good
    1903 06/Oct/2013 21 good
    1322 06/Oct/2013 22 good
       2 06/Oct/2013 22 bad
       3 06/Oct/2013 22 good
       1 06/Oct/2013 22 bad
       5 06/Oct/2013 22 good
       1 06/Oct/2013 22 bad
      11 06/Oct/2013 22 good
       1 06/Oct/2013 22 bad
       4 06/Oct/2013 22 good
       1 06/Oct/2013 22 bad
       5 06/Oct/2013 22 good
       1 06/Oct/2013 22 bad
     540 06/Oct/2013 22 good
    1915 06/Oct/2013 23 good
    1008 07/Oct/2013 00 good

With recs we can easily get latency metrics batched by arbitrary time periods:

    > recs-fromaccesslog access.log | recs-normalizetime --key date --threshold '1 hr' --strict | recs-collate -k n_date --aggregator percs=percmap,'50 100',latency | recs-sort -k n_date | recs-xform '{{n_date}} = localtime({{n_date}})' | recs-totable
    n_date                     percs                       
    ------------------------   -----------------------------
    Sun Oct  6 10:00:00 2013   {"50":"0.132","100":"1.210"}
    Sun Oct  6 11:00:00 2013   {"50":"0.135","100":"0.258"}
    Sun Oct  6 12:00:00 2013   {"50":"0.134","100":"0.277"}
    Sun Oct  6 13:00:00 2013   {"50":"0.134","100":"0.351"}
    Sun Oct  6 14:00:00 2013   {"50":"0.134","100":"0.446"}
    Sun Oct  6 15:00:00 2013   {"50":"0.146","100":"29.155"}
    Sun Oct  6 16:00:00 2013   {"50":"0.134","100":"0.274"}
    Sun Oct  6 17:00:00 2013   {"50":"0.134","100":"0.376"}
