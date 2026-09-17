/*
class scoreboard extends uvm_scoreboard;

	`uvm_component_utils(scoreboard)

	uvm_analysis_imp #(my_transaction, scoreboard) in_mon;
	uvm_analysis_imp_out #(my_transaction, scoreboard) out_mon;

	my_transaction in_q[$],out_q[$];
	my_transaction held;

	int TOTAL,MISMATCH,MATCH;
	bit [7:0] mem [63:0];
	bit wr_add,wr_data;
	bit count;

	function new(string name, uvm_component parent);
		super.new(name,parent);
		in_mon=new("in_mon",this);
		out_mon=new("out_mon",this);
	endfunction

	virtual function void write(my_transaction tx);
		in_q.push_back(tx);
	endfunction
	
	virtual function void write_out(my_transaction tx);
		out_q.push_back(tx);
	endfunction
	
	task run_phase(uvm_phase phase);
		my_transaction inp_mon_xn;
		my_transaction out_mon_xn;
		held=my_transaction::type_id::create("held");
		forever begin
			wait((in_q.size()!=0)&&(out_q.size()!=0)) begin
				if (inp_mon_xn==null) begin
					inp_mon_xn=in_q.pop_front();
					void'(out_q.pop_front());
				end else begin
					out_mon_xn=out_q.pop_front();
					ref_task(inp_mon_xn);
					validate_outputs(inp_mon_xn,out_mon_xn);
					inp_mon_xn=in_q.pop_front();
				end
			end
		end
	endtask

	task validate_outputs(my_transaction inp, my_transaction out);
		++TOTAL;
		if(inp.compare(out)) begin
			++MATCH;
			`uvm_info("SCOREBOARD",$sformatf("DUT: BRESP=%0h, RDATA=%0h, RRESP=%0h\nREF: BRESP=%0h, RDATA=%0h, RRESP=%0h\n\n", out.BRESP, out.RDATA, out.RRESP, inp.BRESP, inp.RDATA, inp.RRESP),UVM_NONE);
		end else begin
			++MISMATCH;
			`uvm_info("SCOREBOARD",$sformatf("DUT: BRESP=%0h, RDATA=%0h, RRESP=%0h\nREF: BRESP=%0h, RDATA=%0h, RRESP=%0h\n_______________________________________________________________________________________________________________________\n_", out.BRESP, out.RDATA, out.RRESP, inp.BRESP, inp.RDATA, inp.RRESP),UVM_NONE);
		end
	endtask

	task ref_task(my_transaction inp);
		if (!inp.rst) begin
			reset_operation();
			reset_hold();
			feed_held_values(inp);
		end else begin
			feed_held_values(inp);
			rd_task(inp);
			wr_task(inp);
		end
	endtask
	
	task wr_task(my_transaction tr);
		if((!wr_add)&&(tr.AWREADY)&&(tr.AWVALID)) begin held.AWADDR=tr.AWADDR; held.AWPROT=tr.AWPROT; wr_add=1; end
		if((!wr_data)&&(tr.WREADY)&&(tr.WVALID)) begin held.WDATA=tr.WDATA; held.WSTRB=tr.WSTRB; wr_data=1; end
		if((wr_add)&&(wr_data)) if(count==1) begin gen_wr_resp(tr); wr_add=0; wr_data=0; count=0; end else count++;
	endtask

	task rd_task(my_transaction tr);
		if((tr.ARREADY)&&(tr.ARVALID)) begin held.ARADDR =tr.ARADDR; held.ARPROT=tr.ARPROT; gen_rd_resp(tr); end
	endtask

	task gen_wr_resp(my_transaction tr);
		wr_operation(tr);
		hold_wr_values(tr);
	endtask

	task gen_rd_resp(my_transaction tr);
		rd_operation(tr);
		hold_rd_values(tr);
	endtask
	
	task reset_operation();
		for(int i=0;i<64;i++) mem[i]=0;
	endtask

	task wr_operation(my_transaction tr);
		if (held.AWADDR>63) begin
			tr.BRESP=2'b11;
		end else if ((held.AWADDR>`AW'h24&&held.AWADDR<`AW'h34)||(held.AWADDR[1:0]!=00)) begin
			tr.BRESP=2'b10;
		end else begin
			tr.BRESP=00;
			if(held.AWPROT==00) begin
				if(held.WSTRB[3]) mem[held.AWADDR+3]=held.WDATA[31:24];
				if(held.WSTRB[2]) mem[held.AWADDR+2]=held.WDATA[23:16];
				if(held.WSTRB[1]) mem[held.AWADDR+1]=held.WDATA[15:8];
				if(held.WSTRB[0]) mem[held.AWADDR+0]=held.WDATA[7:0];
			end
		end
	endtask

	task rd_operation(my_transaction tr);
		if (held.ARADDR>63) begin
			tr.RRESP=2'b11;
			tr.RDATA={`DW{1'b0}};
		end else if ((held.ARADDR>`AW'h30&&held.ARADDR<`AW'h3C)||(held.ARADDR[1:0]!=00)) begin
			tr.RRESP=2'b10;
			tr.RDATA={`DW{1'b0}};
		end else begin
			tr.RRESP=00;
			if(held.ARPROT==00) begin
				tr.RDATA[7:0]=mem[held.ARADDR];
				tr.RDATA[15:8]=mem[held.ARADDR+1];
				tr.RDATA[23:16]=mem[held.ARADDR+2];
				tr.RDATA[31:24]=mem[held.ARADDR+3];
			end
		end	
	endtask

	task reset_hold();
		held.RRESP=0;
		held.RDATA=0;
		held.BRESP=0;
	endtask

	task hold_wr_values(my_transaction tr);
		held.BRESP=tr.BRESP;
	endtask

	task hold_rd_values(my_transaction tr);
		held.RRESP=tr.RRESP;
		held.RDATA=tr.RDATA;
	endtask

	task feed_held_values(my_transaction tr);
		tr.RDATA=held.RDATA;
		tr.RRESP=held.RRESP;
		tr.BRESP=held.BRESP;
	endtask

	function void report_phase(uvm_phase phase);
		super.report_phase(phase);
		`uvm_info("SCOREBOARD",$sformatf("\nTotal clock Cycles Checked:%0d\n Total cycles matched:%0d\n Total cycles failes:%0d",TOTAL,MATCH,MISMATCH),UVM_NONE);
	endfunction
endclass
*/

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

		if(tx.BVALID && tx.BREADY) begin
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

	function void check_write(bit [`AW-1:0] addr,bit [`DW-1:0] data,
		bit [(`DW/8)-1:0] strb,bit [1:0] act_resp);

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

		log_result(exp,2'b0,{`DW{1'b0}},act_resp,2'b0,{`DW{1'b0}},exp==act_resp);
	endfunction

	function void check_read(bit [`AW-1:0] addr,bit [`DW-1:0] act_data,
		bit [1:0] act_resp);

		bit [1:0] exp=decode(addr,0);
		bit [`DW-1:0] exp_data=(exp==2'b00) ?
			{mem[addr+3],mem[addr+2],mem[addr+1],mem[addr]}:'0;

		log_result(2'b0,exp,exp_data,2'b0,act_resp,act_data,
			(exp==act_resp && exp_data==act_data));
	endfunction

	function void log_result(bit [1:0] exp_bresp,bit [1:0] exp_rresp,
		bit [`DW-1:0] exp_rdata,bit [1:0] act_bresp,bit [1:0] act_rresp,
		bit [`DW-1:0] act_rdata,bit ok);

		++TOTAL;

		if(ok) begin
			++MATCH;
			`uvm_info("SCOREBOARD",$sformatf(
				"DUT: BRESP=%0h, RDATA=%0h, RRESP=%0h\nREF: BRESP=%0h, RDATA=%0h, RRESP=%0h\n\n",
				act_bresp,act_rdata,act_rresp,exp_bresp,exp_rdata,exp_rresp),UVM_NONE);
		end
		else begin
			++MISMATCH;
			`uvm_info("SCOREBOARD",$sformatf(
				"DUT: BRESP=%0h, RDATA=%0h, RRESP=%0h\nREF: BRESP=%0h, RDATA=%0h, RRESP=%0h\n_______________________________________________________________________________________________________________________\n_",
				act_bresp,act_rdata,act_rresp,exp_bresp,exp_rdata,exp_rresp),UVM_NONE);
		end
	endfunction

	function void report_phase(uvm_phase phase);
		super.report_phase(phase);
		`uvm_info("SCOREBOARD",$sformatf(
			"\nTotal transactions:%0d matched:%0d failed:%0d",
			TOTAL,MATCH,MISMATCH),UVM_NONE);
	endfunction
endclass

