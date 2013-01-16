class LinearPeakFinder < PeakFinder

  # This method calls peak_finder_fid to find peaks using the modified
  # peak finder algorithm. It is only used to find methane peaks.
  # returns: an array of hashes [{:mv => millivolts, :datetime => times},...,{}]
  # of peak mvs and corresponding datetimes
  def find_fid_peak
    volt = injection.fid_with_time
    unless volt.empty?
      unless volt[0][:mv].nil?
        peak_finder_fid(volt)
      end
    end
  end

  # This method calls peak_finder_ecd to find peaks using the modified
  # peak finder algorithm. It is only used for nitrous oxide peaks.
  # returns: an array of hashes [{:mv => millivolts, :datetime => times},...,{}]
  # of peak mvs and corresponding datetimes
  def find_ecd_peak
    volt = injection.ecd_with_time
    unless volt.empty?
      unless volt[0][:mv].nil?
        peak_finder_ecd(volt)
      end
    end
  end

  # # # # # # # # # # # # Method: peak_finder_fid # # # # # # # # # # # # # # # # # # # 
  # This method is the callee of find_fid_peaks2. It uses numerical differentiation
  # to find the peak beginning. This value becomes a baseline, and is used to 
  # locate the end of the desired peak. The variable trend is used to ignore irrelevant 
  # oscillations that may occur during the peak.
  # (Three consecutive negative slopes constitute a trend)
  # Note: The value of 500 has been hardcoded, as it seems
  # to be effective. This value can be set manually if necessary. NWD
  # param volt-an array of hashes such as:
  # [{:mv=>millivolt,:datetime=>time},...{}] for the injection period
  # return peak_array[0]-an array of hashes such as:
  # [{:mv=>millivolt,:datetime=>time},...{}] for the peak
  #####################################################################################
  def peak_finder_fid(volt)
    diff = []
    peak_array = []
    peak_found = false # is true when desired CH4 peak is found
	  peak_dec = false   # is true when the peak slope begins decreasing
    trend = 0
    # an array of hashes
    for i in 1..(volt.size - 1)
      diff[i] = volt[i][:mv] - volt[i-1][:mv]
      # looking for a rate of change of > 500, which typifies a peak beginning
			if ((diff[i] > 500) and (peak_found == false))
				vs = i - 1
				base = volt[vs][:mv]
				peak_found = true	
			end
      # if a peak has been found, then start looking for its descent
			if ((peak_found == true) and (diff[i] < 0)) 
				# want to ignore trends to find real descent
        if (trend < 2) 
					trend = trend + 1
				else
				  # a trend has been established; peak is decreasing
					peak_dec = true
				end			
			# want to find a trend of three dec. slopes in a row; else reset trend count to zero
			elsif  ((peak_found == true) and (diff[i] > 0)) 
				trend = 0 #reset trend
			end
			# if true than the peak end has been established
			if ((peak_dec == true) and (volt[i-1][:mv] <= base))
				# We have found the desired peak end point	
				ve = i - 1
        temp_peak = volt[vs..ve] # put peak interval into a new array
        peak_array << temp_peak  
        # reset booleans to check for more peaks
				peak_found = false
				peak_dec = false
			end # if dip below base volt
    end # end big for loop
    # If more than one peak found, inform user.
    if (peak_array.size > 1)
      puts "More than one peak found."
    end
    return peak_array.first # there should only be one peak per injection
  end # end method fid
  
  # # # # # # # # # # # # Method: peak_finding_fid # # # # # # # # # # # # # # # # # # # 
  # This method uses numerical differentiation to find the peak beginning. 
  # This value becomes a baseline, and is used to 
  # locate the end of the desired peak. The variable trend is used to ignore irrelevant 
  # oscillations that may occur during the peak.
  # This method differs from peak_finder_fid() in that it looks for a small-peak to
  # precede the peak of interest. This small-peak is part of the peak of interest and
  # the algorithm looks for signs of small peak and uses small-peak's starting point to 
  # set the baseline later when the start of the real peak is found NWD
  # (Three consecutive negative slopes constitute a trend)
  # Note: The values of 500 and 100 have been hardcoded, as it seems
  # to be effective. This values can be set manually if necessary. NWD
  # param volt-an array of hashes such as:
  # [{:mv=>millivolt,:datetime=>time},...{}] for the injection period
  # return peak_array[0]-an array of hashes such as:
  # [{:mv=>millivolt,:datetime=>time},...{}] for the peak
  #####################################################################################
  def peak_finding_fid(volt)
    diff = []
    peak_array = []
    peak_found = false # is true when desired CH4 peak is found
	  peak_dec = false   # is true when the peak slope begins decreasing
    trend = 0
    small_base = 0
    small_found = false
    small_index = -1
    for i in 1..(volt.size - 1)
      volt0 = volt[i-1][:mv]
      volt1 = volt[i][:mv]
      diff[i] = (volt1 - volt0)
      # looking for a small-peak
      if ((diff[i] > 100) and (diff[i] <= 500) and (peak_found == false) and (small_found == false))
        small_index = i
        small_found = true
      end
      # looking for a rate of change of > 500, which typifies a peak beginning
      if ((diff[i] > 500) and (peak_found == false))
        vs = i - 1
        # if small-peak found set peak start to base mv value
        if(small_found == true)
          volt[vs][:mv] = volt[small_index][:mv]
        end
        base = volt[vs][:mv]        
        peak_found = true   
      end
      # if a peak has been found, then start looking for its descent
      if ((peak_found == true) and (diff[i] < 0)) 
        # want to ignore trends to find real descent
        if (trend < 2) 
          trend = trend + 1
		    else
		      # a trend has been established; peak is decreasing
		      peak_dec = true
		    end			
			# want to find a trend of three dec. slopes in a row; else reset trend count to zero
			elsif  ((peak_found == true) and (diff[i] > 0)) 
			  trend = 0 #reset trend
			end
      # if true than the peak end has been established
      if ((peak_dec == true) and (volt[i-1][:mv] <= base))
        # We have found the desired peak end point
        ve = i - 1
        temp_peak = volt[vs..ve]
        peak_array << temp_peak
        # reset booleans to check for more peaks
	      peak_found = false
        peak_dec = false
      end # end below base check
    end # end big for loop
    # If more than one peak found, inform user.
    if (peak_array.size > 1)
      puts "More than one peak found."
    end
    return peak_array.first # there should only be one peak per injection
  end # end method peak_finding_fid

  # # # # # # # # # # # # Method: peak_finder_ecd # # # # # # # # # # # # # # # # # # # 
  # This method is the callee of find_ecd_peaks2. It uses numerical differentiation
  # to find the beginning of a peak. This value becomes a baseline, and is used to 
  # locate the end of the desired peak.
  # Note: The values of 10000 and 3000 have currently been hardcoded, as they seem
  # to be effective. These values can be set manually if necessary. NWD
  # param volt-an array of hashes such as:
  # [{:mv=>millivolt,:datetime=>time},...{}] for the injection period
  # return peak_array[0]-an array of hashes such as:
  # [{:mv=>millivolt,:datetime=>time},...{}] for the peak
  #####################################################################################
  def peak_finder_ecd(volt)
    diff = []
    peak_array = []
    peak_found = false # is true when desired N20 peak is found
	 peak_dec = false # is true when desired N20 peak descends
    big_peak = false # is true when start of big peak is found
	 big_peak_decrease = false # is true when big peak slope begins decreasing
	 trend = 0
    # an array of hashes
    for i in 1..(volt.size - 1)
        diff[i] = volt[i][:mv] - volt[i-1][:mv]
        # looking for a rate of change of > 10000, which typifies a peak beginning
				if ((diff[i] > 10000) and (big_peak == false) and (peak_found == false))
				  big_peak = true
			  end
			  # if the big peak has been found, then start looking for its descent
			  if ((big_peak == true) and (diff[i] < 0))
				  # want to ignore trends to find real descent
              if (trend < 2) 
                 trend = trend + 1
				  else
				    # a trend has been established; big peak is decreasing
					  big_peak_decrease = true
				  end	
				# want to find a trend of three dec. slopes in a row; else reset trend count to zero
			  elsif ((big_peak == true) and (diff[i] > 0))
              trend = 0 # reset trend
		  	  end
			  # The big peak declination has been found.
				# When it increases we know that the desired peak has been found.
        # The value of 3000 is used to ignore insignificant fluxuations
				if ((big_peak_decrease == true) and (diff[i] > 3000) and (peak_found == false)) 
					# We have found the desired peak start point
					vs = i - 1
					base = volt[vs][:mv] # set baseline to find peak end
					peak_found = true
				end
			  # when the peak starts decreasing we must start looking for the end of the peak
				if ((peak_found == true) and (diff[i] < 0))
					peak_dec = true
				end
			   # if true than peak has bottomed out
				if ((peak_dec == true) and (volt[i-1][:mv] <= base)) 
					ve = i - 1 # We have found the desired peak end point
					temp_peak = volt[vs..ve] # put peak interval into a new array
				  peak_array << temp_peak
				  # reset all booleans; begin the search for the next peak pair
					big_peak = false
					big_peak_decrease = false
					peak_dec = false
					peak_found = false
				end # end if below base
    end # end volt loop
			# If more than one peak found, inform user.
			if (peak_array.size > 1)
        puts "More than one peak found."
      end
      return peak_array.first # there should only be one peak per injection
	end # end method ecd
	
	# # # # # # # # # # # # Method: peak_finding_ecd # # # # # # # # # # # # # # # # # # # 
  # This method uses numerical differentiation to find the peak beginning. 
  # This value becomes a baseline, and is used to 
  # locate the end of the desired peak.
  # This method differs from peak_finder_ecd() in that the algorithm has been modified
  # to deal with two special cases: 1) peaks with tails
  # (that do not dip below base in a timely fashion), and 2) smaller "false" peaks
  # (there is a small mv increase that precedes the peak of interest). When looking for
  # the peak's end, the slope is also checked. If slope greater than -500 (after min peak size 20), truncate peak.
  # In the case of false peaks, the second peak is returned.
  # Note: The values of 10000, 3000, -500, and 20 have currently been hardcoded, as they seem
  # to be effective. These values can be set manually if necessary. NWD
  # param volt-an array of hashes such as:
  # [{:mv=>millivolt,:datetime=>time},...{}] for the injection period
  # return peak_array[0]-an array of hashes such as:
  # [{:mv=>millivolt,:datetime=>time},...{}] for the peak
	#####################################################################################
  def peak_finding_ecd(volt)
    diff = []
    peak_array = []
    peak_found = false # is true when desired N20 peak is found
	  peak_dec = false # is true when desired N20 peak descends
    big_peak = false # is true when start of big peak is found
	  big_peak_decrease = false # is true when big peak slope begins decreasing
	  trend = 0
    for i in 1..(volt.size - 1)
      volt0 = volt[i-1][:mv]
      volt1 = volt[i][:mv]
      diff[i] = (volt1 - volt0)
      # looking for a rate of change of > 10000, which typifies a peak beginning
		  if ((diff[i] > 10000) and (big_peak == false) and (peak_found == false))
		    big_peak = true
	    end
	    # if the big peak has been found, then start looking for its descent
	    if ((big_peak == true) and (diff[i] < 0))
		    # want to ignore trends to find real descent
        if (trend < 2) 
          trend = trend + 1
		    else
		      # a trend has been established; big peak is decreasing
			    big_peak_decrease = true
		    end	
      # want to find a trend of three dec. slopes in a row; else reset trend count to zero
	    elsif ((big_peak == true) and (diff[i] > 0))
       trend = 0 # reset trend
  	  end
	    # The big peak declination has been found.
	    # When it increases we know that the desired peak has been found.
	    # The value of 3000 is used to ignore insignificant fluxuations
	    if ((big_peak_decrease == true) and (diff[i] > 3000) and (peak_found == false)) 
        # We have found the desired peak start point
        vs = i - 1
        base = volt[vs][:mv] # set baseline to find peak end
        peak_found = true
      end
	    # when the peak starts decreasing we must start looking for the end of the peak
	    if ((peak_found == true) and (diff[i] < 0))
	      peak_dec = true
	    end
	    # if true than peak has bottomed out
			#added OR part to account for peaks slow to pass baseline 
			if (  (peak_dec == true) and ( (volt[i-1][:mv] <= base) or ((diff[i] > -500) and (i-vs > 20)) )  )
	      ve = i - 1 # We have found the desired peak end point
	      temp_peak = volt[vs..ve] # put peak interval into a new array
	      peak_array << temp_peak
	      # reset all booleans; begin the search for the next peak pair
	      peak_found = false 
        peak_dec = false
        #only reset the big peak booleans so we can try to find a second peak 
        #big_peak = false
        #big_peak_decrease = false 
	    end #end if below base
	  end # end volt loop
		# If more than one peak is found, the second is the real peak.
		if (peak_array.size > 1)
      puts "More than one peak found."
      return peak_array[1]
    end
    return peak_array.first # there should only be one peak per injection
	end # end method peak_finding_ecd
	
	

end
