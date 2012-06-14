require 'pg'
require 'dbi'
require  'peak_finder'
require  'peak_integration'

# Program: peak_main###########################################################
# Author: Nathan DiPiazza
# Company: GLBRC
# Main class for the KBS Greenhouse Gas Peak Project
# Selects a run from the database and finds the peaks and area of those peaks
# for each injection of that run. It then inserts these values into the 
# injections table. 
# A peak growth tolerance can also be set; 
# it is the sixth command line argument; default: 100mV 
# Command line parameters: 
# 0: database name
# 1: username
# 2: password
# 3: gas type
# 4: run_id
# 5: tolerance (OPTIONAL)
#
# Alternatively the program can also read data and find peaks/areas 
# from a peak simple file directly.
# The peak simple filename is entered as the first command line argument.
# A peak growth tolerance can also be set as second command line argument. 
# default: 100mV
###############################################################################

#################### method: write_to_file#####################################
# Creates a csv txt file to be used for testing purposes 
# and manual file processing.
# parameters: peak_s-start of peak, peak_e-end of peak, run_id-id for file
# return: void
###############################################################################
def write_to_file(peak_s, peak_e, areas, run_id)
    output_file = File.new("millivolt#{run_id}.txt", "w")
    # loops putting all data into a comma seperated text file
    for i in 0..(peak_s.size - 1) 
	output_file.print  peak_s[i] 
	output_file.print  ','
	output_file.print  peak_e[i] 
	output_file.print  ','
	output_file.print  areas[i] 
	output_file.puts   ""
    end

end # end write_to method

# GLOBAL VARIABLES:
areas = [] # an array storing all area calculations one injection
peak_s = [] # peak start time
peak_e = [] # peak end time
time = []  # an array that stores all datetimes for one injection
time_array = [] # doesn't need to be array if one peak per injection
run_array = []  # doesn't need to be array if one peak per injection
temp_arr = []   # temp array used to convert mv's to integers
time_mv_array = [] # Used to store all peak data returned by the peak_finder
t = [] # temp array holding time
m = [] # temp array holding millivolt readings
tolerance = 100 # tolerance for the rate of growth of a peak; default is 100
id = 0  #TODO erase after development###################################!!!!!!!!!!!!!!!!!!!!!!
start_time = "" # used in manual peak simple file reading; date parsing
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# These are the arrays that store peak data:                                  #
# areas[], peak_s[], peak_e[]                                                 #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

################################################################################
# Main Block: Automated database peak and area processing code                 #
################################################################################
# Parameter validation
if ARGV.size == 0
    puts "Usage: No command line arguments given. Quitting"
    exit
elsif ARGV.size > 6
    puts "Usage: Too many command line arguments. Quitting"
    exit
elsif ((ARGV.size == 5) || (ARGV.size == 6))
    # if optional tolerance given; set new tolerance
    if ARGV[5].nil? == false
		tolerance = ARGV[5].to_i
	end
	# must be positive
	if tolerance <= 0
		tolerance = 100
	end
    db_name = ARGV[0] # gasflux
    user_name = ARGV[1] # gasflux
    pass = ARGV[2] # g@sf1ux
  
    dbh = DBI.connect("DBI:Pg:#{db_name}", user_name, pass)
    
    gas = ARGV[3] # ecd or fid
    run_id = ARGV[4] # 5864 or any valid id number

    mv_db = dbh.execute("select run_id, chamber, injections.id, sampled_at, array_agg(#{gas}) from  injections join mv  on mv.datetime between injections.sampled_at + interval '1 minute'  and injections.sampled_at + interval '6 minutes'  where #{gas} is not NULL and run_id = #{run_id}  group by run_id, chamber, injections.id, sampled_at  order by sampled_at")
    date_to_time = nil 
    while row = mv_db.fetch do
        # put every injection period in this run into an array
        date_to_time = row[3].to_time
        temp_arr = row[4]
        # for some reason they are strings not doubles
        for i in 0..(temp_arr.size) do
            # entries remain as Time class 
            time[i] = date_to_time + i
            temp_arr[i] = temp_arr[i].to_i
        end
        time_array << time
        run_array  << temp_arr
        
    end # end while row...
    mv_db.finish
    pf = Peak_finder.new
    p_i = Peak_Integration.new # p_i object is used to find the area under peaks

    for i in 0..(run_array.size - 1) do
        # data is placed in array together for method parameter
        data_array = [run_array[i], time_array[i]] 
        # gas will be cool
        # time_mv_array index 0 is the timestamps, index 1 is the mv data. 
        # the indicies of these respective arrays are parallel
        time_mv_array = pf.getPeaks(gas, data_array, tolerance) 
        t = time_mv_array[0]
        m = time_mv_array[1]
        # loops through array of peak millivolt readings 
        # and fills the array areas with the respective area calculations
        for h in 0..(m.size - 1) do
	    # overwriting array a; no longer in use above
	    a = p_i.integrate(m[h]) # get area
	    areas << a # add to array 
        end
        # this loop pulls the start and end times from the data.
        for j in 0..(t.size - 1) do
            s = t[j].first
	    e = t[j].last
	    peak_s << s
	    peak_e << e
        end
        # temp code; will want to insert into db when finalized
        id = i + 1
        write_to_file(peak_s, peak_e, areas, id)
        # reset arrays for the next loop
        areas = []
        peak_s = []
        peak_e = []
        # really at this point areas should have one entry (the area of the one injection peak)
        # there should also only be one entry in peak_s/e arrays too; (one for start/end time)
        # TODO INSERT INTO ##OR## UPDATE ??? injections table in: peak_area, peak_start, and peak_end
        # dbh.do("insert into injections(peak_area, peak_start, peak_end) values (#{areas}, #{peak_s}, #{peak_e})")
        # ??? What key will correspond to the proper injection ???
    end
    puts "data processed successfully!"
    exit # done with program at this point 
 # end if ARGV.size == 5
elsif ((ARGV.size == 1) || (ARGV.size == 2))

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

	pf = Peak_finder.new # this object is used to find peaks 
	# time_mv_array index 0 is the timestamps, index 1 is the mv data. 
	# the indicies of these respective arrays are parallel
	time_mv_array = pf.getPeaks(gas, data_array, tolerance) 
	t = time_mv_array[0]
	m = time_mv_array[1]

	p_i = Peak_Integration.new # p_i object is used to find the area under peaks

	# loops through array of peak millivolt readings 
	# and fills the array areas with the respective area calculations
	for i in 0..(m.size - 1)
		# overwriting array a; no longer in use above
		a = p_i.integrate(m[i]) # get area
		areas << a # add to array 

	end
	# this loop pulls the start and end times from the data.
	for i in 0..(t.size - 1)
		s = t[i].first
		e = t[i].last
		peak_s << s
		peak_e << e
	end
	id = ".csv"
	write_to_file(peak_s, peak_e, areas, id)

	# close the peak simple file
	file.close
else 
    puts "Usage: Wrong number of command line arguments. Quitting."
    exit
end	# end main
