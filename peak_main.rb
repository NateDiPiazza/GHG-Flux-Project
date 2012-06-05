require  'peak_finder'
require  'peak_integration'

# Author: Nathan DiPiazza######################################################
# Company: GLBRC
# Main class for the KBS Greenhouse Gas Peak Project
# Reads in a peak simple file and puts the data into arrays for analysis.
# The peak simple filename is entered as the first command line argument.
# A peak growth tolerance can be set; it is the second command line argument. 
# If left blank program uses the default of 100 mV
# It uses the peak_finder gem to find the peaks and peak start/end times. 
# Also uses the peak_integration gem to calculate area for discovered peaks.
###############################################################################
# These are the arrays that store peak data####################################
# areas[] all area calculations for the peak file                             #
# peak_s[] peak start time                                                    #
# peak_e[] peak end time						      #
# t[] times								      #
# m[] millivolt readings						      #
###############################################################################

tolerance = 100 # tolerance for the rate of growth of a peak; default is 100
# file validation
if ARGV.size == 0
	puts "Usage: No filename entered on command line. Quitting."
	exit
end
if File.exist?(ARGV[0]) == false
	puts "Usage: File " + ARGV[0] + " not found. Quitting."
	exit
end
# reads in the command line argument as a peak simple file name
file = File.open( ARGV[0] ) 
if ARGV[1].nil? == false
	tolerance = ARGV[1].to_i
end
# must be positive
if tolerance <= 0
	tolerance = 100
end
	
a = [] # an array that is used to hold input data for parsing
var = file.gets() # var is temp variable in while loop
# this string appears one line before the data begins;
stop = "<CONTROL FILENAME>=DEFAULT.CON\r\n" 
#  (change if peak simple file ever changes pattern)
c = 0 # loop variable used to find gas type
gas = String.new # variable to hold the gas type

# loop skips past the header of the peak simple file to get to the data needed
while !var.eql?(stop)
	c += 1
	#if var != nil
	#	var.chop!  Only need if escape carriage return charc. removed
	#	puts var
	#end
	var = file.gets()
	if c == 8
		gas = var.delete "<DESCRIPTION>="

                # added for newer verisions of Peak Simple
                if gas.size > 3
                	gas = gas[0..2]
                else
		# chop off \r\n
		gas.chop!
                end
	end
        if c == 18
                var.delete! "<DATE>= "
        	start_date = var.split('-') #index list: 0 is month, 1 is day, 2 is year
                 
        end
        if c == 19
                var.delete! "<TIME>= "
        	start_time = var.split(':') #index list: 0 is month, 1 is day, 2 is year
                # starting_point keeps track of the the first sample time. Add seconds to this to determine entry times of peaks.
                starting_point = Time.new(start_date[2].to_i, start_date[0].to_i, start_date[1].to_i, start_time[0].to_i, start_time[1].to_i, start_time[2].to_i)
                
        end

end # end while !var.eql?(stop)

# variables in this block are used for seperating peak file into ordered arrays
text = String.new
volt = []
time = []
date = String.new
temp_date = []
tmp = []
# this array holds the rate of change from one voltage sample to the next
#diff = [] 
# first entry is zero because the first sample doesn't have a previous sample 
# to compare the change in text is assigned all of peak simple data
#diff[0] = 0  
text = file.gets(nil) 
a = text.split("\r\n")
sum = 0

for i in 0..(a.size - 1)
	tmp = a[i].split(',') # strip off the commas
	tmp.delete_at(0) #deletes the identical millivolt reading;
	# add following if neeeded: subtract form index with standards
        # shaves of min. number for testing 

	volt[i] = (Integer(tmp[0]))
        # starting_point is a time object 
        # adding i adds one second to time sample
        # then it is converted to a string
        raw_time = starting_point + i
 	raw_time = raw_time.to_s
        # shave off uneeded data (-600)
	time[i] = raw_time[0..18]

        # Not needed anymore Peak Simple files eliminated timestamps columns,
        # and these changes should work with all versions if 1 Mhz sample period 
        # changes this will break (Nate DiPiazza GLBRC)
        #########################################################################
        #date = tmp[1] #formatting to match sql timestamp enforcement
        #temp_date = date.split('/') #index list: 0 is month, 1 is day, 2 is year
        
        ## logic to add leading zeroes if needed
        #test = Integer(temp_date[0])
        #if test < 10
        #        temp_date[0] = "0" + temp_date[0]
        #end
        #test = Integer(temp_date[1])
        #if test < 10
        #        temp_date[1] = "0" + temp_date[1]
        #end

        #date = temp_date[2] + "-" + temp_date[0] + "-" + temp_date[1]
        
        #time[i] = date + " "
	#time[i] += tmp[2]
	#########################################################################

	#volt[i] = (Integer(tmp[0])) 
        #date = tmp[1] #formatting to match sql timestamp enforcement
        #temp_date = date.split('/') #index list: 0 is month, 1 is day, 2 is year
        
        # logic to add leading zeroes if needed
        #test = Integer(temp_date[0])
       # if test < 10
       #         temp_date[0] = "0" + temp_date[0]
       # end
       # test = Integer(temp_date[1])
       #if test < 10
       #        temp_date[1] = "0" + temp_date[1]
       #end

        #date = temp_date[2] + "-" + temp_date[0] + "-" + temp_date[1]
        
        #time[i] = date + " "
	#time[i] += tmp[2]
	

end

# data needed to find peaks
# data is placed in array together for method parameter
data_array = [volt, time] 
time_mv_array = [] # Used to store all peak data returned by the peak_finder
pf = Peak_finder.new # this object is used to find peaks 
# time_mv_array index 0 is the timestamps, index 1 is the mv data. 
# the indicies of these respective arrays are parallel
time_mv_array = pf.getPeaks(gas, data_array, tolerance) 
t = [] # temp array holding time
m = [] # temp array holding millivolt readings
t = time_mv_array[0]
m = time_mv_array[1]

areas = [] # an array storing all area calculations for the peak file
p_i = Peak_Integration.new # p_i object is used to find the area under peaks

# loops through array of peak millivolt readings 
# and fills the array areas with those respective area calculations
for i in 0..(m.size - 1)
	# overwriting array a; no longer in use above
	a = p_i.integrate(m[i]) # get area
	areas << a # add to array 

end
peak_s = [] # peak start time
peak_e = [] # peak end time
# this loop pulls the start and end times from the data.
for i in 0..(t.size - 1)
	s = t[i].first
	e = t[i].last
	peak_s << s
	peak_e << e
end

output_file = File.new("millivolt.txt", "w")
# loops putting all data into a comma seperated text file
for i in 0..(peak_s.size - 1) 
	output_file.print  peak_s[i] 
	output_file.print  ','
	output_file.print  peak_e[i] 
	output_file.print  ','
	output_file.print  areas[i] 
	output_file.puts   ""
end
# close the peak simple file
file.close
# end main
