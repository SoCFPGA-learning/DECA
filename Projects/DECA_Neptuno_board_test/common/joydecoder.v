`timescale 1ns / 1ps
`default_nettype none

//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    09:00:25 07/20/2018 
// Design Name: 
// Module Name:    joydecoder 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
/*
module joydecoder (
//-------------------------------------------
  input wire clk,//si reloj de entrada en este caso 1.3888Mhz va a patilla 11 integrado
  input wire joy_data,//datos serializados patilla viene de la patilla 9 integrado
  output wire joy_clk,//este reloj no se usa
  output wire joy_load_n,//este reloj negado se usa directamente en las patillas 12 y 13
  input wire clock_locked,
  input wire hsync_n_s,
//-----------------------------------------
  output wire joy1up,
  output wire joy1down,
  output wire joy1left,
  output wire joy1right,
  output wire joy1fire1,
  output wire joy1fire2,
  output wire joy1fire3,
  output wire joy1start,
  output wire joy2up,
  output wire joy2down,
  output wire joy2left,
  output wire joy2right,
  output wire joy2fire1,
  output wire joy2fire2,
  output wire joy2fire3,
  output wire joy2start  
  );
  

     // Divisor de relojes
  reg [7:0] delay_count;
  wire ena_x;
  
  always @ (posedge clk or negedge clock_locked) begin
    if (!clock_locked) begin
      delay_count <= 8'd0;
    end else begin
      delay_count <= delay_count + 1'b1;       
    end
  end
    
  //assign ena_x = delay_count[3]; //para clk aprox, 4Mhz
  //assign ena_x = delay_count[4]; //para clk aprox, 8Mhz
  //assign ena_x = delay_count[5]; //para clk aprox, 16Mhz
	assign ena_x = delay_count[1];
  
  
  //Gestion de Joystick
// wire [11:0] j1 , j2;
   reg [11:0] joy1  = 12'hFFF, joy2  = 12'hFFF;
	reg [11:0] joy1s  = 12'hFFF, joy2s  = 12'hFFF;
   reg joy_renew = 1'b1;
   reg [4:0]joy_count = 5'd0;
	reg hsyncaux;
   
   assign joy_clk = ena_x;
   assign joy_load_n = joy_renew;
	
   assign joy1up    = joy1[0];
   assign joy1down  = joy1[1];
   assign joy1left  = joy1[2];
   assign joy1right = joy1[3];
   assign joy1fire1 = joy1[4];
   assign joy1fire2 = joy1[5];
   assign joy1fire3 = joy1[6];
   assign joy1start = joy1[8];
   assign joy2up    = joy2[0];
   assign joy2down  = joy2[1];
   assign joy2left  = joy2[2];
   assign joy2right = joy2[3];
   assign joy2fire1 = joy2[4];
   assign joy2fire2 = joy2[5];
   assign joy2fire3 = joy2[6];
   assign joy2start = joy2[8];
	
	always @(negedge joy_renew) 
	begin 
		hsyncaux <= hsync_n_s;
		if (hsyncaux == hsync_n_s)
		begin
			joy1s <= joy1;
			joy2s <= joy2;			
		end
	end

	always @(posedge ena_x) 
	  begin 
      if (joy_count == 5'd0) 
		  begin
         joy_renew <= 1'b0;
        end 
		else 
		  begin
         joy_renew <= 1'b1;
        end
      if (joy_count == 5'd25) 
		  begin
         joy_count <= 5'd0;
        end
		else 
		  begin
         joy_count <= joy_count + 1'd1;
        end      
     end
   always @(posedge ena_x) begin
         case (joy_count)
            5'd2  : joy1[8]  <= joy_data;   //  1p start
            5'd3  : joy1[6]  <= joy_data;   //  1p fire3
            5'd4  : joy1[5]  <= joy_data;   //  1p fire2
            5'd5  : joy1[4]  <= joy_data;   //  1p fire1
            5'd6  : joy1[3]  <= joy_data;   //  1p right
            5'd7  : joy1[2]  <= joy_data;   //  1p left
            5'd8  : joy1[1]  <= joy_data;   //  1p down
            5'd9  : joy1[0]  <= joy_data;   //  1p up
            5'd10 : joy2[8]  <= joy_data;   //  2p start
            5'd11 : joy2[6]  <= joy_data;   //  2p fire3
            5'd12 : joy2[5]  <= joy_data;   //  2p fire2
            5'd13 : joy2[4]  <= joy_data;   //  2p fire1
            5'd14 : joy2[3]  <= joy_data;   //  2p right
            5'd15 : joy2[2]  <= joy_data;   //  2p left
            5'd16 : joy2[1]  <= joy_data;   //  2p down
            5'd17 : joy2[0]  <= joy_data;   //  2p up
            5'd18 : joy2[10] <= joy_data;   //  2p select
            5'd19 : joy2[11] <= joy_data;   //  test
            5'd20 : joy2[9]  <= joy_data;   //  2p coin
            5'd21 : joy2[7]  <= joy_data;   //  2p fire4
            5'd22 : joy1[10] <= joy_data;   //  1p select
            5'd23 : joy1[11] <= joy_data;   //  service
            5'd24 : joy1[9]  <= joy_data;   //  1p coin
            5'd25 : joy1[7]  <= joy_data;   //  1p fire4
         endcase              
      end
endmodule
*/
`timescale 1ns / 1ps
`default_nettype none

