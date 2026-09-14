class out_monitor extends uvm_monitor;
        `uvm_component_utils(out_monitor)

        virtual my_if.OUT_MON vif;
        uvm_analysis_port #(my_transaction) ap;

        my_transaction tr;

        function new(string name,uvm_component parent);
                super.new(name,parent);
                ap=new("ap",this);
        endfunction

        function void build_phase(uvm_phase phase);
                super.build_phase(phase);
                if(!uvm_config_db#(virtual my_if)::get(this,"","vif",vif))
                        `uvm_fatal("NOVIF","vif is not set for monitor");
        endfunction

        task run_phase(uvm_phase phase);
                @(vif.cb_out_mon);
                forever
                        collect_output();
        endtask

        task collect_output();
                my_transaction tr;
                begin
                        tr=my_transaction::type_id::create("tr");
                        @(vif.cb_out_mon);
                        tr.awready=vif.cb_out_mon.awready;
                        tr.wready=vif.cb_out_mon.wready;
                        tr.bresp=vif.cb_out_mon.bresp;
                        tr.bvalid=vif.cb_out_mon.bvalid;
                        tr.arready=vif.cb_out_mon.arready;
			tr.rdata=vif.cb_out_mon.rdata;
                        tr.rresp=vif.cb_out_mon.rresp;
                        tr.rvalid=vif.cb_out_mon.rvalid;
                        `uvm_info("INPUT_MONITOR",$sformatf("I_m: rst=%0b, wr_cs=%0b, rd_cs=%0b, wr_en=%0b, rd_en=%0b, data_in=%0h ",vif.cb_out_mon.rst, vif.cb_out_mon.wr_cs, vif.cb_out_mon.rd_cs, vif.cb_out_mon.wr_en, vif.cb_out_mon.rd_en, vif.cb_out_mon.data_in),UVM_NONE)
                        ap.write(tr);
                end
        endtask
endclass
