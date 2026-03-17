`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/16/2026 07:28:33 PM
// Design Name: 
// Module Name: RT_Clock
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

// Modified IP from https://github.com/Goutham-CJ/Real-Time-Digital-clock/blob/main/Digitalclock.v 

// Assume 1 GHz clock for sims
module digitalClock(
    input logic clk,rstn,
    output logic [3:0] ms1, ms2, ms3, sec1,sec2,min1,min2,hour1,hour2
    );
    
    integer max_hour1, max_hour2;
    
    always @(posedge clk) begin
        
        if(!rstn) begin
            ms1 <= 0;
            ms2 <= 0;
            ms3 <= 0;
            sec1 <= 0;
            sec2 <= 0;
            min1 <= 0;
            min2 <= 0; 
            hour1 <= 0;
            hour2 <= 0;
        end
        else begin
            max_hour1 = 3;
            max_hour2 = 2;
            
            if(ms1 < 9) begin
                ms1 <= ms1 + 1;
            end
            else begin
                ms1 <= 0;
                if(ms2 < 9) begin
                    ms2 <= ms2 + 1;
                end
                else begin
                    ms2 <= 0;
                    if(ms3 < 9) begin
                        ms3 <= ms3 + 1;
                    end
                    else begin
                        ms3 <= 0;
                        if(sec1 < 9) begin
                            sec1 <= sec1 + 1;
                        end 
                        else begin
                            sec1 <= 0;
                            if(sec2 < 5) begin
                                sec2 <= sec2 + 1;
                            end 
                            else begin
                                sec2 <= 0;
                                if(min1 < 9) begin
                                    min1 <= min1 + 1;
                                end 
                                else begin
                                    min1 <= 0;
                                    if(min2 < 5) begin
                                        min2 <= min2 + 1;
                                    end 
                                    else begin
                                        min2 <= 0;
                                        if(hour1 < max_hour1) begin
                                            hour1 <= hour1 + 1;
                                        end 
                                        else begin
                                            hour1 <= 0;
                                            if(hour2 < max_hour2) begin
                                                hour2 <= hour2 + 1;
                                            end 
                                            else begin
                                                hour2 <= 0;
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

endmodule
