library ieee; -- Import IEEE standard logic library for common logic operations
use ieee.std_logic_1164.all; -- Use the IEEE standard logic package for logic operations
use ieee.std_logic_unsigned.all; -- Use the IEEE standard logic package for unsigned arithmetic operations
use ieee.std_logic_arith.all; -- Use the IEEE standard logic package for arithmetic operations
library std; -- Import standard library
use std.textio.all; -- Use standard text I/O package for file handling

entity matrices_mult_tb is
end entity; -- Testbench entity for matrices_mult

architecture behave of matrices_mult_tb is

    constant C_CLK_PRD      : time := 20 ns; -- Clock period for the simulation
	constant NUM_OF_TESTS	: integer := 3; -- Number of test cases to be simulated

    type int_array is array(integer range <>) of integer; -- Define a type for an array of integers

    component matrices_mult is
    port (
		CLK                     : in    std_logic;  -- System clock input
		RSTn                    : in    std_logic;  -- Asynchronous, active-low reset input
		
		STARTn                  : in    std_logic;	-- Active-low start signal
		DISPLAYn				: in    std_logic;	-- Active-low display signal
		HEX0                    : out   std_logic_vector(6 downto 0); -- Output to 7-segment display 0
		HEX1                    : out   std_logic_vector(6 downto 0); -- Output to 7-segment display 1
		HEX2                    : out   std_logic_vector(6 downto 0); -- Output to 7-segment display 2
		HEX3                    : out   std_logic_vector(6 downto 0); -- Output to 7-segment display 3
		LEDS_1E4				: out   std_logic_vector(3 downto 0); -- Output for LED display (thousands place)
		LED_SIGN                : out   std_logic; -- Output for sign LED
		LEDG                    : out   std_logic_vector(3 downto 1) -- Output for additional green LEDs
    );
    end component; -- End of matrices_mult component declaration

    function seg7_to_bcd(val_in: std_logic_vector(6 downto 0)) return integer is
    begin
        -- Convert 7-segment display code to corresponding BCD integer value
        case val_in is
            when "1000000" =>
                return 0;
            when "1111001" =>
                return 1;
            when "0100100" =>
                return 2;
            when "0110000" =>
                return 3;
            when "0011001" =>
                return 4;
            when "0010010" =>
                return 5;
            when "0000010" =>
                return 6;
            when "1111000" =>
                return 7;
            when "0000000" =>
                return 8;
            when "0010000" =>
                return 9;
            when others =>
                return -1; -- Return -1 if input does not match any valid 7-segment code
        end case;
    end function; -- End of function seg7_to_bcd
    
    -- Signals for testbench stimulus and response
    signal clk          : std_logic := '0'; -- Clock signal
    signal rstn         : std_logic := '0'; -- Active-low reset signal
    signal start        : std_logic := '1'; -- Start signal for matrices_mult
    signal display      : std_logic := '1'; -- Display signal for matrices_mult
    signal hex0         : std_logic_vector(6 downto 0); -- Output signal for 7-segment display 0
    signal hex1         : std_logic_vector(6 downto 0); -- Output signal for 7-segment display 1
    signal hex2         : std_logic_vector(6 downto 0); -- Output signal for 7-segment display 2
	signal hex3         : std_logic_vector(6 downto 0); -- Output signal for 7-segment display 3
    signal led_sign     : std_logic; -- Output signal for sign LED
    signal ledg         : std_logic_vector(3 downto 1); -- Output signal for additional green LEDs
	signal leds_1e4		: std_logic_vector(3 downto 0); -- Output signal for LED display (thousands place)

