module Peak_Detector_Test (

sourceValid, eop, sop, clk, reset_n, real_sig, img_sig, timeEnd, peak
	
);

input wire sourceValid, clk, reset_n, eop, sop;
input wire signed [31: 0] real_sig, img_sig; // could be -ve or +ve

output reg timeEnd;
output reg [12:0] peak;

reg [31:0] real_abs, img_abs;
reg [12:0] binL, binNum;
reg [32:0] magL, mag;


// Manhattan Magnitude

always@(*)
begin
	begin
		if(real_sig[31] == 1'b1) // negative
		real_abs = -real_sig; // make it positive
		else //positive
		real_abs = real_sig; // keep it the same
		end	
	
		begin
		if(img_sig[31] == 1'b1) // negative
		img_abs = -img_sig; // make it positive
		else //positive
		img_abs = img_sig; // keep it the same
		end	
	
		mag = real_abs + img_abs; // magnitude is the sum (according to the Manhattan Magnitude)

end

// Bin counter

always @(posedge clk or negedge reset_n)
	begin
	if(!reset_n) // resets it to zero
		begin
		binNum <= 13'b0;
		end
	else if(sourceValid) // If the FFT has a valid output
      begin
			if(sop) // If we are at the start go the bin = 0
			binNum <= 13'b0;
			else // if we arent at the start then add 1 to the bin
			binNum <= binNum + 1'b1;
		end
	end
			

// Peak finder

always @(posedge clk or negedge reset_n)
begin
	if(!reset_n) // reset everything to zero
		begin
		binL <= 13'b0;
		magL <= 33'b0;
		timeEnd <= 1'b0;
		peak <= 13'b0;
	   end
	else
		begin	// reset time to 0
timeEnd <= 1'b0;		

if(sourceValid) // If the FFT has a valid output
	begin
		if(sop) // if at the start everything is zero
		begin
		binL <= 13'd0;
		magL <= 33'd0;
		end
	
else if(mag > magL) // if the current magnitude is greater than the highest magnitude we find
		begin
		binL <= binNum; // save the magnitude and the bin number
		magL <= mag;
		end
	end			

if (eop)  // when at the end
	begin
		peak <= binL; // peak is the bin number
		timeEnd <= 1'b1; // timeEnd flag is 1
		end
	end
end
endmodule	
		


	
	
