library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

package JtagTapPkg is
   type JtagTapInstructionArray is array (natural range <>, natural range <>) of std_logic;

   function instructionSize(constant cfg : in JtagTapInstructionArray)
   return natural;

   function numInstructions(constant cfg : in JtagTapInstructionArray)
   return natural;

   function toSlv(constant cfg : in JtagTapInstructionArray; constant which : in natural)
   return std_logic_vector;

   type JtagTapStateType is (
      TEST_LOGIC_RESET,
      RUN_TEST_IDLE,
      SELECT_DR_SCAN,
      CAPTURE_DR,
      SHIFT_DR,
      EXIT1_DR,
      PAUSE_DR,
      EXIT2_DR,
      UPDATE_DR,
      SELECT_IR_SCAN,
      CAPTURE_IR,
      SHIFT_IR,
      EXIT1_IR,
      PAUSE_IR,
      EXIT2_IR,
      UPDATE_IR
   );
end package JtagTapPkg;

package body JtagTapPkg is

   function instructionSize(constant cfg : in JtagTapInstructionArray)
   return natural is
   begin
      return cfg'length(2);
   end function instructionSize;

   function toSlv(constant cfg : in JtagTapInstructionArray; constant which : in natural)
   return std_logic_vector is
      variable v : std_logic_vector(instructionSize(cfg) - 1  downto 0);
   begin
      for i in cfg'range(2) loop
         v(v'left - i) := cfg(which, i);
      end loop;
      return v;
   end function toSlv;

   function numInstructions(constant cfg : in JtagTapInstructionArray)
   return natural is
   begin
      return cfg'length(1);
   end function numInstructions;

end package body JtagTapPkg;
