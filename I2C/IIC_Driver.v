`timescale 1ns / 1ps
module IIC_Driver #(
    parameter P_Clk_Freq    = 32'h50_000_000,
    parameter P_IIC_Freq    = 18'd100_000   
)(
    input           I_Clk       ,
    input           I_Rst       ,
    input           I_Exec      ,
    input           I_Bit_Ctrl  ,
    input           I_Rh_Wl     ,
    input  [15:0]   I_Addr      ,
    input  [ 6:0]   I_SAddr_W   ,
    input  [ 6:0]   I_SAddr_R   ,
    input  [ 7:0]   I_Num       ,
    input  [ 7:0]   I_Data_W    ,
    output [ 7:0]   O_Data_R    ,
    output          O_Data_Valid,
    output          O_Done      ,
    output          O_Ack       ,
    output          O_Scl       ,
    inout           IO_Sda      ,
    output          O_Clk        
);

localparam  P_Idle      = 8'b0000_0001,
            P_Sladdr    = 8'b0000_0010,
            P_Addr16    = 8'b0000_0100,
            P_Addr8     = 8'b0000_1000,
            P_Data_W    = 8'b0001_0000,
            P_Addr_R    = 8'b0010_0000,
            P_Data_R    = 8'b0100_0000,
            P_Stop      = 8'b1000_0000;

reg [7:0]   R_Cur_State     = 8'b0;
reg [7:0]   R_Next_State    = 8'b0;
reg         R_Sda_Dir       = 1'b0;
reg         R_Sda_Out       = 1'b0;
reg [15:0]   R_Clk_Cnt      = 16'b0;
reg         R_Clk           = 1'b0;
reg         R_Scl           = 1'b1;
reg         R_Ack           = 1'b0;
reg         R_BitCtrl       = 1'b0;
reg [7:0]   R_Data          = 8'd0;
reg [7:0]   R_Dout          = 8'd0;
reg [7:0]   R_Data_Cnt      = 8'd0;
reg [7:0]   R_Data_Num      = 8'd0;
reg         R_Rh_Wl         = 1'b0;
reg         R_Done          = 1'b0;
reg         R_Data_Valid    = 1'b0;
wire        W_Sda_In;
wire [15:0]  R_Clk_Divide;

assign IO_Sda = R_Sda_Dir ? R_Sda_Out : 1'bz;
assign W_Sda_In = IO_Sda;
assign R_Clk_Divide = (P_Clk_Freq/P_IIC_Freq) >> 2'd2;
assign O_Scl = R_Scl;
assign O_Ack = R_Ack;
assign O_Data_R=R_Dout;
assign O_Clk = R_Clk;
assign O_Done = (R_Cur_State== P_Stop)&&(R_Done==1);
assign O_Data_Valid = R_Data_Valid;
always @(posedge I_Clk) begin
    if(I_Rst) begin
        R_Clk <= 1'b0;
        R_Clk_Cnt <= 16'd0;
    end
    else if(R_Clk_Cnt == R_Clk_Divide[15:1] - 1'b1) begin
        R_Clk_Cnt <= 16'd0;
        R_Clk <= ~R_Clk;
    end
    else begin
        R_Clk <= R_Clk;
        R_Clk_Cnt <= R_Clk_Cnt + 1'b1;
    end
end

always @(posedge R_Clk) begin
    if(I_Rst) begin
        R_Cur_State <= P_Idle;
    end
    else begin
        R_Cur_State <= R_Next_State;
    end
end

always @(*) begin
    R_Next_State = P_Idle;
    case(R_Cur_State)
    P_Idle  :begin
        if(I_Exec) begin
            R_Next_State = P_Sladdr;
        end
        else begin
            R_Next_State = P_Idle;
        end
    end
    P_Sladdr:begin
        if(R_Done) begin
            if(R_BitCtrl) begin
                R_Next_State = P_Addr16;
            end
            else begin
                R_Next_State = P_Addr8;
            end
        end
        else begin
            R_Next_State = P_Sladdr;
        end
    end
    P_Addr16:begin
        if(R_Done) begin
            R_Next_State = P_Addr8;
        end
        else begin
            R_Next_State = P_Addr16;
        end
    end
    P_Addr8 :begin
        if(R_Done) begin
            if(R_Rh_Wl == 1'b0) begin
                R_Next_State = P_Data_W;
            end
            else begin
                R_Next_State = P_Addr_R;
            end
        end
        else begin
            R_Next_State = P_Addr8;
        end
    end
    P_Data_W:begin
        if(R_Done) begin
            R_Next_State = P_Stop;
        end
        else begin
            R_Next_State = P_Data_W;
        end
    end
    P_Addr_R:begin
        if(R_Done) begin
            R_Next_State = P_Data_R;
        end
        else begin
            R_Next_State = P_Addr_R;
        end
    end
    P_Data_R:begin
        if(R_Done && (R_Data_Num == R_Data_Cnt || R_Data_Num == 8'd0)) begin
            R_Next_State = P_Stop;
        end
        else begin
            R_Next_State = P_Data_R;
        end
    end
    P_Stop  :begin
        if(R_Done) begin
            R_Next_State = P_Idle;
        end
        else begin
            R_Next_State = P_Stop;
        end
    end
    endcase
end

reg [6:0]   R_Cnt       = 7'd0;
reg [15:0]  R_Addr      = 16'd0;
reg [ 7:0]  R_Data_W    = 8'd0;

always @(posedge R_Clk) begin
    if(I_Rst) begin
        R_Cnt   <= 7'd0;
        R_Scl   <= 1'b1;
        R_Rh_Wl <= 1'b0;
        R_Addr  <= 16'd0;
        R_Data_W<= 8'd0;
        R_Ack   <= 1'b0;
        R_Done  <= 1'b1;
        R_BitCtrl <= 1'b0;
        R_Data   <= 8'd0;
        R_Dout   <= 8'd0;
        R_Data_Cnt <= 8'd0;
        R_Data_Num <= 8'd0;
    end
    else begin
	R_Cnt <= R_Cnt + 1'b1;
	R_Done <= 1'b0;
    R_Data_Valid <= 1'b0;
    case(R_Cur_State)
    P_Idle  :begin
        R_Scl <= 1'b1;
        R_Sda_Out <= 1'b1;
        R_Sda_Dir <= 1'b1;
        R_Cnt <= 7'd0;
        R_Done <= 1'b0;
        R_Data_Cnt <= 8'd0;
        R_Data   <= 8'd0;
        if(I_Exec) begin
            R_Rh_Wl <= I_Rh_Wl;
            R_Addr <= I_Addr;
            R_Data_W <= I_Data_W;
            R_Ack <= 1'b0;
            R_BitCtrl <= I_Bit_Ctrl;
            R_Data_Num <= I_Num;
            
        end
    end
    P_Sladdr:begin
        case(R_Cnt) 
            7'd1 : R_Sda_Out    <= 1'b0;
            7'd3 : R_Scl        <= 1'b0;
            7'd4 : R_Sda_Out    <= I_SAddr_W[6];
            7'd5 : R_Scl        <= 1'b1;
            7'd7 : R_Scl        <= 1'b0;
            7'd8 : R_Sda_Out    <= I_SAddr_W[5];
            7'd9 : R_Scl        <= 1'b1;
            7'd11: R_Scl        <= 1'b0;
            7'd12: R_Sda_Out    <= I_SAddr_W[4];
            7'd13: R_Scl        <= 1'b1;
            7'd15: R_Scl        <= 1'b0;
            7'd16: R_Sda_Out    <= I_SAddr_W[3];
            7'd17: R_Scl        <= 1'b1;
            7'd19: R_Scl        <= 1'b0;
            7'd20: R_Sda_Out    <= I_SAddr_W[2];
            7'd21: R_Scl        <= 1'b1;
            7'd23: R_Scl        <= 1'b0;
            7'd24: R_Sda_Out    <= I_SAddr_W[1];
            7'd25: R_Scl        <= 1'b1;
            7'd27: R_Scl        <= 1'b0;
            7'd28: R_Sda_Out    <= I_SAddr_W[0];
            7'd29: R_Scl        <= 1'b1;
            7'd31: R_Scl        <= 1'b0;
            7'd32: R_Sda_Out    <= 1'b0;//write
            7'd33: R_Scl        <= 1'b1;
            7'd35: R_Scl        <= 1'b0;
            7'd36: begin
                R_Sda_Dir       <= 1'b0;
                R_Sda_Out       <= 1'b1;
            end
            7'd37: R_Scl        <= 1'b1;
            7'd38: begin
                R_Done          <= 1'b1;
                R_Ack           <= W_Sda_In;
            end
            7'd39: begin
                R_Scl           <= 1'b0;
                R_Cnt           <= 10'd0;      
            end 
        endcase
    end
    P_Addr16:begin
        case(R_Cnt) 
        7'd0 : begin
            R_Sda_Dir <= 1'b1;
            R_Sda_Out <= R_Addr[15];
        end
        7'd1 : R_Scl  <= 1'b1;
        7'd3 : R_Scl  <= 1'b0;
        7'd4 : R_Sda_Out <= R_Addr[14];
        7'd5 : R_Scl  <= 1'b1;
        7'd7 : R_Scl  <= 1'b0;
        7'd8 : R_Sda_Out <= R_Addr[13];
        7'd9 : R_Scl  <= 1'b1;
        7'd11: R_Scl  <= 1'b0;
        7'd12: R_Sda_Out <= R_Addr[12];
        7'd13: R_Scl  <= 1'b1;
        7'd15: R_Scl  <= 1'b0;
        7'd16: R_Sda_Out <= R_Addr[11];
        7'd17: R_Scl  <= 1'b1;
        7'd19: R_Scl  <= 1'b0;
        7'd20: R_Sda_Out <= R_Addr[10];
        7'd21: R_Scl  <= 1'b1;
        7'd23: R_Scl  <= 1'b0;
        7'd24: R_Sda_Out <= R_Addr[9];
        7'd25: R_Scl  <= 1'b1;
        7'd27: R_Scl  <= 1'b0;
        7'd28: R_Sda_Out <= R_Addr[8];
        7'd29: R_Scl  <= 1'b1;
        7'd31: R_Scl  <= 1'b0;
        7'd32: begin
            R_Sda_Dir <= 1'b0;
            R_Sda_Out <= 1'b1;
        end
        7'd33: R_Scl  <= 1'b1;
        7'd34: begin
            R_Done <= 1'b1;
            R_Ack <= W_Sda_In;
        end
        7'd35: begin
            R_Scl <= 1'b0;
            R_Cnt <= 10'd0;
        end
        default:;
        endcase
    end
    P_Addr8:begin
        case(R_Cnt) 
        7'd0 : begin
            R_Sda_Dir <= 1'b1;
            R_Sda_Out <= R_Addr[7];
        end
        7'd1 : R_Scl  <= 1'b1;
        7'd3 : R_Scl  <= 1'b0;
        7'd4 : R_Sda_Out <= R_Addr[6];
        7'd5 : R_Scl  <= 1'b1;
        7'd7 : R_Scl  <= 1'b0;
        7'd8 : R_Sda_Out <= R_Addr[5];
        7'd9 : R_Scl  <= 1'b1;
        7'd11: R_Scl  <= 1'b0;
        7'd12: R_Sda_Out <= R_Addr[4];
        7'd13: R_Scl  <= 1'b1;
        7'd15: R_Scl  <= 1'b0;
        7'd16: R_Sda_Out <= R_Addr[3];
        7'd17: R_Scl  <= 1'b1;
        7'd19: R_Scl  <= 1'b0;
        7'd20: R_Sda_Out <= R_Addr[2];
        7'd21: R_Scl  <= 1'b1;
        7'd23: R_Scl  <= 1'b0;
        7'd24: R_Sda_Out <= R_Addr[1];
        7'd25: R_Scl  <= 1'b1;
        7'd27: R_Scl  <= 1'b0;
        7'd28: R_Sda_Out <= R_Addr[0];
        7'd29: R_Scl  <= 1'b1;
        7'd31: R_Scl  <= 1'b0;
        7'd32: begin
            R_Sda_Dir <= 1'b0;
            R_Sda_Out <= 1'b1;
        end
        7'd33: R_Scl  <= 1'b1;
        7'd34: begin
            R_Done <= 1'b1;
            R_Ack <= W_Sda_In;
        end
        7'd35: begin
            R_Scl <= 1'b0;
            R_Cnt <= 10'd0;
        end
        default:;
        endcase
    end
    P_Data_W:begin
        case(R_Cnt) 
        7'd0 : begin
            R_Sda_Out <= R_Data_W[7];
            R_Sda_Dir <= 1'b1;
        end
        7'd1 : R_Scl  <= 1'b1;
        7'd3 : R_Scl  <= 1'b0;
        7'd4 : R_Sda_Out <= R_Data_W[6];
        7'd5 : R_Scl  <= 1'b1;
        7'd7 : R_Scl  <= 1'b0;
        7'd8 : R_Sda_Out <= R_Data_W[5];
        7'd9 : R_Scl  <= 1'b1;
        7'd11: R_Scl  <= 1'b0;
        7'd12: R_Sda_Out <= R_Data_W[4];
        7'd13: R_Scl  <= 1'b1;
        7'd15: R_Scl  <= 1'b0;
        7'd16: R_Sda_Out <= R_Data_W[3];
        7'd17: R_Scl  <= 1'b1;
        7'd19: R_Scl  <= 1'b0;
        7'd20: R_Sda_Out <= R_Data_W[2];
        7'd21: R_Scl  <= 1'b1;
        7'd23: R_Scl  <= 1'b0;
        7'd24: R_Sda_Out <= R_Data_W[1];
        7'd25: R_Scl  <= 1'b1;
        7'd27: R_Scl  <= 1'b0;
        7'd28: R_Sda_Out <= R_Data_W[0];
        7'd29: R_Scl  <= 1'b1;
        7'd31: R_Scl  <= 1'b0;
        7'd32: begin
            R_Sda_Dir <= 1'b0;
            R_Sda_Out <= 1'b1;
        end
        7'd33: R_Scl  <= 1'b1;
        7'd34: begin
            R_Done <= 1'b1;
            if(W_Sda_In == 1'b1) begin
                R_Ack = 1'b1;
            end
        end
        7'd35: begin
            R_Scl <= 1'b0;
            R_Cnt <= 10'd0;
        end
        default:;
        endcase
    end
    P_Addr_R:begin
        case(R_Cnt)
            7'd0 :begin
                R_Sda_Dir <= 1'b1;
                R_Sda_Out <= 1'b1;
            end
            7'd1 : R_Scl      <= 1'b1;
            7'd2 : R_Sda_Out  <= 1'b0;
            7'd3 : R_Scl      <= 1'b0;
            7'd4 : R_Sda_Out  <= I_SAddr_R[6];
            7'd5 : R_Scl      <= 1'b1;
            7'd7 : R_Scl      <= 1'b0;
            7'd8 : R_Sda_Out  <= I_SAddr_R[5];
            7'd9 : R_Scl      <= 1'b1;
            7'd11 : R_Scl     <= 1'b0;
            7'd12: R_Sda_Out  <= I_SAddr_R[4];
            7'd13: R_Scl      <= 1'b1;
            7'd15: R_Scl      <= 1'b0;
            7'd16: R_Sda_Out  <= I_SAddr_R[3];
            7'd17: R_Scl      <= 1'b1;
            7'd19: R_Scl      <= 1'b0;
            7'd20: R_Sda_Out  <= I_SAddr_R[2];
            7'd21: R_Scl      <= 1'b1;
            7'd23: R_Scl      <= 1'b0;
            7'd24: R_Sda_Out  <= I_SAddr_R[1];
            7'd25: R_Scl      <= 1'b1;
            7'd27: R_Scl      <= 1'b0;
            7'd28: R_Sda_Out  <= I_SAddr_R[0];
            7'd29: R_Scl      <= 1'b1;
            7'd31: R_Scl      <= 1'b0;
            7'd32: R_Sda_Out  <= 1'b1;
            7'd33: R_Scl      <= 1'b1;
            7'd35: R_Scl      <= 1'b0;
            7'd36: begin
                R_Sda_Dir <= 1'b0;
                R_Sda_Out <= 1'b1;
            end
            7'd37: R_Scl      <= 1'b1;
            7'd38: begin
                R_Done <= 1'b1;
                if(W_Sda_In == 1'b1) begin
                    R_Ack <= 1'b1;
                end
            end
            7'd39:begin
                R_Scl <= 1'b0;
                R_Cnt <= 10'd0;
            end
            default:;
        endcase
    end
    P_Data_R:begin
        case(R_Cnt)
            7'd0 : R_Sda_Dir  <= 1'b0;
            7'd1 : begin
                //R_Data[7]   <= W_Sda_In;
                R_Scl         <= 1'b1;
            end
			7'd2 : R_Data[7]   <= W_Sda_In;
            7'd3 : R_Scl      <= 1'b0;
            7'd5 : begin
               // R_Data[6]   <= W_Sda_In;
                R_Scl         <= 1'b1;
            end
			7'd6 : R_Data[6]   <= W_Sda_In;
            7'd7 : R_Scl      <= 1'b0;
            7'd9 : begin
               // R_Data[5]   <= W_Sda_In;
                R_Scl         <= 1'b1;
            end
			7'd10 : R_Data[5]   <= W_Sda_In;
            7'd11: R_Scl      <= 1'b0;
            7'd13: begin
               // R_Data[4]   <= W_Sda_In;
                R_Scl         <= 1'b1;
            end
			7'd14 : R_Data[4]   <= W_Sda_In;
            7'd15: R_Scl      <= 1'b0;
            7'd17: begin
               // R_Data[3]   <= W_Sda_In;
                R_Scl         <= 1'b1;
            end
			7'd18 : R_Data[3]   <= W_Sda_In;
            7'd19: R_Scl      <= 1'b0;
            7'd21: begin
                //R_Data[2]   <= W_Sda_In;
                R_Scl         <= 1'b1;
            end
			7'd22 : R_Data[2]   <= W_Sda_In;
            7'd23: R_Scl      <= 1'b0;
            7'd25: begin
               // R_Data[1]   <= W_Sda_In;
                R_Scl         <= 1'b1;
            end
			7'd26 : R_Data[1]   <= W_Sda_In;
            7'd27 : R_Scl     <= 1'b0;
            7'd29 : begin
                //R_Data[0]   <= W_Sda_In;
                R_Scl         <= 1'b1;
            end
			7'd30 : R_Data[0]   <= W_Sda_In;
            7'd31 : R_Scl     <= 1'b0;
            7'd32 : begin
                R_Sda_Dir     <= 1'b1;
				if(R_Data_Cnt==R_Data_Num-1)begin
					R_Sda_Out<=1'b1;
				end
                else begin
                    R_Sda_Out     <= 1'b0;
                end
            end
            7'd33 : R_Scl   <= 1'b1;
            7'd34 : begin
                R_Done <= 1'b1;
                R_Data_Cnt  <= R_Data_Cnt + 1'b1;
            end
            7'd35 : begin
                R_Scl       <= 1'b0;
                R_Cnt       <= 10'b0;
                R_Dout      <= R_Data;
                R_Data_Valid <= 1'b1;
            end
            default:;
        endcase
    end
    P_Stop:begin
        case(R_Cnt)
            7'd0 :begin
                R_Sda_Dir     <= 1'b1;
                R_Sda_Out     <= 1'b0;
            end
            7'd1 : R_Scl      <= 1'b1;
            7'd3 : R_Sda_Out  <= 1'b1;
            7'd15: R_Done  <= 1'b1;
            7'd16: begin
                R_Cnt <= 10'd0;
                R_Done <= 1'b1;
            end
            default:;
        endcase
    end
    endcase  
    end
end

ila_1 ila_1_inst (
	.clk(I_Clk), // input wire clk


	.probe0({R_Cur_State,R_Next_State,R_Done,R_Cnt,R_Data_Valid,R_Data,O_Scl,R_Addr,R_Sda_Out,W_Sda_In,R_Clk,R_Sda_Dir}) // input wire [49:0] probe0
);
endmodule


