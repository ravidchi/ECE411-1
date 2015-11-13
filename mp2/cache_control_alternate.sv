//####################################################################
//####################################################################
//####################################################################
//################ Created by Nick Moore  ############################
//################  for MP2 in ECE 411 at ############################
//################ University of Illinois ############################
//################ Fall 2015              ############################
//####################################################################
//####################################################################
//####################################################################
//#                                                                  #
//#   cache_control_alternate.sv                                     #
//#     Implements the control module for the LC3B cache             #
//#     controls the datapath module for the LC3B cache              #
//#     instantiate both in cache.sv and connect the inputs/outputs  #
//#                                                                  #
//####################################################################

import cache_types::*;

module cache_control
(
	//signals between cache and cpu datapath
	input mem_read,
	input mem_write,
	output logic mem_resp,

	//signals between cache and physical memory
	output logic pmem_read,
	output logic pmem_write,
	input pmem_resp,

	//signals between cache datapath and cache controller
	input clk,
	output logic valid_data,
	output logic dirty_data,
	output logic [1:0] write,
	output logic pmem_wdatamux_sel,		//mux selects
	output logic [1:0] datainmux_sel,	//mux selects
    output logic  pmem_address_mux_sel,
    output logic basemux_sel,
	input cache_tag tag,
	input cache_index index,
	input [1:0] Valid,
	input [1:0] Hit,		//logic determining if there was a hit
	input [1:0] Dirty
);

//#############################################################################################################
//#############################################################################################################
//#############################################################################################################
//############################                                                 ################################
//############################                                                 ################################
//############################              variable declarations              ################################
//############################                                                 ################################
//############################                                                 ################################
//############################                                                 ################################
//#############################################################################################################
//#############################################################################################################
//#############################################################################################################

enum {READY, WRITE_BACK, GET_MEM,GET_MEM_2} state, next_state;
//logic isFull;
logic lru_in,lru_out,lru_write;
logic [1:0] dirty;
logic [1:0] write;
logic [1:0] valid;
logic [1:0] hit;
logic [1:0] datain_sel;
logic recipient;	//the associativity way to write to in the event of a cache miss 

//#############################################################################################################
//#############################################################################################################
//#############################################################################################################
//############################                                                 ################################
//############################                                                 ################################
//############################              variable definitions               ################################
//############################                                                 ################################
//############################                                                 ################################
//############################                                                 ################################
//#############################################################################################################
//#############################################################################################################
//#############################################################################################################


always_comb begin : recipient_determination
	
	if (valid[0] == 1'b0)
		recipient = 1'b0;
	else if (valid[1] == 1'b0)
		recipient = 1'b1;
	else if (lru_out == 1'b0)
		recipient = 1'b0;
	else
		recipient = 1'b1;

end : recipient_determination

//#############################################################################################################
//#############################################################################################################
//#############################################################################################################
//############################                                                 ################################
//############################                                                 ################################
//############################               least recently used               ################################
//############################                     array                       ################################
//############################                                                 ################################
//############################                                                 ################################
//#############################################################################################################
//#############################################################################################################
//#############################################################################################################

array #(.width(1)) lru
(
    .clk(clk),
    .write(lru_write),
    .index(index),
    .datain(lru_in),
    .dataout(lru_out)
);

//#############################################################################################################
//#############################################################################################################
//#############################################################################################################
//############################                                                 ################################
//############################                                                 ################################
//############################                 Next State Logic                ################################
//############################                                                 ################################
//############################                                                 ################################
//############################                                                 ################################
//#############################################################################################################
//#############################################################################################################
//#############################################################################################################
always_ff @ (posedge clk) state <= next_state;


always_comb begin : next_state_logic
	case (state)
		READY: begin
			if (((mem_read == 1 && mem_write == 0) || (mem_read == 0 && mem_write == 1)) && !(hit[1] == 1'b1 || hit[0] == 1'b1)) begin
				if (dirty[recipient] == 1) begin
					next_state = WRITE_BACK;
				end
				else begin
					next_state = GET_MEM;
				end
			end
			else begin
				next_state = READY;
			end
		end
		
		WRITE_BACK:begin
			if (pmem_resp == 1)
				next_state = GET_MEM;
			else
				next_state = WRITE_BACK;
		end
		GET_MEM:begin
			if (pmem_resp == 1)
				next_state = GET_MEM_2;
			else
				next_state = GET_MEM;

		end	
		GET_MEM_2: begin
			next_state = READY;
		end	
	endcase

end : next_state_logic

//#############################################################################################################
//#############################################################################################################
//#############################################################################################################
//############################                                                 ################################
//############################                                                 ################################
//############################               State Control Signals             ################################
//############################                                                 ################################
//############################                                                 ################################
//############################                                                 ################################
//#############################################################################################################
//#############################################################################################################
//#############################################################################################################

always_comb begin : state_control_signals
	mem_resp = 1'b0;
	pmem_read = 1'b0;
	pmem_write = 1'b0;
	valid_data = 1'b0;
	dirty_data = 1'b0;
	write = 2'b00;
	pmem_wdatamux_sel = 1'b0;
	datainmux_sel = 2'b00;
	lru_in = 1'b0;
	lru_write = 1'b0;
    basemux_sel = recipient;
    pmem_address_mux_sel = 1'b0;
   	case (state) 
		READY:	begin
			//if there's a hit and mem_write is high, write to
			//the correct way and respond
			//if there is a hit and mem_write is not high, respond
			if (hit[1] == 1'b1 || hit[0] == 1'b1) begin
				if (mem_write == 1'b1) begin
					//write the data
					dirty_data = 1'b1;
					write[hit[1]] = 1'b1;
					valid_data = 1'b1;

					//set the LRU
					lru_in = ~hit[1];
					lru_write = 1'b1;

					//respond to cpu
					mem_resp = 1'b1;
				end
				if (mem_read == 1'b1) begin
					//set the LRU
					lru_in = ~hit[1];
					lru_write = 1'b1;

					//respond to cpu, as read logic is automatic
					mem_resp = 1'b1;
				end
			end
		end	

		WRITE_BACK: begin
				pmem_wdatamux_sel = recipient;
				pmem_write = 1'b1;
		        pmem_address_mux_sel = 1'b1;
		end

		GET_MEM: begin
			pmem_read = 1'b1;
		end

		GET_MEM_2:	begin
			datainmux_sel[recipient] = 1'b1;
			write[recipient] = 1'b1;
			valid_data = 1'b1;
		end	

		default:	;

	endcase

end : state_control_signals

endmodule : cache_control