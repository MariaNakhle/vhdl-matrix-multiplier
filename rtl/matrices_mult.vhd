library ieee; -- Import the IEEE library for standard logic and arithmetic operations
use ieee.std_logic_1164.all; -- Use the IEEE standard logic package for logic operations
use ieee.numeric_std.all; -- Use the IEEE numeric standard package for arithmetic operations

entity matrices_mult is
    port (
        CLK         : in std_logic; -- Input clock signal
        RSTn        : in std_logic; -- Active-low reset signal
        STARTn      : in std_logic; -- Active-low start signal
        DISPLAYn    : in std_logic; -- Active-low display signal
        HEX0        : out std_logic_vector(6 downto 0); -- 7-segment display output for lower digit
        HEX1        : out std_logic_vector(6 downto 0); -- 7-segment display output for the next digit
        HEX2        : out std_logic_vector(6 downto 0); -- 7-segment display output for the third digit
        HEX3        : out std_logic_vector(6 downto 0); -- 7-segment display output for the fourth digit
        LEDS_1E4    : out std_logic_vector(3 downto 0); -- Output for LEDs showing thousands place
        LED_SIGN    : out std_logic; -- Output for the sign LED
        LEDG        : out std_logic_vector(3 downto 1) -- Output for additional green LEDs
    );
end entity matrices_mult;

architecture structural of matrices_mult is

    -- Internal signals for communication between data_generator and main_controller components
    signal data_request : std_logic; -- Signal to request new data
    signal din          : std_logic_vector(7 downto 0); -- Data input from data_generator to main_controller
    signal din_valid    : std_logic; -- Validity flag for the data input
    signal result       : std_logic_vector(16 downto 0); -- Result output from main_controller
    signal result_ready : std_logic; -- Flag indicating the result is ready
    signal got_all_matrices : std_logic; -- Flag indicating all matrices have been processed

    -- Signals for converting binary result to BCD and driving 7-segment displays
    signal bcd_ones          : std_logic_vector(3 downto 0) := (others => '0'); -- BCD value for ones place
    signal bcd_tenths        : std_logic_vector(3 downto 0) := (others => '0'); -- BCD value for tens place
    signal bcd_hundreds      : std_logic_vector(3 downto 0) := (others => '0'); -- BCD value for hundreds place
    signal bcd_thousands     : std_logic_vector(3 downto 0) := (others => '0'); -- BCD value for thousands place
    signal bcd_tens_of_thousands : std_logic_vector(3 downto 0) := (others => '0'); -- BCD value for tens of thousands place
    signal display_hex0      : std_logic_vector(6 downto 0) := (others => '1'); -- Default off state for HEX0
    signal display_hex1      : std_logic_vector(6 downto 0) := (others => '1'); -- Default off state for HEX1
    signal display_hex2      : std_logic_vector(6 downto 0) := (others => '1'); -- Default off state for HEX2
    signal display_hex3      : std_logic_vector(6 downto 0) := (others => '1'); -- Default off state for HEX3

    -- Additional internal signals
    signal sign_out          : std_logic; -- Signal indicating the sign of the result
    signal dout              : std_logic_vector(15 downto 0); -- Processed data output

    -- Synchronization signals for START and DISPLAY
    signal START_SIG           : std_logic; -- Synchronized start signal
    signal DISPLAY_SIG         : std_logic; -- Synchronized display signal

    -- Component declarations

    component data_generator
        port (
            CLK         : in std_logic; -- Input clock signal
            RST         : in std_logic; -- Reset signal
            DATA_REQUEST: in std_logic; -- Signal to request data generation
            DOUT        : out std_logic_vector(7 downto 0); -- Generated data output
            DOUT_VALID  : out std_logic -- Validity flag for the generated data
        );
    end component;

    component main_controller
        port (
            CLK             : in std_logic; -- Input clock signal
            RST             : in std_logic; -- Reset signal
            START           : in std_logic; -- Start signal
            DISPLAY         : in std_logic; -- Display control signal
            DIN             : in std_logic_vector(7 downto 0); -- Data input
            DIN_VALID       : in std_logic; -- Validity flag for the data input
            DATA_REQUEST    : out std_logic; -- Signal to request more data
            RESULT          : out std_logic_vector(16 downto 0); -- Computed result output
            RESULTS_READY   : out std_logic; -- Signal indicating the result is ready
            GOT_ALL_MATRICES: out std_logic -- Signal indicating all matrices have been processed
        );
    end component;

    component bin2bcd_12bit_sync
        port (
            CLK             : in std_logic; -- Input clock signal
            binIN           : in std_logic_vector(15 downto 0); -- Binary input value
            ones            : out std_logic_vector(3 downto 0); -- BCD output for ones place
            tenths          : out std_logic_vector(3 downto 0); -- BCD output for tens place
            hunderths       : out std_logic_vector(3 downto 0); -- BCD output for hundreds place
            thousands       : out std_logic_vector(3 downto 0); -- BCD output for thousands place
            tensofthousands : out std_logic_vector(3 downto 0) -- BCD output for tens of thousands place
        );
    end component;

    component bcd_to_7seg
        port (
            BCD_IN     : in std_logic_vector(3 downto 0); -- BCD input value
            SHUTDOWNn  : in std_logic; -- Shutdown control signal, active low
            D_OUT      : out std_logic_vector(6 downto 0) -- 7-segment display output
        );
    end component;

    component sync_diff
        generic (
            G_DERIVATE_RISING_EDGE  : boolean := true; -- Enable/disable edge detection
            G_SIG_IN_INIT_VALUE     : std_logic := '0'; -- Initial value of the input signal
            G_RESET_ACTIVE_VALUE    : std_logic := '0' -- Reset active value
        );
        port (
            CLK     : in std_logic; -- Input clock signal
            RST     : in std_logic; -- Reset signal
            SIG_IN  : in std_logic; -- Input signal to be synchronized
            SIG_OUT : out std_logic -- Synchronized output signal
        );
    end component;

    component num_convert
        port (
            CLK       : in std_logic; -- Input clock signal
            RST       : in std_logic; -- Reset signal
            DIN       : in std_logic_vector(16 downto 0); -- Input data value
            DIN_VALID : in std_logic; -- Validity flag for input data
            DOUT      : out std_logic_vector(15 downto 0); -- Output data value
            SIGN      : out std_logic -- Output sign indicator
        );
    end component;

