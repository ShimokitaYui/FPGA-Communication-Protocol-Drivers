module RS232_Send #(
    parameter P_CLK_FREQ  = 5000_0000,    //Clk_Freq
    parameter P_RS232_BPS = 115200        //Bps
)(
    input       I_Clk   ,
    input       I_Rst   ,

    input       I_En    ,
    input [7:0] I_Data  ,
    output reg  O_Txd   ,
    output      O_Busy  
);

parameter P_BPS_Cnt = P_CLK_FREQ / P_RS232_BPS;
reg [15:0] R_Clk_Cnt = 16'd0;
reg [7:0] R_Data = 8'd0;
reg [3:0] R_Tx_Cnt = 4'd0;
reg R_En_D0 = 1'b0;
reg R_En_D1 = 1'b0;
reg R_Tx_Flag = 1'b0;
reg R_Busy = 1'b0;
//reg R_Busy_Flag = 1'b0;
wire W_En_Flag;
reg [3:0] R_Tx_Cnt_D0 = 4'd0;
reg [3:0] R_Tx_Cnt_D1 = 4'd0;

assign W_En_Flag = (R_En_D0 & ~R_En_D1);
assign O_Busy = (R_Busy | I_En);

always @(posedge I_Clk) begin
    if(I_Rst) begin
        R_En_D0 <= 1'b0;
        R_En_D1 <= 1'b0;
    end
    else begin
        R_En_D0 <= I_En;
        R_En_D1 <= R_En_D0;
    end
end

always @(posedge I_Clk) begin
    if(I_Rst) 
        R_Busy <= 1'b0;
    else if(I_En) 
        R_Busy <= 1'b1;
    else if((R_Tx_Cnt == 4'd9 && (R_Clk_Cnt == P_BPS_Cnt * 15/ 16))) 
        R_Busy <= 1'b0;
    else
        R_Busy <= R_Busy;
end

always @(posedge I_Clk) begin
    if(I_Rst) begin
        R_Tx_Flag <= 1'b0;
        R_Data <= 8'd0;
    end
    else if(W_En_Flag) begin
        R_Tx_Flag <= 1'b1;
        R_Data <= I_Data;
    end
    else if((R_Tx_Cnt == 4'd9 && (R_Clk_Cnt == P_BPS_Cnt * 15/ 16))) begin
        R_Tx_Flag <= 1'b0;
        R_Data <= 8'd0;
    end
    else begin
        R_Tx_Flag <= R_Tx_Flag;
        R_Data <= R_Data;
    end
end

always @(posedge I_Clk) begin
    if(I_Rst)
        R_Clk_Cnt <= 16'd0;
    else if(R_Tx_Flag) begin
        if(R_Clk_Cnt < P_BPS_Cnt - 1) 
            R_Clk_Cnt <= R_Clk_Cnt + 1'b1;
        else
            R_Clk_Cnt <= 16'd0;
    end
    else 
        R_Clk_Cnt <= 16'd0;
end

always @(posedge I_Clk) begin
    if(I_Rst)
        R_Tx_Cnt <= 4'd0;
    else if(R_Tx_Flag) begin
        if(R_Clk_Cnt == P_BPS_Cnt - 1)
            R_Tx_Cnt <= R_Tx_Cnt + 1'b1;
        else
            R_Tx_Cnt <= R_Tx_Cnt;
    end
    else
        R_Tx_Cnt <= 4'd0;
end

always @(posedge I_Clk) begin
    if(I_Rst)
        O_Txd <= 1'b1;
    else if(R_Tx_Flag)begin
        case(R_Tx_Cnt)
        4'd0 : O_Txd <= 1'b0;
        4'd1 : O_Txd <= R_Data[0];
        4'd2 : O_Txd <= R_Data[1];
        4'd3 : O_Txd <= R_Data[2];
        4'd4 : O_Txd <= R_Data[3];
        4'd5 : O_Txd <= R_Data[4];
        4'd6 : O_Txd <= R_Data[5];
        4'd7 : O_Txd <= R_Data[6];
        4'd8 : O_Txd <= R_Data[7];
        4'd9 : O_Txd <= 1'b1;
        default:;
        endcase
    end
    else 
        O_Txd <= 1'b1;
end


endmodule