class scoreboard extends uvm_scoreboard;
	`uvm_component_utils(scoreboard)

	uvm_analysis_imp #(my_transaction,scoreboard) in_mon;
	uvm_analysis_imp_out #(my_transaction,scoreboard) out_mon;

	my_transaction in_q[$],out_q[$];
	my_transaction held;

	int TOTAL,MISMATCH,MATCH;
	bit [7:0] mem[64];
	bit wr_add,wr_data;
	bit count;

	function new(string name,uvm_component parent);
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
		my_transaction inp_mon_xn,out_mon_xn;
		held=my_transaction::type_id::create("held");

		forever begin
			wait(in_q.size()&&out_q.size());

			if(inp_mon_xn==null) begin
				inp_mon_xn=in_q.pop_front();
				void'(out_q.pop_front());
			end
			else begin
				out_mon_xn=out_q.pop_front();
				ref_task(inp_mon_xn);
				validate_outputs(inp_mon_xn,out_mon_xn);
				inp_mon_xn=in_q.pop_front();
			end
		end
	endtask

	task validate_outputs(my_transaction inp,my_transaction out);
		++TOTAL;

		if(inp.compare(out))
			++MATCH;
		else
			++MISMATCH;

		`uvm_info("SCOREBOARD",$sformatf(
			"%s: DUT BRESP=%0h RDATA=%0h RRESP=%0h | REF BRESP=%0h RDATA=%0h RRESP=%0h",
			inp.compare(out)?"MATCH":"MISMATCH",
			out.BRESP,out.RDATA,out.RRESP,
			inp.BRESP,inp.RDATA,inp.RRESP),UVM_NONE);
	endtask

	task ref_task(my_transaction inp);
		if(!inp.rst) begin
			foreach(mem[i])
				mem[i]=0;

			held.RRESP=0;
			held.RDATA=0;
			held.BRESP=0;

			inp.RDATA=held.RDATA;
			inp.RRESP=held.RRESP;
			inp.BRESP=held.BRESP;
		end
		else begin
			inp.RDATA=held.RDATA;
			inp.RRESP=held.RRESP;
			inp.BRESP=held.BRESP;

			rd_task(inp);
			wr_task(inp);
		end
	endtask

	task wr_task(my_transaction tr);
		if(tr.AWREADY&&tr.AWVALID) begin
			held.AWADDR=tr.AWADDR;
			held.AWPROT=tr.AWPROT;
			wr_add=1;
		end

		if(tr.WREADY&&tr.WVALID) begin
			held.WDATA=tr.WDATA;
			held.WSTRB=tr.WSTRB;
			wr_data=1;
		end

		if(wr_add&&wr_data) begin
			if(count) begin
				wr_operation(tr);
				held.BRESP=tr.BRESP;
				wr_add=0;
				wr_data=0;
				count=0;
			end
			else
				count++;
		end
	endtask

	


	task rd_task(my_transaction tr);
		if(tr.ARREADY&&tr.ARVALID) begin
			held.ARADDR=tr.ARADDR;
			held.ARPROT=tr.ARPROT;
			rd_operation(tr);
			held.RRESP=tr.RRESP;
			held.RDATA=tr.RDATA;
		end
	endtask

	task wr_operation(my_transaction tr);
		if(held.AWADDR>63)
			tr.BRESP=2'b11;
		else if((held.AWADDR>`AW'h24&&held.AWADDR<`AW'h34)||held.AWADDR[1:0]!=0)
			tr.BRESP=2'b10;
		else begin
			tr.BRESP=0;

			if(held.AWPROT==0)
				foreach(held.WSTRB[i])
					if(held.WSTRB[i])
						mem[held.AWADDR+i]=held.WDATA[i*8+:8];
		end
	endtask

	task rd_operation(my_transaction tr);
		if(held.ARADDR>63)
			tr.RRESP=2'b11;
		else if((held.ARADDR>`AW'h30&&held.ARADDR<`AW'h3C)||held.ARADDR[1:0]!=0)
			tr.RRESP=2'b10;
		else begin
			tr.RRESP=0;

			if(held.ARPROT==0)
				for(int i=0;i<4;i++)
					tr.RDATA[i*8+:8]=mem[held.ARADDR+i];
		end
	endtask

	function void report_phase(uvm_phase phase);
		super.report_phase(phase);
		`uvm_info("SCOREBOARD",$sformatf(
			"Total=%0d Matched=%0d Failed=%0d",
			TOTAL,MATCH,MISMATCH),UVM_NONE);
	endfunction
endclass