begin

    -- Instantiate the data_generator component
    data_gen: data_generator
        port map (
            CLK         => CLK, -- Connect clock signal
            RST         => not RSTn, -- Connect inverted reset signal
            DATA_REQUEST=> data_request, -- Connect data request signal
            DOUT        => din, -- Connect data output to din signal
            DOUT_VALID  => din_valid -- Connect data valid output to din_valid signal
        );

    -- Instantiate the main_controller component
    main_ctrl: main_controller
        port map (
            CLK             => CLK, -- Connect clock signal
            RST             => not RSTn, -- Connect inverted reset signal
            START           => START_SIG, -- Connect synchronized start signal
            DISPLAY         => DISPLAY_SIG, -- Connect synchronized display signal
            DATA_REQUEST    => data_request, -- Connect data request signal
            DIN             => din, -- Connect data input
            DIN_VALID       => din_valid, -- Connect data valid input
            RESULT          => result, -- Connect result output
            RESULTS_READY   => result_ready, -- Connect result ready flag
            GOT_ALL_MATRICES=> got_all_matrices -- Connect all matrices processed flag
        );

    -- Instantiate the num_convert component to get the absolute value of the result
    num_convert_inst: num_convert
        port map (
            CLK         => CLK, -- Connect clock signal
            RST         => not RSTn, -- Connect inverted reset signal
            DIN         => result, -- Pass the result to num_convert for processing
            DIN_VALID   => result_ready, -- Connect result ready flag
            DOUT        => dout, -- Connect processed data output
            SIGN        => sign_out -- Connect sign output
        );

    -- Instantiate the binary to BCD converter
    bin2bcd_inst: bin2bcd_12bit_sync
        port map (
            binIN           => dout, -- Use the positive result for BCD conversion
            ones            => bcd_ones, -- Connect BCD ones output
            tenths          => bcd_tenths, -- Connect BCD tens output
            hunderths       => bcd_hundreds, -- Connect BCD hundreds output
            thousands       => bcd_thousands, -- Connect BCD thousands output
            tensofthousands => bcd_tens_of_thousands, -- Connect BCD tens of thousands output
            CLK             => CLK -- Connect clock signal
        );

    -- Instantiate the BCD to 7-segment display converters
    bcd_to_7seg_inst0: bcd_to_7seg
        port map (
            BCD_IN => bcd_ones, -- Connect BCD ones input
            SHUTDOWNn => RSTn, -- Connect reset signal
            D_OUT => display_hex0 -- Connect 7-segment display output for HEX0
        );

    bcd_to_7seg_inst1: bcd_to_7seg
        port map (
            BCD_IN => bcd_tenths, -- Connect BCD tens input
            SHUTDOWNn => RSTn, -- Connect reset signal
            D_OUT => display_hex1 -- Connect 7-segment display output for HEX1
        );

    bcd_to_7seg_inst2: bcd_to_7seg
        port map (
            BCD_IN => bcd_hundreds, -- Connect BCD hundreds input
            SHUTDOWNn => RSTn, -- Connect reset signal
            D_OUT => display_hex2 -- Connect 7-segment display output for HEX2
        );

    bcd_to_7seg_inst3: bcd_to_7seg
        port map (
            BCD_IN => bcd_thousands, -- Connect BCD thousands input
            SHUTDOWNn => RSTn, -- Connect reset signal
            D_OUT => display_hex3 -- Connect 7-segment display output for HEX3
        );

    -- Synchronize the START signal using sync_diff component
    sync_diff_START: sync_diff
        generic map (
            G_DERIVATE_RISING_EDGE  => false, -- Disable edge detection
            G_SIG_IN_INIT_VALUE     => '0', -- Initial value for the input signal
            G_RESET_ACTIVE_VALUE    => '0' -- Reset active value
        )
        port map (
            CLK     => CLK, -- Connect clock signal
            RST     => RSTn, -- Connect reset signal
            SIG_IN  => STARTn, -- Connect raw STARTn input signal
            SIG_OUT => START_SIG -- Output the synchronized START signal
        );
    
    -- Synchronize the DISPLAY signal using sync_diff component
    sync_diff_DISPLAY: sync_diff
        generic map (
            G_DERIVATE_RISING_EDGE  => false, -- Disable edge detection
            G_SIG_IN_INIT_VALUE     => '0', -- Initial value for the input signal
            G_RESET_ACTIVE_VALUE    => '0' -- Reset active value
        )
        port map (
            CLK     => CLK, -- Connect clock signal
            RST     => RSTn, -- Connect reset signal
            SIG_IN  => DISPLAYn, -- Connect raw DISPLAYn input signal
            SIG_OUT => DISPLAY_SIG -- Output the synchronized DISPLAY signal
        );

    -- Connect the 7-segment display outputs, enabling them when result is ready
    HEX0 <= display_hex0 when result_ready else (others=>'1'); -- Show HEX0 when result is ready, otherwise turn off
    HEX1 <= display_hex1 when result_ready else (others=>'1'); -- Show HEX1 when result is ready, otherwise turn off
    HEX2 <= display_hex2 when result_ready else (others=>'1'); -- Show HEX2 when result is ready, otherwise turn off
    HEX3 <= display_hex3 when result_ready else (others=>'1'); -- Show HEX3 when result is ready, otherwise turn off
    
    -- Control the LEDs based on the result readiness and sign
    LEDS_1E4 <= bcd_tens_of_thousands when result_ready else (others=>'0'); -- Show the BCD tens of thousands on LEDs
    LED_SIGN <= sign_out when result_ready else '0'; -- Show the sign of the result on the sign LED         
    LEDG(3) <= result_ready; -- Light up the third green LED when result is ready
    LEDG(2) <= got_all_matrices; -- Light up the second green LED when all matrices are processed
    LEDG(1) <= '1'; -- Constantly light up the first green LED

end architecture structural;
