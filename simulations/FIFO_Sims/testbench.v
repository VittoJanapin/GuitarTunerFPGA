`timescale 1ns/1ps

module tb_Project;

    // Clock and reset
    reg CLOCK_50;
    reg [3:0] KEY;
    reg [3:0] SW;
    wire [9:0] LEDR;
    
    // Audio codec signals (we'll simulate these)
    reg AUD_ADCDAT;
    wire AUD_BCLK;
    wire AUD_ADCLRCK;
    wire AUD_DACLRCK;
    wire AUD_XCK;
    wire AUD_DACDAT;
    
    // I2C (can leave floating for basic tests)
    wire FPGA_I2C_SDAT;
    wire FPGA_I2C_SCLK;
    
    // Instantiate your design
    GuitarTunerFPGA dut (
        .CLOCK_50(CLOCK_50),
        .SW(SW),
        .KEY(KEY),
        .AUD_ADCDAT(AUD_ADCDAT),
        .AUD_BCLK(AUD_BCLK),
        .AUD_ADCLRCK(AUD_ADCLRCK),
        .AUD_DACLRCK(AUD_DACLRCK),
        .FPGA_I2C_SDAT(FPGA_I2C_SDAT),
        .AUD_XCK(AUD_XCK),
        .AUD_DACDAT(AUD_DACDAT),
        .FPGA_I2C_SCLK(FPGA_I2C_SCLK),
        .LEDR(LEDR)
    );
    
    // Generate 50MHz clock
    initial begin
        CLOCK_50 = 0;
        forever #10 CLOCK_50 = ~CLOCK_50;  // 50MHz = 20ns period
    end
    
    // Generate audio sample clock (48kHz)
    // 48kHz = 20.833us period = 20833ns
    reg audio_clk;
    initial begin
        audio_clk = 0;
        forever #500 audio_clk = ~audio_clk;  // 48kHz
    end
    
    // Simulate audio data input
    integer sample_count;
    reg [31:0] test_sample;
    
    initial begin
        // Initialize
        KEY = 4'b1111;  // Active low reset
        SW = 4'b0001;   // Enable audio out
        AUD_ADCDAT = 0;
        sample_count = 0;
        
        // Apply reset
        KEY[0] = 0;
        #1000;
        KEY[0] = 1;
        
        $display("Starting test at time %0t", $time);
        
        // Let audio controller initialize
        #100000;
        
        // Simulate some audio samples coming in
        repeat(10000) begin
            @(posedge audio_clk);
            // Send a test pattern (sine wave simulation)
            test_sample = $sin(sample_count * 0.1) * 32'd1000000;
            sample_count = sample_count + 1;
        end
        
        $display("Test complete at time %0t", $time);
        #10000;
        $stop;
    end
    
    /******************************************************************
     * TIMING VIOLATION CHECKERS
     ******************************************************************/
    
    // Monitor FIFO write operations
    always @(posedge dut.wrclk) begin
        if (KEY[0]) begin  // Only check when not in reset
            // Check for write overflow
            if (dut.wrreq && dut.wrfull) begin
                $error("TIME=%0t: FIFO WRITE OVERFLOW! Writing to full FIFO", $time);
                $display("  State: %b, wrusedw: %d, wrfull: %b", 
                         dut.write_state, dut.wrusedw, dut.wrfull);
            end
            
            // Check write state transitions
            if (dut.write_state == dut.WRITING && dut.wrusedw >= 14'd8192) begin
                $error("TIME=%0t: FIFO write counter exceeded limit", $time);
            end
        end
    end
    
    // Monitor FIFO read operations
    always @(posedge CLOCK_50) begin
        if (KEY[0]) begin
            // Check for read underflow
            if (dut.rdreq && dut.rdempty) begin
                $error("TIME=%0t: FIFO READ UNDERFLOW! Reading from empty FIFO", $time);
                $display("  State: %b, rdusedw: %d, rdempty: %b", 
                         dut.read_state, dut.rdusedw, dut.rdempty);
            end
        end
    end
    
    // Monitor FFT sink interface (your design -> FFT)
    reg prev_sink_sop, prev_sink_eop;
    reg in_packet;
    
    initial begin
        in_packet = 0;
        prev_sink_sop = 0;
        prev_sink_eop = 0;
    end
    
    always @(posedge CLOCK_50) begin
        if (KEY[0]) begin
            // Check SOP/EOP protocol
            if (dut.sink_valid && dut.sink_ready) begin
                // SOP starts a packet
                if (dut.sink_sop) begin
                    if (in_packet) begin
                        $error("TIME=%0t: FFT SOP asserted while already in packet!", $time);
                    end
                    in_packet = 1;
                end
                
                // EOP ends a packet
                if (dut.sink_eop) begin
                    if (!in_packet) begin
                        $error("TIME=%0t: FFT EOP asserted without SOP!", $time);
                    end
                    in_packet = 0;
                end
                
                // Check that we're in a packet when transferring data
                if (!dut.sink_sop && !in_packet) begin
                    $warning("TIME=%0t: FFT data transfer without packet framing", $time);
                end
            end
            
            // Check for valid without ready (potential data loss)
            if (dut.sink_valid && !dut.sink_ready) begin
                $warning("TIME=%0t: FFT sink_valid high but sink_ready low - FFT not ready!", $time);
            end
            
            // Check SOP and EOP shouldn't both be high unless it's a 1-sample packet
            if (dut.sink_sop && dut.sink_eop && dut.sink_valid) begin
                $warning("TIME=%0t: FFT SOP and EOP both high (single sample packet?)", $time);
            end
        end
        
        prev_sink_sop = dut.sink_sop;
        prev_sink_eop = dut.sink_eop;
    end
    
    // Monitor read state machine
    integer samples_read;
    initial samples_read = 0;
    
    always @(posedge CLOCK_50) begin
        if (!KEY[0]) begin
            samples_read = 0;
        end else if (dut.read_state == dut.READING && dut.rdreq) begin
            samples_read = samples_read + 1;
            
            // FFT expects exactly 8192 samples
            if (samples_read > 8192) begin
                $error("TIME=%0t: Read more than 8192 samples!", $time);
            end
        end else if (dut.read_state == dut.DISABLE_EOP) begin
            if (samples_read != 8192) begin
                $error("TIME=%0t: Completed packet with %d samples (expected 8192)", 
                       $time, samples_read);
            end
            samples_read = 0;
        end
    end
    
    // Display state transitions for debugging
    always @(posedge dut.wrclk) begin
        if (dut.write_state != dut.next_write_state) begin
            $display("TIME=%0t: WRITE state %b -> %b (wrusedw=%d)", 
                     $time, dut.write_state, dut.next_write_state, dut.wrusedw);
        end
    end
    
    always @(posedge CLOCK_50) begin
        if (dut.read_state != dut.next_read_state) begin
            $display("TIME=%0t: READ state %b -> %b (rdusedw=%d)", 
                     $time, dut.read_state, dut.next_read_state, dut.rdusedw);
        end
    end
    
    // Summary statistics
    integer errors_detected;
    initial errors_detected = 0;
    
    always @(posedge CLOCK_50) begin
        // Count errors (ModelSim increments $error automatically)
    end

endmodule