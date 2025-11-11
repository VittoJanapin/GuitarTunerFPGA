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

// Internal Registers


// State Machine Registers



/*****************************************************************************
 *                             Sequential Logic                              *
 *****************************************************************************/


/*****************************************************************************
 *                            Combinational Logic                            *
 *****************************************************************************/



assign read_audio_in			= audio_in_available & audio_out_allowed;

assign left_channel_audio_out	= left_channel_audio_in;
assign right_channel_audio_out	= right_channel_audio_in;
assign write_audio_out			= audio_in_available & audio_out_allowed & ~SW[0];

wire	[30:0] abs_sample;
assign abs_sample = left_channel_audio_out[31] ? -left_channel_audio_out[30:0] : left_channel_audio_out[30:0];

//signal strength module
reg     [9:0]   amplitude;
always @ (*)
begin
	amplitude = 10'b0;
    if(abs_sample > 31'b1_000_000_000_000_000_000_000_000_000_000) //30 zeroes
        amplitude = 10'b0111111111;
    else if(abs_sample > 31'b1_000_000_000_000_000_000_000_000_000) //24  
        amplitude = 10'b0011111111;
    else if(abs_sample > 31'b1_000_000_000_000_000_000_000_000)
        amplitude = 10'b0001111111;
    else if(abs_sample > 31'b1_000_000_000_000_000_000_000)
        amplitude = 10'b0000111111;
    else if(abs_sample > 31'b1_000_000_000_000_000_000_0)
        amplitude = 10'b0000011111;
    else if(abs_sample > 31'b1_000_000_000_000_000_000)
        amplitude = 10'b0000001111;
    else if(abs_sample > 31'b1_000_000_000_000_000_00)
        amplitude = 10'b0000000111;
    else if(abs_sample > 31'b1_000_000_000_000_000_0)
        amplitude = 10'b0000000011;
    else if(abs_sample > 31'b1_000_000_000_000_000)
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
endmodule

