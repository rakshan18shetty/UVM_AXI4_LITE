interface my_if(input logic clk,input logic rst);

	logic[`AW-1:0] AWADDR;
	logic[2:0] AWPROT;
	logic AWVALID;
	logic AWREADY;

	logic[`DW-1:0] WDATA;
	logic[(`DW/8)-1:0] WSTRB;
	logic WVALID;
	logic WREADY;

	logic[1:0] BRESP;
	logic BVALID;
	logic BREADY;

	logic[`AW-1:0] ARADDR;
	logic[2:0] ARPROT;
	logic ARVALID;
	logic  ARREADY;

	logic[`DW-1:0] RDATA;
	logic[1:0] RRESP;
	logic RVALID;
	logic RREADY;

	clocking cb_drv@(posedge clk);
		default input #1 output #1;
		output AWADDR,AWPROT,AWVALID,WDATA,WSTRB,WVALID,BREADY,ARADDR,ARPROT,ARVALID,RREADY; 
		input AWREADY,WREADY,BVALID,ARREADY,RVALID;
	endclocking

	clocking cb_mon@(posedge clk);
		default input #1 output #1;
		input rst,AWADDR,AWPROT,AWVALID,WDATA,WSTRB,WVALID,BREADY,ARADDR,ARPROT,ARVALID,RREADY,AWREADY,WREADY,BRESP,BVALID,ARREADY,RDATA,RRESP,RVALID;
	endclocking

	modport DRV(clocking cb_drv);
	modport MON(clocking cb_mon);
	
	check_reset:assert property (@(posedge clk) !rst |-> ({AWREADY, WREADY, BVALID, BRESP, ARREADY, RVALID, RDATA, RRESP} == 0));
	check_async_reset:assert property (@(negedge clk) !rst |-> ({AWREADY, WREADY, BVALID, BRESP, ARREADY, RVALID, RDATA, RRESP} == 0));
	check_bvalid:assert property (@(posedge clk) disable iff (!rst) (BVALID && !BREADY) |=> BVALID);
	check_bresp:assert property (@(posedge clk) disable iff (!rst) (BVALID && !BREADY) |=> ($stable(BRESP)));
	check_rvalid:assert property (@(posedge clk) disable iff (!rst) (RVALID && !RREADY) |=> RVALID);
	check_rdata:assert property (@(posedge clk) disable iff (!rst) (RVALID && !RREADY) |=> ($stable(RDATA)));
	check_rresp:assert property (@(posedge clk) disable iff (!rst) (RVALID && !RREADY) |=> ($stable(RRESP)));	
	
endinterface

