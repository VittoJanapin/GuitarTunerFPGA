module GuitarTunerFPGA (
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
input		[9:0]	SW;
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
/*
wire [2:0] amplification;
assign amplification = SW[3:1];

assign left_channel_audio_out	= left_channel_audio_in << amplification;
assign right_channel_audio_out	= right_channel_audio_in << amplification;
*/

/*******************************************************************************

Amplification uses 3-bit specifications, 
Bit shift left by n bits (each level is a power of 2 more)

********************************************************************************/

/*
reg [25:0] led_counter;
always @ (posedge CLOCK_50)
	begin
		if(!KEY[0])
			led_counter <= 0;
		else
			led_counter <= led_counter+1;
	end

assign LEDR[9] = led_counter[25];
reg [12:0] led_counter2;
reg ledOut;
always @ (posedge AUD_ADCLRCK)
	begin
		if(!KEY[0])
			begin
			led_counter2 <= 0;
			ledOut <= 0;
			end
		else if (led_counter2 < 13'd48000)
			led_counter2 = led_counter2+1;
		else
		begin
			led_counter2 <= 0;
			ledOut <= ~ledOut;
		end
	end

assign LEDR[8] = ledOut;
/*******************************************************************************

Signal Strength Detector, This will display how much amplitude there is
This follows the decibel scale
max is 2^31-1 and min is obviously 0
divide that into ten and account for the logarithmic pattern
each bin is calculated by 10^(18.66n/20)
We evaluate the highest amplitude first

********************************************************************************/
/*
wire	[30:0] abs_sample;
assign abs_sample = left_channel_audio_out[31] ? -left_channel_audio_out[30:0] : left_channel_audio_out[30:0];
reg     [9:0]   amplitude;
always @ (*)
begin
	amplitude =9'b0;
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

assign LEDR[8:0] = amplitude [8:0];
*/
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








/*****************************************************************************
 *                              Controlling Variables                        *
 *****************************************************************************/
//writing clocked in at 48K
wire wrfull, wrempty;
reg wrreq;



//reading clocked in at 50M
wire rdempty, rdfull;
reg rdreq;
 //this is the same clock feeding into the fft
//general stuff
wire aclr;
wire [31:0] audio_in, audio_out;

assign audio_in = left_channel_audio_in;
/*****************************************************************************
 *                              FIFO WRITE CONTROL                            *
 *****************************************************************************/

wire [13:0] wrusedw;
reg [2:0] write_state, next_write_state;

parameter WAIT_AUDIO_DATA = 3'b000, START_WRITE = 3'b001, WRITING = 3'b010, LAST_WRITE = 3'b011, DISABLE_REQ = 3'b100;

reg audio_captured;
// Capture audio_in_available pulse and hold it
always @ (posedge AUD_ADCLRCK)
begin
    if(!KEY[0])
        audio_captured <= 0;
    else if(audio_in_available)  // Capture the pulse
        audio_captured <= 1;
    else if(write_state == DISABLE_REQ)  // Clear after we're done writing
        audio_captured <= 0;
end

//cct a

always @ (*)
    begin
        case(write_state)
        WAIT_AUDIO_DATA: if(wrempty & SW[1]) next_write_state = START_WRITE; else next_write_state = WAIT_AUDIO_DATA;
        START_WRITE: next_write_state = WRITING;
        WRITING: if(wrusedw == 14'd8191) next_write_state = LAST_WRITE; else next_write_state = WRITING;
        LAST_WRITE: next_write_state = DISABLE_REQ;
        DISABLE_REQ: next_write_state = WAIT_AUDIO_DATA;
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
            WAIT_AUDIO_DATA: begin wrreq = 0; end
            START_WRITE: begin wrreq = 1; end
            WRITING: begin wrreq = 1;end
            LAST_WRITE: begin wrreq = 1;end
            DISABLE_REQ: begin wrreq = 0;  end
            default: begin wrreq = 0; amongussy = 5'b00000; end
        endcase 
    end
	 



/*****************************************************************************
 *                              FIFO READ CONTROL                            *
 *****************************************************************************/

// FFT PARAMS
//audio out is linked to fft 
reg sink_valid, sink_sop, sink_eop;
wire sink_ready;
reg [2:0] read_state, next_read_state;
wire [12:0] rdusedw;

parameter WAIT_FIFO = 3'b000, START_READ = 3'b001, READING = 3'b010, LAST_READ = 3'b011, DISABLE_EOP = 3'b100;

reg [12:0] readCount;

always @ (posedge CLOCK_50)
	begin
		if(!KEY[0] || read_state == WAIT_FIFO)
			readCount <= 13'd0;
		else if (rdreq)
			readCount <= readCount + 1;
	end
always @ (*)
    begin
        case (read_state)
            WAIT_FIFO: if(rdfull & SW[2]) next_read_state = START_READ; else next_read_state = WAIT_FIFO;
            START_READ: next_read_state = READING;
            READING: if(readCount == 13'd8190) next_read_state = LAST_READ; else next_read_state = READING;
            LAST_READ:
                begin
                    next_read_state = DISABLE_EOP;
                end
            DISABLE_EOP: next_read_state = WAIT_FIFO;
            default: next_read_state = WAIT_FIFO;
        endcase
    end

always @ (posedge CLOCK_50) 
    begin
        if(!KEY[0])
            read_state <= WAIT_FIFO;
        else
            read_state <= next_read_state;
    end
reg [4:0] amongussy;

always @ (*) 
    begin 
        case (read_state)
            WAIT_FIFO: 
                begin
                    rdreq = 0;
                    sink_valid = 0;
                    sink_sop = 0;
                    sink_eop = 0;
							amongussy = 5'b00001;
                end
            START_READ:
                begin
                    rdreq = 1;
                    sink_valid = 1;
                    sink_sop = 1;
                    sink_eop = 0;
						  amongussy = 5'b00010;
                end
            READING: 
                begin
                    rdreq = 1;
                    sink_valid = 1;
                    sink_sop = 0;
                    sink_eop = 0;
						  amongussy = 5'b00100;
                end
            LAST_READ:
                begin
                    rdreq = 1;
                    sink_valid = 1;
                    sink_sop = 0;
                    sink_eop = 1;
						  amongussy = 5'b01000;
                end
            DISABLE_EOP:
                begin
                    rdreq = 0;
                    sink_valid = 0;
                    sink_sop = 0;
                    sink_eop = 0;
						  amongussy = 5'b10000;
                end
            default: 
                begin
                    rdreq = 0;
                    sink_valid = 0;
                    sink_sop = 0;
                    sink_eop = 0;
						  amongussy = 5'b00000;
                end
        endcase
    end
	 
assign LEDR[0] = sink_ready;
assign LEDR[1] = sink_valid;
assign LEDR[2] = rdreq;
assign LEDR[3] = sink_ready & sink_valid;
assign LEDR[6] = rdempty;
assign LEDR[7] = rdfull;
assign LEDR[8] = wrempty;
assign LEDR[9] = wrfull;
/****

Reconfigure for handshake with FFT

***/

wire [1:0] eccstatus; //needed when debugging

DualClockFIFO FIFO(
					
    .aclr (~KEY[0]), //check
    .data (audio_in), //check
    .rdclk (CLOCK_50), //check
    .rdreq (rdreq), //check
    .wrclk (AUD_ADCLRCK), //check
    .wrreq (wrreq), //check
    .q (audio_out), // check 
    .rdempty (rdempty), //empty from reading
    .rdfull (rdfull), //full from reading //this
    .wrempty (wrempty), //nothc`ing else to write //this are needed
    .wrfull (wrfull), //still full from writing
    .rdusedw (rdusedw),
    .wrusedw (wrusedw)
);


//fft constants

wire [31:0] nothing_imagniary;
assign nothing_imagniary = 32'd0;
wire [13:0] fftpts_in;
assign fftpts_in = 14'd8192;
wire [13:0] fftpts_out;
assign fftpts_out = 14'd8192;

//fft outputs
wire source_sop, source_eop, source_ready; 

wire [31:0] source_real, source_imag; 
assign source_ready = 1;

//fft output flags set by us
wire source_valid; //whenever you are ready to read a frame 

//error flags
wire [1:0] sink_error, source_error;

TunerFFT FFT (
    .clk          (CLOCK_50),          //    clk.clk
    .reset_n      (~KEY[0]),      //    rst.reset_n
    .sink_valid   (sink_valid),   //   us controlled
    .sink_ready   (sink_ready),   //       .tell us
    .sink_error   (sink_error),   //       .sink_error
    .sink_sop     (sink_sop),     //       .sink_sop
    .sink_eop     (sink_eop),     //       .sink_eop
    .sink_real    (audio_out),    //       .sink_real
    .sink_imag    (nothing_imagniary),    //       .does not exist for audio
    .fftpts_in    (fftpts_in),    //       .fftpts_in
    .source_valid (source_valid), // source.source_valid
    .source_ready (source_ready), //       .source_ready
    .source_error (source_error), //       .source_error
    .source_sop   (source_sop),   //       .source_sop
    .source_eop   (source_eop),   //       .source_eop
    .source_real  (source_real),  //       .source_real
    .source_imag  (source_imag),  //       .source_imag
    .fftpts_out   (fftpts_out)    //       .fftpts_out
);




endmodule

