module Project (
	// Inputs
	CLOCK_50,
	SW,
	KEY,

	AUD_ADCDAT,

	// Bidirectionals
	AUD_BCLK,
	AUD_ADCLRCK,
	AUD_DACLRCK,

	FPGA_I2C_SDAT,

	// Outputs
	AUD_XCK,
	AUD_DACDAT,

	FPGA_I2C_SCLK,
    LEDR
);

/*****************************************************************************
 *                           Parameter Declarations                          *
 *****************************************************************************/


/*****************************************************************************
 *                             Port Declarations                             *
 *****************************************************************************/
// Inputs
input				CLOCK_50;
input		[3:0]	KEY;
input		[3:0]	SW;
output       [9:0]   LEDR;

input				AUD_ADCDAT;

// Bidirectionals
inout				AUD_BCLK;
inout				AUD_ADCLRCK;
inout				AUD_DACLRCK;

inout				FPGA_I2C_SDAT;

// Outputs
output				AUD_XCK;
output				AUD_DACDAT;

output				FPGA_I2C_SCLK;

/*****************************************************************************
 *                 Internal Wires and Registers Declarations                 *
 *****************************************************************************/
// Internal Wires
wire				audio_in_available;
wire		[31:0]	left_channel_audio_in;
wire		[31:0]	right_channel_audio_in;
wire				read_audio_in;

wire				audio_out_allowed;
wire		[31:0]	left_channel_audio_out;
wire		[31:0]	right_channel_audio_out;
wire				write_audio_out;

/*******************************************************************************

Audio Controller Interfacing

********************************************************************************/

assign read_audio_in			= audio_in_available; //will set a flag for the audio module to read audio in if theres available signals
assign write_audio_out			= audio_in_available & audio_out_allowed & SW[0]; //set flag to allow outputting

assign left_channel_audio_out	= left_channel_audio_in << amplification;
assign right_channel_audio_out	= right_channel_audio_in << amplification;

/*******************************************************************************

Amplification uses 3-bit specifications, 
Bit shift left by n bits (each level is a power of 2 more)

********************************************************************************/
wire [2:0] amplification;
assign amplification = SW[3:1];

