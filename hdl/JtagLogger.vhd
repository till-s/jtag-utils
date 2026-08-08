library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

entity JtagLogger is
   generic (
      ASYNC_G        : boolean := true
   );
   port (
      clk            : in  std_logic;
      rst            : in  std_logic;
      tck            : in  std_logic;
      tms            : in  std_logic;
      tdi            : in  std_logic;
      tdo            : in  std_logic;
      dataInp        : in  std_logic_vector(7 downto 3) := (others => '0');
      dataOut        : out std_logic_vector(7 downto 0); -- tdo, tdi, tms captured on rising tck edge
      dataVld        : out std_logic; -- 1-cycle asserted when new data are available
      full           : in  std_logic := '0'; -- fifo full (aux)
      overrun        : out std_logic; -- fifo overrun detected
      overrunClr     : in  std_logic; -- clearn overrun detector
      glitch         : out std_logic; -- glitch detected (sticky)
      glitchClr      : in  std_logic  -- clear glitch detector
   );
end entity JtagLogger;

architecture rtl of JtagLogger is
   signal tckSyn               : std_logic_vector(2 downto 0) := (others => '1');
   signal tmsSyn               : std_logic_vector(2 downto 0);
   signal tdiSyn               : std_logic_vector(2 downto 0);
   signal tdoSyn               : std_logic_vector(2 downto 0);
   signal datSyn               : std_logic_vector(7 downto 3) := (others => '0');
begin

   G_ASYNC : if ( ASYNC_G ) generate
   begin
      U_JTAG_SYNC : entity work.SynchronizerBit
         generic map (
             WIDTH_G    => 9
         )
         port map (
             clk        => clk,
             rst        => '0',
             datInp(0)  => tck,
             datInp(1)  => tms,
             datInp(2)  => tdi,
             datInp(3)  => tdo,
             datInp(4)  => dataInp(3),
             datInp(5)  => dataInp(4),
             datInp(6)  => dataInp(5),
             datInp(7)  => dataInp(6),
             datInp(8)  => dataInp(7),

             datOut(0)  => tckSyn(0),
             datOut(1)  => tmsSyn(0),
             datOut(2)  => tdiSyn(0),
             datOut(3)  => tdoSyn(0),
             datOut(4)  => datSyn(3),
             datOut(5)  => datSyn(4),
             datOut(6)  => datSyn(5),
             datOut(7)  => datSyn(6),
             datOut(8)  => datSyn(7)
         );
   end generate G_ASYNC;

   G_SYNC : if ( not ASYNC_G ) generate
   begin
      tckSyn(0) <= tck;
      tmsSyn(0) <= tms;
      tdiSyn(0) <= tdi;
      tdoSyn(0) <= tdo;
      datSyn    <= dataInp;
   end generate G_SYNC;

   B_JTAG_LOG : block is
      signal data         : std_logic_vector(7 downto 0);
      signal vld          : std_logic := '0';
      signal ovr          : std_logic := '0';
      signal gli          : std_logic := '0';
      signal datSyn1      : std_logic_vector(datSyn'range) := (others => '0');
   begin

      dataVld                 <= vld;
      dataOut                 <= data;
      overrun                 <= ovr;
      glitch                  <= gli;

      P_JTAG_LOG : process ( clk ) is
      begin
         if ( rising_edge( clk ) ) then
	    tckSyn(tckSyn'left downto 1) <= tckSyn(tckSyn'left - 1 downto 0);
	    tmsSyn(tmsSyn'left downto 1) <= tmsSyn(tmsSyn'left - 1 downto 0);
	    tdiSyn(tdiSyn'left downto 1) <= tdiSyn(tdiSyn'left - 1 downto 0);
	    tdoSyn(tdoSyn'left downto 1) <= tdoSyn(tdoSyn'left - 1 downto 0);
	    datSyn1                      <= datSyn;
            vld  <= '0';
            if ( full = '1' ) then
               ovr <= '1';
            end if;
            if ( overrunClr = '1' ) then
               ovr <= '0';
            end if;
            if ( glitchClr = '1' ) then
               gli <= '0';
            end if;
            if ( tckSyn = "011" ) then
               if ( tdoSyn /= "111" and tdoSyn /= "000" ) then
                  gli    <= '1';
               end if;
               if ( tmsSyn /= "111" and tmsSyn /= "000" ) then
                  gli    <= '1';
               end if;
               if ( tdiSyn /= "111" and tdiSyn /= "000" ) then
                  gli    <= '1';
               end if;

               data(0)                      <= tmsSyn(1);
               data(1)                      <= tdiSyn(1);
               data(2)                      <= tdoSyn(1);
	       data(7 downto 3)             <= datSyn1;
               vld                          <= '1';
            end if;
            if ( rst = '1' ) then
               tckSyn(tckSyn'left downto 1) <= (others => '1');
               gli                          <= '0';
               ovr                          <= '0';
               vld                          <= '0';
            end if;
         end if;
      end process P_JTAG_LOG;
   end block B_JTAG_LOG;
end architecture rtl;
