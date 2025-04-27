library ieee; -- Import the IEEE library for standard logic and arithmetic operations
use ieee.std_logic_1164.all; -- Use the IEEE standard logic package for logic operations
use ieee.numeric_std.all; -- Use the IEEE numeric standard package for arithmetic operations

entity main_controller is
    port (
        CLK              : in    std_logic; -- System clock input
        RST              : in    std_logic; -- System reset input
        START            : in    std_logic; -- Start signal input
        DISPLAY          : in    std_logic; -- Display signal input
        DIN              : in    std_logic_vector(7 downto 0); -- Data input vector
        DIN_VALID        : in    std_logic; -- Data valid flag input
        DATA_REQUEST     : out   std_logic; -- Data request output signal
        RESULT           : out   std_logic_vector(16 downto 0); -- Result output vector
        RESULTS_READY    : out   std_logic; -- Result ready output flag
        GOT_ALL_MATRICES : out   std_logic -- All matrices received output flag
    );
end entity;

architecture behave of main_controller is
    constant C_NUM_OF_ELEMENTS : integer := 16; -- Number of elements in matrices
    constant N                 : integer := 8; -- Width of data input/output for multiplier
    constant LATENCY           : integer := 2; -- Latency for multiplier
    constant IS_SIGNED         : boolean := true; -- Flag for signed or unsigned operation

    -- State machine definitions for main control and calculation processes
    type main_sm_states is (
        st_idle, -- Idle state
        st_receive_first_mat, -- Receiving first matrix
        st_receive_second_mat, -- Receiving second matrix
        st_wait_for_calculate, -- Waiting to start calculation
        st_calculate, -- Calculating matrix multiplication
        st_display -- Displaying results
    );

    type calc_sm_states is (
        st_idle, -- Idle state
        st_get_row, -- Getting row for calculation
        st_get_col, -- Getting column for calculation
        st_save -- Saving calculated results
    );

    -- Component declaration for matrix RAM
    component matrix_ram is
        generic (
            DATA_WIDTH    : integer := 32; -- Data width of RAM
            ADDRESS_BITS  : integer := 5 -- Number of address bits for RAM
        );
        port (
            CLK       : in  std_logic; -- Clock input
            RST       : in  std_logic; -- Reset input
            DATA      : in  std_logic_vector(DATA_WIDTH-1 downto 0); -- Data input
            WREN      : in  std_logic; -- Write enable input
            ADDRESS   : in  std_logic_vector(ADDRESS_BITS-1 downto 0); -- Address input
            BYTEENA   : in  std_logic_vector(DATA_WIDTH/8-1 downto 0); -- Byte enable input
            Q         : out std_logic_vector(DATA_WIDTH-1 downto 0) -- Data output
        );
    end component;

    -- Component declaration for multiplier
    component my_multiplier is
        generic (
            N          : integer := 8; -- Width of data inputs/outputs
            LATENCY    : integer range 1 to 8 := 2; -- Latency of multiplier
            IS_SIGNED  : boolean := false -- Flag for signed/unsigned operation
        );
        port (
            CLK        : in  std_logic; -- Clock input
            DIN_VALID  : in  std_logic; -- Data valid input
            A          : in  std_logic_vector(N-1 downto 0); -- Multiplier input A
            B          : in  std_logic_vector(N-1 downto 0); -- Multiplier input B
            Q          : out std_logic_vector(N*2-1 downto 0); -- Multiplication result output
            DOUT_VALID : out std_logic -- Data output valid flag
        );
    end component;

    -- Signal declarations
    signal main_sm                : main_sm_states; -- Main state machine signal
    signal calc_sm                : calc_sm_states; -- Calculation state machine signal
    signal data_count             : integer range 0 to C_NUM_OF_ELEMENTS; -- Counter for received data elements
    signal row_num                : integer range 0 to 3; -- Row index signal
    signal col_num                : integer range 0 to 3; -- Column index signal
    signal byte_enable            : std_logic_vector(3 downto 0); -- Byte enable signal for RAM
    signal mem_byte_enable        : std_logic_vector(3 downto 0); -- Byte enable signal for memory
    signal mem_address            : std_logic_vector(4 downto 0); -- Memory address signal
    signal mem_wr_data            : std_logic_vector(31 downto 0); -- Memory write data signal
    signal mem_wr                 : std_logic; -- Memory write enable signal
    signal high_address           : std_logic_vector(2 downto 0) := "000"; -- High bits of the address
    signal iteration_num          : integer range 0 to 3; -- Iteration number for calculation
    signal store_mat1_row_data    : std_logic := '0'; -- Signal to store row data from matrix 1
    signal store_mat2_col_data    : std_logic := '0'; -- Signal to store column data from matrix 2
    signal mat1_row_data          : std_logic_vector(31 downto 0); -- Data for row from matrix 1
    signal mem_dout               : std_logic_vector(31 downto 0); -- Data output from memory

    signal mult1_q                : std_logic_vector(15 downto 0); -- Output of first multiplier
    signal mult2_q                : std_logic_vector(15 downto 0); -- Output of second multiplier
    signal mult3_q                : std_logic_vector(15 downto 0); -- Output of third multiplier
    signal mult4_q                : std_logic_vector(15 downto 0); -- Output of fourth multiplier

    signal mult1_q_valid          : std_logic; -- Valid flag for first multiplier output
    signal mult2_q_valid          : std_logic; -- Valid flag for second multiplier output
    signal mult3_q_valid          : std_logic; -- Valid flag for third multiplier output
    signal mult4_q_valid          : std_logic; -- Valid flag for fourth multiplier output

    signal res_mat_element_valid  : std_logic := '0'; -- Valid flag for result matrix element
    signal res_mat_element        : std_logic_vector(31 downto 0) := (others => '0'); -- Result matrix element
    signal result_ready           : std_logic := '0'; -- Flag to indicate result is ready

