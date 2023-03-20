module top (
    input clk,
    input [1:0] btn,
    input ck_io0,
    input ck_io1,
    input ck_io2,
    input ck_io3,
    output ck_io4,
    output ck_io5,
    output ck_io6,
    output ck_io7,
);

  wire bufg;
  BUFG bufgctrl (
      .I(clk),
      .O(bufg)
  );

  ram_fifo #(.DAT_WID(4), .FIFO_DEPTH(65535/2), .FIFO_DEPTH_WID(16) ) rf (
	  .clk(bufg),
	  .rst(0),
	  .read_enable(btn[0]),
	  .write_enable(btn[1]),
	  .write_dat({ck_io0,ck_io1,ck_io2,ck_io3}),
	  .read_dat({ck_io4,ck_io5,ck_io6,ck_io7})
  );
endmodule
