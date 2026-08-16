library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

use     work.JtagTapPkg.all;

entity JTAGH19EMUL is
   generic (
      HUB_ID_G       : std_logic_vector(23 downto 0) := x"000043"
   );
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

   constant BYP_IDX_C       : integer := -1;
   constant ER1_IDX_C       : natural := 0;
   constant ER2_IDX_C       : natural := 1;

   constant CFG_C           : JtagTapInstructionArray := (
      ER1_IDX_C => "00110010",
      ER2_IDX_C => "00111000"
   );

   type RegType is record
      rstn             : std_logic;
      er2_tdo          : std_logic;
      er1_dr           : std_logic_vector(23 downto 0);
      er1_sr           : std_logic_vector(23 downto 0);
   end record RegType;

   constant REG_INIT_C : RegType := (
      rstn             => '0',
      er2_tdo          => '0',
      er1_dr           => x"000006",
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
   signal tapState     : JtagTapStateType;

begin

   P_COMB : process ( r, tckRising, tckFalling, TDI, instIdx, captureD, shiftD, updateD, ER2_TDO, tapState ) is
      variable v : RegType;
   begin
      v                := r;
      -- JRSTN
      if ( tckFalling = '1' ) then
         if ( tapState = TEST_LOGIC_RESET ) then
            v.rstn := '0';
         else
            v.rstn := '1';
         end if;
      end if;
      if ( (tckRising and captureD) = '1' ) then
         if ( instIdx = ER1_IDX_C ) then
            v.er1_sr := r.er1_dr;
	 else
            -- for all other instructions capture the hub id
	    v.er1_sr := HUB_ID_G;
	 end if;
      end if;

      if ( (tckRising and shiftD) = '1' ) then
         v.er1_sr := TDI & r.er1_sr(r.er1_sr'left downto 1);
	 if ( instIdx = ER2_IDX_C ) then
            -- rotate DR with the HUB ID; if msbit int ER1-DR
            -- is not set then the ID will not be propagated into
            -- er2_tdo, see below
            v.er1_sr(v.er1_sr'left) := r.er1_sr(0);
	 end if;
      end if;

      if ( tckFalling = '1' ) then
         if ( r.er1_dr(23) = '0' ) then
            -- ID not selected
            v.er2_tdo := '0';
            -- if any IP_ENABLE bit is set override and register lsbit
	    L_SEL_ER2 : for i in 0 to 18 loop
               if ( r.er1_dr(i+4) = '1' ) then
                  v.er2_tdo := ER2_TDO(i);
                  exit L_SEL_ER2;
	       end if;
	    end loop;
         end if;
      end if;

      if ( (tckFalling and updateD) = '1' ) then
         if ( instIdx = ER1_IDX_C ) then
            v.er1_dr             := r.er1_sr;
            v.er1_dr(2 downto 0) := "110";
         end if;
      end if;

      
      tdoSel(ER1_IDX_C) <= r.er1_sr(0);
      tdoSel(ER2_IDX_C) <= r.er2_tdo;
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

         state            => tapState,
         instructionIdx   => instIdx,
         instructionCapt  => open,
         instructionSel   => open,
         tdoSel           => tdoSel,
         captureD         => captureD,
         shiftD           => shiftD,
         updateD          => updateD
      );

   JTCK       <= TCK;
   JTDI       <= TDI;
   JSHIFT     <= shiftD               when ( instIdx > BYP_IDX_C ) else '0';
   JUPDATE    <= updateD              when ( instIdx > BYP_IDX_C ) else '0';
   JCE2       <= (captureD or shiftD) when ( instIdx = ER2_IDX_C ) else '0';
   JRSTN      <= r.rstn;
   IP_ENABLE  <= r.er1_dr(22 downto 4);

end architecture rtl;