begin

    -- Instantiate the design under test (DUT)
    dut: matrices_mult
    port map (
        CLK                   	=> clk, -- Connect testbench clock signal
        RSTn                    => rstn, -- Connect testbench reset signal
        STARTn                  => start, -- Connect testbench start signal
        DISPLAYn                => display, -- Connect testbench display signal
        HEX0                    => hex0, -- Connect to testbench HEX0 output
        HEX1                    => hex1, -- Connect to testbench HEX1 output
        HEX2                    => hex2, -- Connect to testbench HEX2 output
        HEX3                    => hex3, -- Connect to testbench HEX3 output
		LEDS_1E4				=> leds_1e4, -- Connect to testbench LEDS_1E4 output
		LED_SIGN                => led_sign, -- Connect to testbench LED_SIGN output
		LEDG                    => ledg -- Connect to testbench LEDG output
    );
    
    clk <= not clk after C_CLK_PRD / 2; -- Generate clock signal with specified period
    rstn <= '0', '1' after 100 ns; -- Apply reset pulse at the beginning of the simulation
    
    process
    begin
        start <= '1'; -- Initialize start signal to idle state
        display <= '1'; -- Initialize display signal to idle state
        wait for 100 us; -- Wait for 100 microseconds
        
        for i in 0 to 2 loop
            start <= '0'; -- Start process to get matrices
            wait for 100 us; -- Wait for 100 microseconds
            start <= '1'; -- Return start signal to idle
            
            wait for 200 us; -- Wait for 200 microseconds
			
            start <= '0'; -- Start calculation process
            wait for 100 us; -- Wait for 100 microseconds
            start <= '1'; -- Return start signal to idle

            wait for 200 us; -- Wait for 200 microseconds

            for j in 0 to 17 loop -- Loop to simulate display process
                display <= '0'; -- Activate display
                wait for 100 us; -- Wait for 100 microseconds
                display <= '1'; -- Deactivate display
                wait for 200 us; -- Wait for 200 microseconds
            end loop;
            
            wait for 1 ms; -- Wait for 1 millisecond

            start <= '0'; -- Return to idle state
            wait for 100 us; -- Wait for 100 microseconds
            start <= '1'; -- Return start signal to idle
            wait for 1 ms; -- Wait for 1 millisecond
            
        end loop;
        
        report "End of Simulation"
        severity failure; -- End the simulation with a failure report to stop the simulation
        
    end process; -- End of test process
    
    
    verify_results: process
        variable expected_values    : int_array(0 to 15); -- Array to store expected values
		variable expected_sign      : int_array(0 to 15); -- Array to store expected sign values
        file infile                 : text open read_mode is "expected_results.dat"; -- Open file for reading expected results
        variable inline             : line; -- Line variable to hold the current line from the file
        variable errors_counter     : integer := 0; -- Counter for the number of errors
        variable param_num          : integer := 0; -- Parameter number for indexing
        variable ones, tens, hunds  : integer := 0; -- Variables to hold decoded 7-segment values
        variable dut_val            : integer := 0; -- Variable to hold the calculated DUT value
		variable thousands   		: integer := 0; -- Variable to hold the thousands place value
		variable tensofthousands    : integer := 0; -- Variable to hold the tens of thousands place value
		
    begin
    
        readline(infile, inline); -- Skip the first line of the file
        
        for i in 1 to NUM_OF_TESTS loop -- Loop through the number of tests
            wait until falling_edge(start); -- Wait until the falling edge of the start signal
			
            for j in 0 to 15 loop -- Loop to read expected values from the file
				readline(infile, inline); -- Read a line from the file
				read(inline, expected_sign(j)); -- Read the expected sign
				read(inline, expected_values(j)); -- Read the expected value
            end loop;
            
            param_num := 0; -- Initialize parameter number
            
            for k in 0 to 17 loop -- Loop through the display segments
                wait until falling_edge(display); -- Wait until the falling edge of the display signal
                ones := seg7_to_bcd(hex0); -- Decode 7-segment HEX0 to BCD
                tens := seg7_to_bcd(hex1); -- Decode 7-segment HEX1 to BCD
                hunds := seg7_to_bcd(hex2); -- Decode 7-segment HEX2 to BCD
                thousands := seg7_to_bcd(hex3); -- Decode 7-segment HEX3 to BCD
				tensofthousands := conv_integer(leds_1e4); -- Convert LEDS_1E4 to integer
				dut_val := ones + tens*10 + hunds*100 + thousands*1E3 + tensofthousands*1E4; -- Calculate the full value from decoded digits
                
                if (dut_val = expected_values(param_num)) then -- Check if the DUT value matches the expected value
                    report "Value Pass" & LF; -- Report success if values match
                else
                    report "Value Fail!  " & "Expected=" & integer'image(expected_values(param_num)) & "    Actual=" & integer'image(dut_val) & LF; -- Report failure if values do not match
                    errors_counter := errors_counter + 1; -- Increment error counter
                end if;
				
				if (conv_integer(led_sign) = expected_sign(param_num)) then -- Check if the DUT sign matches the expected sign
                    report "Sign Pass" & LF; -- Report success if signs match
                else
                    report "Sign Fail!  " & "Expected=" & integer'image(expected_sign(param_num)) & "    Actual=" & integer'image(conv_integer(led_sign)) & LF; -- Report failure if signs do not match
                    errors_counter := errors_counter + 1; -- Increment error counter
                end if;
                
                if param_num = 15 then -- Check if the parameter number has reached its limit
                    param_num := 0; -- Reset the parameter number
                else
                    param_num := param_num + 1; -- Increment the parameter number
                end if;
            end loop;

        end loop;
        
        report "Total errors: " & integer'image(errors_counter) & LF; -- Report the total number of errors
        
        wait; -- Wait indefinitely, effectively ending the process
    
    end process; -- End of verify_results process

end architecture; -- End of architecture behave
