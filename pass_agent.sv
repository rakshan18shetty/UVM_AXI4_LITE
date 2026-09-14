class pass_agent extends uvm_agent;
	`uvm_component_utils(pass_agent)
	out_monitor out_mon;

	function new(string name,uvm_component parent);
		super.new(name,parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		out_mon=out_monitor::type_id::create("out_mon",this);
	endfunction
endclass

