/* MIL-STD-1553 <-> SPI bridge
 * Copyright(c) 2016 Stanislav Zhelnio
 * Licensed under the MIT license (MIT)
 * https://github.com/zhelnio/mil1553-spi
 */

`ifndef MILSPIBLOCK2_INCLUDE
`define MILSPIBLOCK2_INCLUDE

module MilSpiBlock2	(	input logic nRst, clk,							
						ISpi			spi,	
						IMilStd			mil0,
						IMilStd			mil1,
						IPush.master 	pushFromMil0,	//from mil0
						IPush.master 	pushFromMil1,	//from mil1
						IPush.master 	pushFromSpi0,	//from spi0
						IPush.master 	pushFromSpi1,	//from spi1
						IPop.master		popToSpi0,		//to spi0
						IPop.master		popToSpi1,		//to spi1
						IPop.master		popToMil0,		//to mil0
						IPop.master		popToMil1,		//to mil1
						IRingBufferControl.master rcontrolMS0,	// mil0 -> spi
						IRingBufferControl.master rcontrolSM0,	// spi -> mil0
						IRingBufferControl.master rcontrolMS1,	// mil1 -> spi
						IRingBufferControl.master rcontrolSM1,	// spi -> mil1
						output logic nResetRequest);

	parameter SPI_BLOCK_ADDR0 = 8'hAB;
	parameter SPI_BLOCK_ADDR1 = 8'hAC;

	import ServiceProtocol::*;

	logic [1:0] muxKeyPushFromSpi;
	logic [2:0] muxKeyPopToSpi;
	logic enablePushToMil0, enablePushToMil1;

	IPush tMilPush0();
	IPush tMilPush1();
	IPush rSpiPush();
	IPop  tSpiPop();
	IPop  tStatPop0();
	IPop  tStatPop1();

	IMilControl milControl0();
	IMilControl milControl1();
	ILinkSpiControl spiControl();
	IStatusInfoControl statusControl0();
	IStatusInfoControl statusControl1();

	//mil0 -> mem
	LinkMil linkMil0(.nRst(nRst), .clk(clk),
					.pushFromMil(pushFromMil0),     
					.pushToMil(tMilPush0),         
					.milControl(milControl0.slave),
					.mil(mil0));

	//mil1 -> mem
	LinkMil linkMil1(.nRst(nRst), .clk(clk),
					.pushFromMil(pushFromMil1),     
					.pushToMil(tMilPush1),         
					.milControl(milControl1.slave),
					.mil(mil1));

	//mil0 <- busPusher(enablePushToMil0) <- mem
	BusPusher busPusher0(.nRst(nRst), .clk(clk),
						.enable(enablePushToMil0),
						.push(tMilPush0.master),
						.pop(popToMil0));

	//mil1 <- busPusher(enablePushToMil1) <- mem
	BusPusher busPusher1(.nRst(nRst), .clk(clk),
						.enable(enablePushToMil1),
						.push(tMilPush1.master),
						.pop(popToMil1));

	LinkSpi linkSpi(.nRst(nRst), .clk(clk),
					.spi(spi.slave),
					.pushFromSpi(rSpiPush.master),
					.popToSpi(tSpiPop.master),
					.control(spiControl.slave));
	
	//spi -> PushMux(muxKeyPushFromSpi) => mem0, mem1
	PushMux pushMux(.nRst(nRst), .clk(clk),
					.key(muxKeyPushFromSpi),
					.in(rSpiPush),
					.out0(pushFromSpi0),
					.out1(pushFromSpi1));
	
	//spi <- BusMux2(muxKeyPopToSpi) <= mem0, status0, mem1, status1
	BusMux2 busMux(	.nRst(nRst), .clk(clk),
					.key(muxKeyPopToSpi),
					.out(tSpiPop.slave),
					.in0(popToSpi0),
					.in1(tStatPop0.master),
					.in2(popToSpi1),
					.in3(tStatPop1.master));

	//status word generator
	StatusInfo statusInfo0(	.nRst(nRst), .clk(clk),
							.out(tStatPop0.slave),
							.control(statusControl0));
	
	//status word generator
	StatusInfo statusInfo1(	.nRst(nRst), .clk(clk),
							.out(tStatPop1.slave),
							.control(statusControl1));
	
	//checksum error counters
	logic [15:0] errorCounter0;
	logic [15:0] errorCounter1;
	always_ff @ (posedge clk) begin
		if(!nRst)
			{errorCounter0, errorCounter1} <= 0;
		else begin
			errorCounter0 <= errorCounter0 + rcontrolSM0.rollback;
			errorCounter1 <= errorCounter1 + rcontrolSM1.rollback;
		end
	end

	//control interfaces
	assign statusControl0.statusWord0 = rcontrolMS0.memUsed;
	assign statusControl0.statusWord1 = rcontrolSM0.memUsed;
	assign statusControl0.statusWord2 = errorCounter0;
	assign statusControl1.statusWord0 = rcontrolMS1.memUsed;
	assign statusControl1.statusWord1 = rcontrolSM1.memUsed;
	assign statusControl1.statusWord2 = errorCounter1;

	//command processing 
	logic [8:0] confOut;
	assign { muxKeyPushFromSpi, muxKeyPopToSpi, spiControl.outEnable, 
			 nResetRequest, statusControl0.enable, statusControl1.enable } = confOut;
	assign enablePushToMil0 = (rcontrolSM0.memUsed != 0);
	assign enablePushToMil1 = (rcontrolSM1.memUsed != 0);

	assign {rcontrolMS0.open, rcontrolMS0.commit, rcontrolMS0.rollback} = '0;
	assign {rcontrolMS1.open, rcontrolMS1.commit, rcontrolMS1.rollback} = '0;

	logic [5:0] confIn;
	assign confIn[0] = (spiControl.inAddr == SPI_BLOCK_ADDR0);
	assign confIn[1] = (spiControl.inAddr == SPI_BLOCK_ADDR1);
	assign confIn[2] = (spiControl.inCmdCode == TCC_RESET);
	assign confIn[3] = (spiControl.inCmdCode == TCC_SEND_DATA);
	assign confIn[4] = (spiControl.inCmdCode == TCC_RECEIVE_STS);
	assign confIn[5] = (spiControl.inCmdCode == TCC_RECEIVE_DATA);

	always_comb begin
		case(confIn)
			default:	confOut = 9'b101000100; 
			6'b100001:	confOut = 9'b100001100; // TCC_RECEIVE_DATA from SPI_BLOCK_ADDR0
			6'b010001:	confOut = 9'b100011110; // TCC_RECEIVE_STS from SPI_BLOCK_ADDR0
			6'b001001:	confOut = 9'b001000100; // TCC_SEND_DATA from SPI_BLOCK_ADDR0
			6'b000101:	confOut = 9'b101000000; // TCC_RESET from SPI_BLOCK_ADDR0
			6'b100010:	confOut = 9'b100101100; // TCC_RECEIVE_DATA from SPI_BLOCK_ADDR1
			6'b010010:	confOut = 9'b100111101; // TCC_RECEIVE_STS from SPI_BLOCK_ADDR1
			6'b001010:	confOut = 9'b011000100; // TCC_SEND_DATA from SPI_BLOCK_ADDR1
			6'b000110:	confOut = 9'b101000100; // TCC_RESET from SPI_BLOCK_ADDR1
		endcase
	end

	// TCC_SEND_DATA from SPI_BLOCK_ADDR0 
	assign rcontrolSM0.open 	= (confIn == 6'b001001) ? spiControl.inPacketStart	: '0;
	assign rcontrolSM0.commit 	= (confIn == 6'b001001) ? spiControl.inPacketEnd	: '0;
	assign rcontrolSM0.rollback	= (confIn == 6'b001001) ? spiControl.inPacketErr	: '0;

	// TCC_SEND_DATA from SPI_BLOCK_ADDR1
	assign rcontrolSM1.open 	= (confIn == 6'b001010) ? spiControl.inPacketStart	: '0;
	assign rcontrolSM1.commit 	= (confIn == 6'b001010) ? spiControl.inPacketEnd	: '0;
	assign rcontrolSM1.rollback	= (confIn == 6'b001010) ? spiControl.inPacketErr	: '0;

	always_comb begin
		case(confIn)
			default:	begin
							spiControl.outDataSize 	= '0; 
							spiControl.outAddr 		= '0;
							spiControl.outCmdCode 	= TCC_UNKNOWN;
						end
			6'b100001:	begin // TCC_RECEIVE_DATA from SPI_BLOCK_ADDR0
							spiControl.outDataSize	= (spiControl.inSize < rcontrolMS0.memUsed) ? spiControl.inSize : rcontrolMS0.memUsed;	
							spiControl.outAddr 		= SPI_BLOCK_ADDR0;
							spiControl.outCmdCode	= spiControl.inCmdCode;
						end	
			6'b010001:	begin // TCC_RECEIVE_STS from SPI_BLOCK_ADDR0
							spiControl.outDataSize	= statusControl0.statusSize; 
							spiControl.outAddr 		= SPI_BLOCK_ADDR0; 
							spiControl.outCmdCode	= spiControl.inCmdCode;
						end	
			6'b100010:	begin // TCC_RECEIVE_DATA from SPI_BLOCK_ADDR1
							spiControl.outDataSize	= (spiControl.inSize < rcontrolMS1.memUsed) ? spiControl.inSize : rcontrolMS1.memUsed; 
							spiControl.outAddr 		= SPI_BLOCK_ADDR1; 
							spiControl.outCmdCode	= spiControl.inCmdCode;
						end		
			6'b010010:	begin // TCC_RECEIVE_STS from SPI_BLOCK_ADDR1
							spiControl.outDataSize	= statusControl1.statusSize; 
							spiControl.outAddr 		= SPI_BLOCK_ADDR1; 
							spiControl.outCmdCode	= spiControl.inCmdCode;
						end	
		endcase
	end

endmodule

`endif 