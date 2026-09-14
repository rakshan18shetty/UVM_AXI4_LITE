class driver extends uvm_driver#(my_transaction,my_transaction);
	`uvm_component_utils(driver)
	virtual my_if vif;

	function new(string name,uvm_component parent);
		super.new(name,parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		if(!uvm_config_db#(virtual my_if)::get(this,"","vif",vif))
			`uvm_fatal("NOVIF","vif not found in driver")
	endfunction

	task run_phase(uvm_phase phase);
		forever begin
			seq_item_port.get_next_item(req);
			drive(req);
			seq_item_port.item_done(rsp);
		end
	endtask

	task drive(my_transaction tr);
		@(vif.cb_drv);
		vif.cb_drv.AWADDR<=tr.AWADDR;
		vif.cb_drv.AWPROT<=tr.AWPROT;
		vif.cb_drv.AWVALID<=tr.AWVALID;
		vif.cb_drv.WDATA<=tr.WDATA;
		vif.cb_drv.WSTRB<=tr.WSTRB;
		vif.cb_drv.WVALID<=tr.WVALID;
		vif.cb_drv.ARADDR<=tr.ARADDR;
		vif.cb_drv.ARPROT<=tr.ARPROT;
		vif.cb_drv.ARVALID<=tr.ARVALID;
		vif.cb_drv.BREADY<=tr.BREADY;
		vif.cb_drv.RREADY<=tr.RREADY;

		`uvm_info("DRV",$sformatf(
			"AW=%0d/%0b/%0d W=%0d/%0b/%0d AR=%0d/%0b/%0d BREADY=%0d RREADY=%0d",
			tr.AWADDR,tr.AWPROT,tr.AWVALID,tr.WDATA,tr.WSTRB,tr.WVALID,
			tr.ARADDR,tr.ARPROT,tr.ARVALID,tr.BREADY,tr.RREADY),UVM_MEDIUM)

		get_resp(tr);
	endtask

	task get_resp(my_transaction tr);
		$cast(rsp,tr.clone());
		rsp.set_id_info(tr);
		rsp.AWREADY=vif.cb_drv.AWREADY;
		rsp.WREADY=vif.cb_drv.WREADY;
		rsp.BVALID=vif.cb_drv.BVALID;
		rsp.ARREADY=vif.cb_drv.ARREADY;
		rsp.RVALID=vif.cb_drv.RVALID;
	endtask
endclass


