require 'pg'
require 'dbi'
require 'linefit'

# Sample_concentration.rb######################################################
# Author: Nathan DiPiazza
# Company: GLBRC
# Module 4
# This program calculates the sample concentration for a Run.
# 
# Command line parameters: 
# 0: database name
# 1: username
# 2: password
# 3: gas type             might be different than main CHANGE
# 4: run_id 
# 
# Else: 0: filename for a test csv file
###############################################################################

# GLOBAL VARS:
id = []
n2O  = []
cO2  = []
cH4  = []

##############################################################################
# helper method used to find new calibration value of regression
# parameters: y intercept, slope, and x (time)
# returns: a new y value that is on the line
##############################################################################
def get_y(inter, slope, x)
    tmp = slope * x
    y = inter + tmp
    return y
end # end get_y
##############################################################################
# this method parses csv file containing: id,n2o,co2,ch4
# data starts on fifth row of csv file
# Used for testing purposes.
# parameter: csv file of ppm area readings 
# returns: an array containing 4 arrays holding the columns of data
##############################################################################
def parse_csv(file)
 # Skip to the data portion of the file
 for i in 0..4
  temp = file.gets
 end
 text = file.gets(nil) 
 array_data = text.split("\r\n")
 
 # go through and store the data for different gases in seperate arrays
 for i in 0..(array_data.size - 1)
  tmp = array_data[i].split(',') # strip off the commas
  
  id[i]  = tmp[0].to_i
  n2O[i] = tmp[1].to_f
  cO2[i] = tmp[2].to_f
  cH4[i] = tmp[3].to_f
 end
 final_array = id, n2O, cO2, cH4
end # End parse_csv
###############################################################################
# this method prints out the linear regression equation
# parameter: an array containing the slope and y intercept 
# returns: void
###############################################################################
def print_equation(ln_array)
 puts "Linear regression is: "
 lin_reg = ln_array[0].to_s + " + " + ln_array[1].to_s + "x"
 puts lin_reg
end # End print_equation

###############################################################################
# Main Block: 
# Automated database peak and area processing code
###############################################################################
# Parameter validation
if ARGV.size > 5
    puts "Usage: Too many command line arguments. Quitting"
    exit
elsif ARGV.size == 0
    puts "Usage: No command line arguments given. Quitting"
    exit
# If true then filename given; process the file
elsif ARGV.size == 1

    if File.exist?(ARGV[0]) == true
        file = File.open(ARGV[0])
        gas_arrays = parse_csv(file)
    end
# else pull data from the database
else

    db_name = ARGV[0] # gasflux
    user_name = ARGV[1] # gasflux
    pass = ARGV[2] # g@sf1ux 

    dbh = DBI.connect("DBI:Pg:#{db_name}", user_name, pass)
 
    gas = ARGV[3] # ecd or fid
    run_id = ARGV[4] # 5864 or anything

# TODO Write a query that selects areas and their chamber  
# times for one run and for all the available gasses too.
# run_db = dbh.execute("SELECT * FROM injections WHERE run_id = #{some value put here}")
# while row = tank_db.fetch do
    # add code here to get areas and chamber times
    # x = times, y = area values
# end
# run_db.finish

    # This query will pull the first (should be most recent) standards from the tank db
    tank_db = dbh.execute("SELECT * FROM tanks limit 1")
    # Iterates through the selected table and sorts the data into 4 arrays
    while row = tank_db.fetch do
      sid << row[0] # might not need
      sn2O  << row[1]
      scO2  << row[2]
      scH4  << row[3] 
    end
    tank_db.finish
    gas_arrays = sid, sn2O, scO2, scH4

# TODO fix this; should get run areas for regression
# then call get_y for calibration values
# e.g. replace control.mv values
# solve sample.ppm = control.ppm (from tank) * sample.mv (area)/control.mv (see above comment)
# The concentration then needs to be inserted into the database. 
    regr_array = []
    for i in 1..3 do
        x = Array(1..(gas_arrays[i].size))
        y = gas_arrays[i] 
        ts = LineFit.new 
        # this method does the work
        ts.setData(x,y)
        #index 0 = y intercept, index 1 = slope
        line_array = ts.coefficients()
        regr_array << line_array
     end

#dbh.do("insert into injections(peak_concentration) values (addstuffhere...)")
end # end if,elsif,else block


# print all gasses linear equations
print_equation(regr_array[0])
print_equation(regr_array[1])
print_equation(regr_array[2])

# end program






