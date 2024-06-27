module RS232_Recv #(
    parameter P_CLK_FREQ  = 5000_0000,    //Clk_Freq
    parameter P_RS232_BPS = 115200        //Bps
)(
    input            I_Clk  ,
    input            I_Rst  ,
    input            I_Rxd  ,
    //output
    output reg [7:0] O_Data ,
    output reg       O_Done ,//仅仅维持一个时钟周期
    output           O_Begin
);

localparam P_BPS_Cnt = P_CLK_FREQ / P_RS232_BPS;

reg [7:0] R_Data;
reg       R_Rx_Flag;
reg [3:0] R_Rx_Cnt;
reg [15:0] R_Clk_Cnt;
reg       R_Rxd_D0;
reg       R_Rxd_D1;
wire      W_Start_Flag;
assign O_Begin = W_Start_Flag | R_Rx_Flag;
//判断Rxd的下降沿 
assign W_Start_Flag = (( R_Rxd_D0) && (!R_Rxd_D1)) ? 1'b1 : 1'b0;
always @(posedge I_Clk) begin
    if(I_Rst) begin
        R_Rxd_D0 <= 1'b1;
        R_Rxd_D1 <= 1'b1;
    end
    else begin
        R_Rxd_D0 <= R_Rxd_D1;
        R_Rxd_D1 <= I_Rxd;
    end
end

//时钟计时
always @(posedge I_Clk) begin
    if(I_Rst) 
        R_Clk_Cnt <= 16'b0;
    else if(R_Rx_Flag) begin
        if(R_Clk_Cnt == P_BPS_Cnt - 1) 
            R_Clk_Cnt <= 16'b0;
        else
            R_Clk_Cnt <=R_Clk_Cnt + 1'b1;
    end
    else 
        R_Clk_Cnt <= 16'b0;
end

//Rx_Flag
always @(posedge I_Clk) begin
    if(I_Rst) begin
        R_Rx_Flag <= 1'b0;
    end
    else begin
        if(W_Start_Flag)
            R_Rx_Flag <= 1'b1;
        else if((R_Rx_Cnt == 4'd9) && (R_Clk_Cnt == P_BPS_Cnt / 2))
            R_Rx_Flag <= 1'b0;
        else 
            R_Rx_Flag <= R_Rx_Flag;
    end
end

always @(posedge I_Clk) begin
    if(I_Rst) begin
        R_Rx_Cnt <= 4'd0;
    end
    else if(R_Rx_Flag) begin
        if(R_Clk_Cnt == P_BPS_Cnt - 1'b1)
            R_Rx_Cnt <= R_Rx_Cnt + 1'b1;
        else
            R_Rx_Cnt <= R_Rx_Cnt;
    end
    else
        R_Rx_Cnt <= 4'd0;
end

always @(posedge I_Clk) begin
    if(I_Rst) begin
        R_Data <= 8'd0;
    end
    else begin
        if(R_Rx_Flag) begin
            if(R_Clk_Cnt == P_BPS_Cnt /2) 
                R_Data[R_Rx_Cnt - 1'b1] = R_Rxd_D0;
        end
        else 
            R_Data <= R_Data;
    end
end

always @(posedge I_Clk) begin
    if(I_Rst) begin
        O_Data <= 8'd0;
        O_Done <= 1'd0;
    end
    else if(R_Rx_Cnt == 4'd9)begin
        O_Data <= R_Data;
        O_Done <= 1'b1;
    end
    else begin
        O_Data <= 8'd0;
        O_Done <= 1'b0;
    end
end

endmodule