begin

    -- Main process handling the state machines and control logic
    process(CLK, RST)
    begin
        if RST = '1' then -- Reset condition
            main_sm <= st_idle; -- Set main state machine to idle
            calc_sm <= st_idle; -- Set calculation state machine to idle
            DATA_REQUEST <= '0'; -- Clear data request signal
            data_count <= 0; -- Reset data count
            row_num <= 0; -- Reset row number
            col_num <= 0; -- Reset column number
            high_address <= "000"; -- Reset high address bits
            iteration_num <= 0; -- Reset iteration number
            store_mat1_row_data <= '0'; -- Clear store matrix 1 row data signal
            store_mat2_col_data <= '0'; -- Clear store matrix 2 column data signal
            result_ready <= '0'; -- Clear result ready flag
            GOT_ALL_MATRICES <= '0'; -- Clear all matrices received flag
            RESULTS_READY <= '0'; -- Clear results ready flag
        elsif rising_edge(CLK) then -- On rising edge of the clock
            DATA_REQUEST <= '0'; -- Clear data request signal
            store_mat1_row_data <= '0'; -- Clear store matrix 1 row data signal
            store_mat2_col_data <= '0'; -- Clear store matrix 2 column data signal

            -- Main state machine
            case main_sm is
                when st_idle =>
                    if start = '1' then -- Check if start signal is active
                        main_sm <= st_receive_first_mat; -- Transition to receive first matrix state
                        DATA_REQUEST <= '1'; -- Set data request signal
                    end if;
                    row_num <= 0; -- Reset row number
                    col_num <= 0; -- Reset column number
                    iteration_num <= 0; -- Reset iteration number

                when st_receive_first_mat =>
                    if DIN_VALID = '1' then -- Check if data is valid
                        if data_count = C_NUM_OF_ELEMENTS -1 then -- If all elements received
                            main_sm <= st_receive_second_mat; -- Transition to receive second matrix state
                            data_count <= 0; -- Reset data count
                            DATA_REQUEST <= '1'; -- Set data request signal
                        else
                            data_count <= data_count + 1; -- Increment data count
                        end if;

                        if col_num = 3 then -- Check if last column is received
                            col_num <= 0; -- Reset column number
                            if row_num = 3 then -- Check if last row is received
                                row_num <= 0; -- Reset row number
                            else
                                row_num <= row_num + 1; -- Increment row number
                            end if;
                        else
                            col_num <= col_num + 1; -- Increment column number
                        end if;

                    end if;
                    high_address <= "000"; -- Reset high address bits

                when st_receive_second_mat =>
                    if DIN_VALID = '1' then -- Check if data is valid
                        if data_count = C_NUM_OF_ELEMENTS -1 then -- If all elements received
                            main_sm <= st_wait_for_calculate; -- Transition to wait for calculation state
                            GOT_ALL_MATRICES <= '1'; -- Set all matrices received flag
                            data_count <= 0; -- Reset data count
                        else
                            data_count <= data_count + 1; -- Increment data count
                        end if;

                        if row_num = 3 then -- Check if last row is received
                            row_num <= 0; -- Reset row number
                            if col_num = 3 then -- Check if last column is received
                                col_num <= 0; -- Reset column number
                            else
                                col_num <= col_num + 1; -- Increment column number
                            end if;
                        else
                            row_num <= row_num + 1; -- Increment row number
                        end if;
                    end if;
                    high_address <= "001"; -- Set high address bits for second matrix

                when st_wait_for_calculate =>
                    row_num <= 0; -- Reset row number
                    high_address <= "000"; -- Reset high address bits
                    if start = '1' then -- Check if start signal is active
                        main_sm <= st_calculate; -- Transition to calculate state
                        calc_sm <= st_get_row; -- Set calculation state machine to get row state
                    end if;

                when st_calculate =>
                    -- Calculation state machine
                    case calc_sm is
                        when st_get_row =>
                            calc_sm <= st_get_col; -- Transition to get column state
                            high_address <= "001"; -- Set high address bits for second matrix
                            row_num <= 0; -- Reset row number
                            store_mat1_row_data <= '1'; -- Set store matrix 1 row data signal

                        when st_get_col =>
                            if row_num = 3 then -- Check if last row is reached
                                calc_sm <= st_save; -- Transition to save state
                                row_num <= 0; -- Reset row number
                                high_address <= '1' & std_logic_vector(to_unsigned(iteration_num, 2)); -- Set high address bits for result storage
                            else
                                row_num <= row_num + 1; -- Increment row number
                            end if;
                            store_mat2_col_data <= '1'; -- Set store matrix 2 column data signal

                        when st_save =>
                            if row_num = 3 then -- Check if last row is reached
                                if iteration_num = 3 then -- Check if last iteration is done
                                    calc_sm <= st_idle; -- Transition to idle state
                                else
                                    iteration_num <= iteration_num + 1; -- Increment iteration number
                                    calc_sm <= st_get_row; -- Transition to get row state
                                    high_address <= "000"; -- Reset high address bits
                                    row_num <= iteration_num + 1; -- Set row number for next iteration
                                end if;
                            else
                                row_num <= row_num + 1; -- Increment row number
                            end if;

                        when st_idle =>
                            main_sm <= st_display; -- Transition to display state
                            result_ready <= '1'; -- Set result ready flag
                            GOT_ALL_MATRICES <= '0'; -- Clear all matrices received flag
                            row_num <= 0; -- Reset row number
                            high_address <= "100"; -- Set high address bits for result display
                    end case;

                when st_display =>
                    if display = '1' then -- Check if display signal is active
                        if row_num = 3 then -- Check if last row is reached
                            if unsigned(high_address(1 downto 0)) = 3 then -- Check if last address is reached
                                high_address <= "100"; -- Set high address bits to result display state
                            else
                                high_address <= std_logic_vector(unsigned(high_address) + 1); -- Increment high address bits
                            end if;
                            row_num <= 0; -- Reset row number
                        else
                            row_num <= row_num + 1; -- Increment row number
                        end if;
                    end if;
                    if start = '1' then -- Check if start signal is active
                        main_sm <= st_idle; -- Transition to idle state
                        result_ready <= '0'; -- Clear result ready flag
                    end if;

            end case;

            RESULTS_READY <= result_ready; -- Update results ready flag

        end if;
    end process;

    -- Process to store row data from matrix 1 into memory
    process(CLK, RST)
    begin
        if RST = '1' then -- Reset condition
            mat1_row_data <= (others => '0'); -- Clear matrix 1 row data
        elsif rising_edge(CLK) then -- On rising edge of the clock
            if store_mat1_row_data = '1' then -- Check if store signal is active
                mat1_row_data <= mem_dout; -- Store memory output into matrix 1 row data
            end if;
        end if;
    end process;

    -- Memory address and write control logic
    mem_address <= high_address & std_logic_vector(to_unsigned(row_num, 2)); -- Combine high address and row number for memory address
    mem_wr_data <= res_mat_element when res_mat_element_valid = '1' else DIN & DIN & DIN & DIN; -- Select write data for memory
    mem_wr <= DIN_VALID or res_mat_element_valid; -- Enable memory write if data input is valid or result element is valid
    mem_byte_enable <= "1111" when res_mat_element_valid = '1' else byte_enable; -- Select byte enable for memory

    -- Process to generate byte enable signals based on column number
    qen_byte_enable : process(col_num)
    begin
        case col_num is
            when 0 =>
                byte_enable <= "0001"; -- Enable first byte
            when 1 =>
                byte_enable <= "0010"; -- Enable second byte
            when 2 =>
                byte_enable <= "0100"; -- Enable third byte
            when 3 =>
                byte_enable <= "1000"; -- Enable fourth byte
        end case;
    end process;

    -- Instantiate matrix RAM component
    matrix_ram_inst : matrix_ram
        generic map (
            DATA_WIDTH => 32, -- Data width of RAM
            ADDRESS_BITS => 5 -- Number of address bits for RAM
        )
        port map (
            CLK       => CLK, -- Connect clock signal
            RST       => RST, -- Connect reset signal
            DATA      => mem_wr_data, -- Connect memory write data
            WREN      => mem_wr, -- Connect memory write enable
            ADDRESS   => mem_address, -- Connect memory address
            BYTEENA   => mem_byte_enable, -- Connect byte enable signals
            Q         => mem_dout -- Connect memory output data
        );

    -- Instantiate first multiplier component
    mult1 : my_multiplier
        generic map (
            N          => N, -- Width of data inputs/outputs
            LATENCY    => LATENCY, -- Latency of multiplier
            IS_SIGNED  => IS_SIGNED -- Signed/unsigned operation flag
        )
        port map (
            CLK        => CLK, -- Connect clock signal
            DIN_VALID  => store_mat2_col_data, -- Connect data valid signal
            A          => mat1_row_data(7 downto 0), -- Connect lower 8 bits of matrix 1 row data
            B          => mem_dout(7 downto 0), -- Connect lower 8 bits of memory output data
            Q          => mult1_q, -- Connect multiplier output
            DOUT_VALID => mult1_q_valid -- Connect multiplier output valid flag
        );

    -- Instantiate second multiplier component
    mult2 : my_multiplier
        generic map (
            N          => N, -- Width of data inputs/outputs
            LATENCY    => LATENCY, -- Latency of multiplier
            IS_SIGNED  => IS_SIGNED -- Signed/unsigned operation flag
        )
        port map (
            CLK        => CLK, -- Connect clock signal
            DIN_VALID  => store_mat2_col_data, -- Connect data valid signal
            A          => mat1_row_data(15 downto 8), -- Connect next 8 bits of matrix 1 row data
            B          => mem_dout(15 downto 8), -- Connect next 8 bits of memory output data
            Q          => mult2_q, -- Connect multiplier output
            DOUT_VALID => mult2_q_valid -- Connect multiplier output valid flag
        );

    -- Instantiate third multiplier component
    mult3 : my_multiplier
        generic map (
            N          => N, -- Width of data inputs/outputs
            LATENCY    => LATENCY, -- Latency of multiplier
            IS_SIGNED  => IS_SIGNED -- Signed/unsigned operation flag
        )
        port map (
            CLK        => CLK, -- Connect clock signal
            DIN_VALID  => store_mat2_col_data, -- Connect data valid signal
            A          => mat1_row_data(23 downto 16), -- Connect next 8 bits of matrix 1 row data
            B          => mem_dout(23 downto 16), -- Connect next 8 bits of memory output data
            Q          => mult3_q, -- Connect multiplier output
            DOUT_VALID => mult3_q_valid -- Connect multiplier output valid flag
        );

    -- Instantiate fourth multiplier component
    mult4 : my_multiplier
        generic map (
            N          => N, -- Width of data inputs/outputs
            LATENCY    => LATENCY, -- Latency of multiplier
            IS_SIGNED  => IS_SIGNED -- Signed/unsigned operation flag
        )
        port map (
            CLK        => CLK, -- Connect clock signal
            DIN_VALID  => store_mat2_col_data, -- Connect data valid signal
            A          => mat1_row_data(31 downto 24), -- Connect upper 8 bits of matrix 1 row data
            B          => mem_dout(31 downto 24), -- Connect upper 8 bits of memory output data
            Q          => mult4_q, -- Connect multiplier output
            DOUT_VALID => mult4_q_valid -- Connect multiplier output valid flag
        );

    -- Process to sum the products of the multiplications and store the result
    sum_of_products : process(CLK, RST)
    begin
        if RST = '1' then -- Reset condition
            res_mat_element        <= (others => '0'); -- Clear result matrix element
            res_mat_element_valid  <= '0'; -- Clear result element valid flag
        elsif rising_edge(CLK) then -- On rising edge of the clock
            res_mat_element <= std_logic_vector(
                resize(signed(mult1_q), 32) +
                resize(signed(mult2_q), 32) +
                resize(signed(mult3_q), 32) +
                resize(signed(mult4_q), 32)); -- Sum the resized multiplier outputs
            res_mat_element_valid <= mult1_q_valid; -- Set result element valid flag based on first multiplier valid flag
        end if;
    end process;

    RESULT <= mem_dout(16 downto 0); -- Output the lower 17 bits of the memory output as the final result

end architecture;
