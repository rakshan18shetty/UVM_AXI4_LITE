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



class seq_boundary_addr extends sequences;
	`uvm_object_utils(seq_boundary_addr)
	function new(string name="seq_boundary_addr"); 
		super.new(name);
	endfunction

	virtual task randomize_req();
		if(req.randomize() with {
			AWADDR dist{60:=40,64:=40,[0:63]:/20};
			ARADDR dist{60:=40,64:=40,[0:63]:/20};
		})
			log_req();
		else
			`uvm_error("SEQ","SEQ failed");
	endtask
endclass


class seq_ro_wo_region extends sequences;
	`uvm_object_utils(seq_ro_wo_region)
	function new(string name="seq_ro_wo_region");
		super.new(name);
        endfunction

	virtual task randomize_req();
		if(req.randomize() with {
			AWADDR dist{[40:51]:=50,[0:63]:/50};
			ARADDR dist{[52:59]:=50,[0:63]:/50};
		})
			log_req();
		else
			`uvm_error("SEQ","SEQ failed");
	endtask
endclass


class seq_full_handshake extends sequences;
	`uvm_object_utils(seq_full_handshake)
	function new(string name="seq_full_handshake");
		super.new(name);
	endfunction

	virtual task randomize_req();
		if(req.randomize() with{
			AWVALID==1;WVALID==1;ARVALID==1;
			BREADY==1; RREADY==1;
		})
			log_req();
		else
			`uvm_error("SEQ","SEQ failed");
	endtask
endclass

class seq_continuous_write extends sequences;
	`uvm_object_utils(seq_continuous_write)
	function new(string name="seq_continuous_write");
		super.new(name);
	endfunction

	virtual task randomize_req();
		if(req.randomize() with{
			AWVALID==1;WVALID==1;
			ARVALID==0;
			BREADY==1;
		})
			log_req();
		else
			`uvm_error("SEQ","SEQ failed");
	endtask
endclass


class seq_continuous_read extends sequences;
	`uvm_object_utils(seq_continuous_read)
	function new(string name="seq_continuous_read");
		super.new(name);
	endfunction

	virtual task randomize_req();
		if(req.randomize() with{
			ARVALID==1;
			AWVALID==0;WVALID==0;
			RREADY==1;
		})
			log_req();
		else
			`uvm_error("SEQ","SEQ failed");
	endtask
endclass


class seq_concurrent_rw extends sequences;
	`uvm_object_utils(seq_concurrent_rw)
	function new(string name="seq_concurrent_rw");
		super.new(name);
	endfunction

	virtual task randomize_req();
		if(req.randomize() with{
			AWVALID==1;WVALID==1;ARVALID==1;
			BREADY==1;RREADY==1;
		})
			log_req();
		else
			`uvm_error("SEQ","SEQ failed");
	endtask
endclass
