
-- Desription:
-- Calculation of invariant mass based on LUTs and calculation of pt for cutting invariant mass.
-- Limits for invariant mass and pt comparison provided.

-- Version history:
-- HB 2016-11-08: first design

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use work.math_pkg.all;

use work.gtl_pkg.all;

entity invariant_mass_w_pt is
    generic (
	sel_sig_pt_square_cut : boolean := false; -- "true" selects sig_pt_square_cut for simulation, "false" selects pt_square_cut in generic for synthesis
-- limits for comparison of invariant mass, given for M**2/2 [=pt1*pt2*(cosh(eta1-eta2)-cos(phi1-phi2)]
	inv_mass_upper_limit: real := 15.0;
	inv_mass_lower_limit: real := 10.0;
	pt1_width: positive := 12;
	pt2_width: positive := 12;
	cosh_cos_width: positive := 28;
	INV_MASS_PRECISION : positive := 1; -- 1 => first digit after decimal point
	INV_MASS_COSH_COS_PRECISION : positive := 3;
-- HB 2016-11-08: calculation of pt**2
	pt_square_cut : boolean := true; -- used for synthesis
	pt_sq_upper_limit: real := 15.0; -- for pt**2
	pt_sq_lower_limit: real := 15.0;
	sin_cos_width: positive := 10; -- for pt**2 calculation
	PT_PRECISION : positive := 1;
	PT_SQ_SIN_COS_PRECISION : positive := 3
    );
    port(
	pt1 : in std_logic_vector(pt1_width-1 downto 0);
        pt2 : in std_logic_vector(pt2_width-1 downto 0);
	cosh_deta : in std_logic_vector(cosh_cos_width-1 downto 0);
        cos_dphi : in std_logic_vector(cosh_cos_width-1 downto 0);
        cos_phi_1 : in std_logic_vector(sin_cos_width-1 downto 0);
        cos_phi_2 : in std_logic_vector(sin_cos_width-1 downto 0);
        sin_phi_1 : in std_logic_vector(sin_cos_width-1 downto 0);
        sin_phi_2 : in std_logic_vector(sin_cos_width-1 downto 0);
	sig_pt_square_cut : in boolean := true; -- used for simulation only
        inv_mass_comp : out std_logic;
-- HB 2016-11-08: calculation of pt - sim outputs
        sim_pt_square : out std_logic_vector(((max(pt1_width, pt2_width))*2+2)+(sin_cos_width*2)-1 downto 0);
        sim_pt_sq_upper_limit_vector : out std_logic_vector(((max(pt1_width, pt2_width))*2+2)+(sin_cos_width*2)-1 downto 0);
        sim_pt_sq_lower_limit_vector : out std_logic_vector(((max(pt1_width, pt2_width))*2+2)+(sin_cos_width*2)-1 downto 0)
    );
end invariant_mass_w_pt;

architecture rtl of invariant_mass_w_pt is

-- HB 2016-11-08: calculation of pt**2
-- in FACTOR_PT_SQ_LIMIT_VECTOR and FACTOR_INV_MASS_VECTOR multiplication with 4 to get "enough" bits for vector (of the factor integer value)
    constant FACTOR_PT_SQ_LIMIT_VECTOR : std_logic_vector((PT_PRECISION+PT_SQ_SIN_COS_PRECISION*2)*4-1 downto 0) := conv_std_logic_vector(10**(PT_PRECISION+PT_SQ_SIN_COS_PRECISION*2), (PT_PRECISION+PT_SQ_SIN_COS_PRECISION*2)*4);
-- max(pt1_width, pt2_width) used to get max. if pt_width is different
    constant max_pt_width : positive := max(pt1_width, pt2_width);
-- PT_SQ_VECTOR_WIDTH based on formular for pt**2 [...+2+... because of ...+2*pt1*pt2*(cos(phi1)*cos(phi2)+sin(phi1)*sin(phi2))]
    constant PT_SQ_VECTOR_WIDTH : positive := max_pt_width+max_pt_width+2+sin_cos_width*2;
    signal pt_square : std_logic_vector(PT_SQ_VECTOR_WIDTH-1 downto 0);
    signal pt_sq_upper_limit_vector : std_logic_vector(PT_SQ_VECTOR_WIDTH-1 downto 0);
    signal pt_sq_lower_limit_vector : std_logic_vector(PT_SQ_VECTOR_WIDTH-1 downto 0);
    signal pt_square_comp : std_logic;
    signal pt_sin_product : std_logic_vector(PT_SQ_VECTOR_WIDTH-1 downto 0);
    signal pt_cos_product : std_logic_vector(PT_SQ_VECTOR_WIDTH-1 downto 0);
    signal pt1_square : std_logic_vector(PT_SQ_VECTOR_WIDTH-1 downto 0);
    signal pt2_square : std_logic_vector(PT_SQ_VECTOR_WIDTH-1 downto 0);
    signal pt_square_cut_internal : boolean := false; -- internal pt_square_cut, selected with sel_sig_pt_square_cut

-- HB 2015-10-21: length of std_logic_vector for invariant mass (inv_mass_sq_div2) and limits.
    constant INV_MASS_VECTOR_WIDTH : positive := pt1_width+pt2_width+cosh_cos_width;
-- HB 2015-10-21: multiplication factor for limits (number of relevant position after decimal point - INV_MASS_PRECISION => 1, globaly set in gtl.pkg).
    constant INV_MASS_PRECISION_FACTOR : real := real(10**INV_MASS_PRECISION);
-- HB 2015-10-21: multiplication factor for limits vectors. INV_MASS_COSH_COS_PRECISION: number of relevant position after decimal point for cosh_deta and cos_dphi, globaly set in gtl.pkg.
    constant FACTOR_INV_MASS_VECTOR : std_logic_vector((INV_MASS_COSH_COS_PRECISION+1)*4-1 downto 0) := conv_std_logic_vector(10**(INV_MASS_COSH_COS_PRECISION+1),(INV_MASS_COSH_COS_PRECISION+1)*4);

    signal inv_mass_sq_div2 : std_logic_vector(INV_MASS_VECTOR_WIDTH-1 downto 0);
    signal inv_mass_upper_limit_vector : std_logic_vector(INV_MASS_VECTOR_WIDTH-1 downto 0);
    signal inv_mass_lower_limit_vector : std_logic_vector(INV_MASS_VECTOR_WIDTH-1 downto 0);

begin

    pt_square_cut_internal <= sig_pt_square_cut when sel_sig_pt_square_cut else pt_square_cut; -- internal pt_square_cut, selected with sel_sig_pt_square_cut

-- HB 2016-11-08: calculation of pt**2 with formular => pt**2 = pt1**2+pt2**2+2*pt1*pt2*(cos(phi1)*cos(phi2)+sin(phi1)*sin(phi2))

-- in VHDL used: pt**2 = pt1*pt1+pt2*pt2+2*pt1*pt2*cos(phi1)*cos(phi2)+2*pt1*pt2*sin(phi1)*sin(phi2)

    pt1_square <= pt1 * pt1 * conv_std_logic_vector(integer(real(10**(PT_SQ_SIN_COS_PRECISION*2))), PT_SQ_VECTOR_WIDTH-pt1_width*2);
    pt2_square <= pt2 * pt2 * conv_std_logic_vector(integer(real(10**(PT_SQ_SIN_COS_PRECISION*2))), PT_SQ_VECTOR_WIDTH-pt2_width*2);
    pt_cos_product <= conv_std_logic_vector(2,2) * pt1 * pt2 * cos_phi_1 * cos_phi_2;
    pt_sin_product <= conv_std_logic_vector(2,2) * pt1 * pt2 * sin_phi_1 * sin_phi_2;

    pt_square <= pt1_square + pt2_square + pt_cos_product + pt_sin_product;
    sim_pt_square <= pt_square;
    
-- HB 2016-11-11: converting limits to std_logic_vector for comparison. Integer (32-bits in VHDL) would be exeeded, therefore std_logic_vector.
    pt_sq_upper_limit_vector <= conv_std_logic_vector(integer(pt_sq_upper_limit*real(10**PT_PRECISION)),PT_SQ_VECTOR_WIDTH-FACTOR_PT_SQ_LIMIT_VECTOR'length)*FACTOR_PT_SQ_LIMIT_VECTOR;
    sim_pt_sq_upper_limit_vector <= pt_sq_upper_limit_vector;
    pt_sq_lower_limit_vector <= conv_std_logic_vector(integer(pt_sq_lower_limit*real(10**PT_PRECISION)),PT_SQ_VECTOR_WIDTH-FACTOR_PT_SQ_LIMIT_VECTOR'length)*FACTOR_PT_SQ_LIMIT_VECTOR;
    sim_pt_sq_lower_limit_vector <= pt_sq_lower_limit_vector;
    
    pt_square_comp <= '1' when (pt_square >= pt_sq_lower_limit_vector and pt_square <= pt_sq_upper_limit_vector) else '0';
    
-- HB 2015-10-01: converting limits to std_logic_vector for comparison. Integer (32-bits in VHDL) would be exeeded, therefore std_logic_vector.
    inv_mass_upper_limit_vector <= conv_std_logic_vector((integer(inv_mass_upper_limit*INV_MASS_PRECISION_FACTOR)),INV_MASS_VECTOR_WIDTH-FACTOR_INV_MASS_VECTOR'length)*FACTOR_INV_MASS_VECTOR;
    inv_mass_lower_limit_vector <= conv_std_logic_vector((integer(inv_mass_lower_limit*INV_MASS_PRECISION_FACTOR)),INV_MASS_VECTOR_WIDTH-FACTOR_INV_MASS_VECTOR'length)*FACTOR_INV_MASS_VECTOR;

-- HB 2015-10-01: calculation of invariant mass with formular M**2/2=pt1*pt2*(cosh(eta1-eta2)-cos(phi1-phi2)
    inv_mass_sq_div2 <= pt1 * pt2 * (cosh_deta - cos_dphi);

-- HB 2016-11-11: REMARK: logic of pt_square_comp has to be confirmed, whether cutting is done if pt**2 is between limits (current implementation !) or outside limits
    inv_mass_comp <= '1' when (inv_mass_sq_div2 >= inv_mass_lower_limit_vector and inv_mass_sq_div2 <= inv_mass_upper_limit_vector and not (pt_square_comp = '1' and pt_square_cut_internal)) else '0';
    
end architecture rtl;