module joydecoder (
  input wire clk,
  input wire joy_data,
  output wire joy_clk,
  output wire joy_load_n,
  output wire joy1up,
  output wire joy1down,
  output wire joy1left,
  output wire joy1right,
  output wire joy1fire1,
  output wire joy1fire2,
  output wire joy2up,
  output wire joy2down,
  output wire joy2left,
  output wire joy2right,
  output wire joy2fire1,
  output wire joy2fire2,
  input wire hsync
  );

  reg hsync_s;
  reg [7:0] clkdivider = 8'h00;
  assign joy_clk = clkdivider[1];
  always @(posedge clk) begin
    clkdivider <= clkdivider + 8'd1;
  end

  reg [15:0] joyswitches = 16'hFFFF;
  assign joy1up    = joyswitches[7];
  assign joy1down  = joyswitches[6];
  assign joy1left  = joyswitches[5];
  assign joy1right = joyswitches[4];
  assign joy1fire1 = joyswitches[3];
  assign joy1fire2 = joyswitches[2];
  assign joy2up    = joyswitches[15];
  assign joy2down  = joyswitches[14];
  assign joy2left  = joyswitches[13];
  assign joy2right = joyswitches[12];
  assign joy2fire1 = joyswitches[11];
  assign joy2fire2 = joyswitches[10];

  reg [3:0] state = 4'd0;
  assign joy_load_n = ~(state == 4'd0);

  always @(negedge joy_clk) begin
  /*hsync_s <= hsync;
  if (hsync_s ^ hsync) state <= 4'd0;
  else*/ state <= state + 4'd1;
    case (state)
      4'd0:  joyswitches[0]  <= joy_data;
      4'd1:  joyswitches[1]  <= joy_data;
      4'd2:  joyswitches[2]  <= joy_data;
      4'd3:  joyswitches[3]  <= joy_data;
      4'd4:  joyswitches[4]  <= joy_data;
      4'd5:  joyswitches[5]  <= joy_data;
      4'd6:  joyswitches[6]  <= joy_data;
      4'd7:  joyswitches[7]  <= joy_data;
      4'd8:  joyswitches[8]  <= joy_data;
      4'd9:  joyswitches[9]  <= joy_data;
      4'd10: joyswitches[10] <= joy_data;
      4'd11: joyswitches[11] <= joy_data;
      4'd12: joyswitches[12] <= joy_data;
      4'd13: joyswitches[13] <= joy_data;
      4'd14: joyswitches[14] <= joy_data;
      4'd15: joyswitches[15] <= joy_data;
    endcase
  end
endmodule