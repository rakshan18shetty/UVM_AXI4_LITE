class act_agent extends uvm_agent;
	`uvm_component_utils(act_agent)
	driver drv;
	my_sequencer sqr;
	in_monitor in_mon;

	function new(string name,uvm_component parent);
		super.new(name,parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		in_mon=in_monitor::type_id::create("in_mon",this);
		drv=driver::type_id::create("drv",this);
		sqr=my_sequencer::type_id::create("sqr",this);
	endfunction

	function void connect_phase(uvm_phase phase);
		drv.seq_item_port.connect(sqr.seq_item_export);
	endfunction
endclass