/*******************************************************************************

Signal Strength Detector, This will display how much amplitude there is
This follows the decibel scale
max is 2^31-1 and min is obviously 0
divide that into ten and account for the logarithmic pattern
each bin is calculated by 10^(18.66n/20)
We evaluate the highest amplitude first

********************************************************************************/
wire	[30:0] abs_sample;
assign abs_sample = left_channel_audio_out[31] ? -left_channel_audio_out[30:0] : left_channel_audio_out[30:0];
reg     [9:0]   amplitude;
always @ (*)
begin
	amplitude = 10'b0;
    if(abs_sample > 31'd2137962000) //MAX
        amplitude = 10'b1111111111;
    else if(abs_sample > 31'd249459500)
        amplitude = 10'b0111111111;
    else if(abs_sample > 31'd29107170)
        amplitude = 10'b0011111111;
    else if(abs_sample > 31'd3396253)
        amplitude = 10'b0001111111;
    else if(abs_sample > 31'd396278)
        amplitude = 10'b0000111111;
    else if(abs_sample > 31'd46238)
        amplitude = 10'b0000011111;
    else if(abs_sample > 31'd5395)
        amplitude = 10'b0000001111;
    else if(abs_sample > 31'd629)
        amplitude = 10'b0000000111;
    else if(abs_sample > 31'd73)
        amplitude = 10'b0000000011;
    else if(abs_sample > 31'd8)
        amplitude = 10'b0000000001;
    else
        amplitude = 10'b0000000000;
end

assign LEDR[9:0] = amplitude;
/*****************************************************************************
 *                              Internal Modules                             *
 *****************************************************************************/

Audio_Controller Audio_Controller (
	// Inputs
	.CLOCK_50					(CLOCK_50),
	.reset						(~KEY[0]),

	.clear_audio_in_memory		(),
	.read_audio_in				(read_audio_in),
	
	.clear_audio_out_memory		(),
	.left_channel_audio_out		(left_channel_audio_out),
	.right_channel_audio_out	(right_channel_audio_out),
	.write_audio_out			(write_audio_out),

	.AUD_ADCDAT					(AUD_ADCDAT),

	// Bidirectionals
	.AUD_BCLK					(AUD_BCLK),
	.AUD_ADCLRCK				(AUD_ADCLRCK),
	.AUD_DACLRCK				(AUD_DACLRCK),


	// Outputs
	.audio_in_available			(audio_in_available),
	.left_channel_audio_in		(left_channel_audio_in),
	.right_channel_audio_in		(right_channel_audio_in),

	.audio_out_allowed			(audio_out_allowed),

	.AUD_XCK					(AUD_XCK),
	.AUD_DACDAT					(AUD_DACDAT)

);

avconf #(.USE_MIC_INPUT(0)) avc (
	.FPGA_I2C_SCLK					(FPGA_I2C_SCLK),
	.FPGA_I2C_SDAT					(FPGA_I2C_SDAT),
	.CLOCK_50					(CLOCK_50),
	.reset						(~KEY[0])
);


/**********************************************

TunerFFT FFT1 (

	.clk							(CLOCK_50),
	.reset_n						(~KEY[0]),
	
	//time domain
	.sink_valid   (sink_valid),   //   sink.sink_valid
	.sink_ready   (sink_ready),   //       .sink_ready	
	.sink_error   (sink_error),   //       .sink_error
	.sink_sop     (sink_sop),     //       .sink_sop
	.sink_eop     (sink_eop),     //       .sink_eop
	.sink_real    (sink_real),    //       .sink_real
	.sink_imag    (sink_imag),    //       .sink_imag
	.fftpts_in    (fftpts_in),    //       .fftpts_in
	
	//frequency domain
	.source_valid (source_valid), // source.source_valid
	.source_ready (source_ready), //       .source_ready
	.source_error (source_error), //       .source_error
	.source_sop   (source_sop),   //       .source_sop
	.source_eop   (source_eop),   //       .source_eop
	.source_real  (source_real),  //       .source_real
	.source_imag  (source_imag),  //       .source_imag
	.fftpts_out   (fftpts_out)    //       .fftpts_out
);

*************/


/*****************************************************************************
 *                              Controlling Variables                        *
 *****************************************************************************/
//writing clocked in at 48K
wire wrfull, wrempty, wrclk;
reg wrreq;

assign wrclk = AUD_ADCLRCK; //set to whatever preconfigure sampling rate


//reading clocked in at 50M
wire rdempty, rdfull, rdclk;
reg rdreq;
assign rdclk = CLOCK_50; //this is the same clock feeding into the fft
//general stuff
wire aclr;
wire [31:0] audio_in, audio_out;

assign audio_in = left_channel_audio_in;
assign 

/*****************************************************************************
 *                              FIFO READ CONTROL                            *
 *****************************************************************************/

//lets do states
reg [2:0] write_state, next_write_state;

parameter WAIT_AUDIO_DATA = 3'b0, IS_FULL = 3'b001, WRITE_REQUEST = 3'b010, FILLING = 3'b011, FULL = 3'b100;

//cct a

always @ (*)
    begin
        case(write_state)
        WAIT_AUDIO_DATA: if(audio_in_available) write_next_state = IS_FULL;
        IS_FULL: if(!wrfull) write_next_state = WRITE_REQUEST; else write_next_state = IS_FULL;
        WRITE_REQUEST: write_next_state = FILLING
        FILLING: if(wrfull) write_next_state = FULL; else write_next_state = FILLING;
        FULL: if(wrempty) write_next_state = IS_FULL; else write_next_state = FULL;
        default: next_write_state = WAIT_AUDIO_DATA;
        endcase
    end

//flip flop

always @ (posedge AUD_ADCLRCK) 
    begin
        if(!KEY[0])
            write_state <= WAIT_AUDIO_DATA;
        else
            write_state <= next_write_state;
    end

//based on the current state what are the outputs
always @ (*)
    begin
        case (write_state)
            WAIT_AUDIO_DATA: wrreq = 0;
            IS_FULL: wrreq = 0;
            WRITE_REQUEST: wrreq = 1;
            FILLING: wrreq = 1;
            FULL: wrreq = 0;
            default: wrreq = 0;
        endcase 
    end

/*****************************************************************************
 *                              FIFO WRITE CONTROL                            *
 *****************************************************************************/

reg [1:0] read_state, next_read_state;

Parameter WAIT = 2'b0, READ_REQUEST = 2'b01, EMPTYING = 2'b10, EMPTY = 2'b11;

always @ (*)
    begin
        case (read_state)
            WAIT: if(rdfull) next_read_state = READ_REQUEST; else next_read_state = WAIT;
            READ_REQUEST: next_read_state = EMPTYING;
            EMPTYING: if(rdempty) next_read_state = EMPTY; else next_read_state = EMPTYING;
            EMPTY: next_read_state = WAIT;
        endcase
    end

always @ (posedge CLOCK_50) 
    begin
        if(!KEY[0])
            next_read_state = WAIT;
        else
            read_state <= next_read_state;
    end

always @ (*) 
    begin 
        case (read_state)
            WAIT: rdreq = 0;
            READ_REQUEST: rdreq = 1;
            EMPTYING: rdreq = 1;
            EMPTY: rdreq = 0;
        endcase
    end



DualClockFIFOBucket FIFO(
					
    .aclr (aclr), //check
    .data (audio_in), //check
    .rdclk (rdclk), //check
    .rdreq (rdreq), //check
    .wrclk (wrclk), //check
    .wrreq (wrreq), //check
    .q (audio_out), // check 
    .rdempty (rdempty), //empty from reading
    .rdfull (rdfull), //full from reading //this
    .wrempty (wrempty), //nothc`ing else to write //this are needed
    .wrfull (wrfull), //still full from writing
    .eccstatus (),
    .rdusedw (),
    .wrusedw ()
);

endmodule

