class sequences extends uvm_sequence #(my_transaction,my_transaction);
	`uvm_object_utils(sequences)

	bit aw_done,w_done,ar_done;

	function new(string name="seq");
		super.new(name);
	endfunction

	task body();
		repeat(`n) begin
			req=my_transaction::type_id::create("req");
			start_item(req);
			gen_next();
			finish_item(req);
			get_response(rsp);
		end
	endtask

	task gen_next();
		if(rsp==null) begin
			randomize_req();
			return;
		end

		aw_done|=(rsp.AWREADY&&rsp.AWVALID);
		w_done|=(rsp.WREADY&&rsp.WVALID);
		ar_done=(rsp.ARREADY&&rsp.ARVALID);

		if(aw_done&&w_done&&ar_done) begin
			aw_done=0;
			w_done=0;
			randomize_req();
		end
		else if(req.randomize() with {
			aw_done -> (AWADDR==rsp.AWADDR&&AWVALID==rsp.AWVALID);
			w_done -> (WDATA==rsp.WDATA&&WSTRB==rsp.WSTRB&&WVALID==rsp.WVALID);
			ar_done -> (ARADDR==rsp.ARADDR&&ARVALID==rsp.ARVALID);
		})
			log_req();
		else
			`uvm_error("SEQ","SEQ failed");
	endtask

	task randomize_req();
		if(req.randomize())
			log_req();
		else
			`uvm_error("SEQ","SEQ failed");
	endtask

	task log_req();
		`uvm_info("SEQ",$sformatf(
			"AWADDR=%0d,AWPROT=%0b,AWVALID=%0d,WDATA=%0d,WSTRB=%0b,WVALID=%0d,ARADDR=%0d,ARPROT=%0b,ARVALID=%0d,RREADY=%0d",
			req.AWADDR,req.AWPROT,req.AWVALID,req.WDATA,req.WSTRB,req.WVALID,
			req.ARADDR,req.ARPROT,req.ARVALID,req.RREADY),UVM_MEDIUM);
	endtask
endclass

class read_only_seq extends sequences;
	`uvm_object_utils(read_only_seq)

	function new(string name="read_only_seq");
		super.new(name);
	endfunction

	task body();
		repeat(`n) begin
			req=my_transaction::type_id::create("req");
			start_item(req);
			gen_next();
			force_read_only();
			log_req();
			finish_item(req);
			get_response(rsp);
		end
	endtask

	task force_read_only();
		req.AWVALID=1'b0;
		req.WVALID=1'b0;
		req.ARVALID=1'b1;
	endtask
endclass

class write_simul_seq extends sequences;
	`uvm_object_utils(write_simul_seq)

	function new(string name="write_simul_seq");
		super.new(name);
	endfunction

	task body();
		repeat(`n) begin
			req=my_transaction::type_id::create("req");
			start_item(req);
			gen_next();
			force_write_simul();
			log_req();
			finish_item(req);
			get_response(rsp);
		end
	endtask

	task force_write_simul();
		req.AWVALID=1'b1;
		req.WVALID=1'b1;
		req.ARVALID=1'b0;
	endtask
endclass

class wr_rd_simul_seq extends sequences;
	`uvm_object_utils(wr_rd_simul_seq)

	function new(string name="wr_rd_simul_seq");
		super.new(name);
	endfunction

	task body();
		repeat(`n) begin
			req=my_transaction::type_id::create("req");
			start_item(req);
			gen_next();
			force_all_valid();
			log_req();
			finish_item(req);
			get_response(rsp);
		end
	endtask

	task force_all_valid();
		req.AWVALID=1'b1;
		req.WVALID=1'b1;
		req.ARVALID=1'b1;
	endtask
endclass

class write_aw_then_w_seq extends sequences;
	`uvm_object_utils(write_aw_then_w_seq)
	int step;

	function new(string name="write_aw_then_w_seq");
		super.new(name);
	endfunction

	task body();
		repeat(`n) begin
			req=my_transaction::type_id::create("req");
			start_item(req);
			gen_next();
			force_aw_then_w();
			log_req();
			finish_item(req);
			get_response(rsp);
		end
	endtask

	task force_aw_then_w();
		req.ARVALID=1'b0;
		req.AWVALID=1'b0;
		req.WVALID=1'b0;

		if(rsp!=null) begin
			if(step==0) begin
				if(rsp.AWREADY==1'b1) begin
					step++;
					req.AWVALID=1'b1;
				end
			end
			else if(step==5) begin
				if(rsp.WREADY==1'b1) begin
					req.WVALID=1'b1;
					step=0;
				end
			end
			else if(step inside {[1:4],6,7}) begin
				step++;
			end
			else if(step==8) begin
				step=0;
			end
		end
	endtask
endclass

class write_w_then_aw_seq extends sequences;
	`uvm_object_utils(write_w_then_aw_seq)
	int step;

	function new(string name="write_w_then_aw_seq");
		super.new(name);
	endfunction

	task body();
		repeat(`n) begin
			req=my_transaction::type_id::create("req");
			start_item(req);
			gen_next();
			force_w_then_aw();
			log_req();
			finish_item(req);
			get_response(rsp);
		end
	endtask

	task force_w_then_aw();
		req.ARVALID=1'b0;
		req.AWVALID=1'b0;
		req.WVALID=1'b0;

		if(rsp!=null) begin
			if(step==0) begin
				if(rsp.WREADY==1'b1) begin
					step++;
					req.WVALID=1'b1;
				end
			end
			else if(step==5) begin
				if(rsp.AWREADY==1'b1) begin
					req.AWVALID=1'b1;
					step++;
				end
			end
			else if(step inside {[1:4],6,7}) begin
				step++;
			end
			else if(step==8) begin
				step=0;
			end
		end
	endtask
endclass

