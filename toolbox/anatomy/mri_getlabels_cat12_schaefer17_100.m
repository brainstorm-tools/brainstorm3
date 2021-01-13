function Labels = mri_getlabels_shaeffer100()
% ATLAS     : Local-Global Parcellation of the Human Cerebral Cortex from Intrinsic Functional Connectivity MRI
% REFERENCE : https://pubmed.ncbi.nlm.nih.gov/28981612/

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2020 University of Southern California & McGill University
% This software is distributed under the terms of the GNU General Public License
% as published by the Free Software Foundation. Further details on the GPLv3
% license can be found at http://www.gnu.org/copyleft/gpl.html.
% 
% FOR RESEARCH PURPOSES ONLY. THE SOFTWARE IS PROVIDED "AS IS," AND THE
% UNIVERSITY OF SOUTHERN CALIFORNIA AND ITS COLLABORATORS DO NOT MAKE ANY
% WARRANTY, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF
% MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, NOR DO THEY ASSUME ANY
% LIABILITY OR RESPONSIBILITY FOR THE USE OF THIS SOFTWARE.
%
% For more information type "brainstorm license" at command prompt.
% =============================================================================@

Labels = {...
        0, 'Background',               [    0    0    0]; ...
        1, 'VisCent_ExStr_1 L',        [  255    0    0]; ...   % 17Networks_LH_VisCent_ExStr_1
        2, 'VisCent_ExStr_2 L',        [  255    0    0]; ...   % 17Networks_LH_VisCent_ExStr_2
        3, 'VisCent_Striate_1 L',      [  255    0    0]; ...   % 17Networks_LH_VisCent_Striate_1
        4, 'VisCent_ExStr_3 L',        [  255    0    0]; ...   % 17Networks_LH_VisCent_ExStr_3
        5, 'VisPeri_ExStrInf_1 L',     [  102  102  255]; ...   % 17Networks_LH_VisPeri_ExStrInf_1
        6, 'VisPeri_StriCal_1 L',      [  102  102  255]; ...   % 17Networks_LH_VisPeri_StriCal_1
        7, 'VisPeri_ExStrSup_1 L',     [  102  102  255]; ...   % 17Networks_LH_VisPeri_ExStrSup_1
        8, 'SomMotA_1 L',              [  255  177  100]; ...   % 17Networks_LH_SomMotA_1
        9, 'SomMotA_2 L',              [  255  177  100]; ...   % 17Networks_LH_SomMotA_2
       10, 'SomMotB_Aud_1 L',          [    0  255  255]; ...   % 17Networks_LH_SomMotB_Aud_1
       11, 'SomMotB_S2_1 L',           [    0  255  255]; ...   % 17Networks_LH_SomMotB_S2_1
       12, 'SomMotB_S2_2 L',           [    0  255  255]; ...   % 17Networks_LH_SomMotB_S2_2
       13, 'SomMotB_Cent_1 L',         [    0  255  255]; ...   % 17Networks_LH_SomMotB_Cent_1
       14, 'DorsAttnA_TempOcc_1 L',    [  255    0  255]; ...   % 17Networks_LH_DorsAttnA_TempOcc_1
       15, 'DorsAttnA_ParOcc_1 L',     [  255    0  255]; ...   % 17Networks_LH_DorsAttnA_ParOcc_1
       16, 'DorsAttnA_SPL_1 L',        [  255    0  255]; ...   % 17Networks_LH_DorsAttnA_SPL_1
       17, 'DorsAttnB_PostC_1 L',      [  102    0    0]; ...   % 17Networks_LH_DorsAttnB_PostC_1
       18, 'DorsAttnB_PostC_2 L',      [  102    0    0]; ...   % 17Networks_LH_DorsAttnB_PostC_2
       19, 'DorsAttnB_PostC_3 L',      [  102    0    0]; ...   % 17Networks_LH_DorsAttnB_PostC_3
       20, 'DorsAttnB_FEF_1 L',        [  102    0    0]; ...   % 17Networks_LH_DorsAttnB_FEF_1
       21, 'SalVentAttnA_ParOper_1 L', [    0  102    0]; ...   % 17Networks_LH_SalVentAttnA_ParOper_1
       22, 'SalVentAttnA_Ins_1 L',     [    0  102    0]; ...   % 17Networks_LH_SalVentAttnA_Ins_1
       23, 'SalVentAttnA_Ins_2 L',     [    0  102    0]; ...   % 17Networks_LH_SalVentAttnA_Ins_2
       24, 'SalVentAttnA_ParMed_1 L',  [    0  102    0]; ...   % 17Networks_LH_SalVentAttnA_ParMed_1
       25, 'SalVentAttnA_FrMed_1 L',   [    0  102    0]; ...   % 17Networks_LH_SalVentAttnA_FrMed_1
       26, 'SalVentAttnB_PFCl_1 L',    [  255  215    0]; ...   % 17Networks_LH_SalVentAttnB_PFCl_1
       27, 'SalVentAttnB_PFCmp_1 L',   [  255  215    0]; ...   % 17Networks_LH_SalVentAttnB_PFCmp_1
       28, 'LimbicB_OFC_1 L',          [    0  204    0]; ...   % 17Networks_LH_LimbicB_OFC_1
       29, 'LimbicA_TempPole_1 L',     [  255    0    0]; ...   % 17Networks_LH_LimbicA_TempPole_1
       30, 'LimbicA_TempPole_2 L',     [  255    0    0]; ...   % 17Networks_LH_LimbicA_TempPole_2
       31, 'ContA_IPS_1 L',            [  102  102  255]; ...   % 17Networks_LH_ContA_IPS_1
       32, 'ContA_PFCl_1 L',           [  102  102  255]; ...   % 17Networks_LH_ContA_PFCl_1
       33, 'ContA_PFCl_2 L',           [  102  102  255]; ...   % 17Networks_LH_ContA_PFCl_2
       34, 'ContB_PFClv_1 L',          [  255  177  100]; ...   % 17Networks_LH_ContB_PFClv_1
       35, 'ContC_pCun_1 L',           [    0  255  255]; ...   % 17Networks_LH_ContC_pCun_1
       36, 'ContC_pCun_2 L',           [    0  255  255]; ...   % 17Networks_LH_ContC_pCun_2
       37, 'ContC_Cingp_1 L',          [    0  255  255]; ...   % 17Networks_LH_ContC_Cingp_1
       38, 'DefaultA_PFCd_1 L',        [  255    0  255]; ...   % 17Networks_LH_DefaultA_PFCd_1
       39, 'DefaultA_pCunPCC_1 L',     [  255    0  255]; ...   % 17Networks_LH_DefaultA_pCunPCC_1
       40, 'DefaultA_PFCm_1 L',        [  255    0  255]; ...   % 17Networks_LH_DefaultA_PFCm_1
       41, 'DefaultB_Temp_1 L',        [  102    0    0]; ...   % 17Networks_LH_DefaultB_Temp_1
       42, 'DefaultB_Temp_2 L',        [  102    0    0]; ...   % 17Networks_LH_DefaultB_Temp_2
       43, 'DefaultB_IPL_1 L',         [  102    0    0]; ...   % 17Networks_LH_DefaultB_IPL_1
       44, 'DefaultB_PFCd_1 L',        [  102    0    0]; ...   % 17Networks_LH_DefaultB_PFCd_1
       45, 'DefaultB_PFCl_1 L',        [  102    0    0]; ...   % 17Networks_LH_DefaultB_PFCl_1
       46, 'DefaultB_PFCv_1 L',        [  102    0    0]; ...   % 17Networks_LH_DefaultB_PFCv_1
       47, 'DefaultB_PFCv_2 L',        [  102    0    0]; ...   % 17Networks_LH_DefaultB_PFCv_2
       48, 'DefaultC_Rsp_1 L',         [    0  102    0]; ...   % 17Networks_LH_DefaultC_Rsp_1
       49, 'DefaultC_PHC_1 L',         [    0  102    0]; ...   % 17Networks_LH_DefaultC_PHC_1
       50, 'TempPar_1 L',              [  255  215    0]; ...   % 17Networks_LH_TempPar_1
       51, 'VisCent_ExStr_1 R',        [  255    0    0]; ...   % 17Networks_RH_VisCent_ExStr_1
       52, 'VisCent_ExStr_2 R',        [  255    0    0]; ...   % 17Networks_RH_VisCent_ExStr_2
       53, 'VisCent_ExStr_3 R',        [  255    0    0]; ...   % 17Networks_RH_VisCent_ExStr_3
       54, 'VisPeri_StriCal_1 R',      [  102  102  255]; ...   % 17Networks_RH_VisPeri_StriCal_1
       55, 'VisPeri_ExStrInf_1 R',     [  102  102  255]; ...   % 17Networks_RH_VisPeri_ExStrInf_1
       56, 'VisPeri_ExStrSup_1 R',     [  102  102  255]; ...   % 17Networks_RH_VisPeri_ExStrSup_1
       57, 'SomMotA_1 R',              [  255  177  100]; ...   % 17Networks_RH_SomMotA_1
       58, 'SomMotA_2 R',              [  255  177  100]; ...   % 17Networks_RH_SomMotA_2
       59, 'SomMotA_3 R',              [  255  177  100]; ...   % 17Networks_RH_SomMotA_3
       60, 'SomMotA_4 R',              [  255  177  100]; ...   % 17Networks_RH_SomMotA_4
       61, 'SomMotB_Aud_1 R',          [    0  255  255]; ...   % 17Networks_RH_SomMotB_Aud_1
       62, 'SomMotB_S2_1 R',           [    0  255  255]; ...   % 17Networks_RH_SomMotB_S2_1
       63, 'SomMotB_S2_2 R',           [    0  255  255]; ...   % 17Networks_RH_SomMotB_S2_2
       64, 'SomMotB_Cent_1 R',         [    0  255  255]; ...   % 17Networks_RH_SomMotB_Cent_1
       65, 'DorsAttnA_TempOcc_1 R',    [  255    0  255]; ...   % 17Networks_RH_DorsAttnA_TempOcc_1
       66, 'DorsAttnA_ParOcc_1 R',     [  255    0  255]; ...   % 17Networks_RH_DorsAttnA_ParOcc_1
       67, 'DorsAttnA_SPL_1 R',        [  255    0  255]; ...   % 17Networks_RH_DorsAttnA_SPL_1
       68, 'DorsAttnB_PostC_1 R',      [  102    0    0]; ...   % 17Networks_RH_DorsAttnB_PostC_1
       69, 'DorsAttnB_PostC_2 R',      [  102    0    0]; ...   % 17Networks_RH_DorsAttnB_PostC_2
       70, 'DorsAttnB_FEF_1 R',        [  102    0    0]; ...   % 17Networks_RH_DorsAttnB_FEF_1
       71, 'SalVentAttnA_ParOper_1 R', [    0  102    0]; ...   % 17Networks_RH_SalVentAttnA_ParOper_1
       72, 'SalVentAttnA_Ins_1 R',     [    0  102    0]; ...   % 17Networks_RH_SalVentAttnA_Ins_1
       73, 'SalVentAttnA_ParMed_1 R',  [    0  102    0]; ...   % 17Networks_RH_SalVentAttnA_ParMed_1
       74, 'SalVentAttnA_FrMed_1 R',   [    0  102    0]; ...   % 17Networks_RH_SalVentAttnA_FrMed_1
       75, 'SalVentAttnB_IPL_1 R',     [  255  215    0]; ...   % 17Networks_RH_SalVentAttnB_IPL_1
       76, 'SalVentAttnB_PFCl_1 R',    [  255  215    0]; ...   % 17Networks_RH_SalVentAttnB_PFCl_1
       77, 'SalVentAttnB_PFCmp_1 R',   [  255  215    0]; ...   % 17Networks_RH_SalVentAttnB_PFCmp_1
       78, 'LimbicB_OFC_1 R',          [    0  204    0]; ...   % 17Networks_RH_LimbicB_OFC_1
       79, 'LimbicA_TempPole_1 R',     [  255    0    0]; ...   % 17Networks_RH_LimbicA_TempPole_1
       80, 'ContA_IPS_1 R',            [  102  102  255]; ...   % 17Networks_RH_ContA_IPS_1
       81, 'ContA_PFCl_1 R',           [  102  102  255]; ...   % 17Networks_RH_ContA_PFCl_1
       82, 'ContA_PFCl_2 R',           [  102  102  255]; ...   % 17Networks_RH_ContA_PFCl_2
       83, 'ContB_Temp_1 R',           [  255  177  100]; ...   % 17Networks_RH_ContB_Temp_1
       84, 'ContB_IPL_1 R',            [  255  177  100]; ...   % 17Networks_RH_ContB_IPL_1
       85, 'ContB_PFCld_1 R',          [  255  177  100]; ...   % 17Networks_RH_ContB_PFCld_1
       86, 'ContB_PFClv_1 R',          [  255  177  100]; ...   % 17Networks_RH_ContB_PFClv_1
       87, 'ContC_Cingp_1 R',          [    0  255  255]; ...   % 17Networks_RH_ContC_Cingp_1
       88, 'ContC_pCun_1 R',           [    0  255  255]; ...   % 17Networks_RH_ContC_pCun_1
       89, 'DefaultA_IPL_1 R',         [  255    0  255]; ...   % 17Networks_RH_DefaultA_IPL_1
       90, 'DefaultA_PFCd_1 R',        [  255    0  255]; ...   % 17Networks_RH_DefaultA_PFCd_1
       91, 'DefaultA_pCunPCC_1 R',     [  255    0  255]; ...   % 17Networks_RH_DefaultA_pCunPCC_1
       92, 'DefaultA_PFCm_1 R',        [  255    0  255]; ...   % 17Networks_RH_DefaultA_PFCm_1
       93, 'DefaultB_PFCd_1 R',        [  102    0    0]; ...   % 17Networks_RH_DefaultB_PFCd_1
       94, 'DefaultB_PFCv_1 R',        [  102    0    0]; ...   % 17Networks_RH_DefaultB_PFCv_1
       95, 'DefaultB_PFCv_2 R',        [  102    0    0]; ...   % 17Networks_RH_DefaultB_PFCv_2
       96, 'DefaultC_Rsp_1 R',         [    0  102    0]; ...   % 17Networks_RH_DefaultC_Rsp_1
       97, 'DefaultC_PHC_1 R',         [    0  102    0]; ...   % 17Networks_RH_DefaultC_PHC_1
       98, 'TempPar_1 R',              [  255  215    0]; ...   % 17Networks_RH_TempPar_1
       99, 'TempPar_2 R',              [  255  215    0]; ...   % 17Networks_RH_TempPar_2
      100, 'TempPar_3 R',              [  255  215    0]; ...   % 17Networks_RH_TempPar_3
 };
