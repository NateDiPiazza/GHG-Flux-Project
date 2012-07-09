require 'pg'
require 'dbi'


# Flux.rb#####################################################################
# Author: Nathan DiPiazza
# Company: GLBRC
# Module 5
#
# This program calculates the flux for each injection of an 
# entire run(for ch4, n2o, and co2),using the concentrations 
# produced by module 4. The data is then entered into the 
# incubations datatable.
# 
# Command line parameters: 
# 0: database name
# 1: username
# 2: password
# 3: run_id 
#TODO if needed at params for 'b' and 'c'
##############################################################################

# Global Variables############################################################
ch4_flux = [] # hold ch4 ppms    from injections
n2o_flux = [] # hold n20 ppms    from injections
co2_flux = [] # hold sample ppms from licor_samples
times = []    # sampled_at times
ids = []      # primary key to update data table
##############################################################################

db_name = ARGV[0] # gasflux
user_name = ARGV[1] # gasflux
pass = ARGV[2] # g@sf1ux
run_id = ARGV[3] # 5864 or anything

dbh = DBI.connect("DBI:Pg:#{db_name}", user_name, pass)

# select concentrations and injection times from db for one run
flux_db = dbh.execute("SELECT injections.ch4_ppm, injections.n2o_ppm, incubations.sample_ppm, injections.sampled_at, incubations.id FROM injections JOIN incubations ON injections.id = incubations.id WHERE injections.run_id = #{run_id}")

while row = flux_db.fetch do
    ch4_flux << row[0]
    n2o_flux << row[1]
    co2_flux << row[2]
    times    << row[3]
    ids      << row[4]
end
run_array = [ch4_flux, n2o_flux, co2_flux, times, ids]
# loop through updating all incubations with flux values
for j in 0..(run_array.size - 1) do
   # apply formula to get flux
   a = 0 # slope in ppm/min
   b = 0 # headspace volumeof the container (Liters)
   c = 0 # molecular weight
   # loop to handle the three gases
   for i in 0..2 do
      # selects the current gas
      if i == 0
         gas_type = 'ch4_flux'
         a = run_array[j][0]
      elsif i == 1
         gas_type = 'n2o_flux'
         a = run_array[j][1]
      else
         gas_type = 'co2_flux'
         a = run_array[j][2]
      end
      # Chamber time
      t = run_array[i][3]
      # incubation id
      i_id = run_array[i][4]	
      # formula to convert ppm/min to grams of compound per hectare per day
      f = a * b * (1/745) * 10000 * 10000 * 60 * 24 * (1/22.4) * c * (1/1000) * (1/1000)
      # Update the incubations data table
      dbh.do("UPDATE incubations SET #{gas_type} = #{f}, #{sample_time} = #{t} WHERE id = #{i_id} )")

   end # for i
end # end j
