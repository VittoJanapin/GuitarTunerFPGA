
module compFSM( clk, reset_n, peak, target, tolerance, veryFlatThreshold,
    justFlatThreshold, verySharpThreshold, justSharpThreshold, newDomFreq,
    veryFlat, justFlat, tuned, justSharp, verySharp, state
);


input wire clk, reset_n;
input wire [9:0] peak;
input wire [9:0] target;
input wire [9:0] tolerance;

input wire [9:0] veryFlatThreshold;
input wire [9:0] justFlatThreshold;
input wire [9:0] verySharpThreshold;
input wire [9:0] justSharpThreshold;


input wire newDomFreq; // Tells the FSM that there is a new dominant frequency to take in

output reg veryFlat, justFlat, justSharp, verySharp, tuned;

output reg [2:0] state;

 reg [2:0] currentState, nextState;

// Create the different states
// Using [2:0] to let the board know that I am using a width of three
// Might add in two extra states at a later date
parameter [2:0] VF = 3'd000;
parameter [2:0] JF = 3'd001;
parameter [2:0] T = 3'd010;
parameter [2:0] JS = 3'd011;
parameter [2:0] VS = 3'd100;

wire [9:0] tunedZoneFlat = target - tolerance;
wire [9:0] tunedZoneSharp = target + tolerance;

wire isSharp = (peak > tunedZoneSharp); // if the peak is greater than the tuned zone sharp side then isSharp is true
wire isFlat = (peak < tunedZoneFlat); // if the peak is greater than the tuned zone flat then isSharp is false
wire isTuned = ~(isSharp || isFlat);

reg [9:0] unsignedDiff;

always@(*) // sets undigned difference to be the absolute difference between the two
begin
	if(peak >= target)
		unsignedDiff = peak - target;
	else
		unsignedDiff = target - peak;
end

// now we have bothe the magnitude of the difference and if it is flat or sharp

// We can now check which state the machine will be in. We can create booleans to store this
// The FSM will be veryFlat if isFlat is true and the difference is greater than the very flat threshold value
// The FSM will be in justFlat if isFlat is true and the value is between the veryFLat and justFlat threshold values
// This will then be done for the sharp values

wire isVeryFlat = isFlat && (unsignedDiff >= veryFlatThreshold);
wire isJustFlat = isFlat && (unsignedDiff < veryFlatThreshold) && (unsignedDiff >= justFlatThreshold);

wire isVerySharp = isSharp && (unsignedDiff >= verySharpThreshold);
wire isJustSharp = isSharp && (unsignedDiff < verySharpThreshold) && (unsignedDiff >= justSharpThreshold);

always@(*)
	begin
	nextState = currentState;
	
	if(newDomFreq) // when the peak detector says theres a new frequency
		begin
		
		if(isTuned)  // self explanitory 
		nextState = T;
		
		else if(isVeryFlat)
		nextState = VF;
		
		else if(isJustFlat)
		nextState = JF;

		else if(isJustSharp)
		nextState = JS;

		else if(isVerySharp)
		nextState = VS;	
		end
	end	

	
always @(posedge clk or negedge reset_n)
	begin
	if(!reset_n)
		begin
		currentState <= VF; // Start in veryFlat state
		state <= VF;
		veryFlat <= 1'b1; // very flat = 1
		justFlat <= 1'b0; // the rest = 0
		tuned <= 1'b0;
		justSharp <= 1'b0;
		verySharp <= 1'b0;
		end
		
	else if(newDomFreq)	
		begin
		currentState <= nextState;
		state <= nextState;
		veryFlat <= (nextState == VF);
		justFlat <= (nextState == JF);
		tuned <= (nextState == T);
		justSharp <= (nextState == JS);
		verySharp <= (nextState == VS);	
		end
	end
endmodule	
		
		
// TESTER		

module Test_Comp(CLOCK_50, KEY, SW, LEDR);

    input  wire CLOCK_50;
    input  wire [3:0]  KEY;
    input  wire [9:0]  SW;
    output wire [9:0]  LEDR;


    wire reset_n    = KEY[0]; // key 0 resets the signal
    wire newDomFreq = KEY[1]; // when you press KEY 1 the signal wont change
	 
	 parameter[9:0] TARGET = 10'd82;
    parameter[9:0] TOLERANCE = 10'd5;
    parameter[9:0] JUST_FLAT_THRESH = 10'd10;
    parameter[9:0] VERY_FLAT_THRESH = 10'd20;
    parameter[9:0] JUST_SHARP_THRESH = 10'd10;
    parameter[9:0] VERY_SHARP_THRESH = 10'd20;


	 
    wire [9:0] peak = SW[9:0];

	 
    wire veryFlatFlag, justFlatFlag, tunedFlag, justSharpFlag, verySharpFlag;
    wire [2:0] stateOut;



	compFSM FSM(
	 CLOCK_50, reset_n, peak, TARGET, TOLERANCE, VERY_FLAT_THRESH, JUST_FLAT_THRESH,  
	 VERY_SHARP_THRESH, JUST_SHARP_THRESH, newDomFreq, veryFlatFlag,justFlatFlag,      
    tunedFlag, justSharpFlag, verySharpFlag, stateOut  
);



    assign LEDR[0] = veryFlatFlag | justFlatFlag | tunedFlag | justSharpFlag | verySharpFlag;

    assign LEDR[1] = justFlatFlag | tunedFlag | justSharpFlag | verySharpFlag;

    assign LEDR[2] = tunedFlag | justSharpFlag | verySharpFlag;

    assign LEDR[3] = justSharpFlag | verySharpFlag;

    assign LEDR[4] = verySharpFlag;

    assign LEDR[9:5] = 5'b00000;
endmodule



