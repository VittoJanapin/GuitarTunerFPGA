`timescale 1ns/1ps

// Stub Audio Controller - just provides the handshake signals
// Stub Audio Controller - just provides the handshake signals
module Audio_Controller (
    input CLOCK_50,
    input reset,
    input clear_audio_in_memory,
    input read_audio_in,
    input clear_audio_out_memory,
    input [31:0] left_channel_audio_out,
    input [31:0] right_channel_audio_out,
    input write_audio_out,
    input AUD_ADCDAT,
    inout AUD_BCLK,
    inout AUD_ADCLRCK,
    inout AUD_DACLRCK,
    output reg audio_in_available,
    output reg [31:0] left_channel_audio_in,
    output reg [31:0] right_channel_audio_in,
    output reg audio_out_allowed,
    output AUD_XCK,
    output AUD_DACDAT
);
    
    initial begin
        audio_in_available = 0;
        audio_out_allowed = 1;
        left_channel_audio_in = 32'h1000;
        right_channel_audio_in = 32'h1000;
    end
    
    // Generate audio_in_available on every rising edge of AUD_ADCLRCK
    always @(posedge AUD_ADCLRCK or posedge reset) begin
        if (reset) begin
            audio_in_available <= 0;
            left_channel_audio_in <= 32'h1000;
            right_channel_audio_in <= 32'h1000;
        end else begin
            audio_in_available <= 1;  // ALWAYS available for testing
            left_channel_audio_in <= left_channel_audio_in + 1;
            right_channel_audio_in <= right_channel_audio_in + 1;
        end
    end
    
    assign AUD_XCK = 0;
    assign AUD_DACDAT = 0;
endmodule
// Stub avconf - does nothing
module avconf #(parameter USE_MIC_INPUT = 0) (
    input FPGA_I2C_SCLK,
    inout FPGA_I2C_SDAT,
    input CLOCK_50,
    input reset
);
    // Does nothing - just exists
endmodule

// Stub FIFO - simple behavioral model (NO eccstatus)
module DualClockFIFO (
    input aclr,
    input [31:0] data,
    input rdclk,
    input rdreq,
    input wrclk,
    input wrreq,
    output reg [31:0] q,
    output reg rdempty,
    output reg rdfull,
    output reg wrempty,
    output reg wrfull,
    output reg [12:0] rdusedw,  // Changed from [13:0] to match your 14-bit usage
    output reg [12:0] wrusedw
);
    // Simple memory array
    reg [31:0] memory [0:8191];
    reg [13:0] write_ptr;
    reg [13:0] read_ptr;
    reg [14:0] count;  // 15 bits to handle full range
    
    initial begin
        write_ptr = 0;
        read_ptr = 0;
        count = 0;
        rdempty = 1;
        rdfull = 0;
        wrempty = 1;
        wrfull = 0;
        rdusedw = 0;
        wrusedw = 0;
        q = 0;
    end
    
    // Write side
    always @(posedge wrclk or posedge aclr) begin
        if (aclr) begin
            write_ptr <= 0;
            wrusedw <= 0;
            wrempty <= 1;
            wrfull <= 0;
        end else if (wrreq && !wrfull) begin
            memory[write_ptr] <= data;
            write_ptr <= write_ptr + 1;
            wrusedw <= wrusedw + 1;
            
            // Update flags
            wrempty <= 0;
            if (wrusedw >= 14'd8191) begin
                wrfull <= 1;
            end
        end
    end
    
    // Read side
    always @(posedge rdclk or posedge aclr) begin
        if (aclr) begin
            read_ptr <= 0;
            rdusedw <= 0;
            rdempty <= 1;
            rdfull <= 0;
            q <= 0;
        end else if (rdreq && !rdempty) begin
            q <= memory[read_ptr];
            read_ptr <= read_ptr + 1;
            rdusedw <= rdusedw - 1;
            
            // Update flags
            rdfull <= 0;
            if (rdusedw <= 14'd1) begin
                rdempty <= 1;
            end
        end
    end
    
    // Synchronize count between clock domains (simplified)
    always @(posedge rdclk or posedge wrclk) begin
        count = write_ptr - read_ptr;
        rdusedw = count[13:0];
        wrusedw = count[13:0];
        
        rdempty = (count == 0);
        rdfull = (count >= 15'd8192);
        wrempty = (count == 0);
        wrfull = (count >= 15'd8192);
    end
    
    // Error checking
    always @(posedge wrclk) begin
        if (wrreq && wrfull) begin
            $error("TIME=%0t: FIFO STUB - Write to full FIFO!", $time);
        end
    end
    
    always @(posedge rdclk) begin
        if (rdreq && rdempty) begin
            $error("TIME=%0t: FIFO STUB - Read from empty FIFO!", $time);
        end
    end
endmodule

// Stub FFT - just responds to handshake (sink_ready is now INPUT)
module TunerFFT (
    input clk,
    input reset_n,
    input sink_valid,
    input sink_ready,      // Changed to INPUT
    output [1:0] sink_error,
    input sink_sop,
    input sink_eop,
    input [31:0] sink_real,
    input [31:0] sink_imag,
    input [13:0] fftpts_in,
    output reg source_valid,
    input source_ready,
    output [1:0] source_error,
    output reg source_sop,
    output reg source_eop,
    output reg [31:0] source_real,
    output reg [31:0] source_imag,
    output [13:0] fftpts_out
);
    assign sink_error = 2'b00;
    assign source_error = 2'b00;
    assign fftpts_out = fftpts_in;
    
    reg [13:0] sample_count;
    reg processing;
    
    initial begin
        source_valid = 0;
        source_sop = 0;
        source_eop = 0;
        source_real = 0;
        source_imag = 0;
        sample_count = 0;
        processing = 0;
    end
    
    // Simple behavior: accept data when valid AND ready
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            source_valid <= 0;
            sample_count <= 0;
            processing <= 0;
        end else begin
            // Accept input when both valid and ready
            if (sink_valid && sink_ready) begin
                if (sink_sop) begin
                    sample_count <= 0;
                    processing <= 1;
                    $display("TIME=%0t: FFT STUB - Received SOP", $time);
                end
                
                if (sink_eop) begin
                    $display("TIME=%0t: FFT STUB - Received EOP (samples=%0d)", $time, sample_count + 1);
                    
                    // Check sample count
                    if (sample_count + 1 != fftpts_in) begin
                        $error("TIME=%0t: FFT STUB - Received %0d samples, expected %0d", 
                               $time, sample_count + 1, fftpts_in);
                    end else begin
                        $display("TIME=%0t: FFT STUB - Correct sample count!", $time);
                    end
                    
                    processing <= 0;
                end
                
                sample_count <= sample_count + 1;
            end
            
            // Generate dummy output (optional - not needed for your test)
            source_valid <= 0;
        end
    end
    
    // Monitor for protocol violations
    reg last_sop, last_eop;
    reg in_packet;
    
    initial begin
        in_packet = 0;
        last_sop = 0;
        last_eop = 0;
    end
    
    always @(posedge clk) begin
        if (sink_valid && sink_ready) begin
            if (sink_sop && in_packet) begin
                $error("TIME=%0t: FFT STUB - SOP while already in packet!", $time);
            end
            
            if (sink_eop && !in_packet) begin
                $error("TIME=%0t: FFT STUB - EOP without SOP!", $time);
            end
            
            if (sink_sop) in_packet <= 1;
            if (sink_eop) in_packet <= 0;
        end
        
        last_sop <= sink_sop;
        last_eop <= sink_eop;
    end
endmodule