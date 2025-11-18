`timescale 1ns/1ps

module simple_test;

    // Clocks
    reg CLOCK_50;
    reg audio_clk;  // We'll make this much faster for testing
    
    // Reset and controls
    reg [3:0] KEY;
    reg [3:0] SW;
    wire [9:0] LEDR;
    
    // Audio signals - simplified
    reg audio_in_available;
    reg [31:0] left_channel_audio_in;
    
    // Bidirectional audio signals
    wire AUD_BCLK;
    wire AUD_ADCLRCK;
    wire AUD_DACLRCK;
    wire FPGA_I2C_SDAT;
    
    // FIFO signals we want to watch
    wire wrreq, rdreq;
    wire wrfull, wrempty, rdfull, rdempty;
    wire [13:0] wrusedw, rdusedw;
    
    // FFT signals
    wire sink_valid, sink_sop, sink_eop;
    
    // 50MHz clock
    initial begin
        CLOCK_50 = 0;
        forever #10 CLOCK_50 = ~CLOCK_50;
    end
    
    // Audio clock - make it 1MHz for testing (normally 48kHz)
    initial begin
        audio_clk = 0;
        forever #500 audio_clk = ~audio_clk;
    end
    
    // Drive the bidirectional audio clock
    assign AUD_ADCLRCK = audio_clk;
    
    // Simulate audio data coming in
    always @(posedge audio_clk) begin
        audio_in_available <= 1;  // Always have data available
        left_channel_audio_in <= left_channel_audio_in + 1;
    end
    
    // Instantiate just the important parts
    GuitarTunerFPGA dut (
        .CLOCK_50(CLOCK_50),
        .SW(SW),
        .KEY(KEY),
        .LEDR(LEDR),
        .AUD_ADCDAT(1'b0),
        .AUD_BCLK(AUD_BCLK),
        .AUD_ADCLRCK(AUD_ADCLRCK),
        .AUD_DACLRCK(AUD_DACLRCK),
        .FPGA_I2C_SDAT(FPGA_I2C_SDAT),
        .AUD_XCK(),
        .AUD_DACDAT(),
        .FPGA_I2C_SCLK()
    );
    
    // Connect internal signals for visibility
    assign wrreq = dut.wrreq;
    assign rdreq = dut.rdreq;
    assign wrfull = dut.wrfull;
    assign wrempty = dut.wrempty;
    assign rdfull = dut.rdfull;
    assign rdempty = dut.rdempty;
    assign wrusedw = dut.wrusedw;
    assign rdusedw = dut.rdusedw;
    assign sink_valid = dut.sink_valid;
    assign sink_sop = dut.sink_sop;
    assign sink_eop = dut.sink_eop;
    
    // Override audio controller outputs with force
    initial begin
        #1;  // Wait for design to initialize
        force dut.audio_in_available = audio_in_available;
        force dut.left_channel_audio_in = left_channel_audio_in;
        force dut.right_channel_audio_in = left_channel_audio_in;
        force dut.audio_out_allowed = 1'b1;
    end
    
    // Test sequence
    initial begin
        KEY = 4'b1111;
        SW = 4'b0001;
        audio_in_available = 0;
        left_channel_audio_in = 0;
        
        // Reset
        KEY[0] = 0;
        #1000;
        KEY[0] = 1;
        
        $display("=== Test Started ===");
        
        // Wait a bit for things to settle
        #50000;
        
        // Check if write state machine is working
        if (dut.write_state != 3'b000) begin
            $display("TIME=%0t: Write state machine is active: %b", $time, dut.write_state);
        end else begin
            $display("TIME=%0t: Write state machine stuck in WAIT", $time);
        end
        
        // Wait for FIFO to have some data
        wait(wrusedw >= 14'd100);
        $display("TIME=%0t: FIFO has data! wrusedw=%0d", $time, wrusedw);
        
        // Wait for FIFO to fill
        wait(wrusedw >= 14'd8191);
        $display("TIME=%0t: FIFO filled! wrusedw=%0d", $time, wrusedw);
        
        // Wait for read to start
        wait(rdreq == 1);
        $display("TIME=%0t: Read started!", $time);
        
        // Wait for SOP
        wait(sink_sop == 1);
        $display("TIME=%0t: FFT SOP detected!", $time);
        
        // Wait for EOP
        wait(sink_eop == 1);
        $display("TIME=%0t: FFT EOP detected!", $time);
        
        #10000;
        $display("=== Test Complete ===");
        $stop;
    end
    
    // Monitor for errors
    always @(posedge audio_clk) begin
        if (KEY[0] && wrreq && wrfull) begin
            $error("TIME=%0t: WRITE TO FULL FIFO!", $time);
        end
    end
    
    always @(posedge CLOCK_50) begin
        if (KEY[0] && rdreq && rdempty) begin
            $error("TIME=%0t: READ FROM EMPTY FIFO!", $time);
        end
    end
    
    // Display state transitions
    always @(posedge audio_clk) begin
        if (dut.write_state != dut.next_write_state) begin
            $display("TIME=%0t: Write state %b->%b wrusedw=%0d", 
                     $time, dut.write_state, dut.next_write_state, wrusedw);
        end
    end
    
    always @(posedge CLOCK_50) begin
        if (dut.read_state != dut.next_read_state) begin
            $display("TIME=%0t: Read state %b->%b rdusedw=%0d", 
                     $time, dut.read_state, dut.next_read_state, rdusedw);
        end
    end

endmodule