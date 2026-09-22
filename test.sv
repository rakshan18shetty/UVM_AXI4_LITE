class test extends uvm_test;
	`uvm_component_utils(test)

	environment env;
	sequences seq;
	write_simul_seq wr_simul;
	read_only_seq rd_a,rd_b,rd_c;
	write_aw_then_w_seq aw_w;
	write_w_then_aw_seq w_aw;
	wr_rd_simul_seq wr_rd;

	function new(string name,uvm_component parent);
		super.new(name,parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		uvm_top.set_timeout(50000);
		uvm_config_db#(uvm_active_passive_enum)::set(this,"env.act","is_active",UVM_ACTIVE);
		uvm_config_db#(uvm_active_passive_enum)::set(this,"env.pass","is_active",UVM_PASSIVE);
		env=environment::type_id::create("env",this);
	endfunction

	function void end_of_elaboration_phase(uvm_phase phase);
		super.end_of_elaboration_phase(phase);
		uvm_top.print_topology();
	endfunction

	task run_phase(uvm_phase phase);
		phase.raise_objection(this);
		run();
		phase.phase_done.set_drain_time(this,20);
		phase.drop_objection(this);
	endtask

	task run();
		test_cases();
		my_transaction::type_id::set_type_override(out_of_range_addr::get_type());
		test_cases();
		my_transaction::type_id::set_type_override(unaligned_addr::get_type());
		test_cases();
	endtask

	task test_cases();
		fork
			begin
				wr_simul=write_simul_seq::type_id::create("wr_simul");
				wr_simul.start(env.act.sqr);
			end 
			begin
				rd_a=read_only_seq::type_id::create("rd_a");
				rd_a.start(env.act.sqr);
			end 
			begin
				aw_w=write_aw_then_w_seq::type_id::create("aw_w");
				aw_w.start(env.act.sqr);
			end 
			begin
				rd_b=read_only_seq::type_id::create("rd_b");
				rd_b.start(env.act.sqr);
			end 
			begin
				w_aw=write_w_then_aw_seq::type_id::create("w_aw");
				w_aw.start(env.act.sqr);
			end 
			begin
				rd_c=read_only_seq::type_id::create("rd_c");
				rd_c.start(env.act.sqr);
			end
			begin
				wr_rd=wr_rd_simul_seq::type_id::create("wr_rd");
				wr_rd.start(env.act.sqr);
			end
			begin
				seq=sequences::type_id::create("seq");
				seq.start(env.act.sqr);
			end 
		join
	endtask
endclass

