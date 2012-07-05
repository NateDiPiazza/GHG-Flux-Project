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
# 3: run_id 
###############################################################################

# GLOBAL VARS:
gas_array = []
run_array = []
ch4_standard = []
n2o_standard = []
co2_standard = []
control_ppm = 0.0
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
# helper method used to evaluate the linear regression
# parameters: an array of standard mv data
# returns: a new line equation for the desired regression
##############################################################################
def get_line(y)
   
   x = Array(1..y.size)
   # generate the linear regressions required to produce the linear equation
   ts = LineFit.new 
   # this method does the work
   ts.setData(x,y)
   #index 0 = y intercept, index 1 = slope
   line_array = ts.coefficients()

end # end get_line


###############################################################################
# this method prints out the linear regression equation for testing
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
if ARGV.size > 4
   puts "Usage: Too many command line arguments. Quitting"
   exit
elsif ARGV.size == 0
   puts "Usage: No command line arguments given. Quitting"
   exit
# pull data from the database
else
 
   db_name = ARGV[0] # gasflux
   user_name = ARGV[1] # gasflux
   pass = ARGV[2] # g@sf1ux 
   run_id = ARGV[3] # example: 5864 

   dbh = DBI.connect("DBI:Pg:#{db_name}", user_name, pass)

   # query that selects areas for ch4 and n2o
   run_db = dbh.execute("SELECT ch4_area, n2o_area, chamber, id FROM injections WHERE run_id = #{run_id} order by sampled_at")
   licor_db = dbh.execute("SELECT co2_ppm, incubation_id FROM licor_samples WHERE run_id = #{run_id}")
   while row = run_db.fetch do
      # x = times, y = area values coordinates for linear regression
      # both gases should have same time
      # ch4 area:     row[0]
      # n2o area:     row[1]
      # chamber:      row[2]
      # injection id: row[3]
      lrow = licor_db.fetch
      if row[0].nil?
         row[0] = 0
         puts "Warning: ch4 peak area not found. Please inspect run data."
      end 
      if row[1].nil?
         row[1] = 0
         puts "Warning: n2o peak area not found. Please inspect run data."
      end 
      if lrow[0].nil?
         lrow[0] = 0
         puts "Warning: co2 peak area not found. Please inspect run data."
      end 
      # if  chamber is standard than keep the values for linear regression
      if row[2] == 'standard'
         ch4_standard << row[0]
         n2o_standard << row[1]
         co2_standard << lrow[0]
      end # end if row[2]
      gas_array = [row[0],row[1],lrow[0],row[2],row[3],lrow[1]]
      run_array << gas_array
   end # end while row =
   run_db.finish
   licor_db.finish
  
   # These will contain the slope and y intercepts for the linear regressions
   ch4_control_mv = get_line(ch4_standard)
   n2o_control_mv = get_line(n2o_standard)
   co2_control_mv = get_line(co2_standard)
   control_array = [ch4_control_mv, n2o_control_mv, co2_control_mv]
   # used for query column name
   sql_name = ["ch4_ppm", "n2o_ppm", "co2_ppm"]
  
   # This query will pull the first (should be most recent) standards from the tank db
   tank_db = dbh.execute("SELECT ch4_ppm, n2o_ppm, co2_ppm FROM tanks limit 1")
   row = tank_db.fetch 
   sample_array = [row[0], row[1], row[2]]
  
   tank_db.finish
  
   # equation: sample.ppm = control.ppm(from tank) * sample.mv(area)/control.mv 
   for i in 0..(run_array.size - 1) do
      injection = run_array[i]
      for j in 0..2 do
         # if zero than injection area not in db
         # control.ppm from tank
         control_ppm = sample_array[j]        
         # sample.mv at time t
         sample_mv = injection[j]
         # control.mv is linregression evaluated at x at time t,
         # call get_y for calibration values
         control_mv = get_y(control_array[j][0], control_array[j][1], i + 1)       
         sample_ppm = (control_ppm * sample_mv)/control_mv
         # The sample concentration then needs to be put into the database.
         # injection index 4 is injection_id and index 5 is incubation_id
         if j == 2 
            dbh.do("UPDATE licor_samples SET sample_ppm = #{sample_ppm} WHERE incubation_id = #{injection[5]}")
         else
            dbh.do("UPDATE injections SET #{sql_name[j]} = #{sample_ppm} WHERE id = #{injection[4]}")
         end # if j == 2 else
      end # end for j
   end # end for i

end # end if,else block
puts "sample concentrations successfully added!"
# end program






