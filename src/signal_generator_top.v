`timescale 1ns/1ps

module signal_generator_top (
    input  wire clk_27m,
    input  wire uart_rx_pin,
    output wire uart_tx_pin,
    output wire test_led,
    output wire audio_enable,
    output wire i2s_data,
    output wire i2s_lrck,
    output wire i2s_bclk
);

    localparam [31:0] UART_16X_INCREMENT = 32'd293_203_101;

    localparam [1:0]
        ST_IDLE  = 2'd0,
        ST_LOAD  = 2'd1,
        ST_START = 2'd2,
        ST_WAIT  = 2'd3;

    localparam [31:0] AUDIO_SAMPLE_INCREMENT = 32'd7_635_497;

    //--------------------------------------------------
    // Signal declarations
    //--------------------------------------------------

    reg  [7:0] reset_counter = 8'd0;
    wire       reset_n;

// uart 
    wire       uart_rx_sync;
    wire       tick_16x;
    wire [7:0] rx_data;
    wire       rx_valid;
    wire       framing_error;
    reg  [7:0] tx_data;
    reg        tx_start;
    wire       tx_busy;
    wire       tx_done;

//parser from keyboard
    wire [31:0] parsed_frequency;
    wire        parsed_valid;
    wire        command_error;
    reg [31:0] frequency_hz;

// uart test with echo
    reg [1:0] echo_state;
    reg [7:0] echo_pending_byte;

    // dds stuff
    wire [31:0] dds_phase_inc_new;
    wire        dds_phase_inc_valid;
    reg  [31:0] dds_phase_inc;

    wire        sample_ce;
    wire [31:0] dds_phase;
    wire [7:0]  dds_rom_addr;
    wire signed [15:0] sine_sample;

// noise and signal 
    wire signed [15:0] noise_sample;
    wire signed [15:0] audio_sample;
    wire signed [15:0] scaled_sine;
    wire signed [15:0] scaled_noise;
    wire signed [16:0] mixed_sample_wide;
    wire signed [15:0] mixed_sample;

// mix and filter 
    wire signed [31:0] mixer_product;
    wire signed [41:0] integrator_sum;
    wire               integrator_valid;

// i2s stuff to drive MAX for speaker
    localparam [31:0] I2S_HALF_BCLK_INCREMENT =
        32'd977_343_669;

    wire i2s_half_bclk_ce;
    // Startup reset
    always @(posedge clk_27m) begin
        if (reset_counter != 8'hFF)
            reset_counter <= reset_counter + 1'b1;
    end

    assign reset_n = (reset_counter == 8'hFF);

    // Synchronize asynchronous UART RX input
    synchronizer #(
        .RESET_VALUE(1'b1)
    ) rx_sync_inst (
        .clk      (clk_27m),
        .reset_n  (reset_n),
        .async_in (uart_rx_pin),
        .sync_out (uart_rx_sync)
    );

    // 16x115200 UART oversampling tick
    fractional_tick #(
        .INCREMENT(UART_16X_INCREMENT)
    ) uart_tick_inst (
        .clk         (clk_27m),
        .reset_n     (reset_n),
        .tick        (tick_16x),
        .accumulator ()
    );

    // 48 kHz audio sample enable
    fractional_tick #(
        .INCREMENT(AUDIO_SAMPLE_INCREMENT)
    ) audio_sample_tick (
        .clk         (clk_27m),
        .reset_n     (reset_n),
        .tick        (sample_ce),
        .accumulator ()
    );

    // for speaker
    fractional_tick #(
        .INCREMENT(I2S_HALF_BCLK_INCREMENT)
    ) i2s_bclk_tick_inst (
        .clk         (clk_27m),
        .reset_n     (reset_n),
        .tick        (i2s_half_bclk_ce),
        .accumulator ()
    );

    // UART receiver
    uart_rx rx_inst (
        .clk           (clk_27m),
        .reset_n       (reset_n),
        .rx_sync       (uart_rx_sync),
        .tick_16x      (tick_16x),
        .rx_data       (rx_data),
        .rx_valid      (rx_valid),
        .framing_error (framing_error)
    );

    // UART transmitter
    uart_tx tx_inst (
        .clk      (clk_27m),
        .reset_n  (reset_n),
        .tick_16x (tick_16x),
        .tx_data  (tx_data),
        .tx_start (tx_start),
        .uart_tx  (uart_tx_pin),
        .tx_busy  (tx_busy),
        .tx_done  (tx_done)
    );

    // Command parser
    command_parser parser_inst (
        .clk             (clk_27m),
        .reset_n         (reset_n),
        .rx_data         (rx_data),
        .rx_valid        (rx_valid),
        .frequency_hz    (parsed_frequency),
        .frequency_valid (parsed_valid),
        .command_error   (command_error)
    );

    // i2S to drive the MAXnnnn audio amplifier chip
    i2s_tx i2s_tx_inst (
        .clk              (clk_27m),
        .reset_n          (reset_n),
        .i2s_half_bclk_ce (i2s_half_bclk_ce),
        .sample           (audio_sample),
        .i2s_bclk         (i2s_bclk),
        .i2s_lrck         (i2s_lrck),
        .i2s_data         (i2s_data)
    );

    // Echo controller FSM
    always @(posedge clk_27m or negedge reset_n) begin
        if (!reset_n) begin
            echo_state        <= ST_IDLE;
            echo_pending_byte <= 8'd0;
            tx_data           <= 8'd0;
            tx_start          <= 1'b0;
        end else begin
            tx_start <= 1'b0;

            case (echo_state)
                ST_IDLE: begin
                    if (rx_valid) begin
                        echo_pending_byte <= rx_data;
                        echo_state <= ST_LOAD;
                    end
                end

                ST_LOAD: begin
                    tx_data <= echo_pending_byte;
                    echo_state <= ST_START;
                end

                ST_START: begin
                    tx_start <= 1'b1;
                    echo_state <= ST_WAIT;
                end

                ST_WAIT: begin
                    if (tx_done)
                        echo_state <= ST_IDLE;
                end

                default: begin
                    echo_state <= ST_IDLE;
                    tx_start <= 1'b0;
                end
            endcase
        end
    end

// Frequency register
always @(posedge clk_27m or negedge reset_n) begin
    if (!reset_n)
        frequency_hz <= 32'd1;
    else if (parsed_valid && (parsed_frequency != 32'd0))
        frequency_hz <= parsed_frequency;
end

// convert to phase
frequency_to_phase #(
    .SAMPLE_RATE_HZ(48_000)
) dds_frequency_converter (
    .clk             (clk_27m),
    .reset_n         (reset_n),
    .frequency_hz    (frequency_hz),
    .frequency_valid (parsed_valid),
    .phase_inc       (dds_phase_inc_new),
    .phase_inc_valid (dds_phase_inc_valid)
);

// DDS / NCO
waveform_dds dds_inst (
    .clk       (clk_27m),
    .reset_n   (reset_n),
    .sample_ce (sample_ce),
    .phase_inc (dds_phase_inc),
    .phase     (dds_phase),
    .rom_addr  (dds_rom_addr),
    .sample    (sine_sample)
);

// Pseudo-random noise source
noise_lfsr noise_inst (
    .clk          (clk_27m),
    .reset_n      (reset_n),
    .sample_ce    (sample_ce),
    .noise_sample (noise_sample)
);

// DDS tuning-word register
always @(posedge clk_27m or negedge reset_n) begin
    if (!reset_n)
        dds_phase_inc <= 32'd62634940;   // 700 Hz default
    else if (dds_phase_inc_valid)
        dds_phase_inc <= dds_phase_inc_new;
end


/* led pwm code
reg [6:0] led_divider;

always @(posedge clk_27m or negedge reset_n) begin
    if (!reset_n)
        led_divider <= 7'd0;
    else if (sample_ce) begin
        if ((dds_phase + dds_phase_inc) < dds_phase)
            led_divider <= led_divider + 1'b1;
    end
end

assign test_led = ~led_divider[6];
*/
assign audio_enable = 1'b1;

// Add noise and sine wave together
assign scaled_noise         = noise_sample >>> 1;
assign scaled_sine          = sine_sample  >>> 3;
assign mixed_sample_wide    = scaled_noise + scaled_sine;
assign mixed_sample         = mixed_sample_wide[15:0];
assign audio_sample         = mixed_sample;

mixer mixer_inst (
    .signal_in (audio_sample),
    .lo_in     (sine_sample),
    .product   (mixer_product)
);

block_integrator integrator_inst (
    .clk        (clk_27m),
    .reset_n    (reset_n),
    .sample_ce  (sample_ce),
    .sample_in  (mixer_product),
    .sum_out    (integrator_sum),
    .sum_valid  (integrator_valid)
);

reg signed [41:0] integrator_latched;

always @(posedge clk_27m or negedge reset_n) begin
    if (!reset_n)
        integrator_latched <= 42'sd0;
    else if (integrator_valid)
        integrator_latched <= integrator_sum;
end

// Integrator magnitude
wire [41:0] integrator_magnitude;

assign integrator_magnitude = integrator_latched[41] ? (~integrator_latched + 1'b1) : integrator_latched;

wire detector_hit;
assign detector_hit = (integrator_magnitude >= 42'd8_589_934_592);  // 2^33

//assign test_led = ~detector_hit;
//assign test_led = ~integrator_latched[41];

reg [5:0] window_count;
reg [5:0] hit_count;
reg       tone_detected;

always @(posedge clk_27m or negedge reset_n) begin
    if (!reset_n) begin
        window_count  <= 6'd0;
        hit_count     <= 6'd0;
        tone_detected <= 1'b0;
    end
    else if (integrator_valid) begin

        // Count this integration window as a hit
        // if it exceeded our threshold.
        if (detector_hit)
            hit_count <= hit_count + 1'b1;

        // After 32 integration windows, make a decision.
        if (window_count == 6'd31) begin

            // Tone detected if at least 8 of 32
            // windows crossed the threshold.
            if (hit_count >= 6'd8)
                tone_detected <= 1'b1;
            else
                tone_detected <= 1'b0;

            window_count <= 6'd0;
            hit_count    <= 6'd0;
        end
        else begin
            window_count <= window_count + 1'b1;
        end
    end
end

assign test_led = ~tone_detected;

endmodule
