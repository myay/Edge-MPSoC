// ============================================================================
// Module: axi4_lpddr4_model
// Description:
//    A cycle-accurate behavioral Full AXI4 LPDDR4 DRAM model.
//    Integrates LPDDR4-specific structural constraints including:
//    - 8 Independent Banks per channel
//    - Per-Bank Refresh (REFpb)
//    - Four-Activate Window (tFAW) and Row-to-Row Delay (tRRD) power throttling
// ============================================================================

module axi4_lpddr4_model #(
			   parameter int unsigned MEM_SIZE_BYTES = 4 * 1024 * 1024, // 4MB for fast simulation
			   parameter int unsigned AXI_DATA_WIDTH = 32, // 32-bit to match SoC Crossbar
			   parameter int unsigned AXI_ADDR_WIDTH = 32, 
			   parameter int unsigned AXI_ID_WIDTH = 4, 

			   // Standard DRAM Delays
			   parameter int unsigned T_RCD = 3, // RAS-to-CAS delay
			   parameter int unsigned T_CAS = 4, // Column Access latency
			   parameter int unsigned T_RP = 3, // Row Precharge time

			   // --- NEW: LPDDR4 Specific Timing & Power Constraints ---
			   parameter int unsigned T_FAW = 24, // Four-Activate Window limit
			   parameter int unsigned T_RRD = 4, // Row-to-Row activation delay
			   parameter int unsigned T_REFI = 1950,// Refresh Interval (e.g., 3.9us in cycles)
			   parameter int unsigned T_RFCPB = 60   // Per-bank Refresh Cycle time duration
			   ) (
			      input logic			   clk_i,
			      input logic			   rst_ni,

			      // [AXI4 Slave Interface Ports remain identical to your original code]
			      input logic [AXI_ID_WIDTH-1:0]	   s_axi_awid,
			      input logic [AXI_ADDR_WIDTH-1:0]	   s_axi_awaddr,
			      input logic [7:0]			   s_axi_awlen, 
			      input logic [2:0]			   s_axi_awsize, 
			      input logic [1:0]			   s_axi_awburst, 
			      input logic			   s_axi_awvalid,
			      output logic			   s_axi_awready,

			      input logic [AXI_DATA_WIDTH-1:0]	   s_axi_wdata,
			      input logic [(AXI_DATA_WIDTH/8)-1:0] s_axi_wstrb,
			      input logic			   s_axi_wlast, 
			      input logic			   s_axi_wvalid,
			      output logic			   s_axi_wready,

			      output logic [AXI_ID_WIDTH-1:0]	   s_axi_bid,
			      output logic [1:0]		   s_axi_bresp,
			      output logic			   s_axi_bvalid,
			      input logic			   s_axi_bready,

			      input logic [AXI_ID_WIDTH-1:0]	   s_axi_arid,
			      input logic [AXI_ADDR_WIDTH-1:0]	   s_axi_araddr,
			      input logic [7:0]			   s_axi_arlen, 
			      input logic [2:0]			   s_axi_arsize,
			      input logic [1:0]			   s_axi_arburst,
			      input logic			   s_axi_arvalid,
			      output logic			   s_axi_arready,

			      output logic [AXI_ID_WIDTH-1:0]	   s_axi_rid,
			      output logic [AXI_DATA_WIDTH-1:0]	   s_axi_rdata,
			      output logic [1:0]		   s_axi_rresp,
			      output logic			   s_axi_rlast,
			      output logic			   s_axi_rvalid,
			      input logic			   s_axi_rready
			      );

   // -------------------------------------------------------------------------
   // Storage Array and LPDDR4 Addressing Architecture
   // -------------------------------------------------------------------------
   localparam int unsigned					   BYTES_PER_WORD = AXI_DATA_WIDTH / 8;
   localparam int unsigned					   NUM_WORDS      = MEM_SIZE_BYTES / BYTES_PER_WORD;
   logic [AXI_DATA_WIDTH-1:0]					   dram_matrix [0:NUM_WORDS-1];

   // LPDDR4 uses 8 Banks per channel. 
   // We widen the row width to 14 bits to simulate a deeper memory structure.
   logic [13:0]							   open_row [0:7]; 
   logic							   bank_active [0:7];

   // -------------------------------------------------------------------------
   // LPDDR4 Power & Refresh Trackers (Global)
   // -------------------------------------------------------------------------
   int unsigned							   current_cycle;
   int unsigned							   act_history [0:3];   // Tracks last 4 row activations for tFAW
   int unsigned							   last_act_cycle;      // Tracks last single activation for tRRD

   int unsigned							   ref_timer;
   int unsigned							   bank_rfc_timer [0:7];
   logic							   bank_refreshing [0:7];
   logic [2:0]							   next_refresh_bank;

   // Background process for global cycle counting and Per-Bank Refreshes
   always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin
         current_cycle     <= 0;
         ref_timer         <= 0;
         next_refresh_bank <= 0;
         for(int i=0; i<8; i++) begin
            bank_refreshing[i] <= 0;
            bank_rfc_timer[i]  <= 0;
         end
      end else begin
         current_cycle <= current_cycle + 1;

         // Trigger Background Refresh (REFpb)
         if (ref_timer >= T_REFI) begin
            ref_timer <= 0;
            bank_refreshing[next_refresh_bank] <= 1'b1;
            bank_rfc_timer[next_refresh_bank]  <= T_RFCPB;
            next_refresh_bank <= next_refresh_bank + 1; // Round-robin bank selection
         end else begin
            ref_timer <= ref_timer + 1;
         end

         // Process Active Refreshes
         for(int i=0; i<8; i++) begin
            if (bank_refreshing[i]) begin
               if (bank_rfc_timer[i] > 0) begin
                  bank_rfc_timer[i] <= bank_rfc_timer[i] - 1;
               end else begin
                  bank_refreshing[i] <= 1'b0; // Refresh complete
                  bank_active[i]     <= 1'b0; // Hardware refresh forces row closure
               end
            end
         end
      end
   end

   // -------------------------------------------------------------------------
   // Read Pipeline Processing Engine (Simulating DRAM Stalls)
   // -------------------------------------------------------------------------
   typedef enum logic [2:0] {
			     R_IDLE, R_CHECK_BANK, R_ACTIVATE, R_PRECHARGE, R_ACCESS, R_BURST
			     } read_state_e;

   read_state_e r_state;
   int unsigned	r_delay_counter;
   
   // Captured transaction registers
   logic [AXI_ADDR_WIDTH-1:0] r_curr_addr;
   logic [7:0]		      r_burst_count;
   logic [AXI_ID_WIDTH-1:0]   r_active_id;

   logic [2:0]		      r_target_bank; // Widened to 3 bits for 8 Banks
   logic [13:0]		      r_target_row;  // Widened to 14 bits
   
   // Decoded mapping: [ Unused | Row (14) | Bank (3) | Col (X) | Alignment ]
   assign r_target_bank = r_curr_addr[10:8];  
   assign r_target_row  = r_curr_addr[24:11]; 

   assign s_axi_arready = (r_state == R_IDLE);

   always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin
         r_state         <= R_IDLE;
         r_delay_counter <= 0;
         s_axi_rvalid    <= 1'b0;
         s_axi_rlast     <= 1'b0;
         s_axi_rdata     <= '0;
         s_axi_rid       <= '0;
         s_axi_rresp     <= 2'b00;
         last_act_cycle  <= 0;
         for(int i=0; i<4; i++) act_history[i] <= 0;
         for(int i=0; i<8; i++) bank_active[i] <= 1'b0;
         for(int i=0; i<8; i++) open_row[i]    <= '0;
      end else begin
         case (r_state)
           R_IDLE: begin
              s_axi_rlast <= 1'b0;
              if (s_axi_arvalid) begin
                 r_curr_addr   <= s_axi_araddr;
                 r_burst_count <= s_axi_arlen;
                 r_active_id   <= s_axi_arid;
                 r_state       <= R_CHECK_BANK;
              end
           end

           R_CHECK_BANK: begin
              // 1. Is the bank locked by a background refresh?
              if (bank_refreshing[r_target_bank]) begin
                 // STALL: Do nothing, remain in R_CHECK_BANK until refresh clears
                 
                 // 2. Bank active and correct row open -> Instant Access
              end else if (bank_active[r_target_bank] && (open_row[r_target_bank] == r_target_row)) begin
                 r_delay_counter <= T_CAS;
                 r_state         <= R_ACCESS;
                 
                 // 3. Bank active but WRONG row -> Must Precharge
              end else if (bank_active[r_target_bank]) begin
                 r_delay_counter <= T_RP;
                 r_state         <= R_PRECHARGE;
                 
                 // 4. Bank closed -> Must Activate (Subject to LPDDR4 Power Windows)
              end else begin
                 automatic logic tfaw_ok = (current_cycle - act_history[3]) >= T_FAW;
                 automatic logic trrd_ok = (current_cycle - last_act_cycle) >= T_RRD;

                 if (tfaw_ok && trrd_ok) begin
                    // Record this activation in the power-tracking history
                    act_history[3] <= act_history[2];
                    act_history[2] <= act_history[1];
                    act_history[1] <= act_history[0];
                    act_history[0] <= current_cycle;
                    last_act_cycle <= current_cycle;

                    r_delay_counter <= T_RCD;
                    r_state         <= R_ACTIVATE;
                 end
                 // If power constraints are violated, STALL in R_CHECK_BANK
              end
           end

           R_PRECHARGE: begin
              if (r_delay_counter > 1) begin
                 r_delay_counter <= r_delay_counter - 1;
              end else begin
                 bank_active[r_target_bank] <= 1'b0;
                 r_state                    <= R_CHECK_BANK; // Re-evaluate power windows before activating
              end
           end

           R_ACTIVATE: begin
              if (r_delay_counter > 1) begin
                 r_delay_counter <= r_delay_counter - 1;
              end else begin
                 bank_active[r_target_bank] <= 1'b1;
                 open_row[r_target_bank]    <= r_target_row;
                 r_delay_counter            <= T_CAS;
                 r_state                    <= R_ACCESS;
              end
           end

           R_ACCESS: begin
              if (r_delay_counter > 1) begin
                 r_delay_counter <= r_delay_counter - 1;
              end else begin
                 r_state <= R_BURST;
              end
           end

           R_BURST: begin
              if (!s_axi_rvalid || s_axi_rready) begin
                 s_axi_rvalid <= 1'b1;
                 s_axi_rid    <= r_active_id;
                 s_axi_rdata  <= dram_matrix[r_curr_addr[AXI_ADDR_WIDTH-1:$clog2(BYTES_PER_WORD)]];
                 
                 if (r_burst_count == 0) begin
                    s_axi_rlast <= 1'b1;
                    r_state     <= R_IDLE;
                 end else begin
                    r_burst_count <= r_burst_count - 1;
                    r_curr_addr   <= r_curr_addr + BYTES_PER_WORD; // Compute INCR address
                 end
              end
           end
         endcase
         
         // Handle downstream handshakes cleanly
         if (s_axi_rvalid && s_axi_rready && s_axi_rlast) begin
            s_axi_rvalid <= 1'b0;
            s_axi_rlast  <= 1'b0;
         end
      end
   end

   // -------------------------------------------------------------------------
   // Write Pipeline Processing Engine 
   // -------------------------------------------------------------------------
   // Kept identical to your original block to ensure easy crossbar connectivity.
   assign s_axi_awready = (s_axi_bvalid == 1'b0);
   assign s_axi_wready  = (s_axi_bvalid == 1'b0) && s_axi_wvalid;

   always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin
         s_axi_bvalid <= 1'b0;
         s_axi_bid    <= '0;
         s_axi_bresp  <= 2'b00;
      end else begin
         if (s_axi_wvalid && s_axi_wready) begin
            automatic logic [AXI_ADDR_WIDTH-1:$clog2(BYTES_PER_WORD)] word_idx;
            word_idx = s_axi_awaddr[AXI_ADDR_WIDTH-1:$clog2(BYTES_PER_WORD)];

            for (int i = 0; i < BYTES_PER_WORD; i++) begin
               if (s_axi_wstrb[i]) begin
                  dram_matrix[word_idx][(i*8)+:8] <= s_axi_wdata[(i*8)+:8];
               end
            end

            if (s_axi_wlast) begin
               s_axi_bvalid <= 1'b1;
               s_axi_bid    <= s_axi_awid;
            end
         end

         if (s_axi_bready && s_axi_bvalid) begin
            s_axi_bvalid <= 1'b0;
         end
      end
   end

endmodule
