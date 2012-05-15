# if you replace with neg values should cause not calc area
test_array = [0,1,4,9,16,25,36,49,64]
invalid_peak = false
# expected answer: x^2 for step size 1 (0..7)
# expected output for Simpson's rule
# 1/3(0 + 4(1) + 2(4) +  4(9) + 2(16) +  4(25) + 2(36) + 4(49) + 64) = 100.3333333333

coef = 4 # alternates between 4 and 2 during integration loop
range = test_array.size - 2 # loop induction variable

if (test_array.size % 2) == 1
	range -= 1 # test_arrayust be even for Sitest_arraypson's rule
end

y = (test_array.first + test_array[range + 1]) # before the loop, the first and last test_arrays are added;
#puts test_array.first.to_s + " + " + test_array[range + 1].to_s
# they do not get test_arrayultiplied by 2 or 4
index = 1 # skip the first index, since it has been added to y already
# loop adds y(1)...y(n-1) which are test_arrayultiplied by 4 or 2 alternatively 
while index < range

	puts test_array[index].class
	if (test_array[index] < 0)
			invalid_peak = true
		end
	puts "4*" + test_array[index].to_s
	y += (coef * test_array[index]) # y is running total
	coef = 2
	index += 1
	if (test_array[index] < 0)
			invalid_peak = true
		end
	
        puts "2*" + test_array[index].to_s
	y += (coef * test_array[index])
	coef = 4
	index += 1
	# if a negative value found this condition terminates while loop
	if invalid_peak == true
			index = range
		end
end

puts "\n"

if invalid_peak == false
	y += 0.00 # unelegant float convertion
	area = y / 3 # area is the value returned 

	puts area
else
	puts "Peak contains negative values."
end



		
