# apachebenchploter
apache bench + gnuplot

# Install
Requires apachebench `ab`, and GNU plot `gnuplot` already installed in the system.

This is a simple bash4+ script. Just run it.

# Usage
./loadtest.sh -h

./loadtest.sh -l yahoo 1000 10 https://yahoo.com/

runs 1000 requests, 10 at a time, on yahoo.com and plot the results by request per second.

