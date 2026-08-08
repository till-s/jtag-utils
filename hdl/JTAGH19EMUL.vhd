library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

use     work.JtagTapPkg.all;

entity JTAGH19EMUL is
   port (
      clk            : in  std_logic;
      rst            : in  std_logic;

      TCK            : in  std_logic;
      TMS            : in  std_logic;
      TDI            : in  std_logic;

      TDO            : out std_logic;

      JTCK           : out std_logic;
      JTDI           : out std_logic;

      JSHIFT         : out std_logic;
      JUPDATE        : out std_logic;
      JRSTN          : out std_logic;
      JCE2           : out std_logic;
      CDN            : out std_Logic := '0';

      ER2_TDO        : in  std_logic_vector(18 downto 0);
      IP_ENABLE      : out std_logic_vector(18 downto 0)
   );
end entity JTAGH19EMUL;

architecture rtl of JTAGH19EMUL is

   constant ER1_IDX_C       : natural := 0;
   constant ER2_IDX_C       : natural := 1;

   constant CFG_C           : JtagTapInstructionArray := (
      ER1_IDX_C => "00110010",
      ER2_IDX_C => "00111000"
   );

   type RegType is record
      er1_dr           : std_logic_vector(23 downto 0);
      er1_sr           : std_logic_vector(23 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      er1_dr           => (others => '0'),
      er1_sr           => (others => '0')
   );

   signal r            : RegType := REG_INIT_C;
   signal rin          : RegType;
   signal instIdx      : integer;
   signal tdoSel       : std_logic_vector(numInstructions(CFG_C) - 1 downto 0);
   signal captureD     : std_logic;
   signal shiftD       : std_logic;
   signal updateD      : std_logic;
   signal tckRising    : std_logic;
   signal tckFalling   : std_logic;

begin

   P_COMB : process ( r, tckRising, tckFalling, TDI, instIdx, captureD, shiftD, updateD, ER2_TDO ) is
      variable v : RegType;
   begin
      v                := r;
      JCE2             <= '0';
      if ( instIdx = ER1_IDX_C ) then
         if ( (tckRising and captureD) = '1' ) then
            v.er1_sr := r.er1_dr;
         end if;
         if ( (tckRising and shiftD) = '1' ) then
            v.er1_sr := TDI & r.er1_dr(r.er1_dr'left downto 1);
         end if;
         if ( (tckRising and updateD) = '1' ) then
            v.er1_dr := r.er1_sr;
         end if;
      end if;
      if ( instIdx = ER2_IDX_C ) then
         JCE2 <= '1';
      end if;
      
      IP_ENABLE         <= (others => '0');
      tdoSel(ER2_IDX_C) <= '0';
      L_ER2 : for  i in 0 to 18 loop
         if ( '1' = r.er1_dr(4 + i) ) then
            IP_ENABLE(i) <= '1';
            tdoSel(ER2_IDX_C) <= ER2_TDO(i);
            exit L_ER2;
         end if;
      end loop;
      tdoSel(ER1_IDX_C) <= r.er1_sr(0);
      rin               <= v;
   end process P_COMB;


   P_SEQ : process ( clk ) is
   begin
      if ( rising_edge( clk ) ) then
         if ( rst = '1' ) then
            r <= REG_INIT_C;
         else
            r <= rin;
         end if;
      end if;
   end process P_SEQ;

   U_TAP : entity work.JtagTap
      generic map (
         CFG_G            => CFG_C
      )
      port map (
         clk              => clk,
         rst              => rst,

         tck              => TCK,
         tms              => TMS,
         tdi              => TDI,
         tdo              => TDO,
         tckRising        => tckRising,
         tckFalling       => tckFalling,

         state            => open,
         instructionIdx   => instIdx,
         instructionCapt  => open,
         instructionSel   => open,
         tdoSel           => tdoSel,
         captureD         => captureD,
         shiftD           => shiftD,
         updateD          => updateD
      );

   JTCK    <= TCK;
   JTDI    <= TDI;
   JSHIFT  <= shiftD;
   JUPDATE <= updateD;
   JRSTN   <= '1';

end architecture rtl;
