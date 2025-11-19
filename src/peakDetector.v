module peakDetector(
    CLOCK_50,
    source_sop,
    source_eop,
    source_valid,
    source_ready,
    source_imag,
    source_real,
    k_index,
    frame_done
);

/*********************************************
PARAMETER DECLARATIONS
*********************************************/
//inputs
input CLOCK_50;
input source_sop, source_eop; //communicates with fft
input source_valid, source_ready; //redundancy for frame running

input [31:0] source_imag, source_real;
//outputs

output [13:0] k_index;
output frame_done;

/************************************************
Internal Wires
************************************************/
reg [14:0] maxIndex;
reg [64:0] maxValue;
reg [64:0] currValue;

wire allowed = source_valid & source_ready & ~source_eop;

reg [14:0] count;

//Sequential
always @ (posedge CLOCK_50)
begin
    if(allowed)
    begin   
        // Reset on start of packet
        if(source_sop) 
        begin
            count <= 0;
            maxIndex <= 0;
            maxValue <= 0;
            frame_done <= 0;
        end
        else
        begin
            count <= count + 1;
        end
        
        // Calculate current magnitude squared
        currValue <= source_imag*source_imag + source_real*source_real;
        
        // Compare and update max (using registered currValue from previous cycle)
        if(currValue > maxValue) 
        begin
            maxIndex <= count;
            maxValue <= currValue;
        end
    end
    else if(source_eop && source_valid)
    begin
        // Latch final result at end of packet
        k_index <= maxIndex[13:0];
        frame_done <= 1;
    end
end



                



