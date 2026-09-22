class scoreboard extends uvm_scoreboard;
	`uvm_component_utils(scoreboard)

	uvm_analysis_imp #(my_transaction,scoreboard) in_mon;
	uvm_analysis_imp_out #(my_transaction,scoreboard) out_mon;

	bit [7:0] mem[63:0];
	int TOTAL,MATCH,MISMATCH;

	bit [`AW-1:0] aw_addr_lat;
	bit [`DW-1:0] w_data_lat;
	bit [(`DW/8)-1:0] w_strb_lat;
	bit aw_seen,w_seen;
	bit [`AW-1:0] ar_addr_lat;

	function new(string name,uvm_component parent);
		super.new(name,parent);
		in_mon=new("in_mon",this);
		out_mon=new("out_mon",this);
	endfunction

	function void write_out(my_transaction tx);
	endfunction

	function void write(my_transaction tx);
		if(!tx.rst) begin
			reset_all();
			return;
		end

		if(tx.AWVALID && tx.AWREADY && !aw_seen) begin
			aw_addr_lat=tx.AWADDR;
			aw_seen=1;
		end

		if(tx.WVALID && tx.WREADY && !w_seen) begin
			w_data_lat=tx.WDATA;
			w_strb_lat=tx.WSTRB;
			w_seen=1;
		end

		if(tx.BVALID && tx.BREADY && aw_seen && w_seen) begin
			check_write(aw_addr_lat,w_data_lat,w_strb_lat,tx.BRESP);
			aw_seen=0;
			w_seen=0;
		end

		if(tx.ARVALID && tx.ARREADY)
			ar_addr_lat=tx.ARADDR;

		if(tx.RVALID && tx.RREADY)
			check_read(ar_addr_lat,tx.RDATA,tx.RRESP);
	endfunction

	function void reset_all();
		mem='{default:0};
		aw_addr_lat='0;
		w_data_lat='0;
		w_strb_lat='0;
		ar_addr_lat='0;
		aw_seen=0;
		w_seen=0;
	endfunction

	function bit [1:0] decode(bit [`AW-1:0] addr,bit is_wr);
		bit [3:0] w=addr[5:2];

		if(addr>63)
			return 2'b11;

		if(addr[1:0]!=0)
			return 2'b10;

		if(is_wr && w inside {[10:12]})
			return 2'b10;

		if(!is_wr && w inside {[13:14]})
			return 2'b10;

		return 2'b00;
	endfunction

	function void check_write(
		bit [`AW-1:0] addr,
		bit [`DW-1:0] data,
		bit [(`DW/8)-1:0] strb,
		bit [1:0] act_resp
	);

		bit [1:0] exp=decode(addr,1);

		if(exp==2'b00) begin
			if(strb[0])
				mem[addr+0]=data[7:0];

			if(strb[1])
				mem[addr+1]=data[15:8];

			if(strb[2])
				mem[addr+2]=data[23:16];

			if(strb[3])
				mem[addr+3]=data[31:24];
		end

		log_result(
			exp,2'b0,{`DW{1'b0}},
			act_resp,2'b0,{`DW{1'b0}},
			exp==act_resp
		);
	endfunction

	function void check_read(
		bit [`AW-1:0] addr,
		bit [`DW-1:0] act_data,
		bit [1:0] act_resp
	);

		bit [1:0] exp=decode(addr,0);

		bit [`DW-1:0] exp_data=(exp==2'b00) ?
			{mem[addr+3],mem[addr+2],mem[addr+1],mem[addr]}:'0;

		log_result(
			2'b0,exp,exp_data,
			2'b0,act_resp,act_data,
			(exp==act_resp && exp_data==act_data)
		);
	endfunction

	function void log_result(
		bit [1:0] exp_bresp,
		bit [1:0] exp_rresp,
		bit [`DW-1:0] exp_rdata,
		bit [1:0] act_bresp,
		bit [1:0] act_rresp,
		bit [`DW-1:0] act_rdata,
		bit ok
	);

		++TOTAL;

		if(ok) begin
			++MATCH;
			`uvm_info("SCOREBOARD",$sformatf(
				"DUT: BRESP=%0h, RDATA=%0h, RRESP=%0h\nREF: BRESP=%0h, RDATA=%0h, RRESP=%0h\n\n",
				act_bresp,act_rdata,act_rresp,
				exp_bresp,exp_rdata,exp_rresp
			),UVM_NONE);
		end
		else begin
			++MISMATCH;
			`uvm_info("SCOREBOARD",$sformatf(
				"DUT: BRESP=%0h, RDATA=%0h, RRESP=%0h\nREF: BRESP=%0h, RDATA=%0h, RRESP=%0h\n_______________________________________________________________________________________________________________________\n_",
				act_bresp,act_rdata,act_rresp,
				exp_bresp,exp_rdata,exp_rresp
			),UVM_NONE);
		end
	endfunction

	function void report_phase(uvm_phase phase);
		super.report_phase(phase);
		`uvm_info("SCOREBOARD",$sformatf(
			"\nTotal transactions:%0d matched:%0d failed:%0d",
			TOTAL,MATCH,MISMATCH
		),UVM_NONE);
	endfunction

endclass

